#!/usr/bin/env bats

# Tests for install.sh — the root claude-skills installer.
# Each test uses a temporary HOME to avoid touching the real environment.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALLER="${REPO_DIR}/install.sh"

setup() {
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
}

teardown() {
  # Guard: only delete if HOME is a temp directory (safety against real HOME deletion)
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] || return 0
  rm -rf "$HOME"
}

# --- Info commands ---

@test "--version prints version string" {
  run bash "$INSTALLER" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude-skills installer v"* ]]
}

@test "--help prints usage" {
  run bash "$INSTALLER" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "--list shows available skills" {
  run bash "$INSTALLER" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Available skills"* ]]
  [[ "$output" == *"chk1"* ]]
  [[ "$output" == *"chk2"* ]]
  [[ "$output" == *"rr"* ]]
}

# --- Install ---

@test "--force installs all skills" {
  run bash "$INSTALLER" --force
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.claude/skills/chk1/SKILL.md" ]
  [ -f "${HOME}/.claude/skills/chk2/SKILL.md" ]
  [ -f "${HOME}/.claude/skills/rr/SKILL.md" ]
}

@test "installs a specific skill" {
  run bash "$INSTALLER" --force chk1
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.claude/skills/chk1/SKILL.md" ]
  [ ! -f "${HOME}/.claude/skills/chk2/SKILL.md" ]
}

@test "--force overwrites tampered install" {
  # Install first
  bash "$INSTALLER" --force chk1
  # Tamper
  echo "tampered" > "${HOME}/.claude/skills/chk1/SKILL.md"
  # Reinstall
  run bash "$INSTALLER" --force chk1
  [ "$status" -eq 0 ]
  # Verify it matches the source
  cmp -s "${REPO_DIR}/skills/chk1/SKILL.md" "${HOME}/.claude/skills/chk1/SKILL.md"
}

# --- Health check ---

@test "--check fails with nothing installed" {
  run bash "$INSTALLER" --check
  [ "$status" -ne 0 ]
}

@test "--check passes after --force install" {
  bash "$INSTALLER" --force
  run bash "$INSTALLER" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"healthy"* ]]
}

# --- Uninstall ---

@test "--uninstall --all --force removes all skills" {
  bash "$INSTALLER" --force
  [ -d "${HOME}/.claude/skills/chk1" ]
  run bash "$INSTALLER" --uninstall --all --force
  [ "$status" -eq 0 ]
  [ ! -d "${HOME}/.claude/skills/chk1" ]
  [ ! -d "${HOME}/.claude/skills/chk2" ]
  [ ! -d "${HOME}/.claude/skills/rr" ]
}

@test "--uninstall --force removes one skill, leaves others" {
  bash "$INSTALLER" --force
  run bash "$INSTALLER" --uninstall --force chk1
  [ "$status" -eq 0 ]
  [ ! -d "${HOME}/.claude/skills/chk1" ]
  [ -f "${HOME}/.claude/skills/chk2/SKILL.md" ]
  [ -f "${HOME}/.claude/skills/rr/SKILL.md" ]
}

# --- Input validation ---

@test "rejects path traversal" {
  run bash "$INSTALLER" --force "../etc/passwd"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid skill name"* ]]
}

@test "rejects unknown skill name" {
  run bash "$INSTALLER" --force nonexistent-skill-xyz
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

# --- Dry run ---

@test "--dry-run exits 0 and makes no changes" {
  run bash "$INSTALLER" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]
  [ ! -d "${HOME}/.claude/skills/chk1" ]
}

# --- Changelog ---

@test "--changelog prints changelog" {
  run bash "$INSTALLER" --changelog
  [ "$status" -eq 0 ]
  [[ "$output" == *"Changelog"* ]]
}

# --- Quiet mode ---

@test "--quiet --force suppresses non-error output" {
  run bash "$INSTALLER" --quiet --force chk1
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.claude/skills/chk1/SKILL.md" ]
  # Quiet mode should produce no normal output lines
  [ -z "$output" ]
}
