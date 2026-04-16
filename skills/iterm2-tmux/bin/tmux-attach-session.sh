#!/bin/bash
# Set up iTerm2 tab color, then attach tmux.
# Usage: tmux-attach-session.sh <session> <label> <color_index> [window_title] [window_name]
#
# Args 1-4 exist for backwards compat. Arg 5 (optional) is the tmux window name
# to select within the session — needed for the per-project-window architecture
# where /project:launch creates one tmux session with many windows and each
# iTerm2 tab should attach into a specific window.
set -euo pipefail

SESSION="${1:?session required}"
# $2 (label) — tab title is set via AppleScript, not here
INDEX="${3:-0}"
# $4 accepted for compatibility; window title is set at the iTerm2 level
: "${4:-}"
WINDOW_NAME="${5:-}"

# Tab color palette (R G B)
TAB_COLORS=(
  "100 40 40"
  "40 90 110"
  "90 55 110"
  "40 90 55"
  "110 85 30"
  "55 55 110"
  "100 45 75"
  "40 100 100"
  "90 75 40"
  "75 40 90"
  "45 85 45"
  "100 55 40"
)

color_entry="${TAB_COLORS[$((INDEX % ${#TAB_COLORS[@]}))]}"
read -r r g b <<< "$color_entry"

# Set tab color
printf '\033]6;1;bg;red;brightness;%s\a' "$r"
printf '\033]6;1;bg;green;brightness;%s\a' "$g"
printf '\033]6;1;bg;blue;brightness;%s\a' "$b"

# Background image is set via AppleScript in tmux-iterm-tabs.sh (trusted path,
# no confirmation dialog). The escape code SetBackgroundImageFile triggers an
# iTerm2 security prompt, so we avoid it here.

# Replace this process with tmux. If a window_name is supplied, attach to the
# session AND select that window; otherwise let tmux pick the active window.
# `tmux attach -t session:window` is documented shorthand for "attach session,
# then switch to this window" — verified via `man tmux` target-window.
if [ -n "$WINDOW_NAME" ]; then
  exec tmux attach -t "${SESSION}:${WINDOW_NAME}"
else
  exec tmux attach -t "$SESSION"
fi
