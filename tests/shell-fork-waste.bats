#!/usr/bin/env bats
# Tests for CPT-20: Shell fork waste — minor efficiency wins
# Red-green TDD — FAIL before, PASS after.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# --- Finding 1: Redundant SHA256 after cmp -s ---

@test "ra/install.sh does not do redundant shasum after cmp -s" {
  # If cmp -s proved equality, shasum is redundant
  ! grep -A2 'cmp -s' "$REPO_ROOT/skills/ra/install.sh" | grep -q 'shasum'
}

@test "rr/install.sh does not do redundant shasum after cmp -s" {
  ! grep -A6 'cmp -s.*SKILL_SOURCE' "$REPO_ROOT/skills/rr/install.sh" | grep -q 'shasum'
}

# --- Finding 2: $(< file) instead of $(cat file) ---

@test "ra/install.sh uses bash builtin for .source-repo read" {
  # Should use $(< file) instead of $(cat file) for .source-repo
  ! grep -q '\$(cat .*\.source-repo' "$REPO_ROOT/skills/ra/install.sh"
}

@test "rr/install.sh uses bash builtin for .source-repo read" {
  ! grep -q '\$(cat .*\.source-repo' "$REPO_ROOT/skills/rr/install.sh"
}

@test "_publish_one.sh uses bash builtin for auth file read" {
  ! grep -q '\$(cat.*AUTH_FILE' "$REPO_ROOT/skills/rr/bin/_publish_one.sh"
}

# --- Finding 3: glob array instead of ls|wc|tr ---

@test "rr-finalize.sh does not use ls | wc -l | tr for file counting" {
  ! grep -q 'ls.*|.*wc -l.*|.*tr' "$REPO_ROOT/skills/rr/bin/rr-finalize.sh"
}

# --- Finding 5: validate-skills.sh uses bash builtin for SKILL.md read ---

@test "validate-skills.sh uses bash builtin for skill_md_content read" {
  ! grep -q '\$(cat.*skill_file' "$REPO_ROOT/scripts/validate-skills.sh"
}

# --- Finding 6: sanitize_name inlined (no subshell) ---

@test "tmux-sessions.sh inlines name sanitization without subshell function call" {
  # Should NOT call "$(sanitize_name" — that forces a subshell fork
  ! grep -q 'safe_name=.*\$(sanitize_name' "$REPO_ROOT/skills/iterm2-tmux/bin/tmux-sessions.sh"
}

@test "tmux-iterm-tabs.sh inlines name sanitization without subshell function call" {
  ! grep -q 'safe=.*\$(sanitize_name' "$REPO_ROOT/skills/iterm2-tmux/bin/tmux-iterm-tabs.sh"
}

# --- Syntax check ---

@test "ra/install.sh passes bash -n syntax check" {
  bash -n "$REPO_ROOT/skills/ra/install.sh"
}

@test "rr/install.sh passes bash -n syntax check" {
  bash -n "$REPO_ROOT/skills/rr/install.sh"
}

@test "_publish_one.sh passes bash -n syntax check" {
  bash -n "$REPO_ROOT/skills/rr/bin/_publish_one.sh"
}

@test "rr-finalize.sh passes bash -n syntax check" {
  bash -n "$REPO_ROOT/skills/rr/bin/rr-finalize.sh"
}

@test "validate-skills.sh passes bash -n syntax check" {
  bash -n "$REPO_ROOT/scripts/validate-skills.sh"
}

@test "tmux-sessions.sh passes bash -n syntax check" {
  bash -n "$REPO_ROOT/skills/iterm2-tmux/bin/tmux-sessions.sh"
}

@test "tmux-iterm-tabs.sh passes bash -n syntax check" {
  bash -n "$REPO_ROOT/skills/iterm2-tmux/bin/tmux-iterm-tabs.sh"
}
