#!/usr/bin/env bats

# Tests for scripts/validate-config.sh — PROJECT_CONFIG.json validation.
#
# Each test creates a temporary directory with its own config and schema,
# so tests never touch the real project files.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
VALIDATOR="${REPO_DIR}/scripts/validate-config.sh"
SCHEMA="${REPO_DIR}/PROJECT_CONFIG.schema.json"

setup() {
  TEST_DIR="$(mktemp -d)"
  # Copy schema to test dir
  cp "$SCHEMA" "$TEST_DIR/PROJECT_CONFIG.schema.json"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# Helper: write a valid config to TEST_DIR
write_valid_config() {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": {
    "name": "test-project",
    "type": "software",
    "description": "A test project"
  },
  "jira": {
    "projectKey": "TST",
    "epicKey": "TST-1"
  },
  "github": {
    "owner": "test-org",
    "repo": "test-project"
  },
  "sessions": {
    "roles": ["master", "fixer", "reviewer", "merger", "triager"]
  }
}
EOF
}

# --- Exit code tests ---

@test "validate-config: valid config exits 0" {
  write_valid_config
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Result: PASS"* ]]
}

@test "validate-config: missing config file exits 2" {
  run "$VALIDATOR" "$TEST_DIR/nonexistent.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[FAIL]"* ]]
}

@test "validate-config: invalid JSON exits 1" {
  echo "{ not valid json" > "$TEST_DIR/PROJECT_CONFIG.json"
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid JSON syntax"* ]]
}

# --- Schema validation tests ---

@test "validate-config: missing required field fails schema validation" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": {
    "name": "test",
    "type": "software"
  }
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Schema validation failed"* ]]
}

@test "validate-config: wrong schemaVersion fails" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 99,
  "project": { "name": "test", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "test" },
  "sessions": { "roles": ["master"] }
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[FAIL]"* ]]
}

@test "validate-config: invalid project type fails schema validation" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": { "name": "test", "type": "invalid-type" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "test" },
  "sessions": { "roles": ["master"] }
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Schema validation failed"* ]]
}

@test "validate-config: invalid role in sessions.roles fails" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": { "name": "test", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "test" },
  "sessions": { "roles": ["master", "nonexistent-role"] }
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Schema validation failed"* ]]
}

@test "validate-config: additional properties rejected" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": { "name": "test", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "test" },
  "sessions": { "roles": ["master"] },
  "unknownField": true
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Schema validation failed"* ]]
}

# --- Semantic check tests ---

@test "validate-config: epicKey must start with projectKey" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": { "name": "test", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "OTHER-1" },
  "github": { "owner": "org", "repo": "test" },
  "sessions": { "roles": ["master"] }
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not start with"* ]]
}

@test "validate-config: loop role not in roles list fails" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": { "name": "test", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "test" },
  "sessions": {
    "roles": ["master"],
    "loops": {
      "master": { "intervalMinutes": 5 },
      "fixer": { "intervalMinutes": 10 }
    }
  }
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not in sessions.roles"* ]]
}

@test "validate-config: full valid config with all sections passes" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": {
    "name": "full-project",
    "type": "software",
    "description": "A fully configured project"
  },
  "jira": {
    "projectKey": "FP",
    "cloudId": "abc-123",
    "epicKey": "FP-1",
    "boardUrl": "https://example.atlassian.net/board/1"
  },
  "github": {
    "owner": "test-org",
    "repo": "full-project",
    "defaultBranch": "main",
    "issuesEnabled": false,
    "branchProtection": {
      "requiredStatusChecks": ["test", "lint"],
      "strict": true,
      "enforceAdmins": false,
      "allowForcePushes": false,
      "allowDeletions": false
    }
  },
  "sessions": {
    "roles": ["master", "fixer", "implementer", "reviewer", "merger", "triager"],
    "loops": {
      "master": { "intervalMinutes": 5 },
      "fixer": { "intervalMinutes": 10 }
    }
  },
  "coverage": {
    "tool": "kcov",
    "thresholds": {
      "line": 80,
      "branch": 60
    }
  },
  "sandbox": {
    "type": "docker",
    "setupInstructions": "docker run -it ubuntu bash"
  },
  "servers": {
    "test": "http://localhost:3000",
    "staging": "https://staging.example.com"
  },
  "deviations": [
    {
      "standard": "Coverage thresholds",
      "deviation": "Branch coverage below 70%",
      "justification": "Complex shell scripts with many error paths"
    }
  ]
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Result: PASS"* ]]
}

@test "validate-config: non-software project type accepted" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": { "name": "docs-only", "type": "non-software" },
  "jira": { "projectKey": "DOC", "epicKey": "DOC-1" },
  "github": { "owner": "org", "repo": "docs-only" },
  "sessions": { "roles": ["master", "planner"] }
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Result: PASS"* ]]
}

@test "validate-config: real choc-skills config passes" {
  run "$VALIDATOR" "${REPO_DIR}/PROJECT_CONFIG.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Result: PASS"* ]]
}

@test "validate-config: missing schema file exits 2" {
  write_valid_config
  rm "$TEST_DIR/PROJECT_CONFIG.schema.json"
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"schema"* ]]
}

@test "validate-config: deviation missing justification fails" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": { "name": "test", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "test" },
  "sessions": { "roles": ["master"] },
  "deviations": [
    {
      "standard": "Something",
      "deviation": "We skip it"
    }
  ]
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Schema validation failed"* ]]
}

@test "validate-config: negative loop interval fails" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": { "name": "test", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "test" },
  "sessions": {
    "roles": ["master"],
    "loops": { "master": { "intervalMinutes": -5 } }
  }
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Schema validation failed"* ]]
}

@test "validate-config: loop on non-loop-capable role (planner) fails" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": { "name": "test", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "test" },
  "sessions": {
    "roles": ["master", "planner"],
    "loops": { "planner": { "intervalMinutes": 5 } }
  }
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Schema validation failed"* ]]
}

@test "validate-config: env section with project and session vars accepted" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": { "name": "test", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "test" },
  "sessions": { "roles": ["master", "chk2"] },
  "env": {
    "project": { "JIRA_PROJECT": "TST" },
    "sessions": {
      "chk2": { "TARGET_HOST": "staging.example.com" }
    }
  }
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Result: PASS"* ]]
}

@test "validate-config: env with additional top-level property fails" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": { "name": "test", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "test" },
  "sessions": { "roles": ["master"] },
  "env": { "globals": { "FOO": "bar" } }
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Schema validation failed"* ]]
}

@test "validate-config: loop with prompt path accepted" {
  cat > "$TEST_DIR/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": { "name": "test", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "test" },
  "sessions": {
    "roles": ["master", "fixer"],
    "loops": {
      "master": { "intervalMinutes": 5, "prompt": "loops/loop.md" },
      "fixer": { "intervalMinutes": 10, "prompt": "loops/custom.md" }
    }
  }
}
EOF
  run "$VALIDATOR" "$TEST_DIR/PROJECT_CONFIG.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Result: PASS"* ]]
}
