#!/usr/bin/env bats
# Tests for CPT-39: Add YAML frontmatter to chk1 command files
# (CPT-32 handles rr and chk2 sub-commands in a separate branch)
# Red-green TDD — FAIL before, PASS after.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
CHK1_DIR="$REPO_ROOT/skills/chk1/commands"

# --- Each chk1 command file must start with YAML frontmatter ---

@test "chk1/commands/all.md starts with --- frontmatter" {
  [ "$(head -1 "$CHK1_DIR/all.md")" = "---" ]
}

@test "chk1/commands/architecture.md starts with --- frontmatter" {
  [ "$(head -1 "$CHK1_DIR/architecture.md")" = "---" ]
}

@test "chk1/commands/fix.md starts with --- frontmatter" {
  [ "$(head -1 "$CHK1_DIR/fix.md")" = "---" ]
}

@test "chk1/commands/github.md starts with --- frontmatter" {
  [ "$(head -1 "$CHK1_DIR/github.md")" = "---" ]
}

@test "chk1/commands/quick.md starts with --- frontmatter" {
  [ "$(head -1 "$CHK1_DIR/quick.md")" = "---" ]
}

@test "chk1/commands/scope.md starts with --- frontmatter" {
  [ "$(head -1 "$CHK1_DIR/scope.md")" = "---" ]
}

@test "chk1/commands/security.md starts with --- frontmatter" {
  [ "$(head -1 "$CHK1_DIR/security.md")" = "---" ]
}

@test "chk1/commands/update.md starts with --- frontmatter" {
  [ "$(head -1 "$CHK1_DIR/update.md")" = "---" ]
}

# --- Each file must have name, description, allowed-tools ---

@test "all chk1 command files have name field in frontmatter" {
  for f in "$CHK1_DIR"/*.md; do
    head -20 "$f" | grep -q '^name:' || { echo "info: $f missing name:"; [ -z "$f" ]; }
  done
}

@test "all chk1 command files have description field in frontmatter" {
  for f in "$CHK1_DIR"/*.md; do
    head -20 "$f" | grep -q '^description:' || { echo "info: $f missing description:"; [ -z "$f" ]; }
  done
}

@test "all chk1 command files have allowed-tools field in frontmatter" {
  for f in "$CHK1_DIR"/*.md; do
    head -20 "$f" | grep -q '^allowed-tools:' || { echo "info: $f missing allowed-tools:"; [ -z "$f" ]; }
  done
}

# --- Security: no command should have wildcarded Bash(*) ---

@test "no chk1 command has Bash(*) catch-all" {
  for f in "$CHK1_DIR"/*.md; do
    ! head -20 "$f" | grep -q 'Bash(\*)' || { echo "info: $f has Bash(*) catch-all"; [ -z "$f" ]; }
  done
}

# --- Specific tool requirements ---

@test "chk1/commands/github.md includes Bash(gh *)" {
  head -20 "$CHK1_DIR/github.md" | grep -q 'Bash(gh \*)'
}

@test "chk1/commands/fix.md includes Edit tool" {
  head -20 "$CHK1_DIR/fix.md" | grep -q 'Edit'
}

@test "chk1/commands/update.md includes scoped Bash(bash install.sh *)" {
  head -20 "$CHK1_DIR/update.md" | grep -q 'Bash(bash install.sh \*)\|Bash(curl \*)'
}
