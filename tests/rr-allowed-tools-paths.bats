#!/usr/bin/env bats

# CPT-97: /rr update and /rr all --reset invoke scripts directly (not via
# `bash`), but the post-CPT-25 allowed-tools patterns only cover `Bash(bash *)`.
# Direct invocations like `./install.sh --force` or
# `~/.claude/skills/rr/bin/rr-prepare.sh --reset` fail tool-gate checks.
#
# Fix: add Bash() patterns that match the direct invocations to each
# sub-command's frontmatter (least-privilege — per-command, not SKILL.md).

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "rr:update allowed-tools includes pattern matching ./install.sh direct invocation" {
  # update.md invokes `<repo-path>/install.sh --force` — needs a pattern
  # that matches paths ending in install.sh.
  run bash -c "awk '/^---/{n++; next} n==1' '$REPO_DIR/skills/rr/commands/update.md' | grep -E '^allowed-tools:'"
  [ "$status" -eq 0 ]
  echo "$output"
  [[ "$output" == *"install.sh"* ]] || {
    echo "rr:update allowed-tools missing install.sh pattern: $output" >&2
    return 1
  }
}

@test "rr:all allowed-tools includes pattern matching rr-prepare.sh direct invocation" {
  run bash -c "awk '/^---/{n++; next} n==1' '$REPO_DIR/skills/rr/commands/all.md' | grep -E '^allowed-tools:'"
  [ "$status" -eq 0 ]
  echo "$output"
  [[ "$output" == *"rr-prepare.sh"* ]] || {
    echo "rr:all allowed-tools missing rr-prepare.sh pattern: $output" >&2
    return 1
  }
}

@test "rr:all allowed-tools includes pattern matching rr-finalize.sh direct invocation" {
  run bash -c "awk '/^---/{n++; next} n==1' '$REPO_DIR/skills/rr/commands/all.md' | grep -E '^allowed-tools:'"
  [ "$status" -eq 0 ]
  echo "$output"
  [[ "$output" == *"rr-finalize.sh"* ]] || {
    echo "rr:all allowed-tools missing rr-finalize.sh pattern: $output" >&2
    return 1
  }
}

@test "rr:update.md body still invokes install.sh directly (not via bash)" {
  # Sanity check: the command file's body shouldn't have reverted to `bash`
  # prefix. Confirms the CPT-25 design is preserved.
  grep -E 'install\.sh --force' "$REPO_DIR/skills/rr/commands/update.md" | grep -qv '^[^#]*bash install\.sh'
}
