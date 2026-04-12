#!/usr/bin/env bats

# Tests for per-skill installers (chk1, chk2, rr, iterm2-tmux).
#
# Each test uses a temporary HOME so it never touches the real environment.
#
# PARALLEL-UNSAFE: Same HOME-reassignment caveat as install.bats.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] || return 0
  rm -rf "$HOME"
}

# ============================================================
# chk1
# ============================================================

@test "chk1 install.sh --version exits 0" {
  run bash "$REPO_DIR/skills/chk1/install.sh" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"chk1 v"* ]]
}

@test "chk1 install.sh --help exits 0" {
  run bash "$REPO_DIR/skills/chk1/install.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "chk1 install.sh --force installs SKILL.md + router + commands" {
  run bash "$REPO_DIR/skills/chk1/install.sh" --force
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.claude/skills/chk1/SKILL.md" ]
  [ -f "${HOME}/.claude/commands/chk1.md" ]
  [ -d "${HOME}/.claude/commands/chk1" ]
  # Verify at least some command files were installed
  local count
  count=$(ls "${HOME}/.claude/commands/chk1/"*.md 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -ge 5 ]
}

@test "chk1 install.sh --check passes after install" {
  bash "$REPO_DIR/skills/chk1/install.sh" --force
  run bash "$REPO_DIR/skills/chk1/install.sh" --check
  [ "$status" -eq 0 ]
}

@test "chk1 install.sh --uninstall removes files" {
  bash "$REPO_DIR/skills/chk1/install.sh" --force
  [ -f "${HOME}/.claude/skills/chk1/SKILL.md" ]
  run bash "$REPO_DIR/skills/chk1/install.sh" --uninstall
  [ "$status" -eq 0 ]
  [ ! -d "${HOME}/.claude/skills/chk1" ]
  [ ! -d "${HOME}/.claude/commands/chk1" ]
}

# ============================================================
# chk2
# ============================================================

@test "chk2 install.sh --force installs all files (35+ commands)" {
  run bash "$REPO_DIR/skills/chk2/install.sh" --force
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.claude/skills/chk2/SKILL.md" ]
  [ -d "${HOME}/.claude/commands/chk2" ]
  local count
  count=$(ls "${HOME}/.claude/commands/chk2/"*.md 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -ge 30 ]
}

# ============================================================
# rr
# ============================================================

@test "rr install.sh --force installs SKILL.md + router + commands + bin + references" {
  run bash "$REPO_DIR/skills/rr/install.sh" --force
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.claude/skills/rr/SKILL.md" ]
  [ -f "${HOME}/.claude/commands/rr.md" ]
  [ -d "${HOME}/.claude/commands/rr" ]
  [ -d "${HOME}/.claude/skills/rr/bin" ]
  [ -d "${HOME}/.claude/skills/rr/references" ]
}

@test "rr install.sh --check passes after install" {
  bash "$REPO_DIR/skills/rr/install.sh" --force
  run bash "$REPO_DIR/skills/rr/install.sh" --check
  [ "$status" -eq 0 ]
}

# ============================================================
# iterm2-tmux (smoke tests only — cannot mock iTerm2/tmux)
# ============================================================

@test "iterm2-tmux install.sh --help exits 0" {
  run bash "$REPO_DIR/skills/iterm2-tmux/install.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "iterm2-tmux install.sh --check runs without crashing" {
  # --check may report issues (tmux not installed, etc.) but should not crash
  run bash "$REPO_DIR/skills/iterm2-tmux/install.sh" --check
  # Exit 0 (all good) or 1 (issues found) are both acceptable — just not a crash
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}
