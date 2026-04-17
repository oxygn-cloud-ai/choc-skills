#!/bin/bash
# Set up iTerm2 tab color, background image, title, then attach tmux.
#
# Usage (positional — legacy):
#   tmux-attach-session.sh <session> <label> <color_index>
#
# Usage (file handoff — CPT-147):
#   tmux-attach-session.sh --session-file <path> <label> <color_index>
#
# The --session-file form reads the raw session name from <path> (written by
# tmux-iterm-tabs.sh to bytes that would otherwise be unsafe to interpolate
# into AppleScript string literals or shell-quoted command-line arguments:
# newline, CR, tab, single-quote). The helper deletes the file after
# reading it, so each invocation has a single-shot target.
set -euo pipefail

# CPT-147: accept --session-file <path> as an alternative to positional SESSION.
# The file path is written by tmux-iterm-tabs.sh under /tmp with a safe name
# (no shell hazards), so interpolating the PATH is always safe even when the
# VALUE would not be.
if [ "${1:-}" = "--session-file" ]; then
  session_file="${2:?--session-file requires a path argument}"
  if [ ! -f "$session_file" ]; then
    printf 'Error: --session-file %s does not exist\n' "$session_file" >&2
    exit 1
  fi
  # CPT-159: bash command substitution strips ALL trailing newlines
  # from its output. For session names ending in \n bytes, plain
  # SESSION="$(cat file)" would lose them and the name attached here
  # wouldn't match the bytes the writer flushed, breaking CPT-147's
  # stated full-byte round-trip contract. The sentinel-x trick forces
  # a trailing 'x' before substitution, then strips it — everything
  # between survives verbatim.
  SESSION=$(cat "$session_file"; printf x)
  SESSION="${SESSION%x}"
  rm -f "$session_file"
  shift 2
else
  SESSION="${1:?session required}"
  shift
fi
LABEL="${1:?label required}"
INDEX="${2:-0}"
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
