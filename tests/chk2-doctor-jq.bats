#!/usr/bin/env bats

# CPT-98: /chk2 doctor must check for `jq`.
#
# AU3 in skills/chk2/commands/auth.md relies on `jq` as a hard runtime
# dependency (the `--arg i "$i"` pipeline that formats concurrent-session
# output). If jq is missing, the pipeline fails silently (2>/dev/null)
# and the user gets a clean-looking report with zero AU3 evidence.
# Doctor must surface this before the audit runs.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SKILL_MD="${REPO_DIR}/skills/chk2/SKILL.md"

@test "chk2 SKILL.md exists" {
  [ -f "$SKILL_MD" ]
}

@test "chk2 doctor section lists a jq availability check (CPT-98)" {
  # Extract the doctor section and verify it contains a jq check
  awk '/^### doctor$/,/^### version$/' "$SKILL_MD" | grep -qE 'which jq|jq.*available|jq.*installed'
}

@test "chk2 doctor output format includes a jq PASS/FAIL line (CPT-98)" {
  # The worked-example output block inside the doctor section must show a jq line
  # so auditors can visually confirm the check ran.
  awk '/^### doctor$/,/^### version$/' "$SKILL_MD" | grep -qE '\[(PASS|FAIL)\] jq'
}

@test "chk2 pre-flight verifies jq is available (CPT-98)" {
  # jq must be checked before the audit runs, not just in the explicit doctor
  # subcommand, so that `/chk2 all` (no doctor) still aborts on missing jq.
  awk '/^## Pre-flight Checks/,/^## Routing/' "$SKILL_MD" | grep -qiE 'jq.*which|which.*jq|jq.*available|jq.*installed'
}
