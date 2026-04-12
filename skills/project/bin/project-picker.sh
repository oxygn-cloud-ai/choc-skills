#!/usr/bin/env bash
set -euo pipefail

# project-picker.sh — Two-level TUI for navigating project tmux sessions
# Works in any terminal (iTerm2, Blink, Moshi, Prompt 3) over SSH/Mosh
#
# Usage: project-picker.sh
# Bind in tmux: bind-key P run-shell "~/.local/bin/project-picker.sh"

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

# --- Session discovery ---
get_sessions() {
  tmux ls -F '#{session_name}' 2>/dev/null || true
}

get_windows() {
  local session=$1
  tmux list-windows -t "$session" -F '#{window_name} #{window_activity}' 2>/dev/null || true
}

get_window_count() {
  local session=$1
  tmux list-windows -t "$session" 2>/dev/null | wc -l | tr -d ' '
}

get_active_count() {
  local session=$1
  tmux list-windows -t "$session" -F '#{window_activity}' 2>/dev/null | while read -r activity; do
    now=$(date +%s)
    diff=$((now - activity))
    # Consider "active" if activity within last 300 seconds (5 min)
    [ "$diff" -lt 300 ] && echo "active"
  done | wc -l | tr -d ' '
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

# --- Key mapping ---
LETTERS=(a b c d e f g h i j k l m n o p q r s t u v w x y z)

# --- Level 1: Project Selection ---
show_projects() {
  local sessions=()
  while IFS= read -r s; do
    [ -n "$s" ] && sessions+=("$s")
  done < <(get_sessions)

  if [ ${#sessions[@]} -eq 0 ]; then
    clear_screen
    echo "No tmux sessions found. Run /project:launch to create sessions."
    exit 0
  fi

  while true; do
    clear_screen
    local width=52

    draw_box_top "$width"
    draw_row "$width" "${BOLD}Projects${RESET}                             ${DIM}[?] Help${RESET}"
    draw_row "$width" ""

    local idx=0
    for session in "${sessions[@]}"; do
      local letter="${LETTERS[$idx]}"
      local wcount
      wcount=$(get_window_count "$session")
      local acount
      acount=$(get_active_count "$session")
      local indicator
      if [ "$acount" -gt 0 ]; then
        indicator="${GREEN}●${RESET}"
      else
        indicator="${DIM}○${RESET}"
      fi
      draw_row "$width" "  ${BOLD}${letter})${RESET} ${CYAN}${session}${RESET}$(printf '%*s' $((20 - ${#session})) '')${wcount} windows  ${acount} active ${indicator}"
      idx=$((idx + 1))
    done

    draw_row "$width" ""
    draw_row "$width" "  ${DIM}Press a-${LETTERS[$((idx - 1))]} to select, r refresh, q quit${RESET}"
    draw_box_bottom "$width"

    # Read single keypress
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
        echo "  a-k    Attach to specific role window"
        echo "  *      Attach to project session (master window)"
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
        # Check if it's a valid letter selection
        local selected_idx=-1
        for i in "${!LETTERS[@]}"; do
          if [ "${LETTERS[$i]}" = "$key" ] && [ "$i" -lt "${#sessions[@]}" ]; then
            selected_idx=$i
            break
          fi
        done
        if [ "$selected_idx" -ge 0 ]; then
          show_roles "${sessions[$selected_idx]}"
        fi
        ;;
    esac
  done
}

# --- Level 2: Role Selection ---
show_roles() {
  local session=$1

  while true; do
    clear_screen
    local width=52

    local windows=()
    local activities=()
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      local wname wactivity
      wname=$(echo "$line" | awk '{print $1}')
      wactivity=$(echo "$line" | awk '{print $2}')
      windows+=("$wname")
      activities+=("$wactivity")
    done < <(get_windows "$session")

    draw_box_top "$width"
    draw_row "$width" "${BOLD}${CYAN}${session}${RESET}                          ${DIM}[Esc] Back${RESET}"
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
        # Attach to session (lands on current/master window)
        clear_screen
        exec tmux attach-session -t "$session"
        ;;
      $'\x1b')
        # Esc key — could be standalone or start of escape sequence
        # Read additional chars with tiny timeout
        local seq=""
        read -rsn2 -t 0.1 seq 2>/dev/null || true
        if [ -z "$seq" ]; then
          # Standalone Esc — go back
          return
        fi
        # Otherwise it was an escape sequence (arrow key etc) — ignore
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
