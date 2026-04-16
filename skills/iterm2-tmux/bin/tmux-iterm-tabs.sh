#!/bin/bash
# Open iTerm2 tabs for tmux sessions.
#
# Modes:
#   tmux-iterm-tabs.sh                     — autostart: opt-in via AUTOSTART_ENABLED=true in
#                                            ~/.config/iterm2-tmux/config. Default is no-op
#                                            so a shell launch inside iTerm2 no longer opens
#                                            a tab per global tmux session (the old "tab per
#                                            /Repos/* entry" behavior that pre-dated the
#                                            per-project-window architecture).
#   tmux-iterm-tabs.sh --session <project> — open one iTerm2 window for a /project:launch
#                                            tmux session, with one tab per WINDOW (role).
#                                            Iterates `tmux list-windows -t <project>`; does
#                                            NOT enumerate global tmux sessions.
#
# Environment overrides:
#   TMUX_REPOS_DIR        — path to repos directory (autostart mode only; default: ~/Repos)
#   TMUX_SESSIONS_SCRIPT  — path to tmux-sessions.sh (autostart mode only)
#   AUTOSTART_ENABLED     — "true" to allow autostart mode to do work (default: no-op)
set -euo pipefail

# Source user config if available
[[ -f "${HOME}/.config/iterm2-tmux/config" ]] && source "${HOME}/.config/iterm2-tmux/config"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPOS_DIR="${TMUX_REPOS_DIR:-$HOME/Repos}"
SESSIONS_SCRIPT="${TMUX_SESSIONS_SCRIPT:-$SCRIPT_DIR/tmux-sessions.sh}"
ATTACH_SCRIPT="$SCRIPT_DIR/tmux-attach-session.sh"
BG_DIR="$HOME/.local/share/iterm2-tmux/backgrounds"
BG_GENERATOR="$SCRIPT_DIR/gen-session-bg.py"
export PATH="/opt/homebrew/bin:$PATH"

# --- Argument parsing ---

TARGET_PROJECT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --session)
      [[ -z "${2:-}" ]] && { echo "[ERROR] --session requires a project name." >&2; exit 1; }
      TARGET_PROJECT="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--session <project>]"
      echo "  No args:              Open tabs for all unattached tmux sessions"
      echo "  --session <project>:  Open tabs for one project's role sessions"
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# --- Shared helpers ---

sanitize_name() {
  local n="$1"
  n="${n//\./-}"
  n="${n//:/-}"
  n="${n//=/-}"
  n="${n//+/-}"
  n="${n// /-}"
  echo "$n"
}

lookup_label() {
  local session="$1"
  for dir in "$REPOS_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    local name safe
    name="$(basename "$dir")"
    safe="$(sanitize_name "$name")"
    if [[ "$safe" == "$session" ]]; then
      echo "$name"
      return
    fi
  done
  echo "$session"
}

escape_applescript() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//\'/\'}"
  echo "$s"
}

generate_background() {
  local label="$1" session_name="$2" idx="$3"
  if command -v python3 &>/dev/null && [[ -f "$BG_GENERATOR" ]]; then
    mkdir -p "$BG_DIR"
    local bg_path="$BG_DIR/${session_name}.png"
    if [[ ! -f "$bg_path" ]]; then
      python3 "$BG_GENERATOR" "$label" "$bg_path" "$idx" 2>/dev/null || \
        echo "[WARN] Failed to generate background for '$session_name'" >&2
    fi
  fi
}

# --- Autostart opt-in gate (runs BEFORE preflight) ---
# Autostart mode (no --session arg) used to open a tab per global tmux session.
# On hosts with many pre-existing tmux sessions this produced tab spam for
# unrelated projects. Default is now no-op unless explicitly enabled. Gate runs
# before the preflight checks so Linux/CI (no iTerm2, no tmux) can exit clean.
if [[ -z "$TARGET_PROJECT" ]] && [[ "${AUTOSTART_ENABLED:-false}" != "true" ]]; then
  exit 0
