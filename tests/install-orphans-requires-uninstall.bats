#!/usr/bin/env bats

# CPT-154: CPT-138 added --orphans as an opt-in recovery path for the
# uninstall flow, but the arg parser's shared while-loop sets
# ORPHANS_FLAG=true without enforcing that ACTION is also "uninstall".
# Scenarios that silently install everything instead of failing fast:
#
#   ./install.sh --orphans           → ACTION stays "install"
#   ./install.sh --orphans chk1      → ACTION stays "install"
#   ./install.sh --orphans --all     → ACTION stays "install"
#
# Help text at line 52 and info message at line 262 both describe
# --orphans as uninstall-only, so the parser behaviour contradicts the
# documentation.
#
# Fix: post-parse validation that rejects --orphans without --uninstall.
# Matches the CPT-123 principle (reject conflicting action flags at
# parse time) established for per-skill installers.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALLER="$REPO_DIR/install.sh"

setup() {
  unset CLAUDE_CONFIG_DIR  # CPT-174: ensure tests never inherit ambient CLAUDE_CONFIG_DIR
  [ -f "$INSTALLER" ]
  # Use a fake HOME so any accidental install doesn't touch the real one.
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/* ]] && rm -rf "$HOME"
}

# --- RED shape 1: bare --orphans alone ---

@test "CPT-154: ./install.sh --orphans (alone) fails fast" {
  run bash "$INSTALLER" --orphans
  [ "$status" -ne 0 ]
  [[ "$output" == *"--orphans requires --uninstall"* ]]
}

# --- RED shape 2: --orphans with a skill name ---

@test "CPT-154: ./install.sh --orphans chk1 fails fast" {
  run bash "$INSTALLER" --orphans chk1
  [ "$status" -ne 0 ]
  [[ "$output" == *"--orphans requires --uninstall"* ]]
}

# --- RED shape 3: --orphans --all ---

@test "CPT-154: ./install.sh --orphans --all fails fast" {
  run bash "$INSTALLER" --orphans --all
  [ "$status" -ne 0 ]
  [[ "$output" == *"--orphans requires --uninstall"* ]]
}

# --- RED shape 4: --orphans --update ---
#   CPT-138's info message explicitly says "uninstall-only"; --update is
#   an install-class action, so --orphans combined with it must also fail.

@test "CPT-154: ./install.sh --orphans --update fails fast" {
  run bash "$INSTALLER" --orphans --update
  [ "$status" -ne 0 ]
  [[ "$output" == *"--orphans requires --uninstall"* ]]
}

# --- Positive sanity: --orphans with --uninstall still reaches the
#     uninstall path (may fail for other reasons in the fake HOME but
#     NOT for the CPT-154 combo check).

@test "CPT-154: ./install.sh --uninstall --orphans <name> does NOT emit the combo error" {
  # nothing installed in fake HOME so uninstall will error; but the
  # error MUST NOT be the CPT-154 combo message.
  run bash "$INSTALLER" --uninstall --orphans somemissing
  if echo "$output" | grep -q '\-\-orphans requires \-\-uninstall'; then
    echo "CPT-154 combo check wrongly fires when --uninstall --orphans is used together" >&2
    echo "$output" >&2
    return 1
  fi
}

# --- Static: the combo check appears after the parser loop ---

@test "CPT-154: combo check appears AFTER the while-loop done and BEFORE the action dispatch" {
  local check_line loop_done_line dispatch_line
  check_line=$(grep -nE 'ORPHANS_FLAG.*uninstall' "$INSTALLER" | head -1 | cut -d: -f1)
  # The parser's closing `done` — locate the argv-parse loop's specific done.
  loop_done_line=$(awk '/^while \[ \$# -gt 0 \]; do$/,/^done$/ {if (/^done$/) {print NR; exit}}' "$INSTALLER")
  dispatch_line=$(grep -nE '^case "\$ACTION" in' "$INSTALLER" | head -1 | cut -d: -f1)

  [ -n "$check_line" ] || { echo "CPT-154 combo check missing" >&2; return 1; }
  [ -n "$loop_done_line" ] || { echo "parser loop done missing" >&2; return 1; }
  [ -n "$dispatch_line" ] || { echo "action dispatch missing" >&2; return 1; }
  [ "$loop_done_line" -lt "$check_line" ] || { echo "check (line $check_line) must be AFTER parser done (line $loop_done_line)" >&2; return 1; }
  [ "$check_line" -lt "$dispatch_line" ] || { echo "check (line $check_line) must be BEFORE action dispatch (line $dispatch_line)" >&2; return 1; }
}
