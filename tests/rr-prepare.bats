#!/usr/bin/env bats

# Tests for rr-prepare.sh — symlink resolution and path validation.
#
# CPT-26: Verify that WORK_DIR symlinks are resolved before the case guard,
# preventing symlink traversal attacks on rm -rf.
#
# Each test uses a temporary HOME so it never touches the real environment.
#
# PARALLEL-UNSAFE: This test suite reassigns HOME in setup().

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
RR_PREPARE="${REPO_DIR}/skills/rr/bin/rr-prepare.sh"
RR_FINALIZE="${REPO_DIR}/skills/rr/bin/rr-finalize.sh"

setup() {
  export HOME="$(mktemp -d)"
  # Create a fake target directory that looks like a valid rr-work dir
  FAKE_TARGET="$(mktemp -d)"
  touch "$FAKE_TARGET/batch.log"
  touch "$FAKE_TARGET/discovery.json"
  # Suppress Jira credentials check — we're only testing path validation
  export JIRA_EMAIL="test@example.com"
  export JIRA_API_KEY="fake-key"
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] || return 0
  rm -rf "$HOME"
  [ -d "$FAKE_TARGET" ] && rm -rf "$FAKE_TARGET"
}

# --- rr-prepare.sh: symlink resolution ---

@test "rr-prepare --reset rejects symlink under HOME pointing outside HOME" {
  # Create symlink: $HOME/rr-work -> /tmp/fake-target (resolves outside $HOME)
  # The symlink path passes the case guard ($HOME/*) but the resolved path
  # would be /tmp/... which is allowed. Use a path that resolves outside both.
  local outside_dir
  outside_dir="$(mktemp -d)"
  touch "$outside_dir/batch.log"

  ln -s "$outside_dir" "$HOME/rr-work"
  export RR_WORK_DIR="$HOME/rr-work"

  # The resolved path is outside $HOME and outside /tmp (on macOS, mktemp
  # creates under /var/folders which is neither $HOME nor /tmp)
  # On Linux mktemp creates under /tmp so this test needs a different approach.
  # We create a directory outside both allowed prefixes.
  local attack_dir="/var/tmp/rr-test-attack-$$"
  mkdir -p "$attack_dir"
  touch "$attack_dir/batch.log"
  ln -sf "$attack_dir" "$HOME/rr-work"

  run "$RR_PREPARE" --reset
  rm -rf "$attack_dir" "$outside_dir"

  [ "$status" -ne 0 ]
  [[ "$output" == *"FATAL"* ]] || [[ "$output" == *"symlink"* ]] || [[ "$output" == *"Refusing"* ]]
}

@test "rr-prepare --reset works with normal (non-symlink) path under HOME" {
  mkdir -p "$HOME/rr-work"
  touch "$HOME/rr-work/batch.log"
  touch "$HOME/rr-work/discovery.json"
  export RR_WORK_DIR="$HOME/rr-work"

  run "$RR_PREPARE" --reset

  [ "$status" -eq 0 ]
  [[ "$output" == *"reset"* ]]
  # Directory should be deleted
  [ ! -d "$HOME/rr-work" ]
}

@test "rr-prepare rejects WORK_DIR that is a symlink resolving outside allowed paths" {
  local attack_dir="/var/tmp/rr-test-attack2-$$"
  mkdir -p "$attack_dir"
  ln -sf "$attack_dir" "$HOME/rr-work"
  export RR_WORK_DIR="$HOME/rr-work"

  run "$RR_PREPARE"
  rm -rf "$attack_dir"

  [ "$status" -ne 0 ]
  [[ "$output" == *"FATAL"* ]]
}

@test "rr-prepare accepts normal path under /tmp" {
  local tmp_work="/tmp/rr-test-work-$$"
  mkdir -p "$tmp_work"
  touch "$tmp_work/batch.log"
  touch "$tmp_work/discovery.json"
  export RR_WORK_DIR="$tmp_work"

  run "$RR_PREPARE" --reset

  rm -rf "$tmp_work" 2>/dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"reset"* ]]
}

# --- rr-finalize.sh: path validation ---

@test "rr-finalize rejects WORK_DIR that is a symlink resolving outside allowed paths" {
  local attack_dir="/var/tmp/rr-test-attack3-$$"
  mkdir -p "$attack_dir"
  ln -sf "$attack_dir" "$HOME/rr-work"
  export RR_WORK_DIR="$HOME/rr-work"

  run "$RR_FINALIZE"
  rm -rf "$attack_dir"

  [ "$status" -ne 0 ]
  [[ "$output" == *"FATAL"* ]]
}