fi

# --- Preflight checks ---

if ! command -v tmux &>/dev/null; then
  echo "[ERROR] tmux not found in PATH." >&2
  exit 1
fi

if [[ ! -x "$ATTACH_SCRIPT" ]]; then
  echo "[ERROR] Attach script not found: $ATTACH_SCRIPT" >&2
  exit 1
fi

if ! pgrep -qf "iTerm"; then
  echo "[ERROR] iTerm2 is not running. Cannot open tabs." >&2
  exit 1
fi

# ===========================================================================
# MODE: --session <project> (one iTerm2 tab per window of a single tmux session)
# ===========================================================================
#
# Architecture note: /project:launch creates ONE tmux session per project, with
# one named WINDOW per role. This mode iterates those windows — NOT sessions —
# so we don't leak tabs from other projects' tmux sessions. Earlier iterations
# of this mode filtered sessions by a PROJECT tmux env var that /project:launch
# never actually set, so it produced zero tabs. Now we use `tmux list-windows`
# on the single project session, which is the authoritative source.

# Helper: render an AppleScript line that sets the background image if one exists.
# Used in both --session and autostart paths; defined once here at file scope so
# it's available to every mode below.
bg_applescript_line() {
  local sname="$1"
  local bgfile="$BG_DIR/${sname}.png"
  if [[ -f "$bgfile" ]]; then
    local safe_bg
    safe_bg="${bgfile//\\/\\\\}"
    safe_bg="${safe_bg//\"/\\\"}"
    echo "      set background image to \"$safe_bg\""
  fi
}

