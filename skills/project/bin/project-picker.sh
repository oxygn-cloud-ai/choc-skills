#!/usr/bin/env bash
set -euo pipefail

# project-picker.sh — Two-level TUI for navigating project tmux sessions
# Works in any terminal (iTerm2, Blink, Moshi, Prompt 3) over SSH/Mosh
#
# Supports two session models:
#   - Per-role sessions: grouped by PROJECT env var (set by /project:launch)
#   - Standalone sessions: legacy single-session-per-repo (backward compatible)
#
# Usage: project-picker.sh
# Bind in tmux: bind-key P display-popup -E -w 60 -h 20 "~/.local/bin/project-picker.sh"

# --- Colors (ANSI, universally supported) ---
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  BOLD='\033[1m'
  DIM='\033[2m'
  GREEN='\033[32m'
  YELLOW='\033[33m'
  CYAN='\033[36m'
  RED='\033[31m'
  RESET='\033[0m'
else
  # shellcheck disable=SC2034
  BOLD='' DIM='' GREEN='' YELLOW='' CYAN='' RED='' RESET=''
fi

# --- Helpers ---
clear_screen() { printf '\033[2J\033[H'; }

draw_box_top() {
  local w=$1
  printf '┌'; printf '─%.0s' $(seq 1 "$w"); printf '┐\n'
}

draw_box_bottom() {
  local w=$1
  printf '└'; printf '─%.0s' $(seq 1 "$w"); printf '┘\n'
}

