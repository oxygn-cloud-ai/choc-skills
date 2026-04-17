#!/usr/bin/env bats
# Tests for CPT-32: Router-level allowed-tools should be minimal,
# with heavy tools moved to individual sub-command files.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# --- rr SKILL.md router ---

@test "rr/SKILL.md allowed-tools has 10 or fewer entries" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/SKILL.md")
  # Count comma-separated entries
  count=$(echo "$line" | tr ',' '\n' | wc -l | tr -d ' ')
  [ "$count" -le 10 ]
}

@test "rr/SKILL.md allowed-tools does not include Bash(python3 *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/SKILL.md")
  [[ "$line" != *"Bash(python3"* ]]
}

@test "rr/SKILL.md allowed-tools does not include Bash(bash *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/SKILL.md")
  [[ "$line" != *"Bash(bash"* ]]
}

@test "rr/SKILL.md allowed-tools does not include Bash(curl *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/SKILL.md")
  [[ "$line" != *"Bash(curl"* ]]
}

@test "rr/SKILL.md allowed-tools does not include WebSearch" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/SKILL.md")
  [[ "$line" != *"WebSearch"* ]]
}

# --- chk2 SKILL.md router ---

@test "chk2/SKILL.md allowed-tools has 10 or fewer entries" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/SKILL.md")
  count=$(echo "$line" | tr ',' '\n' | wc -l | tr -d ' ')
  [ "$count" -le 10 ]
}

@test "chk2/SKILL.md allowed-tools does not include Bash(python3 *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/SKILL.md")
  [[ "$line" != *"Bash(python3"* ]]
}

@test "chk2/SKILL.md allowed-tools does not include Bash(openssl *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/SKILL.md")
  [[ "$line" != *"Bash(openssl"* ]]
}

@test "chk2/SKILL.md allowed-tools does not include Bash(dig *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/SKILL.md")
  [[ "$line" != *"Bash(dig"* ]]
}

@test "chk2/SKILL.md allowed-tools does not include Bash(nmap *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/SKILL.md")
  [[ "$line" != *"Bash(nmap"* ]]
}

# --- rr sub-commands must have allowed-tools frontmatter ---

@test "every rr sub-command has allowed-tools in frontmatter" {
  missing=""
  for f in "$REPO_ROOT"/skills/rr/commands/*.md; do
    name=$(basename "$f")
    if ! head -20 "$f" | grep -q '^allowed-tools:'; then
      missing="$missing $name"
    fi
  done
  echo "missing:$missing"
  [ -z "$missing" ]
}

@test "rr sub-commands have YAML frontmatter delimiters" {
  missing=""
  for f in "$REPO_ROOT"/skills/rr/commands/*.md; do
    name=$(basename "$f")
    first_line=$(head -1 "$f")
    if [ "$first_line" != "---" ]; then
      missing="$missing $name"
    fi
  done
  echo "missing:$missing"
  [ -z "$missing" ]
}

# --- chk2 sub-commands must have allowed-tools frontmatter ---

@test "every chk2 sub-command has allowed-tools in frontmatter" {
  missing=""
  for f in "$REPO_ROOT"/skills/chk2/commands/*.md; do
    name=$(basename "$f")
    if ! head -20 "$f" | grep -q '^allowed-tools:'; then
      missing="$missing $name"
    fi
  done
  echo "missing:$missing"
  [ -z "$missing" ]
}

@test "chk2 sub-commands have YAML frontmatter delimiters" {
  missing=""
  for f in "$REPO_ROOT"/skills/chk2/commands/*.md; do
    name=$(basename "$f")
    first_line=$(head -1 "$f")
    if [ "$first_line" != "---" ]; then
      missing="$missing $name"
    fi
  done
  echo "missing:$missing"
  [ -z "$missing" ]
}

# --- Sub-command tools must be sufficient for their job ---

@test "rr review sub-command has WebSearch (needs regulatory lookups)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/commands/review.md")
  [[ "$line" == *"WebSearch"* ]]
}

@test "rr review sub-command has Write (creates JSON artifacts)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/commands/review.md")
  [[ "$line" == *"Write"* ]]
}

@test "rr all sub-command has Agent (spawns sub-agents)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/commands/all.md")
  [[ "$line" == *"Agent"* ]]
}

@test "chk2 tls sub-command has Bash(openssl *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/commands/tls.md")
  [[ "$line" == *"Bash(openssl"* ]]
}

@test "chk2 dns sub-command has Bash(dig *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/commands/dns.md")
  [[ "$line" == *"Bash(dig"* ]]
}

@test "chk2 timing sub-command has Bash(python3 *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/commands/timing.md")
  [[ "$line" == *"Bash(python3"* ]]
}

@test "chk2 github sub-command has Bash(gh *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/commands/github.md")
  [[ "$line" == *"Bash(gh"* ]]
}

# --- chk2 sub-commands should not have Bash(bash *) catch-all ---
# (rr sub-commands may need it for shell script invocation)

@test "no chk2 sub-command has Bash(bash *) catch-all" {
  offenders=""
  for f in "$REPO_ROOT"/skills/chk2/commands/*.md; do
    name=$(basename "$f")
    if head -20 "$f" | grep '^allowed-tools:' | grep -q 'Bash(bash \*)'; then
      offenders="$offenders $name"
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}