if [[ -n "$TARGET_PROJECT" ]]; then
  # 1. Verify the project's tmux session exists. If not, /project:launch has not
  #    run yet (or was run in --dry-run mode), and there are no windows to tab.
  if ! tmux has-session -t "=$TARGET_PROJECT" 2>/dev/null; then
    echo "[ERROR] tmux session '$TARGET_PROJECT' does not exist." >&2
    echo "Run /project:launch first to create it (without --dry-run)." >&2
    exit 1
  fi

  # 2. Enumerate WINDOWS of the project session. Format: <idx>|<name>
  #    We pipe through read to an array to avoid mapfile portability issues
  #    on older bash (macOS default bash 3.2 does not have mapfile).
  win_entries=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && win_entries+=("$line")
  done < <(tmux list-windows -t "=$TARGET_PROJECT" \
    -F '#{window_index}|#{window_name}' 2>/dev/null)

  if [[ ${#win_entries[@]} -eq 0 ]]; then
    echo "[ERROR] tmux session '$TARGET_PROJECT' has no windows." >&2
    exit 1
  fi

  # 3. Generate a distinct background image per role-window. The BG filename
  #    namespaces on project name so two different projects can each have a
  #    "master" window without clobbering each other's backgrounds.
  for entry in "${win_entries[@]}"; do
    IFS='|' read -r w_idx w_name <<< "$entry"
    bg_key="${TARGET_PROJECT}-${w_name}"
    generate_background "$w_name" "$bg_key" "$w_idx"
  done

  # 4. Build AppleScript — create a new iTerm2 window, one tab per window.
  TMPSCRIPT=$(mktemp /tmp/tmux-iterm.XXXXXX) || {
    echo "[ERROR] Failed to create temp file." >&2
    exit 1
  }
  trap 'rm -f "$TMPSCRIPT"' EXIT

  # First role-window gets the freshly-created iTerm2 window's initial session.
  IFS='|' read -r first_idx first_name <<< "${win_entries[0]}"
  safe_project="$(escape_applescript "$TARGET_PROJECT")"
  safe_first_name="$(escape_applescript "$first_name")"
  first_bg_line="$(bg_applescript_line "${TARGET_PROJECT}-${first_name}")"

  # Lock sentinels suppress the autostart path if a user opens a new shell
  # during/right-after tab creation; see autostart guard below.
  echo "$TARGET_PROJECT" > "/tmp/.iterm2-tmux-session-active"
  rm -rf "/tmp/.iterm2-tmux-autostart" 2>/dev/null || true
  mkdir "/tmp/.iterm2-tmux-autostart" 2>/dev/null || true

  # Attach command: the 1st arg is the tmux session; the 5th arg is the window
  # name to select-window into after attach. tmux-attach-session.sh handles
  # both args.
  cat > "$TMPSCRIPT" << HEADER
tell application "iTerm2"
  activate
  create window with default profile
  set newWindow to current window
  tell newWindow
    tell current session
      set name to "$safe_first_name"
${first_bg_line}
      write text "exec $ATTACH_SCRIPT '$safe_project' '$safe_first_name' $first_idx '$safe_project' '$safe_first_name'"
    end tell
HEADER

  # Remaining role-windows become additional tabs within the same iTerm2 window.
  rest_entries=()
  [[ ${#win_entries[@]} -gt 1 ]] && rest_entries=("${win_entries[@]:1}")

  for entry in ${rest_entries[@]+"${rest_entries[@]}"}; do
    IFS='|' read -r w_idx w_name <<< "$entry"
    safe_name="$(escape_applescript "$w_name")"
    tab_bg_line="$(bg_applescript_line "${TARGET_PROJECT}-${w_name}")"
    cat >> "$TMPSCRIPT" << EOF
    set newTab to (create tab with default profile)
    tell current session of newTab
      set name to "$safe_name"
${tab_bg_line}
      write text "exec $ATTACH_SCRIPT '$safe_project' '$safe_name' $w_idx '$safe_project' '$safe_name'"
    end tell
EOF
  done

  cat >> "$TMPSCRIPT" << FOOTER
    select
  end tell
end tell

delay 0.5
tell application "System Events"
  tell process "iTerm2"
    click menu item "Edit Window Title" of menu 1 of menu bar item "Window" of menu bar 1
    delay 0.5
    keystroke "a" using command down
    keystroke "$safe_project"
    key code 36
  end tell
end tell
FOOTER

  if ! osascript "$TMPSCRIPT"; then
    echo "[ERROR] AppleScript execution failed." >&2
    exit 1
  fi

  # Refresh locks post-AppleScript so late-arriving shells still see the lock.
  touch "/tmp/.iterm2-tmux-session-active" 2>/dev/null || true
  touch "/tmp/.iterm2-tmux-autostart" 2>/dev/null || true

  exit 0
fi

# ===========================================================================
# MODE: autostart (all unattached sessions) — OPT-IN via AUTOSTART_ENABLED=true
# ===========================================================================
#
# This path used to run unconditionally from ~/.zshrc whenever a shell opened
# inside iTerm2. That was fine when each /Repos/* subdir had its own tmux
# session and the user wanted one iTerm2 tab per project. It is WRONG for the
# per-project-window architecture: it produced a tab per global tmux session
# (17+ on this host), one of which might attach to the "right" project while
# the rest are noise. The opt-in gate above this point (just after arg parsing)
# exits early when AUTOSTART_ENABLED is not true — so reaching this section
# means the user explicitly opted in.

# Skip if --session mode recently ran (prevents tab explosion from new shells)
SESSION_LOCK="/tmp/.iterm2-tmux-session-active"
if [[ -f "$SESSION_LOCK" ]]; then
  lock_age=$(( $(date +%s) - $(/usr/bin/stat -f%m "$SESSION_LOCK") ))
  if (( lock_age < 60 )); then
    exit 0
  fi
fi

# Wait for external volume if needed (up to 10s)
for _ in {1..10}; do
  [[ -d "$REPOS_DIR" ]] && break
  sleep 1
done
[[ -d "$REPOS_DIR" ]] || { echo "[ERROR] Repos dir not found: $REPOS_DIR" >&2; exit 1; }

# Ensure tmux sessions exist for non-worktree repos
if ! "$SESSIONS_SCRIPT"; then
  echo "[ERROR] $SESSIONS_SCRIPT failed." >&2
  exit 1
fi

# Get sessions
if ! all_sessions=$(tmux ls -F '#{session_name}' 2>/dev/null); then
  echo "[ERROR] Failed to list tmux sessions." >&2
  exit 1
fi
[[ -z "$all_sessions" ]] && { echo "[ERROR] No tmux sessions found." >&2; exit 1; }

if ! attached=$(tmux ls -F '#{session_name} #{session_attached}' 2>/dev/null); then
  echo "[ERROR] Failed to query attached sessions." >&2
  exit 1
fi
attached=$(echo "$attached" | awk '$2 > 0 {print $1}')

# Filter to only unattached sessions
new_sessions=()
while IFS= read -r s; do
  if ! echo "$attached" | grep -qx "$s"; then
    new_sessions+=("$s")
  fi
done <<< "$all_sessions"

if [[ ${#new_sessions[@]} -eq 0 ]]; then
  echo "All sessions already attached."
  exit 0
fi

# Generate background images
if command -v python3 &>/dev/null && [[ -f "$BG_GENERATOR" ]]; then
  mkdir -p "$BG_DIR"
  idx=0
  for s in "${new_sessions[@]}"; do
    label="$(lookup_label "$s")"
    bg_path="$BG_DIR/${s}.png"
    if [[ ! -f "$bg_path" ]]; then
      python3 "$BG_GENERATOR" "$label" "$bg_path" "$idx" 2>/dev/null || \
        echo "[WARN] Failed to generate background for '$s'" >&2
    fi
    idx=$((idx + 1))
  done
else
  echo "[WARN] python3 or gen-session-bg.py not found, skipping background images." >&2
fi

# Build AppleScript — use current window
first="${new_sessions[0]}"
rest=()
if [[ ${#new_sessions[@]} -gt 1 ]]; then
  rest=("${new_sessions[@]:1}")
fi

TMPSCRIPT=$(mktemp /tmp/tmux-iterm.XXXXXX) || {
  echo "[ERROR] Failed to create temp file." >&2
  exit 1
}
trap 'rm -f "$TMPSCRIPT"' EXIT

first_label="$(lookup_label "$first")"
safe_first_label="$(escape_applescript "$first_label")"
safe_first="$(escape_applescript "$first")"

# Background image AppleScript line for autostart mode
autostart_bg_line() {
  local sname="$1"
  local bgfile="$BG_DIR/${sname}.png"
  if [[ -f "$bgfile" ]]; then
    local safe_bg
    safe_bg="${bgfile//\\/\\\\}"
    safe_bg="${safe_bg//\"/\\\"}"
    echo "      set background image to \"$safe_bg\""
  fi
}

first_auto_bg="$(autostart_bg_line "$first")"

cat > "$TMPSCRIPT" << HEADER
tell application "iTerm2"
  activate
  tell current window
    tell current session
      set name to "$safe_first_label"
${first_auto_bg}
      write text "$ATTACH_SCRIPT '$safe_first' '$safe_first_label' 0"
    end tell
HEADER

idx=1
for s in ${rest[@]+"${rest[@]}"}; do
  label="$(lookup_label "$s")"
  safe_label="$(escape_applescript "$label")"
  safe_s="$(escape_applescript "$s")"
  tab_auto_bg="$(autostart_bg_line "$s")"
  cat >> "$TMPSCRIPT" << EOF
    set newTab to (create tab with default profile)
    tell current session of newTab
      set name to "$safe_label"
${tab_auto_bg}
      write text "$ATTACH_SCRIPT '$safe_s' '$safe_label' $idx"
    end tell
EOF
  idx=$((idx + 1))
done

cat >> "$TMPSCRIPT" << 'FOOTER'
  end tell
end tell
FOOTER

if ! osascript "$TMPSCRIPT"; then
  echo "[ERROR] AppleScript execution failed." >&2
  exit 1
fi
