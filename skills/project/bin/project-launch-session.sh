#!/usr/bin/env bash
# project-launch-session.sh — launch a single tmux window for a project role.
#
# Invoked once per role by /project:launch. Keeps all helper functions in one
# process (so they don't evaporate across Claude-Code Bash tool invocations)
# and uses shell-safe quoting via jq @sh rather than tab-delimited strings.
#
# Exit codes:
#   0 — launched successfully (or skipped idle role cleanly)
#   1 — usage / arg error
#   2 — missing dependency or unreadable config
#   3 — tmux operation failed
#   4 — Claude readiness timeout (window left in place; operator must intervene)
#
# Usage:
#   project-launch-session.sh \
#     --target   tmux-session:window \
#     --role     master \
#     --repo     /path/to/repo \
#     [--claude-flags "--dangerously-skip-permissions --verbose"] \
#     [--prompt-pipe] [--skip-idle] [--dry-run]
#
# The tmux window at --target must already exist and have cwd set to the
# worktree for this role (done by the outer /project:launch orchestration).

set -euo pipefail

#-----------------------------------------------------------------------------
# Arg parsing
#-----------------------------------------------------------------------------

TARGET=""
ROLE=""
REPO_ROOT=""
CLAUDE_FLAGS=""
PROMPT_PIPE="false"
SKIP_IDLE="false"
DRY_RUN="false"
READY_TIMEOUT="${PROJECT_LAUNCH_READY_TIMEOUT:-60}"
PROCESS_TIMEOUT="${PROJECT_LAUNCH_PROCESS_TIMEOUT:-120}"
STABLE_SAMPLES="${PROJECT_LAUNCH_STABLE_SAMPLES:-3}"

usage() {
  sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)       TARGET="${2:-}"; shift 2 ;;
    --role)         ROLE="${2:-}"; shift 2 ;;
    --repo)         REPO_ROOT="${2:-}"; shift 2 ;;
    --claude-flags) CLAUDE_FLAGS="${2:-}"; shift 2 ;;
    --prompt-pipe)  PROMPT_PIPE="true"; shift ;;
    --skip-idle)    SKIP_IDLE="true"; shift ;;
    --dry-run)      DRY_RUN="true"; shift ;;
    -h|--help)      usage 0 ;;
    *)              echo "Unknown arg: $1" >&2; usage 1 ;;
  esac
done

[ -n "$TARGET" ]    || { echo "--target required" >&2; exit 1; }
[ -n "$ROLE" ]      || { echo "--role required" >&2; exit 1; }
[ -n "$REPO_ROOT" ] || { echo "--repo required" >&2; exit 1; }
[ -d "$REPO_ROOT" ] || { echo "Repo path does not exist: $REPO_ROOT" >&2; exit 2; }

# $REPO_ROOT is expected to be the MAIN repo path (where .worktrees/ lives).
# PROJECT_CONFIG.json may live at the main repo root (once merged to main) OR
# only in .worktrees/master/ (if the config is still on session/master). We
# accept either location so /project:launch works before the config lands on
# main. Session prompts and loop prompts live inside each role's worktree.

WORKTREE="$REPO_ROOT/.worktrees/$ROLE"
SESSION_PROMPT="$WORKTREE/.claude/sessions/$ROLE.md"
# Fallback — some setups keep session prompts at repo root's .claude/sessions/
[ -f "$SESSION_PROMPT" ] || SESSION_PROMPT="$REPO_ROOT/.worktrees/master/.claude/sessions/$ROLE.md"
[ -f "$SESSION_PROMPT" ] || SESSION_PROMPT="$REPO_ROOT/.claude/sessions/$ROLE.md"
LOOP_PROMPT_REL=""
LOOP_INTERVAL=0

CONFIG=""
for loc in "$REPO_ROOT/PROJECT_CONFIG.json" "$REPO_ROOT/.worktrees/master/PROJECT_CONFIG.json"; do
  if [ -f "$loc" ]; then
    CONFIG="$loc"
    break
  fi
done
[ -n "$CONFIG" ] || { echo "PROJECT_CONFIG.json not found (checked $REPO_ROOT/ and $REPO_ROOT/.worktrees/master/)" >&2; exit 2; }

[ -d "$WORKTREE" ] || { echo "No worktree for role $ROLE at $WORKTREE" >&2; exit 2; }

