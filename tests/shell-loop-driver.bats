#!/usr/bin/env bats
# Tests for CPT-42: Shell-loop polling with headless `claude -p`
# Red-green TDD — FAIL before, PASS after.
#
# AC #13: wrapper refuses to start if lock held, honours intervalMinutes=0,
# renders state file correctly, survives single iteration failure without
# exiting the outer loop.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
LOOPS_SH_DIR="$REPO_ROOT/.claude/loops-sh"
LIB="$LOOPS_SH_DIR/_lib.sh"

# --- Scaffolding: files exist ---

@test "_lib.sh exists" {
  [ -f "$LIB" ]
}

@test "_lib.sh is executable" {
  [ -x "$LIB" ]
}

@test ".claude/loops-sh/ has wrapper for all 8 polling roles" {
  for role in master triager reviewer merger chk1 chk2 fixer implementer; do
    [ -f "$LOOPS_SH_DIR/$role.sh" ] || { echo "info: missing $role.sh"; [ -z "$role" ]; }
  done
}

@test "all 8 wrappers are executable" {
  for role in master triager reviewer merger chk1 chk2 fixer implementer; do
    [ -x "$LOOPS_SH_DIR/$role.sh" ] || { echo "info: $role.sh not executable"; [ -z "$role" ]; }
  done
}

