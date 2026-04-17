#!/usr/bin/env bats

# CPT-102: CPT-28 (v5.2.8) replaced `echo -n "$JIRA_EMAIL:$JIRA_API_KEY"`
# with `printf '%s'` in rr-prepare.sh / rr-finalize.sh / _update_cpt.sh
# to keep credentials out of `ps aux` visibility. The fix missed 4
# call sites in rr commands/*.md (3 in remove.md, 1 in board.md). Same
# exploit class; same remediation needed in those files.
#
# CPT-28's test only scanned skills/rr/bin/*.sh. This test extends the
# scope to commands/*.md so the full user-visible /rr surface is
# covered.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "no rr bin script echoes credentials to the process list (CPT-28 guard, pre-existing)" {
  # This is the original CPT-28 invariant. Kept here for completeness; if it
  # ever goes red, the class of bug has resurfaced in bin/ too.
  local bin_dir="${REPO_DIR}/skills/rr/bin"
  local hits
  hits=$(grep -rE 'echo[[:space:]]+-n.*\$\{?JIRA_(EMAIL|API_KEY)' "$bin_dir" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "rr bin/ script uses echo -n with credentials (CPT-28 regression):" >&2
    echo "$hits" >&2
    return 1
  fi
}

@test "no rr commands/*.md file echoes credentials to the process list (CPT-102)" {
  local cmd_dir="${REPO_DIR}/skills/rr/commands"
  local hits
  # Refuse `echo -n "..."` when combined with JIRA_EMAIL or JIRA_API_KEY —
  # this is the exact CPT-28 exploit shape that leaks credentials via ps(1).
  hits=$(grep -rnE 'echo[[:space:]]+-n.*\$\{?JIRA_(EMAIL|API_KEY)' "$cmd_dir" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "rr commands/*.md uses echo -n with credentials (CPT-102):" >&2
    echo "$hits" >&2
    echo "Fix: replace with printf '%s' (does not show arguments in process list)" >&2
    return 1
  fi
}

@test "no ra bin/commands file echoes credentials either (CPT-102 audit-scope)" {
  # The CPT-102 ticket asked to audit skills/ra/ for the same pattern.
  # Currently ra has no bin/ scripts and commands/ don't use JIRA_* shell
  # auth — this test enshrines that so any future addition of a shell
  # base64-auth line would be caught.
  local ra_dir="${REPO_DIR}/skills/ra"
  local hits
  hits=$(grep -rnE 'echo[[:space:]]+-n.*\$\{?JIRA_(EMAIL|API_KEY)' "$ra_dir" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "ra/ uses echo -n with credentials (same CPT-28 class):" >&2
    echo "$hits" >&2
    return 1
  fi
}