command -v tmux >/dev/null 2>&1 || { echo "tmux not found" >&2; exit 2; }
command -v jq   >/dev/null 2>&1 || { echo "jq not found (required for PROJECT_CONFIG.json reading)" >&2; exit 2; }

#-----------------------------------------------------------------------------
# Helpers
#-----------------------------------------------------------------------------

log()  { printf '[%s] %s\n' "$ROLE" "$*"; }
warn() { printf '[%s] [WARN] %s\n' "$ROLE" "$*" >&2; }
die()  { printf '[%s] [FAIL] %s\n' "$ROLE" "$*" >&2; exit "${2:-1}"; }

# Uppercase + sanitize dir name to a valid shell identifier, then append _PATH.
# 'choc-skills' → CHOC_SKILLS_PATH. '42repo' → _42REPO_PATH.
compute_project_env_name() {
  local name safe
  name=$(basename "$REPO_ROOT")
  safe=$(printf '%s' "$name" | LC_ALL=C tr '[:lower:]' '[:upper:]' | LC_ALL=C sed 's/[^A-Z0-9_]/_/g')
  # Strip leading underscores if the sanitized name is all underscores (pathological).
  [ -z "$safe" ] && safe="REPO"
  [[ "$safe" =~ ^[0-9] ]] && safe="_$safe"
  printf '%s_PATH' "$safe"
}

# Returns 0 when the pane capture is unchanged for $STABLE_SAMPLES consecutive
# 1-second samples, or non-zero if it times out first.
wait_pane_stable() {
  local timeout="${1:-$READY_TIMEOUT}"
  local t=0 same=0 prev="" cur
  while [ "$t" -lt "$timeout" ]; do
    cur=$(tmux capture-pane -p -t "$TARGET" 2>/dev/null || true)
    if [ -n "$cur" ] && [ "$cur" = "$prev" ]; then
      same=$((same + 1))
      [ "$same" -ge "$STABLE_SAMPLES" ] && return 0
    else
      same=0
    fi
    prev="$cur"
    sleep 1
    t=$((t + 1))
  done
  return 1
}

# Submit a single-line text as a user message (no newlines — keeps /loop's
# slash-command parser in known-good territory).
#
# IMPORTANT: the newline check uses bash pattern matching, NOT `grep -q $'\n'`
# — grep treats newlines as record separators, so the pattern becomes empty
# and matches any non-empty line, rejecting every valid call. v2.0.3 shipped
# with that bug; v2.0.4 uses [[ == *$'\n'* ]] which actually works.
send_single_line() {
  local text="$1"
  if [[ "$text" == *$'\n'* ]]; then
    die "send_single_line refuses multi-line text" 3
  fi
  # Use send-keys with -l to treat the string as literal input (no key-name
  # interpretation), then Enter to submit.
  tmux send-keys -t "$TARGET" -l "$text"
  tmux send-keys -t "$TARGET" Enter
}

#-----------------------------------------------------------------------------
# Idle-skip (evaluate first — if idle, we skip launching Claude)
#-----------------------------------------------------------------------------

if [ "$SKIP_IDLE" = "true" ]; then
  # Don't let pipefail kill us on a non-git directory — git status exits 128
  # and `wc -l` on empty stdin returns 0, which is exactly what we want.
  dirty=$({ git -C "$WORKTREE" status --porcelain 2>/dev/null || true; } | wc -l | tr -d ' ')
  ahead=$(git -C "$WORKTREE" rev-list --count "main..session/$ROLE" 2>/dev/null || echo 0)
  if [ "$dirty" = "0" ] && [ "$ahead" = "0" ]; then
    log "idle (no dirty files, no commits ahead) — skipping Claude launch for this role"
    exit 0
  fi
fi

#-----------------------------------------------------------------------------
# Build the per-role setup script (file-based — avoids tmux send-keys
# quoting hazards entirely).
#
# The script:
#   1. Exports <SANITIZED_DIRNAME>_PATH
#   2. Exports env.project entries (via jq @sh for shell-safe quoting)
#   3. Exports env.sessions.<role> entries (overrides project-level)
#   4. cd's into the worktree
#   5. exec's claude with the requested flags
#
# This is sourced in the pane, so the pane's shell process becomes claude
# with the correct env and cwd.
#-----------------------------------------------------------------------------

