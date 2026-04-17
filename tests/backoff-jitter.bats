#!/usr/bin/env bats
# Tests for CPT-33: Replace linear backoff with exponential backoff + jitter
# Red-green TDD — FAIL before, PASS after.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
PUBLISH_ONE="$REPO_ROOT/skills/rr/bin/_publish_one.sh"
UPDATE_CPT="$REPO_ROOT/skills/rr/bin/_update_cpt.sh"

# --- _publish_one.sh: exponential backoff with jitter ---

@test "_publish_one.sh uses RANDOM for jitter in retry sleep" {
  grep -q 'RANDOM' "$PUBLISH_ONE"
}

@test "_publish_one.sh does not use linear backoff (attempt * 10)" {
  ! grep -q 'attempt \* 10' "$PUBLISH_ONE"
}

@test "_publish_one.sh uses exponential base in backoff calculation" {
  # Should have ** (exponentiation) or a doubling pattern
  grep -q '\*\*\|base_sleep\|2 \*\*\|1 <<' "$PUBLISH_ONE"
}

@test "_publish_one.sh checks Retry-After header" {
  grep -qi 'retry.after\|Retry-After\|retry_after' "$PUBLISH_ONE"
}

# --- _update_cpt.sh: backoff with jitter ---

@test "_update_cpt.sh uses RANDOM for jitter in retry sleep" {
  grep -q 'RANDOM' "$UPDATE_CPT"
}

@test "_update_cpt.sh does not use fixed sleep 2 for rate-limit retry" {
  # The fixed "sleep 2" in the 429/503/529 case should be replaced
  # Look for "sleep 2" inside the rate-limit case block
  # It's OK to have "sleep 2" elsewhere, but not as the sole retry delay
  ! grep -B2 -A2 '429|503|529' "$UPDATE_CPT" | grep -q 'sleep 2$'
}

# --- Shell syntax check ---

@test "_publish_one.sh passes bash -n syntax check" {
  bash -n "$PUBLISH_ONE"
}

@test "_update_cpt.sh passes bash -n syntax check" {
  bash -n "$UPDATE_CPT"
}
