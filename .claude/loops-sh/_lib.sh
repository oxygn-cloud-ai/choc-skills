#!/usr/bin/env bash
# .claude/loops-sh/_lib.sh — shared helpers for CPT-42 shell-loop wrappers.
# Each role wrapper sources this via `source "$(dirname "$0")/_lib.sh"` and
# uses acquire_lock / release_lock / log / render_prompt / heartbeat.
#
# Wrappers are sourced *and* executed; the library itself is marked executable
# only so the bats scaffold check (`-x _lib.sh`) passes — it is not meant to
# be run directly. Running it is a harmless no-op.

set -euo pipefail

# shellcheck disable=SC2034
# PROJECT_CONFIG / PROJECT_ROOT / LOCK_DIR / LOG_DIR / STATE_DIR are exported to
# the sourcing wrapper (module-style public vars); shellcheck flags them as
# unused because it lints this file in isolation.
_LOOPS_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$_LOOPS_SH_DIR/../.." && pwd)"
PROJECT_CONFIG="$PROJECT_ROOT/PROJECT_CONFIG.json"
LOCK_DIR="$PROJECT_ROOT/.claude/locks"
LOG_DIR="$PROJECT_ROOT/.claude/logs"
STATE_DIR="$PROJECT_ROOT/.claude/state"
export PROJECT_ROOT PROJECT_CONFIG LOCK_DIR LOG_DIR STATE_DIR
mkdir -p "$LOCK_DIR" "$LOG_DIR" "$STATE_DIR"

# log — structured stderr + per-role file log. Always prefixes with ISO-8601 UTC.
# Usage: log <role> <message…>
log() {
  local role="${1:-unknown}"; shift || true
  local ts
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  local line="[$ts] [$role] $*"
  printf '%s\n' "$line" >&2
  printf '%s\n' "$line" >> "$LOG_DIR/$role.log"
}

# acquire_lock — non-blocking flock on .claude/locks/<role>.lock.
# Exits the process if another holder owns the lock (AC #2: refuses to start).
# Usage: acquire_lock <role>
acquire_lock() {
  local role="$1"
  local lockfile="$LOCK_DIR/$role.lock"
  exec {LOCK_FD}>"$lockfile"
  if ! flock -n "$LOCK_FD"; then
    log "$role" "lock held by another process (pidfile: $lockfile.pid) — refusing to start"
    exit 1
  fi
  echo "$$" > "$lockfile.pid"
}

# release_lock — best-effort cleanup of pid sidecar (flock itself releases on fd-close).
# Intended to be wired via: trap 'release_lock <role>' EXIT.
# Usage: release_lock <role>
release_lock() {
  local role="$1"
  rm -f "$LOCK_DIR/$role.lock.pid"
}

# render_prompt — produce the prompt string passed to `claude -p`.
# Prepends a state-handoff preamble (the state file is the only durable memory
# between shell-driver iterations — AC #4/#5) and substitutes {{STATE_FILE}} /
# {{ROLE}} placeholders in the role's loop prompt. If the prompt file already
# contains an explicit state-handoff section, the preamble still fires — it is
# idempotent guidance, not harmful duplication.
# Usage: render_prompt <prompt-file> <state-file>
render_prompt() {
  local prompt_file="$1"
  local state_file="$2"
  cat <<EOF
# Shell-loop state handoff (CPT-42)

You are running under the shell-loop driver. Each iteration is a **fresh**
\`claude -p\` process with no memory of prior iterations. The state file at
\`$state_file\` is the only durable memory between iterations.

**On entry:** read \`$state_file\`. If it does not exist, this is the first
iteration — treat state as empty and continue.

**On exit:** before you finish, overwrite \`$state_file\` with a fresh handoff
that the next iteration needs (open work, last-seen git SHA, last-seen Jira
update timestamp, running notes). Keep it concise — future iterations pay for
every byte.

---

$(sed -e "s|{{STATE_FILE}}|$state_file|g" -e "s|{{ROLE}}|${ROLE:-unknown}|g" "$prompt_file")
EOF
}

# heartbeat — record iteration completion for /project:status staleness detection (AC #7).
# Writes JSON to .claude/state/<role>.heartbeat.json each iteration.
# Usage: heartbeat <role> <exit-code>
heartbeat() {
  local role="$1"
  local exit_code="${2:-0}"
  local ts
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  cat > "$STATE_DIR/$role.heartbeat.json" <<EOF
{
  "role": "$role",
  "lastIteration": "$ts",
  "lastExitCode": $exit_code,
  "pid": $$
}
EOF
}
