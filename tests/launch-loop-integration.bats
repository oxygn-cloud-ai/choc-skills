#!/usr/bin/env bats
# Tests for CPT-41: /project:launch loop integration with env vars and loop prompts

PROJECT_DIR="skills/project"
COMMANDS_DIR="$PROJECT_DIR/commands"
SCRIPTS_DIR="scripts"

# --- PROJECT_CONFIG.json env section ---

@test "PROJECT_CONFIG.json has env top-level key" {
  run jq 'has("env")' PROJECT_CONFIG.json
  [ "$output" = "true" ]
}

@test "PROJECT_CONFIG.json env.project exists and is an object" {
  run jq '.env.project | type' PROJECT_CONFIG.json
  [ "$output" = '"object"' ]
}

@test "PROJECT_CONFIG.json env.project has CHOC-SKILLS_PATH" {
  run jq -r '.env.project["CHOC-SKILLS_PATH"] // empty' PROJECT_CONFIG.json
  [ -n "$output" ]
}

@test "PROJECT_CONFIG.json env.sessions exists and is an object" {
  run jq '.env.sessions | type' PROJECT_CONFIG.json
  [ "$output" = '"object"' ]
}

@test "PROJECT_CONFIG.json env.sessions has all 11 roles" {
  for role in master planner implementer fixer merger chk1 chk2 performance playtester reviewer triager; do
    run jq --arg r "$role" '.env.sessions | has($r)' PROJECT_CONFIG.json
    [ "$output" = "true" ]
  done
}

@test "PROJECT_CONFIG.json env.project values are strings" {
  count=$(jq '[.env.project | to_entries[] | select(.value | type != "string")] | length' PROJECT_CONFIG.json)
  [ "$count" = "0" ]
}

# --- validate-config.sh handles env section ---

@test "validate-config.sh validates env section" {
  grep -q 'env' "$SCRIPTS_DIR/validate-config.sh"
}

@test "validate-config.sh passes with env section present" {
  run "$SCRIPTS_DIR/validate-config.sh" PROJECT_CONFIG.json
  [ "$status" -eq 0 ]
}

# --- launch.md references env vars and loop commands ---

@test "launch.md references env.project for var export" {
  grep -q 'env.project' "$COMMANDS_DIR/launch.md" || grep -q 'env\.project' "$COMMANDS_DIR/launch.md"
}

@test "launch.md references loop prompt files in worktree loops/" {
  grep -q '\.worktrees/.*loops/' "$COMMANDS_DIR/launch.md"
}

@test "launch.md sends /loop command for polling sessions" {
  grep -q '/loop' "$COMMANDS_DIR/launch.md"
}

@test "launch.md exports env vars via tmux send-keys" {
  grep -q 'export' "$COMMANDS_DIR/launch.md"
}

@test "launch.md report table includes Loop column" {
  grep -q 'Loop' "$COMMANDS_DIR/launch.md"
}

# --- config.md has env var menu option ---

@test "config.md has environment variables menu option" {
  grep -qi 'environment variable' "$COMMANDS_DIR/config.md"
}

# --- new.md scaffolds env and loops ---

@test "new.md scaffolds env section in PROJECT_CONFIG.json" {
  grep -q 'env' "$COMMANDS_DIR/new.md"
}

@test "new.md creates worktree loops/ directories" {
  grep -q '\.worktrees.*loops' "$COMMANDS_DIR/new.md"
}

@test "new.md creates loop prompt files for polling roles" {
  grep -q 'loop.*prompt\|loops.*master\|loops.*triager' "$COMMANDS_DIR/new.md"
}

# --- status.md shows env/loop state ---

@test "status.md references env vars" {
  grep -q 'env' "$COMMANDS_DIR/status.md"
}
