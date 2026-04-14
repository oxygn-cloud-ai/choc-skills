#!/usr/bin/env bats
# Tests for CPT-14: ra:publish parallel MCP calls for finding/mitigation creation

SKILL_DIR="skills/ra"
PUBLISH_CMD="$SKILL_DIR/commands/publish.md"

setup() {
  [ -f "$PUBLISH_CMD" ] || skip "publish.md not found"
}

@test "ra:publish step 5 instructs parallel creation of finding tasks" {
  # Must mention parallel/concurrent/batch creation of findings
  run grep -iE 'parallel|concurrent|simultaneously|single message|all.*finding.*parallel|batch.*creat' "$PUBLISH_CMD"
  [ "$status" -eq 0 ]
}

@test "ra:publish step 6 instructs parallel creation of mitigation sub-tasks" {
  # Must mention parallel/concurrent creation of mitigations
  run grep -A 10 'Mitigation Sub-task' "$PUBLISH_CMD"
  [ "$status" -eq 0 ]
  echo "$output" | grep -iqE 'parallel|concurrent|simultaneously|single message|batch'
}

@test "ra:publish describes wave-based publication flow" {
  # Should describe the 3-wave approach: epic, then findings, then mitigations
  run grep -iE 'wave|sequential.*wave|phase.*1.*epic.*2.*finding.*3.*mitig' "$PUBLISH_CMD"
  [ "$status" -eq 0 ]
}