draw_row() {
  local w=$1 content=$2
  # Strip ANSI for length calculation
  local stripped
  stripped=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
  local slen=${#stripped}
  local pad=$((w - slen))
  [ "$pad" -lt 0 ] && pad=0
  printf '│ %b%*s│\n' "$content" "$pad" ""
}

format_age() {
  local activity=$1
  local now
  now=$(date +%s)
  local diff=$((now - activity))
  if [ "$diff" -lt 60 ]; then
    echo "${diff}s ago"
  elif [ "$diff" -lt 3600 ]; then
    echo "$((diff / 60))m ago"
  elif [ "$diff" -lt 86400 ]; then
    echo "$((diff / 3600))h ago"
  else
    echo "$((diff / 86400))d ago"
  fi
}

# --- Session discovery ---

# Get tmux env var for a session, returns empty string on failure
get_session_env() {
  local session="$1" var="$2"
  local val
  val=$(tmux show-environment -t "$session" "$var" 2>/dev/null | cut -d= -f2-) || true
  # tmux prints "-VAR" when var is removed; filter that out
  if [[ "$val" == -* ]] || [[ -z "$val" ]]; then
    echo ""
  else
    echo "$val"
  fi
}

# Build project list: groups per-role sessions by PROJECT, keeps standalone sessions as-is
# Output format: "type:name" where type is "project" or "standalone"
get_projects() {
  local -A seen_projects
  local entries=()

  while IFS= read -r s; do
    [ -z "$s" ] && continue
    local proj
    proj=$(get_session_env "$s" "PROJECT")
    if [ -n "$proj" ]; then
      # Per-role session — group under project
      if [ -z "${seen_projects[$proj]+x}" ]; then
        seen_projects["$proj"]=1
        entries+=("project:$proj")
      fi
    else
      # Standalone session
      entries+=("standalone:$s")
    fi
  done < <(tmux ls -F '#{session_name}' 2>/dev/null || true)

  printf '%s\n' "${entries[@]}"
}

# Get role count and active count for a project (per-role sessions)
get_project_role_count() {
  local project="$1" count=0
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    local proj
    proj=$(get_session_env "$s" "PROJECT")
    [ "$proj" = "$project" ] && count=$((count + 1))
  done < <(tmux ls -F '#{session_name}' 2>/dev/null || true)
  echo "$count"
}

get_project_active_count() {
  local project="$1" count=0 now
  now=$(date +%s)
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    local proj
    proj=$(get_session_env "$s" "PROJECT")
    [ "$proj" = "$project" ] || continue
    # Check session activity (most recent window activity)
    local activity
    activity=$(tmux list-windows -t "$s" -F '#{window_activity}' 2>/dev/null | sort -rn | head -1)
    [ -z "$activity" ] && continue
    local diff=$((now - activity))
    [ "$diff" -lt 300 ] && count=$((count + 1))
  done < <(tmux ls -F '#{session_name}' 2>/dev/null || true)
  echo "$count"
}

# Get window count and active count for a standalone session
get_window_count() {
  local session=$1
  tmux list-windows -t "$session" 2>/dev/null | wc -l | tr -d ' '
}

get_standalone_active_count() {
  local session=$1 count=0 now
  now=$(date +%s)
  while read -r activity; do
    [ -z "$activity" ] && continue
    local diff=$((now - activity))
    [ "$diff" -lt 300 ] && count=$((count + 1))
  done < <(tmux list-windows -t "$session" -F '#{window_activity}' 2>/dev/null)
  echo "$count"
}

# --- Key mapping ---
LETTERS=(a b c d e f g h i j k l m n o p q r s t u v w x y z)

# --- Level 1: Project Selection ---
show_projects() {
  local entries=()
  while IFS= read -r e; do
    [ -n "$e" ] && entries+=("$e")
  done < <(get_projects)

  if [ ${#entries[@]} -eq 0 ]; then
    clear_screen
    echo "No tmux sessions found. Run /project:launch to create sessions."
    exit 0
  fi

  while true; do
    clear_screen
    local width=56

    draw_box_top "$width"
    draw_row "$width" "${BOLD}Projects${RESET}                                 ${DIM}[?] Help${RESET}"
    draw_row "$width" ""

    local idx=0
    for entry in "${entries[@]}"; do
      local etype ename
      etype="${entry%%:*}"
      ename="${entry#*:}"

      local letter="${LETTERS[$idx]}"
      local count_label active_count indicator

      if [ "$etype" = "project" ]; then
        count_label="$(get_project_role_count "$ename") roles"
        active_count=$(get_project_active_count "$ename")
      else
        count_label="$(get_window_count "$ename") windows"
        active_count=$(get_standalone_active_count "$ename")
      fi

      if [ "$active_count" -gt 0 ]; then
        indicator="${GREEN}●${RESET}"
      else
        indicator="${DIM}○${RESET}"
      fi

      local npad=$((20 - ${#ename}))
      [ "$npad" -lt 1 ] && npad=1
      draw_row "$width" "  ${BOLD}${letter})${RESET} ${CYAN}${ename}${RESET}$(printf '%*s' "$npad" '')${count_label}  ${active_count} active ${indicator}"
      idx=$((idx + 1))
    done

    draw_row "$width" ""
    draw_row "$width" "  ${DIM}Press a-${LETTERS[$((idx - 1))]} to select, r refresh, q quit${RESET}"
    draw_box_bottom "$width"

    local key
    IFS= read -rsn1 key

    case "$key" in
      q) clear_screen; exit 0 ;;
      r) continue ;;
      '?')
        clear_screen
        echo -e "${BOLD}Project Picker Help${RESET}\n"
        echo "Level 1 (Projects):"
        echo "  a-z    Select project by letter"
        echo "  r      Refresh session list"
        echo "  q      Quit picker"
        echo "  ?      Show this help"
        echo ""
        echo "Level 2 (Roles):"
        echo "  a-z    Attach to specific role session"
        echo "  *      Attach to master role (or first window)"
        echo "  Esc    Back to project list"
        echo "  r      Refresh"
        echo "  q      Quit"
        echo ""
        echo "tmux shortcut: Prefix + Shift+P opens this picker"
        echo ""
        echo -e "${DIM}Press any key to return...${RESET}"
        read -rsn1
        continue
        ;;
      *)
        local selected_idx=-1
        for i in "${!LETTERS[@]}"; do
          if [ "${LETTERS[$i]}" = "$key" ] && [ "$i" -lt "${#entries[@]}" ]; then
            selected_idx=$i
            break
          fi
        done
        if [ "$selected_idx" -ge 0 ]; then
          local sel_entry="${entries[$selected_idx]}"
          local sel_type="${sel_entry%%:*}"
          local sel_name="${sel_entry#*:}"
          if [ "$sel_type" = "project" ]; then
            show_project_roles "$sel_name"
          else
            show_standalone_windows "$sel_name"
          fi
        fi
        ;;
    esac
  done
}

# --- Level 2: Role Selection (per-role sessions grouped by PROJECT) ---
show_project_roles() {
  local project=$1

  while true; do
    clear_screen
    local width=56

    # Collect role sessions sorted by ROLE_INDEX
    local role_names=()
    local role_sessions=()
    local role_activities=()

    local raw_entries=()
    while IFS= read -r s; do
      [ -z "$s" ] && continue
      local proj
      proj=$(get_session_env "$s" "PROJECT")
      [ "$proj" = "$project" ] || continue
      local role role_idx activity
      role=$(get_session_env "$s" "ROLE")
      role_idx=$(get_session_env "$s" "ROLE_INDEX")
      [ -z "$role" ] && role="$s"
      [ -z "$role_idx" ] && role_idx="99"
      activity=$(tmux list-windows -t "$s" -F '#{window_activity}' 2>/dev/null | sort -rn | head -1)
      [ -z "$activity" ] && activity="0"
      raw_entries+=("${role_idx}:${role}:${s}:${activity}")
    done < <(tmux ls -F '#{session_name}' 2>/dev/null || true)

    # Sort by ROLE_INDEX
    local sorted=()
    while IFS= read -r line; do
      [ -n "$line" ] && sorted+=("$line")
    done < <(printf '%s\n' "${raw_entries[@]}" | sort -t: -k1 -n)

    for entry in "${sorted[@]}"; do
      IFS=: read -r _ role session activity <<< "$entry"
      role_names+=("$role")
      role_sessions+=("$session")
      role_activities+=("$activity")
    done

    draw_box_top "$width"
    draw_row "$width" "${BOLD}${CYAN}${project}${RESET}                              ${DIM}[Esc] Back${RESET}"
    draw_row "$width" ""

    local idx=0
    for role in "${role_names[@]}"; do
      local letter="${LETTERS[$idx]}"
      local activity="${role_activities[$idx]}"
      local now
      now=$(date +%s)
      local diff=$((now - activity))
      local indicator age_str

      if [ "$diff" -lt 300 ]; then
        indicator="${GREEN}● active${RESET}"
        age_str=$(format_age "$activity")
      else
        indicator="${DIM}○ idle${RESET}"
        age_str=""
      fi

      local name_pad=$((16 - ${#role}))
      [ "$name_pad" -lt 1 ] && name_pad=1
      draw_row "$width" "  ${BOLD}${letter})${RESET} ${role}$(printf '%*s' "$name_pad" '')${indicator}  ${DIM}${age_str}${RESET}"
      idx=$((idx + 1))
    done

    draw_row "$width" ""
    draw_row "$width" "  ${DIM}Press a-${LETTERS[$((idx - 1))]} to attach, * master, Esc back, q quit${RESET}"
    draw_box_bottom "$width"

    local key
    IFS= read -rsn1 key

    case "$key" in
      q) clear_screen; exit 0 ;;
      r) continue ;;
      '*')
        # Attach to master role session (or first if master not found)
        local master_session=""
        for i in "${!role_names[@]}"; do
          if [ "${role_names[$i]}" = "master" ]; then
            master_session="${role_sessions[$i]}"
            break
          fi
        done
        [ -z "$master_session" ] && master_session="${role_sessions[0]}"
        clear_screen
        exec tmux attach-session -t "$master_session"
        ;;
      $'\x1b')
        local seq=""
        read -rsn2 -t 0.1 seq 2>/dev/null || true
        if [ -z "$seq" ]; then
          return
        fi
        continue
        ;;
      *)
        local selected_idx=-1
        for i in "${!LETTERS[@]}"; do
          if [ "${LETTERS[$i]}" = "$key" ] && [ "$i" -lt "${#role_sessions[@]}" ]; then
            selected_idx=$i
            break
          fi
        done
        if [ "$selected_idx" -ge 0 ]; then
          local target_session="${role_sessions[$selected_idx]}"
          clear_screen
          exec tmux attach-session -t "$target_session"
        fi
        ;;
    esac
  done
}

