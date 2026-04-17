#!/usr/bin/env bash
set -uo pipefail

# project-picker-fzf — FZF-based role picker for /project:launch tmux sessions.
#
# Implements: CPT-73 Option 6 (Hybrid letters + FZF picker)
#
# Use as:
#   project-picker-fzf.sh                 # interactive: list roles → pick → jump
#   project-picker-fzf.sh --list          # just enumerate roles (no fzf)
#   project-picker-fzf.sh --session <s>   # target a specific tmux session
#   project-picker-fzf.sh --help
#
# iTerm2 keybinding: bind ⌘⇧P to send-keys:
#   "bash ~/.local/bin/project-picker-fzf.sh" + Enter
# The keymap JSON at skills/project/docs/iterm2-keymap.json has a ready-made entry.

SCRIPT_NAME="$(basename "$0")"
TMUX_SESSION="${TMUX_SESSION:-}"
MODE="interactive"

usage() {
  cat <<EOF
${SCRIPT_NAME} — FZF-based role picker for /project:launch tmux sessions

USAGE
  ${SCRIPT_NAME}                     Interactive FZF picker
  ${SCRIPT_NAME} --list              List roles in the current tmux session
  ${SCRIPT_NAME} --session <name>    Target a named tmux session (else current TMUX session)
  ${SCRIPT_NAME} --help              Show this help

ENV
  TMUX_SESSION    Default session name if --session not provided

EXIT
  0  window selected and switched to, or --list completed
  2  no fzf available / no active tmux / invalid flag
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --list) MODE="list" ;;
    --session) TMUX_SESSION="$2"; shift ;;
    --session=*) TMUX_SESSION="${1#*=}" ;;
    *) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not installed — picker requires a running tmux session" >&2
  exit 2
fi

# Resolve session name
if [ -z "$TMUX_SESSION" ]; then
  if [ -n "${TMUX:-}" ]; then
    TMUX_SESSION=$(tmux display-message -p '#S' 2>/dev/null || true)
  fi
fi

if [ -z "$TMUX_SESSION" ]; then
  # Use the first tmux session as fallback
  TMUX_SESSION=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | head -1 || true)
fi

if [ -z "$TMUX_SESSION" ]; then
  echo "no tmux session found — run /project:launch first" >&2
  exit 2
fi

if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  echo "tmux session '${TMUX_SESSION}' does not exist" >&2
  exit 2
fi

# Enumerate windows — one per role
windows=$(tmux list-windows -t "$TMUX_SESSION" -F '#{window_index}: #{window_name}' 2>/dev/null)
if [ -z "$windows" ]; then
  echo "no windows in session '${TMUX_SESSION}'" >&2
  exit 2
fi

if [ "$MODE" = "list" ]; then
  printf '%s\n' "$windows"
  exit 0
fi

# Interactive mode — needs fzf
if ! command -v fzf >/dev/null 2>&1; then
  cat <<EOF >&2
fzf not installed — falling back to plain list.

Install fzf for interactive picker:
  macOS:  brew install fzf
  Linux:  apt/dnf/pacman install fzf

Windows in session '${TMUX_SESSION}':
EOF
  printf '%s\n' "$windows" >&2
  exit 2
fi

# Run fzf
selected=$(printf '%s\n' "$windows" | fzf \
  --prompt "project:$TMUX_SESSION > " \
  --height 40% \
  --border \
  --reverse \
  --header "Pick a role (Enter to jump, Esc to cancel)" \
  --no-mouse)

if [ -z "$selected" ]; then
  # User cancelled
  exit 0
fi

# Extract window index (before the colon)
window_index="${selected%%:*}"

# Switch to the selected window
if [ -n "${TMUX:-}" ]; then
  # Already inside tmux — use select-window
  tmux select-window -t "${TMUX_SESSION}:${window_index}"
else
  # Outside tmux — attach and select
  tmux attach-session -t "$TMUX_SESSION" \; select-window -t "$window_index"
fi
