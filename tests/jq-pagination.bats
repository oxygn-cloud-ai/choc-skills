#!/usr/bin/env bats
# Tests for CPT-35: O(p×n) jq accumulation → O(n) temp-file approach
# Red-green TDD — FAIL before, PASS after.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
PREPARE="$REPO_ROOT/skills/rr/bin/rr-prepare.sh"

# --- phase_discovery uses temp file instead of in-memory jq accumulation ---

@test "rr-prepare.sh does not use jq -s accumulation in pagination loop" {
  # The O(p×n) pattern: jq -s '.[0] + .[1].issues' inside the while loop
  ! grep -q "\.\[0\].*\.\[1\]\.issues" "$PREPARE"
}

@test "rr-prepare.sh uses temp file for page accumulation" {
  # Should write each page to a temp file, then combine once
  grep -q 'tmp\|TMPFILE\|tmpfile\|_pages\|page_file\|mktemp' "$PREPARE"
}

@test "rr-prepare.sh combines pages with single jq pass after loop" {
  # After the while loop, there should be a single jq -s or jq add to combine
  grep -q 'jq.*-s.*add\|jq.*add\|jq -s' "$PREPARE"
}

@test "rr-prepare.sh cleans up temp files" {
  # Should clean up the temp file after use
  grep -q 'rm.*tmp\|rm.*page\|trap.*rm\|cleanup' "$PREPARE"
}

# --- Shell syntax check ---

@test "rr-prepare.sh passes bash -n syntax check" {
  bash -n "$PREPARE"
}
