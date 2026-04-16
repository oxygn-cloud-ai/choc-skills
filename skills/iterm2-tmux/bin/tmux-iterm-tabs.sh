#!/bin/bash
# Open iTerm2 tabs for tmux sessions.
#
# Mode:
#   tmux-iterm-tabs.sh  — autostart: opens one iTerm2 tab per unattached tmux
#                         session discovered in ${TMUX_REPOS_DIR:-~/Repos}.
#
# Environment overrides:
#   TMUX_REPOS_DIR        — path to repos directory (default: ~/Repos)
#   TMUX_SESSIONS_SCRIPT  — path to tmux-sessions.sh (default: alongside this script)
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      echo "Usage: $(basename "$0")"
      echo "  Open iTerm2 tabs for all unattached tmux sessions."
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
# MODE: autostart (all unattached sessions)
# ===========================================================================

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