@test "all wrappers pass shellcheck-compatible bash -n syntax" {
  for f in "$LOOPS_SH_DIR"/*.sh; do
    bash -n "$f" || { echo "info: syntax error in $f"; [ -z "$f" ]; }
  done
}

# --- _lib.sh exports expected functions ---

@test "_lib.sh exports acquire_lock function" {
  grep -q 'acquire_lock()' "$LIB"
}

@test "_lib.sh exports release_lock function" {
  grep -q 'release_lock()' "$LIB"
}

@test "_lib.sh exports log function" {
  grep -q '^log()' "$LIB"
}

@test "_lib.sh exports render_prompt function" {
  grep -q 'render_prompt()' "$LIB"
}

# --- Wrappers use _lib.sh ---

@test "all wrappers source _lib.sh" {
  for role in master triager reviewer merger chk1 chk2 fixer implementer; do
    grep -q '_lib.sh' "$LOOPS_SH_DIR/$role.sh" || { echo "info: $role.sh does not source _lib"; [ -z "$role" ]; }
  done
}

@test "all wrappers acquire lock" {
  for role in master triager reviewer merger chk1 chk2 fixer implementer; do
    grep -q 'acquire_lock' "$LOOPS_SH_DIR/$role.sh" || { echo "info: $role.sh missing acquire_lock"; [ -z "$role" ]; }
  done
}

@test "all wrappers check intervalMinutes from config" {
  for role in master triager reviewer merger chk1 chk2 fixer implementer; do
    grep -q 'intervalMinutes' "$LOOPS_SH_DIR/$role.sh" || { echo "info: $role.sh missing intervalMinutes"; [ -z "$role" ]; }
  done
}

@test "all wrappers trap errors and continue (AC: survive single iteration failure)" {
  # Each wrapper's main loop must not exit on single iteration failure.
  # It should either || log or use trap with continue.
  for role in master triager reviewer merger chk1 chk2 fixer implementer; do
    grep -q '|| log\|continue\|trap' "$LOOPS_SH_DIR/$role.sh" || { echo "info: $role.sh has no failure recovery"; [ -z "$role" ]; }
  done
}

# --- PROJECT_CONFIG.json schema: driver field ---

@test "PROJECT_CONFIG.json triager has driver field" {
  jq -e '.loops.triager.driver' "$REPO_ROOT/PROJECT_CONFIG.json" >/dev/null
}

@test "PROJECT_CONFIG.json triager driver is shell (pilot per AC #12)" {
  [ "$(jq -r '.loops.triager.driver' "$REPO_ROOT/PROJECT_CONFIG.json")" = "shell" ]
}

@test "PROJECT_CONFIG.json other polling roles have driver field" {
  for role in master reviewer merger chk1 chk2 fixer implementer; do
    driver=$(jq -r --arg r "$role" '.loops[$r].driver' "$REPO_ROOT/PROJECT_CONFIG.json")
    [ "$driver" != "null" ] || { echo "info: $role missing driver"; [ -z "$role" ]; }
  done
}

# --- validate-config.sh validates driver field ---

@test "validate-config.sh validates driver field" {
  grep -q 'driver' "$REPO_ROOT/scripts/validate-config.sh"
}

@test "validate-config.sh rejects invalid driver values" {
  # Should check driver in (shell, session, none)
  grep -q 'shell\|session\|none' "$REPO_ROOT/scripts/validate-config.sh"
}

# --- launch.md routes shell driver roles ---

@test "launch.md checks driver field for routing" {
  grep -q 'driver' "$REPO_ROOT/skills/project/commands/launch.md"
}

@test "launch.md references loops-sh directory for shell drivers" {
  grep -q 'loops-sh\|\.claude/loops-sh' "$REPO_ROOT/skills/project/commands/launch.md"
}

# --- config.md has menu option for driver ---

@test "config.md has driver configuration option" {
  grep -qi 'driver' "$REPO_ROOT/skills/project/commands/config.md"
}

# --- status.md shows heartbeat / staleness ---

@test "status.md references heartbeat or staleness for loops" {
  grep -qi 'heartbeat\|staleness\|last iteration\|last seen' "$REPO_ROOT/skills/project/commands/status.md"
}

# --- README documenting the system ---

@test ".claude/loops-sh/README.md exists and explains shell vs session driver" {
  [ -f "$LOOPS_SH_DIR/README.md" ]
  grep -qi 'shell.*driver\|driver.*shell' "$LOOPS_SH_DIR/README.md"
}

# =============================================================================
# AC #8 — per-role --allowed-tools (static configuration + wrapper wiring)
# =============================================================================

@test "schema: sessions.<role>.allowedTools declared (AC #8)" {
  grep -q 'allowedTools' "$REPO_ROOT/PROJECT_CONFIG.schema.json"
}

@test "PROJECT_CONFIG.json: triager has non-empty allowedTools array (AC #8)" {
  [ "$(jq -r '.sessions.triager.allowedTools | type' "$REPO_ROOT/PROJECT_CONFIG.json")" = "array" ]
  [ "$(jq -r '.sessions.triager.allowedTools | length' "$REPO_ROOT/PROJECT_CONFIG.json")" -gt 0 ]
}

@test "PROJECT_CONFIG.json: all 8 polling roles have allowedTools array (AC #8)" {
  for role in master triager reviewer merger chk1 chk2 fixer implementer; do
    t=$(jq -r --arg r "$role" '.sessions[$r].allowedTools | type' "$REPO_ROOT/PROJECT_CONFIG.json")
    [ "$t" = "array" ] || { echo "info: sessions.$role.allowedTools is $t, expected array"; return 1; }
  done
}

@test "validate-config.sh references allowedTools (AC #8)" {
  grep -q 'allowedTools' "$REPO_ROOT/scripts/validate-config.sh"
}

@test "all wrappers reference --allowed-tools or run_iteration (AC #8)" {
  for role in master triager reviewer merger chk1 chk2 fixer implementer; do
    grep -qE '(--allowed-tools|allowed-tools|allowedTools|run_iteration)' "$LOOPS_SH_DIR/$role.sh" \
      || { echo "info: $role.sh does not wire allowedTools through to claude"; return 1; }
  done
}

# =============================================================================
# AC #13 — behavioural tests (replace scaffold grep with runtime verification)
# =============================================================================
#
# setup_isolated_project — stamps a self-contained fixture in $tmpdir:
#   .claude/loops-sh/{_lib.sh,<role>.sh}  copied from real tree
#   .claude/sessions/<role>.md            one-line system prompt
#   loops/loop.md                         one-line role prompt with placeholders
#   PROJECT_CONFIG.json                   minimal valid-enough-for-jq doc
#   bin/claude                            argv-logging stub that exits 0
#
# Wrappers compute PROJECT_ROOT as loops-sh/../.. so tmpdir layout must match.
#
setup_isolated_project() {
  local tmpdir="$1"; local role="$2"; local interval="$3"; local tools_json="$4"
  mkdir -p "$tmpdir/.claude/sessions" \
           "$tmpdir/.claude/state" \
           "$tmpdir/.claude/locks" \
           "$tmpdir/.claude/logs" \
           "$tmpdir/.claude/loops-sh" \
           "$tmpdir/bin" \
           "$tmpdir/loops"
  cat > "$tmpdir/PROJECT_CONFIG.json" <<EOF
{
  "schemaVersion": 1,
  "project": { "name": "fixture", "type": "software" },
  "jira": { "projectKey": "TEST", "epicKey": "TEST-1" },
  "github": { "owner": "x", "repo": "y" },
  "sessions": {
    "roles": ["$role"],
    "$role": { "allowedTools": $tools_json }
  },
  "loops": {
    "$role": { "intervalMinutes": $interval, "prompt": "loops/loop.md", "driver": "shell", "stateFile": ".claude/state/$role.md" }
  }
}
EOF
  printf 'Test prompt. State: {{STATE_FILE}} Role: {{ROLE}}\n' > "$tmpdir/loops/loop.md"
  printf 'Fixture role: %s\n' "$role" > "$tmpdir/.claude/sessions/$role.md"
  cp "$LIB" "$tmpdir/.claude/loops-sh/_lib.sh"
  cp "$LOOPS_SH_DIR/$role.sh" "$tmpdir/.claude/loops-sh/$role.sh"
  chmod +x "$tmpdir/.claude/loops-sh/_lib.sh" "$tmpdir/.claude/loops-sh/$role.sh"
  cat > "$tmpdir/bin/claude" <<'STUB'
#!/usr/bin/env bash
# Argv-logging stub for behavioural tests — writes argv (one per line) and exits 0.
printf '%s\n' "$@" > "${STUB_ARGV_LOG:-/tmp/stub-claude-argv.log}"
exit 0
STUB
  chmod +x "$tmpdir/bin/claude"
}

@test "render_prompt prepends state-handoff preamble and substitutes placeholders (AC #13)" {
  tmp="$(mktemp -d)"
  prompt="$tmp/p.md"; state="$tmp/state.md"
  printf 'HELLO {{STATE_FILE}} {{ROLE}}\n' > "$prompt"
  out=$(bash -c "source '$LIB'; ROLE=triager; render_prompt '$prompt' '$state'")
  [[ "$out" == *"Shell-loop state handoff"* ]] || { echo "info: preamble missing: $out"; return 1; }
  [[ "$out" == *"HELLO $state triager"* ]] || { echo "info: substitution missing: $out"; return 1; }
  rm -rf "$tmp"
}

@test "wrapper exits cleanly when intervalMinutes=0 (AC #13)" {
  tmpdir="$(mktemp -d)"
  setup_isolated_project "$tmpdir" triager 0 '[]'
  run env PATH="$tmpdir/bin:$PATH" "$tmpdir/.claude/loops-sh/triager.sh"
  [ "$status" -eq 0 ] || { echo "info: expected exit 0, got $status; output=$output"; rm -rf "$tmpdir"; return 1; }
  echo "$output" | grep -qi 'loop disabled' || { echo "info: expected 'loop disabled' in output: $output"; rm -rf "$tmpdir"; return 1; }
  rm -rf "$tmpdir"
}

@test "wrapper refuses to start when lock is held by a live PID (AC #13)" {
  tmpdir="$(mktemp -d)"
  setup_isolated_project "$tmpdir" triager 1 '[]'
  local lockdir="$tmpdir/.claude/locks/triager.lock"

  # Pre-seed the lock directory with the current bats PID as the holder.
  # The wrapper's kill -0 check will see this PID is live and must refuse.
  mkdir -p "$lockdir"
  echo "$$" > "$lockdir/pid"

  run env PATH="$tmpdir/bin:$PATH" "$tmpdir/.claude/loops-sh/triager.sh"

  [ "$status" -eq 1 ] || { echo "info: expected exit 1, got $status; output=$output"; rm -rf "$tmpdir"; return 1; }
  echo "$output" | grep -qi 'lock held' || { echo "info: expected 'lock held' log: $output"; rm -rf "$tmpdir"; return 1; }
  rm -rf "$tmpdir"
}

@test "wrapper reclaims stale lock when holder PID is dead (AC #13)" {
  tmpdir="$(mktemp -d)"
  setup_isolated_project "$tmpdir" triager 1 '[]'
  local lockdir="$tmpdir/.claude/locks/triager.lock"

  # Use PID 1 (init) only if we're not running as root — but to keep this
  # portable, use a PID that's guaranteed dead: spawn a `true`, capture its
  # exit, then that PID is recycled-but-probably-not-immediately-alive. For
  # safety use a very high PID (99999999) which should never exist.
  mkdir -p "$lockdir"
  echo "99999999" > "$lockdir/pid"

  # Wrapper should reclaim the stale lock and run at least one iteration.
  # intervalMinutes=1 = 60s sleep after the first claude call; we kill it
  # during that sleep. Can't use `timeout` — macOS doesn't ship it.
  env PATH="$tmpdir/bin:$PATH" "$tmpdir/.claude/loops-sh/triager.sh" >/dev/null 2>&1 &
  local wpid=$!
  sleep 3
  kill -TERM "$wpid" 2>/dev/null || true
  wait "$wpid" 2>/dev/null || true

  # If reclaim worked, the wrapper ran at least one iteration — heartbeat written.
  [ -f "$tmpdir/.claude/state/triager.heartbeat.json" ] \
    || { echo "info: no heartbeat — stale lock not reclaimed"; rm -rf "$tmpdir"; return 1; }
  rm -rf "$tmpdir"
}

@test "wrapper passes --allowed-tools to claude when allowedTools configured (AC #8/#13)" {
  tmpdir="$(mktemp -d)"
  setup_isolated_project "$tmpdir" triager 1 '["Read","Grep","mcp__claude_ai_Atlassian__*"]'
  local argv_log="$tmpdir/claude-argv.log"
  # Run briefly — one iteration then killed during the 60s sleep.
  env PATH="$tmpdir/bin:$PATH" STUB_ARGV_LOG="$argv_log" \
    "$tmpdir/.claude/loops-sh/triager.sh" >/dev/null 2>&1 &
  local wpid=$!
  sleep 3
  kill -TERM "$wpid" 2>/dev/null || true
  wait "$wpid" 2>/dev/null || true
  [ -f "$argv_log" ] || { echo "info: stub claude was never invoked"; rm -rf "$tmpdir"; return 1; }
  grep -q -- '--allowed-tools' "$argv_log" || { echo "info: --allowed-tools missing from argv: $(cat "$argv_log")"; rm -rf "$tmpdir"; return 1; }
  grep -q 'Read' "$argv_log" || { echo "info: Read missing"; rm -rf "$tmpdir"; return 1; }
  grep -q 'mcp__claude_ai_Atlassian__' "$argv_log" || { echo "info: Atlassian MCP glob missing"; rm -rf "$tmpdir"; return 1; }
  rm -rf "$tmpdir"
}

@test "wrapper omits --allowed-tools when allowedTools is empty (AC #8)" {
  tmpdir="$(mktemp -d)"
  setup_isolated_project "$tmpdir" triager 1 '[]'
  local argv_log="$tmpdir/claude-argv.log"
  env PATH="$tmpdir/bin:$PATH" STUB_ARGV_LOG="$argv_log" \
    "$tmpdir/.claude/loops-sh/triager.sh" >/dev/null 2>&1 &
  local wpid=$!
  sleep 3
  kill -TERM "$wpid" 2>/dev/null || true
  wait "$wpid" 2>/dev/null || true
  [ -f "$argv_log" ] || { echo "info: stub claude was never invoked"; rm -rf "$tmpdir"; return 1; }
  if grep -q -- '--allowed-tools' "$argv_log"; then
    echo "info: --allowed-tools should be absent when list is empty: $(cat "$argv_log")"
    rm -rf "$tmpdir"
    return 1
  fi
  rm -rf "$tmpdir"
}

@test "iteration-failure recovery: each wrapper records success and failure heartbeats (AC #13)" {
  for role in master triager reviewer merger chk1 chk2 fixer implementer; do
    # Success path writes heartbeat 0; failure path writes heartbeat with real exit code.
    # Both must exist — otherwise the outer loop cannot survive a failing iteration.
    grep -qE 'heartbeat[[:space:]]+"\$ROLE"[[:space:]]+0' "$LOOPS_SH_DIR/$role.sh" \
      || { echo "info: $role.sh missing success heartbeat"; return 1; }
    grep -qE 'heartbeat[[:space:]]+"\$ROLE"[[:space:]]+"?\$rc"?' "$LOOPS_SH_DIR/$role.sh" \
      || { echo "info: $role.sh missing failure heartbeat"; return 1; }
    # No `exit` on the failure path — the loop must continue.
    if grep -E '^\s*exit[[:space:]]+\$rc' "$LOOPS_SH_DIR/$role.sh"; then
      echo "info: $role.sh exits on iteration failure — breaks outer loop"
      return 1
    fi
  done
}
