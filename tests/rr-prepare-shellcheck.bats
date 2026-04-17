#!/usr/bin/env bats

# CPT-117: rr-prepare.sh phase_filter referenced undefined $reviews_tmpfile
# (typo of $tmp_reviews). Under `set -euo pipefail` this aborts every
# /rr all invocation at phase 2. Separately flagged by ShellCheck as
# SC2154 + SC2034 (dead `all_reviews` assignment).
#
# This test asserts the file passes `shellcheck -S warning` — the same
# severity the CI job enforces.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "rr-prepare.sh does not reference undefined \$reviews_tmpfile" {
  # Literal string match — present means the bug is still there.
  run grep -n 'reviews_tmpfile' "$REPO_DIR/skills/rr/bin/rr-prepare.sh"
  [ "$status" -ne 0 ]
}

@test "rr-prepare.sh has no unused local all_reviews (dead code)" {
  # all_reviews was declared and assigned by the dead block; should be gone.
  run grep -n 'local all_reviews\|all_reviews=' "$REPO_DIR/skills/rr/bin/rr-prepare.sh"
  [ "$status" -ne 0 ]
}

@test "rr-prepare.sh passes shellcheck -S warning" {
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi
  run shellcheck -S warning "$REPO_DIR/skills/rr/bin/rr-prepare.sh"
  [ "$status" -eq 0 ]
}

@test "rr-prepare.sh passes bash -n syntax check" {
  run bash -n "$REPO_DIR/skills/rr/bin/rr-prepare.sh"
  [ "$status" -eq 0 ]
}
