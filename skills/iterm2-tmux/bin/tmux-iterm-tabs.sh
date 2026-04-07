#!/bin/bash
# Open an iTerm2 window with one named tab per tmux session.
# Skips sessions that already have an attached client.
# Designed to run automatically when iTerm2 starts.
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
BG_DIR="$SCRIPT_DIR/.session-backgrounds"
BG_GENERATOR="$SCRIPT_DIR/gen-session-bg.py"
export PATH="/opt/homebrew/bin:$PATH"

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

# --- Preflight checks ---

if ! command -v tmux &>/dev/null; then
  echo "[ERROR] tmux not found in PATH." >&2
  exit 1
fi

if [[ ! -x "$ATTACH_SCRIPT" ]]; then
  echo "[ERROR] Attach script not found: $ATTACH_SCRIPT" >&2
  exit 1
fi

# Wait for external volume if needed (up to 10s)
for _ in {1..10}; do
  [[ -d "$REPOS_DIR" ]] && break
  sleep 1
done
[[ -d "$REPOS_DIR" ]] || { echo "[ERROR] Repos dir not found: $REPOS_DIR" >&2; exit 1; }

if ! pgrep -qf "iTerm"; then
  echo "[ERROR] iTerm2 is not running. Cannot open tabs." >&2
  exit 1
fi

# --- Ensure tmux sessions exist ---

if ! "$SESSIONS_SCRIPT"; then
  echo "[ERROR] $SESSIONS_SCRIPT failed." >&2
  exit 1
fi

# --- Get sessions ---

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

# --- Generate background images ---

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

# --- Build AppleScript ---

first="${new_sessions[0]}"
rest=("${new_sessions[@]:1}")

TMPSCRIPT=$(mktemp /tmp/tmux-iterm.XXXXXX) || {
  echo "[ERROR] Failed to create temp file." >&2
  exit 1
}
trap 'rm -f "$TMPSCRIPT"' EXIT

first_label="$(lookup_label "$first")"
cat > "$TMPSCRIPT" << HEADER
tell application "iTerm2"
  activate
  tell current window
    tell current session
      set name to "$first_label"
      write text "$ATTACH_SCRIPT '$first' '$first_label' 0"
    end tell
HEADER

idx=1
for s in "${rest[@]}"; do
  label="$(lookup_label "$s")"
  cat >> "$TMPSCRIPT" << EOF
    set newTab to (create tab with default profile)
    tell current session of newTab
      set name to "$label"
      write text "$ATTACH_SCRIPT '$s' '$label' $idx"
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
