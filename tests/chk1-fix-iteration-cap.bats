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

@test "chk1 fix.md Round 2 trigger covers both new regressions and unresolved original findings (CPT-95)" {
  # The iteration cap's Round 2 trigger must not be narrowed to "new issues introduced"
  # only. A partial Round 1 fix that leaves some of the original findings unresolved
  # must also qualify for Round 2, per the CHANGELOG/commit-message contract of
  # "maximum of 2 fix→audit rounds".
  #
  # Extract the Iteration cap paragraph and assert it admits the unresolved-original
  # case (via "any remaining", "any issues", "unresolved", or equivalent), not just
  # "new issues introduced by the fixes".
  local cap_line
  cap_line=$(grep -iE 'iteration cap' "$FIX_MD" | head -n1)
  [ -n "$cap_line" ]
  # Must not gate Round 2 solely on "new" findings
  if echo "$cap_line" | grep -qE 'finds new issues introduced by the fixes, you may attempt'; then
    echo "Round 2 trigger is narrowed to new regressions only — partial-fix case excluded" >&2
    return 1
  fi
  # Must broaden to the any-remaining / unresolved-original case
  echo "$cap_line" | grep -qiE '(any (remaining|issue|unresolved)|unresolved.*(original|finding)|new regression.*OR.*unresolved|remaining issue)'
}
