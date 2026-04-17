#!/usr/bin/env bats

# CPT-77: Per-skill installers' --check must exit non-zero when issues reported.
#
# Regression suite: running `./install.sh --check` in a clean HOME where no
# skill is installed must produce rc != 0 (root install.sh already does this
# via `check_health; exit $?`; per-skill installers were hard-coded to exit 0).
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

@test "chk1 --check on empty HOME exits non-zero" {
  run bash "$REPO_DIR/skills/chk1/install.sh" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"issue"* ]]
}

@test "chk1 --check after --force install exits zero" {
  bash "$REPO_DIR/skills/chk1/install.sh" --force >/dev/null 2>&1
  run bash "$REPO_DIR/skills/chk1/install.sh" --check
  [ "$status" -eq 0 ]
}

@test "chk2 --check on empty HOME exits non-zero" {
  run bash "$REPO_DIR/skills/chk2/install.sh" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"issue"* ]]
}

@test "project --check on empty HOME exits non-zero" {
  run bash "$REPO_DIR/skills/project/install.sh" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"issue"* ]]
}

@test "ra --check on empty HOME exits non-zero" {
  run bash "$REPO_DIR/skills/ra/install.sh" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"issue"* ]]
}

@test "rr --check on empty HOME exits non-zero" {
  run bash "$REPO_DIR/skills/rr/install.sh" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"issue"* ]]
}