# --- Level 2: Window Selection (standalone sessions, backward compatible) ---
show_standalone_windows() {
  local session=$1

  while true; do
    clear_screen
    local width=56

    local windows=()
    local activities=()
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      local wname wactivity
      wname=$(echo "$line" | awk '{print $1}')
      wactivity=$(echo "$line" | awk '{print $2}')
      windows+=("$wname")
      activities+=("$wactivity")
    done < <(tmux list-windows -t "$session" -F '#{window_name} #{window_activity}' 2>/dev/null || true)

    draw_box_top "$width"
    draw_row "$width" "${BOLD}${CYAN}${session}${RESET}                              ${DIM}[Esc] Back${RESET}"
    draw_row "$width" ""

    local idx=0
    for wname in "${windows[@]}"; do
      local letter="${LETTERS[$idx]}"
      local activity="${activities[$idx]}"
      local now
      now=$(date +%s)
      local diff=$((now - activity))
      local indicator age_str

      if [ "$diff" -lt 300 ]; then
        indicator="${GREEN}● active${RESET}"
        age_str=$(format_age "$activity")
      else
        indicator="${DIM}○ idle${RESET}"
        age_str=""
      fi

      local name_pad=$((16 - ${#wname}))
      [ "$name_pad" -lt 1 ] && name_pad=1
      draw_row "$width" "  ${BOLD}${letter})${RESET} ${wname}$(printf '%*s' "$name_pad" '')${indicator}  ${DIM}${age_str}${RESET}"
      idx=$((idx + 1))
    done

    draw_row "$width" ""
    draw_row "$width" "  ${DIM}Press a-${LETTERS[$((idx - 1))]} to attach, * all, Esc back, q quit${RESET}"
    draw_box_bottom "$width"

    local key
    IFS= read -rsn1 key

    case "$key" in
      q) clear_screen; exit 0 ;;
      r) continue ;;
      '*')
        clear_screen
        exec tmux attach-session -t "$session"
        ;;
      $'\x1b')
        local seq=""
        read -rsn2 -t 0.1 seq 2>/dev/null || true
        if [ -z "$seq" ]; then
          return
        fi
        continue
        ;;
      *)
        local selected_idx=-1
        for i in "${!LETTERS[@]}"; do
          if [ "${LETTERS[$i]}" = "$key" ] && [ "$i" -lt "${#windows[@]}" ]; then
            selected_idx=$i
            break
          fi
        done
        if [ "$selected_idx" -ge 0 ]; then
          local target_window="${windows[$selected_idx]}"
          clear_screen
          exec tmux select-window -t "$session:$target_window" \; attach-session -t "$session"
        fi
        ;;
    esac
  done
}

# --- Entry point ---
if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not found. Install with: brew install tmux"
  exit 1
fi

if ! tmux ls >/dev/null 2>&1; then
  echo "No tmux server running. Run /project:launch first."
  exit 0
fi

show_projects
