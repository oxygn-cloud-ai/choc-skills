#!/usr/bin/env bats
# Tests for CPT-10: rr-prepare.sh performance — no O(n²) grep, no repeated jq accumulation.
# Also pins bash-3.2 compatibility (macOS default) after the CPT-10 rework.

SCRIPT="skills/rr/bin/rr-prepare.sh"

setup() {
  [ -f "$SCRIPT" ] || skip "rr-prepare.sh not found"
}

@test "rr-prepare.sh phase_filter uses a pure-bash set lookup, not per-risk grep" {
  # Must NOT use grep for reviewed_parents lookup (the O(N×M) regression)
  run grep -c 'grep.*reviewed_parents\|reviewed_parents.*grep' "$SCRIPT"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
  # Must use the bash-3-compatible case-pattern lookup on the space-delimited set
  run grep -F 'case "$reviewed_set"' "$SCRIPT"
  [ "$status" -eq 0 ]
  run grep -F '*" $key "*' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "rr-prepare.sh phase_filter is bash-3.2 compatible (no declare -A, readarray, mapfile)" {
  # Regression gate: these bash 4+ features break /bin/bash on macOS (3.2.57).
  # declare -A was the CPT-10 first-pass fix; Reviewer flagged it; must stay out.
  # Use `run` + explicit status check because bats' `! cmd` negation bypasses set -e,
  # which would mask intermediate failures on the first two checks.
  # Strip comment lines first so references in documentation don't false-positive.
  local src
  src=$(grep -vE '^[[:space:]]*#' "$SCRIPT")
  run bash -c "printf %s \"\$1\" | grep -E 'declare[[:space:]]+-A'" _ "$src"
  [ "$status" -ne 0 ]
  run bash -c "printf %s \"\$1\" | grep -E 'readarray\\b'" _ "$src"
  [ "$status" -ne 0 ]
  run bash -c "printf %s \"\$1\" | grep -E 'mapfile\\b'" _ "$src"
  [ "$status" -ne 0 ]
}

@test "rr-prepare.sh parses under /bin/bash (catches accidental bash-4 features)" {
  # Runtime-style gate: parse the script under macOS's /bin/bash (3.2 on macOS;
  # 4+ on Linux). On either platform a bash-4-only feature would trip syntax
  # parse here. Complements the structural negation above.
  run /bin/bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "rr-prepare.sh phase_discovery uses temp file accumulation not in-loop jq -s" {
  # The jq -s accumulation pattern in a while loop is the O(P*N) issue
  # After fix: should use temp file + final jq -s, not per-page jq -s re-parse
  # Check that phase_discovery does NOT have the pattern: all_risks=$(... jq -s '.[0] + .[1]
  run grep -c "all_risks=.*jq.*-s.*\[0\].*\[1\]" "$SCRIPT"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
}

@test "rr-prepare.sh phase_filter uses temp file accumulation for reviews not in-loop jq -s" {
  # Same pattern: all_reviews should not use in-loop jq -s accumulation
  run grep -c "all_reviews=.*jq.*-s.*\[0\].*\[1\]" "$SCRIPT"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
}

@test "rr-prepare.sh still has set -euo pipefail" {
  run grep 'set -euo pipefail' "$SCRIPT"
  [ "$status" -eq 0 ]
}
