#!/usr/bin/env bats

# Tests for CPT-15: rr:remove pagination safety cap.
#
# Verifies that the pagination loop in remove.md has a maximum page count
# to prevent infinite loops from malformed API responses.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
REMOVE_MD="${REPO_DIR}/skills/rr/commands/remove.md"

@test "rr remove.md exists" {
  [ -f "$REMOVE_MD" ]
}

@test "rr remove.md pagination loop has a page counter or iteration cap" {
  # The while loop should have a page counter variable and a max check
  grep -qiE '(page_count|page_num|iteration|max_pages|MAX_PAGES|page_limit)' "$REMOVE_MD"
}

@test "rr remove.md breaks out of loop when page cap is reached" {
  # Should have a conditional break or exit when the cap is hit
  grep -qiE '(page.*(>=|>|exceed|reach|limit)|break.*max|abort.*pag|warning.*limit)' "$REMOVE_MD"
}

@test "rr remove.md while-true loop is no longer unbounded" {
  # The loop should no longer be a bare 'while true' without any page cap logic nearby
  # Extract the while-true block and check it has a page counter increment
  local loop_section
  loop_section=$(sed -n '/while true/,/done/p' "$REMOVE_MD")
  echo "$loop_section" | grep -qiE '(page_count|page_num|iteration)'
}
