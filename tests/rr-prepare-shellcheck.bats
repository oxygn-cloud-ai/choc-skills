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

@test "tests/rr-prepare.bats: runtime-probe helper is defined exactly once (CPT-122)" {
  # The helper must be defined once at the top of the file as a function.
  # CPT-153: the previous "≥4 textual occurrences" guard counted comment
  # mentions, so a regression that dropped one call + kept the comment
  # still satisfied the threshold. Split into two stricter greps: one
  # asserts exactly one function definition, the other asserts ≥3 call
  # sites (comments can't match either shape).
  local def_count
  def_count=$(grep -cE '^[[:space:]]*(probe_attack_dir|_rr_probe_attack_dir)[[:space:]]*\(\)[[:space:]]*\{' \
                   "$REPO_DIR/tests/rr-prepare.bats" || true)
  if [ "$def_count" -ne 1 ]; then
    echo "expected exactly 1 definition of probe_attack_dir(); got $def_count" >&2
    return 1
  fi
}

@test "tests/rr-prepare.bats: runtime-probe helper is called from every symlink test (CPT-122, CPT-153)" {
  # Count call-site shapes only. A call site is either:
  #   - `$(probe_attack_dir ...)` — command substitution assignment form
  #   - a bare `probe_attack_dir ...` command invocation at line start
  # Comments (anywhere containing the name as prose) are excluded because
  # the patterns require specific non-comment syntax.
  local call_count
  call_count=$(grep -cE '\$\((probe_attack_dir|_rr_probe_attack_dir)([[:space:]]|\))' \
                    "$REPO_DIR/tests/rr-prepare.bats" || true)
  if [ "$call_count" -lt 3 ]; then
    echo "expected ≥3 call sites of probe_attack_dir; got $call_count" >&2
    grep -nE '(probe_attack_dir|_rr_probe_attack_dir)' "$REPO_DIR/tests/rr-prepare.bats" >&2
    return 1
  fi
}
