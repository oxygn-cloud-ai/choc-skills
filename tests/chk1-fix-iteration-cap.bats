#!/usr/bin/env bats

# Tests for CPT-13: chk1:fix iteration cap on fix→audit→fix cycle.
#
# Verifies that the fix command has a maximum iteration limit to prevent
# unbounded fix→audit→fix loops.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
FIX_MD="${REPO_DIR}/skills/chk1/commands/fix.md"

@test "chk1 fix.md exists" {
  [ -f "$FIX_MD" ]
}

@test "chk1 fix.md has an iteration cap or maximum cycle count" {
  # The file should mention a maximum number of fix→audit rounds
  grep -qiE '(max.*(round|cycle|iteration|attempt)|limit.*(round|cycle|iteration)|at most [0-9]|no more than [0-9]|cap|maximum of [0-9])' "$FIX_MD"
}

@test "chk1 fix.md stops looping after the cap and presents remaining findings" {
  # After hitting the cap, it should present remaining issues as a summary
  # rather than continuing to fix
  grep -qiE '(remaining|still open|outstanding|present.*summary|report.*remaining|list.*unfixed)' "$FIX_MD"
}
