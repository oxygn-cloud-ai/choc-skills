#!/usr/bin/env bats

# CPT-63: chk2 SKILL.md target-reachability curl invocations lack
# --max-time / --connect-timeout, can hang 120-300s on unreachable DNS
# or TCP black-holes during /chk2 pre-flight.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SKILL_MD="$REPO_DIR/skills/chk2/SKILL.md"

@test "every curl against myzr.io in chk2 SKILL.md has --max-time" {
  local missing=()
  while IFS= read -r line; do
    if [[ "$line" != *"--max-time"* ]]; then
      missing+=("$line")
    fi
  done < <(grep -E 'curl .*myzr\.io' "$SKILL_MD")
  if [ ${#missing[@]} -gt 0 ]; then
    printf 'curl line missing --max-time:\n%s\n' "${missing[@]}" >&2
    return 1
  fi
}

@test "every curl against myzr.io in chk2 SKILL.md has --connect-timeout" {
  local missing=()
  while IFS= read -r line; do
    if [[ "$line" != *"--connect-timeout"* ]]; then
      missing+=("$line")
    fi
  done < <(grep -E 'curl .*myzr\.io' "$SKILL_MD")
  if [ ${#missing[@]} -gt 0 ]; then
    printf 'curl line missing --connect-timeout:\n%s\n' "${missing[@]}" >&2
    return 1
  fi
}
