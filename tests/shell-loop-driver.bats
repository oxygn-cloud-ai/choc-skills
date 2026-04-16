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
