#!/bin/bash
# Auto-create a tmux session for each first-level directory in Repos
set -euo pipefail

# Source user config if available
[[ -f "${HOME}/.config/iterm2-tmux/config" ]] && source "${HOME}/.config/iterm2-tmux/config"

REPOS_DIR="${TMUX_REPOS_DIR:-$HOME/Repos}"
export PATH="/opt/homebrew/bin:$PATH"

if ! command -v tmux &>/dev/null; then
  echo "[ERROR] tmux not found in PATH." >&2
  exit 1
fi

[[ -d "$REPOS_DIR" ]] || { echo "[ERROR] Repos dir not found: $REPOS_DIR" >&2; exit 1; }

sanitize_name() {
  local n="$1"
  n="${n//\./-}"
  n="${n//:/-}"
  n="${n//=/-}"
  n="${n//+/-}"
  n="${n// /-}"
  echo "$n"
}

if ! tmux start-server 2>/dev/null; then
  echo "[ERROR] Failed to start tmux server." >&2
  exit 1
fi

for dir in "$REPOS_DIR"/*/; do
  [[ -d "$dir" ]] || continue
  name="$(basename "$dir")"
  safe_name="$(sanitize_name "$name")"
  if ! tmux has-session -t "=$safe_name" 2>/dev/null; then
    if ! tmux new-session -d -s "$safe_name" 2>/dev/null; then
      echo "[WARN] Failed to create session '$safe_name', skipping." >&2
      continue
    fi
    tmux send-keys -t "$safe_name" "cd \"$dir\" && clear" Enter 2>/dev/null || \
      echo "[WARN] Could not send keys to session '$safe_name'" >&2
  fi
done
