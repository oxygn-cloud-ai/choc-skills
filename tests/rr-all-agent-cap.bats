#!/usr/bin/env bats
# Tests for CPT-30: rr:all agent cap, global retry budget, finalization gating

SKILL_DIR="skills/rr"
ALL_CMD="$SKILL_DIR/commands/all.md"

setup() {
  [ -f "$ALL_CMD" ] || skip "all.md not found"
}

@test "rr:all Agent Orchestrator defines a maximum total agent cap" {
  # Must define a hard cap on total agents regardless of register size
  run grep -i "max.*total.*agent\|total.*agent.*cap\|MAX_TOTAL_AGENTS\|maximum.*agent" "$ALL_CMD"
  [ "$status" -eq 0 ]
  # Must specify a numeric limit
  run grep -oE '(MAX_TOTAL_AGENTS|maximum.*agents?|total agent cap).*[0-9]+' "$ALL_CMD"
  [ "$status" -eq 0 ]
}

@test "rr:all Agent Orchestrator enforces agent cap before dispatching waves" {
  # The dispatch section must check cumulative agent count against the cap
  run grep -i "agents_dispatched\|agent.count\|cumulative.*agent\|stop.*dispatch\|skip.*remaining.*wave\|abort.*wave" "$ALL_CMD"
  [ "$status" -eq 0 ]
}

@test "rr:all retry section defines a global retry budget" {
  # Must have a global retry limit, not just per-batch
  run grep -iE "global.*retr(y|ies).*budget|max.*total.*retr|MAX_TOTAL_RETRIES|global retr" "$ALL_CMD"
  [ "$status" -eq 0 ]
  # Must specify a numeric limit
  run grep -oE '(MAX_TOTAL_RETRIES|global.*retr[yi].*budget|total retr[yi]).*[0-9]+' "$ALL_CMD"
  [ "$status" -eq 0 ]
}

@test "rr:all finalization runs exactly once after all retries complete" {
  # Must explicitly state finalization runs once after retries, not per-retry
  run grep -i "finali[sz]ation.*once\|run.*finali[sz].*after.*all.*retries\|single.*finali[sz]\|once.*after.*retr" "$ALL_CMD"
  [ "$status" -eq 0 ]
}
