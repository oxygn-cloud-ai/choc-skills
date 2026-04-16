#!/usr/bin/env bash
# CPT-42: shell-loop driver for reviewer role.
# Each iteration is a fresh `claude -p` process — no context carry-over —
# guarding against long-running-session context exhaustion. State handoff
# is via .claude/state/reviewer.md (read on entry, written on exit).

set -euo pipefail
source "$(dirname "$0")/_lib.sh"

ROLE="reviewer"
PROMPT_FILE="$PROJECT_ROOT/.claude/loops/$ROLE.md"
STATE_FILE="$STATE_DIR/$ROLE.md"
SESSION_PROMPT="$PROJECT_ROOT/.claude/sessions/$ROLE.md"

INTERVAL_MINUTES="$(jq -r --arg r "$ROLE" '.loops[$r].intervalMinutes // 0' "$PROJECT_CONFIG")"
if [[ "$INTERVAL_MINUTES" == "0" ]]; then
  log "$ROLE" "loop disabled (intervalMinutes=0) — exiting cleanly"
  exit 0
fi

acquire_lock "$ROLE"
trap 'release_lock "$ROLE"' EXIT

log "$ROLE" "loop starting (interval=${INTERVAL_MINUTES}m, driver=shell)"

while true; do
  log "$ROLE" "iteration start"
  if claude --dangerously-skip-permissions \
            --append-system-prompt "$(cat "$SESSION_PROMPT" 2>/dev/null || printf 'Role: %s' "$ROLE")" \
            -p "$(render_prompt "$PROMPT_FILE" "$STATE_FILE")"; then
    heartbeat "$ROLE" 0
    log "$ROLE" "iteration complete"
  else
    rc=$?
    heartbeat "$ROLE" "$rc"
    log "$ROLE" "iteration failed (exit $rc) — continuing loop"
  fi
  sleep "$((INTERVAL_MINUTES * 60))"
done
