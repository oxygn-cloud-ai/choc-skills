#!/usr/bin/env bats
# Tests for CPT-19: Eliminate redundant file reads across skills
# Red-green TDD — these tests must FAIL before implementation, PASS after.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# --- Finding 1: chk1 all.md must NOT re-read SKILL.md ---

@test "chk1 all.md does not instruct to re-read SKILL.md" {
  # all.md should NOT contain "Read the main skill file" or similar re-read instruction
  ! grep -qi 'read.*skill.*file\|read.*SKILL\.md' "$REPO_ROOT/skills/chk1/commands/all.md"
}

@test "chk1 all.md references SKILL.md as already in context" {
  # Should have a note that SKILL.md is already loaded
  grep -qi 'already.*context\|already.*loaded\|in context' "$REPO_ROOT/skills/chk1/commands/all.md"
}

# --- Finding 2: chk1 SKILL.md avoids duplicate git diff --stat ---

@test "chk1 SKILL.md scope detection references pre-flight stat" {
  # The scope detection section should reference the pre-flight stat rather than re-running it
  grep -q 'pre-flight\|already.*stat\|stat.*above\|from.*step\|from.*check' "$REPO_ROOT/skills/chk1/SKILL.md"
}

# --- Finding 3: rr review.md marks reference files as loaded for step files ---

@test "rr review.md marks reference files as loaded for subsequent steps" {
  grep -qi 'already.*context\|do not re-read\|in context\|loaded above' "$REPO_ROOT/skills/rr/commands/review.md"
}

# --- Finding 4: ra assess.md marks reference files as loaded for step files ---

@test "ra assess.md marks reference files as loaded for subsequent steps" {
  grep -qi 'already.*context\|do not re-read\|in context\|loaded above' "$REPO_ROOT/skills/ra/commands/assess.md"
}

# --- Finding 5: project status.md does not read full architecture doc ---

@test "project status.md does not read full MULTI_SESSION_ARCHITECTURE.md" {
  # Should NOT instruct to read the full architecture doc just for the role list
  ! grep -q 'Read.*MULTI_SESSION_ARCHITECTURE' "$REPO_ROOT/skills/project/commands/status.md"
}

@test "project status.md gets roles from worktree directories" {
  # Should derive roles from .worktrees/ instead of the architecture doc
  grep -q '\.worktrees\|worktree' "$REPO_ROOT/skills/project/commands/status.md"
}

# --- Finding 6: project new.md marks Step 1 files as loaded ---

@test "project new.md does not re-read config in Step 6" {
  # Step 6 should NOT say "Read label definitions from ~/.claude/GITHUB_CONFIG.md"
  # It should reference what was already loaded in Step 1
  ! grep -q 'Read.*label.*definitions.*from.*GITHUB_CONFIG\|Read.*label.*definitions.*from.*PROJECT_CONFIG' "$REPO_ROOT/skills/project/commands/new.md"
}

@test "project new.md does not re-read config in Step 11" {
  # Step 11 should NOT say "from ~/.claude/GITHUB_CONFIG.md section 3"
  ! grep -q 'from.*~/.claude/GITHUB_CONFIG\.md.*section\|from.*~/.claude/PROJECT_CONFIG\.json.*section' "$REPO_ROOT/skills/project/commands/new.md"
}

# --- Finding 7: update.md uses parallel downloads ---

@test "chk1 update.md uses parallel curl downloads" {
  # Should use xargs -P or & for parallel downloads, not sequential for loop
  grep -q 'xargs.*-P\|parallel\|wait\|&' "$REPO_ROOT/skills/chk1/commands/update.md"
}

@test "chk2 update.md uses parallel curl downloads" {
  grep -q 'xargs.*-P\|parallel\|wait\|&' "$REPO_ROOT/skills/chk2/commands/update.md"
}
