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

# --- CPT-122: all symlink-attack tests must runtime-probe the attack path ---
#
# CPT-96 extracted the probe for the first test at line 47 but left two more
# symlink tests (lines 87 and 116) with hardcoded `/var/tmp/rr-test-attackN-$$`.
# On runners where `realpath /var/tmp` resolves into `/tmp`, the symlink target
# lands inside the allowed `/tmp/*` prefix, the case guard accepts it,
# rr-prepare / rr-finalize exit 0, and the test's "exit non-zero" assertion
# fails (hidden CI red). Guard: no `attack_dir=` in rr-prepare.bats may hardcode
# `/var/tmp` — all three tests must go through the runtime-probed helper.

@test "tests/rr-prepare.bats: no attack_dir hardcodes /var/tmp (CPT-122)" {
  run grep -nE '^[[:space:]]*local attack_dir="/var/tmp' "$REPO_DIR/tests/rr-prepare.bats"
  [ "$status" -ne 0 ]
}

@test "tests/rr-prepare.bats: runtime-probe helper is shared across symlink tests (CPT-122)" {
  # The helper should be defined once at the top of the file and called from
  # every symlink test rather than inlined per-test. Expect at least 3 calls
  # to the helper — one for each of the three symlink-attack tests.
  run grep -cE '(probe_attack_dir|_rr_probe_attack_dir)' "$REPO_DIR/tests/rr-prepare.bats"
  [ "$status" -eq 0 ]
  [ "$output" -ge 4 ]  # 1 definition + ≥3 call sites
}