PROJECT_ENV_NAME=$(compute_project_env_name)
SETUP_SCRIPT=$(mktemp "/tmp/project-launch-${ROLE}-XXXXXX.sh")
chmod 600 "$SETUP_SCRIPT"
cleanup_setup() { rm -f "$SETUP_SCRIPT"; }
trap cleanup_setup EXIT

{
  echo "#!/usr/bin/env bash"
  # Guarantee we run under bash so 'exec' + exports behave consistently even
  # if the pane's login shell is zsh (fine) or a stranger shell (weird).
  echo ""
  # Project-path var (known-good identifier; printf %q is safe here because
  # this file is executed by bash).
  printf 'export %s=%q\n' "$PROJECT_ENV_NAME" "$REPO_ROOT"
  # env.project entries (@sh produces POSIX-compatible single-quoted strings;
  # lossless for tabs, newlines, single quotes, dollar signs).
  jq -r '.env.project // {} | to_entries[] | "export \(.key)=\(.value | @sh)"' "$CONFIG"
  # env.sessions.<role> entries (override project-level on conflict)
  jq -r --arg r "$ROLE" '.env.sessions[$r] // {} | to_entries[] | "export \(.key)=\(.value | @sh)"' "$CONFIG"
  # cd into the worktree (double-safety — tmux -c should have already done this)
  printf 'cd %q\n' "$WORKTREE"
  # Self-delete BEFORE exec — on Unix you can unlink an open file without
  # affecting the running process. This matters because `exec claude` replaces
  # this bash process, so any post-exec cleanup would never run. The old
  # approach appended '; rm -f' to the tmux send-keys string but that also
  # never ran for the same reason.
  echo 'rm -f "$0"'
  # CPT-75: deliver role identity as the positional prompt arg (with `--`
  # sentinel to terminate flag parsing) instead of paste-buffering it into the
  # TUI post-readiness. Removes the TUI paste-collapse / Enter-timing race and
  # leaves the identity as the first user message in the transcript (same
  # visible semantics as the old path). printf %q handles newlines in the
  # identity via bash ANSI-C $'...' quoting — lossless for multiline markdown.
  # Argv size guard: files >64 KB skip the inline path (falls back to a plain
  # `exec claude`; role re-establishes state from MEMORY.md + progress-registry
  # on first /loop tick). Current role prompts are ~1.9 KB so the guard is
  # strictly defensive and never fires in practice.
  SESSION_SIZE=0
  if [ "$PROMPT_PIPE" = "true" ] && [ -f "$SESSION_PROMPT" ]; then
    SESSION_SIZE=$(wc -c < "$SESSION_PROMPT" | tr -d ' ')
  fi
  # shellcheck disable=SC2086  # intentional word-splitting of flags
  if [ "$PROMPT_PIPE" = "true" ] && [ -f "$SESSION_PROMPT" ] && [ "$SESSION_SIZE" -le 65536 ]; then
    if [ -n "$CLAUDE_FLAGS" ]; then
      printf 'exec claude %s -- %q\n' "$CLAUDE_FLAGS" "$(cat "$SESSION_PROMPT")"
    else
      printf 'exec claude -- %q\n' "$(cat "$SESSION_PROMPT")"
    fi
  elif [ "$PROMPT_PIPE" = "true" ] && [ -f "$SESSION_PROMPT" ]; then
    warn "session prompt >64 KB at $SESSION_PROMPT — skipping inline identity (role will establish state on first /loop tick)"
    if [ -n "$CLAUDE_FLAGS" ]; then
      printf 'exec claude %s\n' "$CLAUDE_FLAGS"
    else
      echo 'exec claude'
    fi
  else
    if [ -n "$CLAUDE_FLAGS" ]; then
      printf 'exec claude %s\n' "$CLAUDE_FLAGS"
    else
      echo 'exec claude'
    fi
  fi
} > "$SETUP_SCRIPT"

#-----------------------------------------------------------------------------
# Validate env-var keys in the config BEFORE we source the setup script.
# jq @sh already handles values safely, but invalid KEYS would make the
# generated 'export' line a syntax error, dying mid-setup.
#-----------------------------------------------------------------------------

