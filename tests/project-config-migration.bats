#!/usr/bin/env bats
# Tests for CPT-40: Replace GITHUB_CONFIG.md with PROJECT_CONFIG.json

PROJECT_DIR="skills/project"
COMMANDS_DIR="$PROJECT_DIR/commands"
SCRIPTS_DIR="scripts"

# --- PROJECT_CONFIG.json structure ---

@test "PROJECT_CONFIG.json exists at repo root" {
  [ -f "PROJECT_CONFIG.json" ]
}

@test "PROJECT_CONFIG.json is valid JSON" {
  run jq empty PROJECT_CONFIG.json
  [ "$status" -eq 0 ]
}

@test "PROJECT_CONFIG.json has all required top-level keys" {
  for key in schemaVersion project jira github sessions loops coverage deviations; do
    run jq --arg k "$key" 'has($k)' PROJECT_CONFIG.json
    [ "$output" = "true" ]
  done
}

@test "PROJECT_CONFIG.json schemaVersion is 1" {
  run jq '.schemaVersion' PROJECT_CONFIG.json
  [ "$output" = "1" ]
}

@test "PROJECT_CONFIG.json sessions defines all 11 roles" {
  for role in master planner implementer fixer merger chk1 chk2 performance playtester reviewer triager; do
    run jq --arg r "$role" '.sessions | has($r)' PROJECT_CONFIG.json
    [ "$output" = "true" ]
  done
}

@test "PROJECT_CONFIG.json loops defines only polling roles" {
  # Should have the 8 polling roles
  for role in master triager reviewer merger chk1 chk2 fixer implementer; do
    run jq --arg r "$role" '.loops | has($r)' PROJECT_CONFIG.json
    [ "$output" = "true" ]
  done
  # Should NOT have event-driven roles
  for role in planner performance playtester; do
    run jq --arg r "$role" '.loops | has($r)' PROJECT_CONFIG.json
    [ "$output" = "false" ]
  done
}

@test "PROJECT_CONFIG.json loop intervalMinutes are non-negative integers" {
  run jq '[.loops[]] | all(.intervalMinutes >= 0 and (.intervalMinutes | floor) == .intervalMinutes)' PROJECT_CONFIG.json
  [ "$output" = "true" ]
}

# --- validate-config.sh ---

@test "scripts/validate-config.sh exists and is executable" {
  [ -f "$SCRIPTS_DIR/validate-config.sh" ]
  [ -x "$SCRIPTS_DIR/validate-config.sh" ]
}

@test "validate-config.sh passes on valid PROJECT_CONFIG.json" {
  run "$SCRIPTS_DIR/validate-config.sh" PROJECT_CONFIG.json
  [ "$status" -eq 0 ]
}

@test "validate-config.sh requires jq" {
  # Script should reference jq
  run grep -q 'jq' "$SCRIPTS_DIR/validate-config.sh"
  [ "$status" -eq 0 ]
}

@test "validate-config.sh validates schemaVersion field" {
  run grep -i 'schemaVersion' "$SCRIPTS_DIR/validate-config.sh"
  [ "$status" -eq 0 ]
}

@test "validate-config.sh validates loops keys are valid polling roles" {
  run grep -i 'polling\|loop.*role\|valid.*role' "$SCRIPTS_DIR/validate-config.sh"
  [ "$status" -eq 0 ]
}

# --- GITHUB_CONFIG.md references removed from command files ---

@test "config.md references PROJECT_CONFIG.json not GITHUB_CONFIG.md" {
  run grep -c 'GITHUB_CONFIG' "$COMMANDS_DIR/config.md"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
  run grep 'PROJECT_CONFIG' "$COMMANDS_DIR/config.md"
  [ "$status" -eq 0 ]
}

@test "audit.md references PROJECT_CONFIG.json not GITHUB_CONFIG.md" {
  run grep -c 'GITHUB_CONFIG' "$COMMANDS_DIR/audit.md"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
  run grep 'PROJECT_CONFIG' "$COMMANDS_DIR/audit.md"
  [ "$status" -eq 0 ]
}

@test "new.md references PROJECT_CONFIG.json not GITHUB_CONFIG.md" {
  run grep -c 'GITHUB_CONFIG' "$COMMANDS_DIR/new.md"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
  run grep 'PROJECT_CONFIG' "$COMMANDS_DIR/new.md"
  [ "$status" -eq 0 ]
}

@test "status.md references PROJECT_CONFIG.json not GITHUB_CONFIG.md" {
  run grep -c 'GITHUB_CONFIG' "$COMMANDS_DIR/status.md"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
  run grep 'PROJECT_CONFIG' "$COMMANDS_DIR/status.md"
  [ "$status" -eq 0 ]
}

@test "launch.md references PROJECT_CONFIG.json not GITHUB_CONFIG.md" {
  run grep -c 'GITHUB_CONFIG' "$COMMANDS_DIR/launch.md"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
  # launch.md should read loop intervals from PROJECT_CONFIG.json
  run grep -i 'loop.*interval\|intervalMinutes\|PROJECT_CONFIG' "$COMMANDS_DIR/launch.md"
  [ "$status" -eq 0 ]
}

# --- SKILL.md and install.sh references ---

@test "SKILL.md references PROJECT_CONFIG.json not GITHUB_CONFIG.md" {
  run grep -c 'GITHUB_CONFIG' "$PROJECT_DIR/SKILL.md"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
  run grep 'PROJECT_CONFIG' "$PROJECT_DIR/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "install.sh references PROJECT_CONFIG.json not GITHUB_CONFIG.md" {
  run grep -c 'GITHUB_CONFIG' "$PROJECT_DIR/install.sh"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
  run grep 'PROJECT_CONFIG' "$PROJECT_DIR/install.sh"
  [ "$status" -eq 0 ]
}

@test "README.md references PROJECT_CONFIG.json not GITHUB_CONFIG.md" {
  run grep -c 'GITHUB_CONFIG' "$PROJECT_DIR/README.md"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
  run grep 'PROJECT_CONFIG' "$PROJECT_DIR/README.md"
  [ "$status" -eq 0 ]
}

# --- Launch report shows loop intervals ---

@test "launch.md report includes loop interval per role" {
  run grep -i 'loop\|interval\|polling' "$COMMANDS_DIR/launch.md"
  [ "$status" -eq 0 ]
}
