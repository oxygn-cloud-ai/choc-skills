#!/usr/bin/env bats
# Tests for CPT-4: notify-recovery job must include actions/checkout and contents:read

SKILL_DIR="skills/project"
NEW_CMD="$SKILL_DIR/commands/new.md"

setup() {
  [ -f "$NEW_CMD" ] || skip "new.md not found"
}

@test "project:new CI step includes actions/checkout in notify-recovery" {
  # The notify-recovery job YAML must include actions/checkout@v4
  run grep -A 30 'notify-recovery' "$NEW_CMD"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'actions/checkout'
}

@test "project:new CI step includes contents:read permission in notify-recovery" {
  # The notify-recovery job must have contents: read permission
  run grep -A 30 'notify-recovery' "$NEW_CMD"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'contents.*read\|contents: read'
}

@test "project:new CI step does not reference defunct GITHUB_CONFIG.md section 3 YAML" {
  # Step 11 should NOT reference section 3 for the YAML snippet (it no longer exists there)
  run grep 'section 3 reference implementation' "$NEW_CMD"
  [ "$status" -ne 0 ]
}

@test "project:new CI step includes notify-failure with actions/checkout" {
  # The notify-failure job YAML must also include actions/checkout@v4
  run grep -A 30 'notify-failure' "$NEW_CMD"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'actions/checkout'
}
