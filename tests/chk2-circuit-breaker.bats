#!/usr/bin/env bats

# Tests for CPT-11: chk2 session-level circuit breaker for rate limiting.
#
# Verifies that SKILL.md has a circuit breaker that stops testing after
# repeated 429s, rather than allowing unbounded 65s retries per category.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SKILL_MD="${REPO_DIR}/skills/chk2/SKILL.md"

@test "chk2 SKILL.md has a rate limit handling section" {
  grep -q '## Rate Limit Handling' "$SKILL_MD"
}

@test "chk2 rate limit section includes a session-level circuit breaker" {
  local section
  section=$(sed -n '/^## Rate Limit Handling/,/^---$/p' "$SKILL_MD")
  echo "$section" | grep -qiE '(circuit.?breaker|consecutive|session.?level|abort|stop testing|total.*budget)'
}

@test "chk2 circuit breaker triggers after a specific count of consecutive 429s" {
  local section
  section=$(sed -n '/^## Rate Limit Handling/,/^---$/p' "$SKILL_MD")
  echo "$section" | grep -qiE '(consecutive.*429|[0-9]+.*consecutive.*rate.?limit)'
}

@test "chk2 circuit breaker aborts remaining tests when triggered" {
  local section
  section=$(sed -n '/^## Rate Limit Handling/,/^---$/p' "$SKILL_MD")
  echo "$section" | grep -qiE '(abort|stop|skip|halt).*remaining'
}
