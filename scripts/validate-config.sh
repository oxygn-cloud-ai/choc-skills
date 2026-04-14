#!/usr/bin/env bash
set -euo pipefail

# Validate PROJECT_CONFIG.json against expected schema using jq.
# Usage: validate-config.sh [path/to/PROJECT_CONFIG.json]
# Exit 0 on success, 1 on validation failure.

CONFIG="${1:-PROJECT_CONFIG.json}"
errors=0

# Colors (disabled if not a terminal)
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; RESET='\033[0m'
else
  GREEN=''; RED=''; RESET=''
fi

pass() { printf "${GREEN}  PASS${RESET}  %s\n" "$*"; }
fail() { printf "${RED}  FAIL${RESET}  %s\n" "$*"; errors=$((errors + 1)); }

# --- Pre-checks ---

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not found in PATH" >&2
  exit 1
fi

if [ ! -f "$CONFIG" ]; then
  echo "ERROR: Config file not found: $CONFIG" >&2
  exit 1
fi

if ! jq empty "$CONFIG" 2>/dev/null; then
  echo "ERROR: $CONFIG is not valid JSON" >&2
  exit 1
fi

echo "Validating $CONFIG..."
echo ""

# --- Required top-level keys ---

for key in schemaVersion project jira github sessions loops coverage deviations; do
  if jq -e --arg k "$key" 'has($k)' "$CONFIG" >/dev/null 2>&1; then
    pass "Top-level key: $key"
  else
    fail "Missing required top-level key: $key"
  fi
done

# --- schemaVersion ---

sv=$(jq '.schemaVersion' "$CONFIG")
if [ "$sv" = "1" ]; then
  pass "schemaVersion is 1"
else
  fail "schemaVersion must be 1 (got: $sv)"
fi

# --- project section ---

ptype=$(jq -r '.project.type // ""' "$CONFIG")
if [ "$ptype" = "software" ] || [ "$ptype" = "non-software" ]; then
  pass "project.type is valid: $ptype"
else
  fail "project.type must be 'software' or 'non-software' (got: '$ptype')"
fi

for field in name repo defaultBranch; do
  if jq -e --arg f "$field" '.project[$f] // empty' "$CONFIG" >/dev/null 2>&1; then
    pass "project.$field present"
  else
    fail "project.$field is missing or empty"
  fi
done

# --- sessions keys must be valid role names ---

VALID_ROLES="master planner implementer fixer merger chk1 chk2 performance playtester reviewer triager"

session_keys=$(jq -r '.sessions | keys[]' "$CONFIG" 2>/dev/null)
for sk in $session_keys; do
  found=0
  for vr in $VALID_ROLES; do
    if [ "$sk" = "$vr" ]; then found=1; break; fi
  done
  if [ "$found" -eq 1 ]; then
    pass "sessions.$sk is a valid role"
  else
    fail "sessions.$sk is not a valid role name"
  fi
done

# --- loops keys must be subset of the 8 valid polling roles ---

POLLING_ROLES="master triager reviewer merger chk1 chk2 fixer implementer"

loop_keys=$(jq -r '.loops | keys[]' "$CONFIG" 2>/dev/null)
for lk in $loop_keys; do
  found=0
  for pr in $POLLING_ROLES; do
    if [ "$lk" = "$pr" ]; then found=1; break; fi
  done
  if [ "$found" -eq 1 ]; then
    pass "loops.$lk is a valid polling role"
  else
    fail "loops.$lk is not a valid polling role (must be one of: $POLLING_ROLES)"
  fi
done

# --- intervalMinutes must be non-negative integers ---

for lk in $loop_keys; do
  iv=$(jq --arg k "$lk" '.loops[$k].intervalMinutes' "$CONFIG")
  if echo "$iv" | grep -qE '^[0-9]+$'; then
    pass "loops.$lk.intervalMinutes is a non-negative integer ($iv)"
  else
    fail "loops.$lk.intervalMinutes must be a non-negative integer (got: $iv)"
  fi
done

# --- env section (optional but validated if present) ---

if jq -e 'has("env")' "$CONFIG" >/dev/null 2>&1; then
  pass "Top-level key: env"

  # env.project must be an object
  if jq -e '.env.project | type == "object"' "$CONFIG" >/dev/null 2>&1; then
    pass "env.project is an object"
  else
    fail "env.project must be an object"
  fi

  # env.project values must be strings
  bad_types=$(jq '[.env.project | to_entries[] | select(.value | type != "string")] | length' "$CONFIG")
  if [ "$bad_types" = "0" ]; then
    pass "env.project values are all strings"
  else
    fail "env.project has $bad_types non-string values"
  fi

  # env.sessions must be an object with valid role keys
  if jq -e '.env.sessions | type == "object"' "$CONFIG" >/dev/null 2>&1; then
    pass "env.sessions is an object"
    env_session_keys=$(jq -r '.env.sessions | keys[]' "$CONFIG" 2>/dev/null)
    for esk in $env_session_keys; do
      found=0
      for vr in $VALID_ROLES; do
        if [ "$esk" = "$vr" ]; then found=1; break; fi
      done
      if [ "$found" -eq 1 ]; then
        pass "env.sessions.$esk is a valid role"
      else
        fail "env.sessions.$esk is not a valid role name"
      fi
    done
  else
    fail "env.sessions must be an object"
  fi
fi

# --- Summary ---

echo ""
if [ "$errors" -eq 0 ]; then
  echo "Validation passed: 0 errors"
  exit 0
else
  echo "Validation failed: $errors error(s)"
  exit 1
fi
