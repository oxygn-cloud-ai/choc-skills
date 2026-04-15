#!/bin/bash
# Set up iTerm2 tab color, then attach tmux.
# Usage: tmux-attach-session.sh <session> <label> <color_index> [window_title]
set -euo pipefail

SESSION="${1:?session required}"
# $2 (label) — tab title is set via AppleScript, not here
INDEX="${3:-0}"
# $4 accepted for compatibility; window title is set at the iTerm2 level
: "${4:-}"

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

# Replace this process with tmux
exec tmux attach -t "$SESSION"
