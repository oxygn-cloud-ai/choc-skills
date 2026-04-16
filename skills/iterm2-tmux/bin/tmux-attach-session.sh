#!/bin/bash
# Set up iTerm2 tab color, background image, title, then attach tmux.
# Usage: tmux-attach-session.sh <session> <label> <color_index>
set -euo pipefail

SESSION="${1:?session required}"
LABEL="${2:?label required}"
INDEX="${3:-0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BG_DIR="$SCRIPT_DIR/.session-backgrounds"

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

# Set tab title (persists because tmux has set-titles off + allow-rename off)
printf '\033]0;%s\007' "$LABEL"

# Set tab color
printf '\033]6;1;bg;red;brightness;%s\a' "$r"
printf '\033]6;1;bg;green;brightness;%s\a' "$g"
printf '\033]6;1;bg;blue;brightness;%s\a' "$b"

# Set background image if available
bg_path="$BG_DIR/${SESSION}.png"
if [[ -f "$bg_path" ]]; then
  b64_path=$(printf '%s' "$bg_path" | base64)
  printf '\033]1337;SetBackgroundImageFile=%s\a' "$b64_path"
fi

# Replace this process with tmux
exec tmux attach -t "$SESSION"
