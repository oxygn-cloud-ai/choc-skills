#!/usr/bin/env bats

# CPT-76: Per-skill installers parse flags order-independently.
#
# Regression suite: `install.sh -f --uninstall` must uninstall (not re-install).
# Also: `--uninstall -f`, `--force --uninstall`, and unknown flags must error.
#
# Each test uses a temporary HOME so it never touches the real environment.
#
# PARALLEL-UNSAFE: reassigns HOME in setup().

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] || return 0
  rm -rf "$HOME"
}

# Helper: install a skill cleanly first, then assert the command under test
# uninstalls it. Works for all 5 per-skill installers.
assert_uninstall_removes() {
  local skill="$1"; shift
  local installer="$REPO_DIR/skills/$skill/install.sh"

  # Seed: install cleanly with --force
  bash "$installer" --force >/dev/null 2>&1
  [ -f "${HOME}/.claude/skills/${skill}/SKILL.md" ] || return 1

  # Command under test
  run bash "$installer" "$@"
  [ "$status" -eq 0 ] || { echo "uninstall exited $status: $output" >&2; return 1; }
  [ ! -d "${HOME}/.claude/skills/${skill}" ] || { echo "skill dir still present after $*" >&2; return 1; }
  [ ! -d "${HOME}/.claude/commands/${skill}" ] || { echo "commands dir still present after $*" >&2; return 1; }
  [ ! -f "${HOME}/.claude/commands/${skill}.md" ] || { echo "router still present after $*" >&2; return 1; }
}

# =====================================================================
# chk1
# =====================================================================

@test "chk1: -f --uninstall removes skill" {
  assert_uninstall_removes chk1 -f --uninstall
}

@test "chk1: --force --uninstall removes skill" {
  assert_uninstall_removes chk1 --force --uninstall
}

@test "chk1: --uninstall -f removes skill (order-independent)" {
  assert_uninstall_removes chk1 --uninstall -f
}

@test "chk1: unknown flag exits non-zero" {
  run bash "$REPO_DIR/skills/chk1/install.sh" --bogus-flag
  [ "$status" -ne 0 ]
}

# =====================================================================
# chk2
# =====================================================================

@test "chk2: -f --uninstall removes skill" {
  assert_uninstall_removes chk2 -f --uninstall
}

@test "chk2: --force --uninstall removes skill" {
  assert_uninstall_removes chk2 --force --uninstall
}

@test "chk2: --uninstall -f removes skill (order-independent)" {
  assert_uninstall_removes chk2 --uninstall -f
}

@test "chk2: unknown flag exits non-zero" {
  run bash "$REPO_DIR/skills/chk2/install.sh" --bogus-flag
  [ "$status" -ne 0 ]
}

# =====================================================================
# project
# =====================================================================

@test "project: -f --uninstall removes skill" {
  assert_uninstall_removes project -f --uninstall
}

@test "project: --force --uninstall removes skill" {
  assert_uninstall_removes project --force --uninstall
}

@test "project: --uninstall -f removes skill (order-independent)" {
  assert_uninstall_removes project --uninstall -f
}

@test "project: unknown flag exits non-zero" {
  run bash "$REPO_DIR/skills/project/install.sh" --bogus-flag
  [ "$status" -ne 0 ]
}

# =====================================================================
# ra
# =====================================================================

@test "ra: -f --uninstall removes skill" {
  assert_uninstall_removes ra -f --uninstall
}

@test "ra: --force --uninstall removes skill" {
  assert_uninstall_removes ra --force --uninstall
}

@test "ra: --uninstall -f removes skill (order-independent)" {
  assert_uninstall_removes ra --uninstall -f
}

@test "ra: unknown flag exits non-zero" {
  run bash "$REPO_DIR/skills/ra/install.sh" --bogus-flag
  [ "$status" -ne 0 ]
}

# =====================================================================
# rr
# =====================================================================

@test "rr: -f --uninstall removes skill" {
  assert_uninstall_removes rr -f --uninstall
}

@test "rr: --force --uninstall removes skill" {
  assert_uninstall_removes rr --force --uninstall
}

@test "rr: --uninstall -f removes skill (order-independent)" {
  assert_uninstall_removes rr --uninstall -f
}

@test "rr: unknown flag exits non-zero" {
  run bash "$REPO_DIR/skills/rr/install.sh" --bogus-flag
  [ "$status" -ne 0 ]
}
