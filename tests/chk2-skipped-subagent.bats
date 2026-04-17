#!/usr/bin/env bats

# CPT-90: Two chk2:all design-precision gaps.
#
# Gap 1: Summary format has no SKIPPED state. When the circuit breaker (CPT-89)
# aborts later waves, those categories should be marked SKIPPED, not silently
# omitted or faked with zeros.
#
# Gap 2: Agent dispatch doesn't specify `subagent_type`. The Agent tool
# defaults to `general-purpose` if omitted, which may expose a different
# tool set than the chk2 sub-skill was designed for. Make the choice explicit.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ALL_MD="$REPO_DIR/skills/chk2/commands/all.md"

@test "chk2:all summary table includes SKIPPED state" {
  grep -qiE "SKIPPED" "$ALL_MD"
}

@test "chk2:all summary table structure has a SKIPPED column or row" {
  # Either a new column in the table header, or a state value in the rows
  grep -qiE "\\| .*SKIPPED.* \\|" "$ALL_MD" ||
  grep -qiE "Skipped.*reason|reason.*skipped" "$ALL_MD"
}

@test "chk2:all orchestrator explicitly specifies subagent_type for Agent dispatch" {
  grep -qE "subagent_type" "$ALL_MD"
}