bad_keys=$(jq -r '
  [(.env.project // {} | keys[]),
   (.env.sessions // {} | values[] | keys[])]
  | .[]
' "$CONFIG" 2>/dev/null | awk '!/^[A-Za-z_][A-Za-z0-9_]*$/ {print}' || true)
if [ -n "$bad_keys" ]; then
  while IFS= read -r bad; do
    warn "ignoring env var with invalid identifier: '$bad' (must match ^[A-Za-z_][A-Za-z0-9_]*\$)"
  done <<< "$bad_keys"
  # Regenerate the setup script with the invalid keys filtered out. The
  # identity-injection and size-guard logic (CPT-75) is byte-for-byte
  # equivalent with the primary generator above.
  {
    echo "#!/usr/bin/env bash"
    echo ""
    printf 'export %s=%q\n' "$PROJECT_ENV_NAME" "$REPO_ROOT"
    jq -r '.env.project // {} | to_entries[] | select(.key | test("^[A-Za-z_][A-Za-z0-9_]*$")) | "export \(.key)=\(.value | @sh)"' "$CONFIG"
    jq -r --arg r "$ROLE" '.env.sessions[$r] // {} | to_entries[] | select(.key | test("^[A-Za-z_][A-Za-z0-9_]*$")) | "export \(.key)=\(.value | @sh)"' "$CONFIG"
    printf 'cd %q\n' "$WORKTREE"
    echo 'rm -f "$0"'
    # shellcheck disable=SC2086  # intentional word-splitting of flags
    if [ "$PROMPT_PIPE" = "true" ] && [ -f "$SESSION_PROMPT" ] && [ "$SESSION_SIZE" -le 65536 ]; then
      if [ -n "$CLAUDE_FLAGS" ]; then
        printf 'exec claude %s -- %q\n' "$CLAUDE_FLAGS" "$(cat "$SESSION_PROMPT")"
      else
        printf 'exec claude -- %q\n' "$(cat "$SESSION_PROMPT")"
      fi
    elif [ "$PROMPT_PIPE" = "true" ] && [ -f "$SESSION_PROMPT" ]; then
      # Size-guard warn already emitted in the primary generator; avoid
      # duplicating it here (otherwise bats would see two WARN lines).
      if [ -n "$CLAUDE_FLAGS" ]; then
        printf 'exec claude %s\n' "$CLAUDE_FLAGS"
      else
        echo 'exec claude'
      fi
    else
      if [ -n "$CLAUDE_FLAGS" ]; then
        printf 'exec claude %s\n' "$CLAUDE_FLAGS"
      else
        echo 'exec claude'
      fi
    fi
  } > "$SETUP_SCRIPT"
fi

#-----------------------------------------------------------------------------
# Read loop config
#-----------------------------------------------------------------------------

LOOP_CAPABLE_ROLES="master triager reviewer merger chk1 chk2 fixer implementer"
ROLE_IS_LOOP_CAPABLE="false"
for r in $LOOP_CAPABLE_ROLES; do
  [ "$ROLE" = "$r" ] && ROLE_IS_LOOP_CAPABLE="true"
done

if [ "$ROLE_IS_LOOP_CAPABLE" = "true" ]; then
  LOOP_INTERVAL=$(jq -r --arg r "$ROLE" '.sessions.loops[$r].intervalMinutes // 0' "$CONFIG")
  LOOP_PROMPT_REL=$(jq -r --arg r "$ROLE" '.sessions.loops[$r].prompt // "loops/loop.md"' "$CONFIG")
fi

LOOP_PROMPT_ABS="$WORKTREE/$LOOP_PROMPT_REL"
[ -f "$LOOP_PROMPT_ABS" ] || LOOP_PROMPT_ABS="$REPO_ROOT/.worktrees/master/$LOOP_PROMPT_REL"
[ -f "$LOOP_PROMPT_ABS" ] || LOOP_PROMPT_ABS="$REPO_ROOT/$LOOP_PROMPT_REL"

#-----------------------------------------------------------------------------
# Dry run — print plan and exit
#-----------------------------------------------------------------------------

if [ "$DRY_RUN" = "true" ]; then
  log "DRY RUN — plan:"
  log "  target:         $TARGET"
  log "  worktree:       $WORKTREE"
  log "  env name:       $PROJECT_ENV_NAME=$REPO_ROOT"
  log "  claude flags:   ${CLAUDE_FLAGS:-<none>}"
  log "  prompt pipe:    $PROMPT_PIPE (file: $([ -f "$SESSION_PROMPT" ] && echo "$SESSION_PROMPT" || echo "MISSING"))"
  log "  loop interval:  ${LOOP_INTERVAL}m"
  log "  loop prompt:    $LOOP_PROMPT_REL (abs: $([ -f "$LOOP_PROMPT_ABS" ] && echo "$LOOP_PROMPT_ABS" || echo "MISSING"))"
  log "  setup script:   $SETUP_SCRIPT"
  log "  --- setup script contents ---"
  sed 's/^/    /' "$SETUP_SCRIPT"
  exit 0
fi

#-----------------------------------------------------------------------------
# Live launch
#-----------------------------------------------------------------------------

tmux has-session -t "${TARGET%:*}" 2>/dev/null || die "tmux session does not exist: ${TARGET%:*} (caller must create it)" 3

# Move setup script to a unique path the pane can read. Unique filename
# (mktemp) avoids collisions when the same project+role is launched twice
# concurrently (or when a previous launch crashed mid-flight and left stale
# files). 0600 perms since the file contains env var values that may be
# non-secret but are still project-specific.
PANE_SETUP=$(mktemp "/tmp/project-launch-$(basename "$REPO_ROOT")-${ROLE}-XXXXXX.sh")
cp "$SETUP_SCRIPT" "$PANE_SETUP"
chmod 600 "$PANE_SETUP"

log "executing setup script in pane under bash ($PROJECT_ENV_NAME -> $REPO_ROOT, $CLAUDE_FLAGS)"
# Use `exec bash PANE_SETUP` (NOT `source`) so we know the setup script runs
# under bash regardless of the pane's login shell (zsh, fish, sh, etc.).
# 'exec' replaces the pane's shell with bash, bash runs the setup script,
# the setup script self-deletes (rm -f "$0") and then `exec claude` replaces
# bash with claude — pane is now claude, 0 leftover files.
#
# We single-quote the path for the pane's shell. The path comes from mktemp
# so it contains only [A-Za-z0-9./_-]; no quoting hazards.
tmux send-keys -t "$TARGET" "exec bash '$PANE_SETUP'" Enter

# Wait for Claude to initialize (MCP servers, plugins, etc. — 8-15s typical,
# longer on first run).
if ! wait_pane_stable "$READY_TIMEOUT"; then
  warn "Claude did not reach stable state within ${READY_TIMEOUT}s; leaving window as-is, NOT dispatching prompt or /loop"
  exit 4
fi

log "Claude ready"

# CPT-75: identity is now delivered as the positional prompt arg on the
# `exec claude` line in the setup script above. No post-readiness paste step.
# We still wait for Claude to finish processing that first user message
# before dispatching /loop, so the slash-command parser sees a ready REPL.
if [ "$PROMPT_PIPE" = "true" ] && [ -f "$SESSION_PROMPT" ]; then
  log "identity prompt delivered as positional arg on exec line; waiting for first-message processing"
  if ! wait_pane_stable "$PROCESS_TIMEOUT"; then
    warn "identity prompt did not finish processing within ${PROCESS_TIMEOUT}s; NOT dispatching /loop"
    exit 4
  fi
  log "identity prompt processed"
fi

# Dispatch /loop as a SINGLE LINE. We do NOT inline multi-line prompt text
# because /loop's argument parser behavior on multi-line bracketed pastes is
# undocumented — a path-starting-with-/ line would flip slash-command mode.
# Instead, the recurring prompt is: "read loops/<prompt>.md and do it."
# The session reads the file fresh each cycle, so edits to the file take
# effect next tick.
if [ "$ROLE_IS_LOOP_CAPABLE" = "true" ] && [ "$LOOP_INTERVAL" -gt 0 ] 2>/dev/null; then
  if [ -f "$LOOP_PROMPT_ABS" ]; then
    loop_cmd="/loop ${LOOP_INTERVAL}m Read the file ${LOOP_PROMPT_ABS} and execute the recurring task described there."
    log "dispatching: $loop_cmd"
    send_single_line "$loop_cmd"
  else
    warn "loop prompt file missing at $LOOP_PROMPT_ABS — skipping /loop dispatch"
  fi
elif [ "$ROLE_IS_LOOP_CAPABLE" = "true" ]; then
  log "loop disabled for this role (intervalMinutes=$LOOP_INTERVAL)"
else
  log "not loop-capable (on-demand role)"
fi

log "OK"
exit 0
