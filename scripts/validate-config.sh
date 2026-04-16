#!/usr/bin/env bash
# validate-config.sh — Validate PROJECT_CONFIG.json against PROJECT_CONFIG.schema.json
# Usage: ./scripts/validate-config.sh [path/to/PROJECT_CONFIG.json]
#
# If no path is given, looks for PROJECT_CONFIG.json in the current directory,
# then walks up to the repo root.
#
# Exit codes:
#   0 — valid
#   1 — validation errors found
#   2 — missing file or missing dependencies

set -euo pipefail

ERRORS=0

err() { echo "[FAIL] $*" >&2; ERRORS=$((ERRORS + 1)); }
pass() { echo "[PASS] $*"; }
warn() { echo "[WARN] $*"; }

# --- Locate config file ---

CONFIG_FILE="${1:-}"

if [[ -z "$CONFIG_FILE" ]]; then
  # Walk up from cwd to find PROJECT_CONFIG.json
  dir="$(pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/PROJECT_CONFIG.json" ]]; then
      CONFIG_FILE="$dir/PROJECT_CONFIG.json"
      break
    fi
    dir="$(dirname "$dir")"
  done
fi

if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
  err "PROJECT_CONFIG.json not found"
  echo ""
  echo "Usage: $0 [path/to/PROJECT_CONFIG.json]"
  exit 2
fi

CONFIG_DIR="$(cd "$(dirname "$CONFIG_FILE")" && pwd)"
CONFIG_FILE="$CONFIG_DIR/$(basename "$CONFIG_FILE")"

echo "Validating: $CONFIG_FILE"
echo ""

# --- Locate schema file ---

SCHEMA_FILE="$CONFIG_DIR/PROJECT_CONFIG.schema.json"
if [[ ! -f "$SCHEMA_FILE" ]]; then
  err "PROJECT_CONFIG.schema.json not found at $CONFIG_DIR/"
  echo "  The schema file must be in the same directory as PROJECT_CONFIG.json."
  exit 2
fi

# --- Check dependencies ---

if ! command -v jq &>/dev/null; then
  err "jq is required but not installed"
  exit 2
fi

if ! command -v python3 &>/dev/null; then
  err "python3 is required but not installed"
  exit 2
fi

if ! python3 -c "import jsonschema" 2>/dev/null; then
  err "python3 jsonschema module is required: pip3 install jsonschema"
  exit 2
fi

# --- Phase 1: Valid JSON ---

JQ_ERR=$(jq empty "$CONFIG_FILE" 2>&1) || {
  err "Invalid JSON syntax"
  echo "$JQ_ERR" | sed 's/^/  /'
  exit 1
}
pass "Valid JSON syntax"

# --- Phase 2: Schema validation ---

SCHEMA_RESULT=$(python3 -c "
import json, sys
from jsonschema import validate, ValidationError, SchemaError

with open('$SCHEMA_FILE') as f:
    schema = json.load(f)
with open('$CONFIG_FILE') as f:
    config = json.load(f)

try:
    validate(instance=config, schema=schema)
    print('OK')
except ValidationError as e:
    path = '.'.join(str(p) for p in e.absolute_path) if e.absolute_path else '(root)'
    print(f'FAIL:{path}:{e.message}')
except SchemaError as e:
    print(f'SCHEMA_ERROR:{e.message}')
" 2>&1)

if [[ "$SCHEMA_RESULT" == "OK" ]]; then
  pass "Schema validation"
elif [[ "$SCHEMA_RESULT" == SCHEMA_ERROR:* ]]; then
  err "Schema file is invalid: ${SCHEMA_RESULT#SCHEMA_ERROR:}"
else
  err "Schema validation failed"
  echo "  Path: $(echo "$SCHEMA_RESULT" | cut -d: -f2)"
  echo "  Error: $(echo "$SCHEMA_RESULT" | cut -d: -f3-)"
fi

# --- Phase 3: Semantic checks (only if schema passed) ---

if [[ "$ERRORS" -gt 0 ]]; then
  echo ""
  echo "Result: FAIL — $ERRORS error(s) found (skipping semantic checks)"
  exit 1
fi

# Check schemaVersion
SV=$(jq -r '.schemaVersion' "$CONFIG_FILE")
if [[ "$SV" == "1" ]]; then
  pass "schemaVersion is 1"
else
  err "schemaVersion must be 1, got: $SV"
fi

# Check project.name matches directory name. In a git worktree the directory
# basename is the ROLE (e.g., "master"), not the project. Resolve to the main
# repo name via `git rev-parse --git-common-dir` so the check stays meaningful.
#
# CRITICAL: `git rev-parse --git-common-dir` can return a path relative to
# the git invocation cwd (`.git`) or absolute (when in a worktree). Without
# `--path-format=absolute` we'd `cd` relative to the process cwd, not
# CONFIG_DIR, resolving the wrong repo when the validator is invoked with a
# path arg from elsewhere. The flag is git 2.31+ (Mar 2021) — safe to require.
PROJ_NAME=$(jq -r '.project.name' "$CONFIG_FILE")
DIR_NAME=$(basename "$CONFIG_DIR")
if command -v git &>/dev/null && git -C "$CONFIG_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
  COMMON_DIR=$(git -C "$CONFIG_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
  # Fallback for old git (<2.31) — resolve relative path against CONFIG_DIR.
  if [[ -z "$COMMON_DIR" ]]; then
    REL_COMMON=$(git -C "$CONFIG_DIR" rev-parse --git-common-dir 2>/dev/null || true)
    if [[ -n "$REL_COMMON" ]]; then
      if [[ "$REL_COMMON" = /* ]]; then
        COMMON_DIR="$REL_COMMON"
      else
        COMMON_DIR=$(cd "$CONFIG_DIR" && cd "$REL_COMMON" && pwd 2>/dev/null || true)
      fi
    fi
  fi
  if [[ -n "$COMMON_DIR" && -d "$COMMON_DIR" ]]; then
    # COMMON_DIR is <main-repo>/.git — its parent is the main repo.
    MAIN_REPO=$(cd "$COMMON_DIR/.." && pwd 2>/dev/null || true)
    [[ -n "$MAIN_REPO" ]] && DIR_NAME=$(basename "$MAIN_REPO")
  fi
fi
if [[ "$PROJ_NAME" == "$DIR_NAME" ]]; then
  pass "project.name matches repo directory name ($PROJ_NAME)"
else
  warn "project.name ($PROJ_NAME) does not match repo directory name ($DIR_NAME)"
fi

# Check jira.epicKey starts with jira.projectKey
PROJ_KEY=$(jq -r '.jira.projectKey' "$CONFIG_FILE")
EPIC_KEY=$(jq -r '.jira.epicKey' "$CONFIG_FILE")
if [[ "$EPIC_KEY" == "$PROJ_KEY"-* ]]; then
  pass "jira.epicKey ($EPIC_KEY) matches jira.projectKey ($PROJ_KEY)"
else
  err "jira.epicKey ($EPIC_KEY) does not start with jira.projectKey ($PROJ_KEY)"
fi

# Check all loop roles are in the roles list.
# CPT-42: loops relocated from .sessions.loops to top-level .loops. We read
# the new location and fall back to the old one if a caller still has a v0
# config (warn to flag the migration).
ROLES=$(jq -r '.sessions.roles[]' "$CONFIG_FILE" 2>/dev/null)
LOOP_ROLES=$(jq -r '.loops // {} | keys[]' "$CONFIG_FILE" 2>/dev/null)
if [[ -z "$LOOP_ROLES" ]] && [[ "$(jq -r '.sessions.loops // empty | keys // []' "$CONFIG_FILE" 2>/dev/null)" != "[]" ]]; then
  warn ".sessions.loops is deprecated (CPT-42) — move this block to top-level .loops"
  LOOP_ROLES=$(jq -r '.sessions.loops // {} | keys[]' "$CONFIG_FILE" 2>/dev/null)
fi
for role in $LOOP_ROLES; do
  if echo "$ROLES" | grep -qx "$role"; then
    pass "Loop role '$role' is in sessions.roles"
  else
    err "Loop role '$role' has a loop config but is not in sessions.roles"
  fi
done

# Check every loop-capable role in sessions.roles has a loops entry (or warn).
# Loop-capable roles are the 8 polling roles: master, triager, reviewer,
# merger, chk1, chk2, fixer, implementer. A missing entry isn't an error —
# the launcher will just skip dispatch — but it's almost always a config
# mistake worth surfacing.
LOOP_CAPABLE="master triager reviewer merger chk1 chk2 fixer implementer"
for role in $LOOP_CAPABLE; do
  if echo "$ROLES" | grep -qx "$role"; then
    if echo "$LOOP_ROLES" | grep -qx "$role"; then
      :
    else
      warn "Loop-capable role '$role' is in sessions.roles but has no .loops entry (launcher will skip /loop for this role)"
    fi
  fi
done

# CPT-42: validate driver field per role. Must be one of shell / session / none.
# Missing driver is allowed (defaults to session) but emit a WARN so the operator
# knows which path the launcher will take.
VALID_DRIVERS="shell session none"
for role in $LOOP_ROLES; do
  ROLE_DRIVER=$(jq -r --arg r "$role" '.loops[$r].driver // "session"' "$CONFIG_FILE" 2>/dev/null)
  if echo "$VALID_DRIVERS" | grep -qw "$ROLE_DRIVER"; then
    pass "Loop role '$role' driver is valid ($ROLE_DRIVER)"
  else
    err "Loop role '$role' has invalid driver '$ROLE_DRIVER' (must be one of: $VALID_DRIVERS)"
  fi
done

# CPT-42 AC #8: allowedTools per role. Array-of-strings shape is enforced by the
# JSON Schema; here we check semantic consistency — shell-driver roles should
# have a non-empty allowedTools list, and non-string entries (if any slipped
# past the schema because a tool was run without --schema) get flagged.
for role in $LOOP_ROLES; do
  ROLE_DRIVER=$(jq -r --arg r "$role" '.loops[$r].driver // "session"' "$CONFIG_FILE" 2>/dev/null)
  ALLOWED_TYPE=$(jq -r --arg r "$role" '.sessions[$r].allowedTools | type' "$CONFIG_FILE" 2>/dev/null)
  case "$ALLOWED_TYPE" in
    array)
      ALLOWED_LEN=$(jq -r --arg r "$role" '.sessions[$r].allowedTools | length' "$CONFIG_FILE")
      NON_STRING=$(jq -r --arg r "$role" '[.sessions[$r].allowedTools[] | select(type != "string")] | length' "$CONFIG_FILE" 2>/dev/null)
      if [[ "$NON_STRING" -gt 0 ]]; then
        err "sessions.$role.allowedTools contains $NON_STRING non-string entries (must be list of strings)"
      elif [[ "$ALLOWED_LEN" -eq 0 && "$ROLE_DRIVER" == "shell" ]]; then
        warn "sessions.$role.allowedTools is empty but driver is 'shell' — claude -p will run with its default allowlist"
      else
        pass "sessions.$role.allowedTools is a valid array ($ALLOWED_LEN entries)"
      fi
      ;;
    null)
      if [[ "$ROLE_DRIVER" == "shell" ]]; then
        warn "sessions.$role.allowedTools not set but driver is 'shell' — claude -p will run with its default allowlist"
      fi
      ;;
    *)
      err "sessions.$role.allowedTools must be an array, got: $ALLOWED_TYPE"
      ;;
  esac
done

# env.sessions.<role> keys must appear in sessions.roles (schema pattern
# allows any of the 11 role names, but declaring env for a role that isn't
# active is almost certainly a bug).
ENV_SESSION_ROLES=$(jq -r '.env.sessions // {} | keys[]' "$CONFIG_FILE" 2>/dev/null)
for role in $ENV_SESSION_ROLES; do
  if echo "$ROLES" | grep -qx "$role"; then
    pass "env.sessions.$role role is active in sessions.roles"
  else
    err "env.sessions.$role declares env vars for a role not in sessions.roles"
  fi
done

# env keys must be valid shell identifiers — schema doesn't enforce this and
# the launcher's `export $KEY=…` would fail if the key contains hyphens, dots,
# spaces, or starts with a digit.
INVALID_ENV_KEYS=$(jq -r '
  [(.env.project // {} | to_entries[] | .key),
   (.env.sessions // {} | to_entries[] | .value | to_entries[] | .key)]
  | .[]
' "$CONFIG_FILE" 2>/dev/null | awk '!/^[A-Za-z_][A-Za-z0-9_]*$/ {print}')
if [[ -n "$INVALID_ENV_KEYS" ]]; then
  while IFS= read -r bad; do
    err "env var name is not a valid shell identifier: '$bad' (must match ^[A-Za-z_][A-Za-z0-9_]*\$)"
  done <<< "$INVALID_ENV_KEYS"
else
  if [[ -n "$(jq -r '.env // empty' "$CONFIG_FILE" 2>/dev/null)" ]]; then
    pass "All env var names are valid shell identifiers"
  fi
fi

# Check github.owner/repo are non-empty
GH_OWNER=$(jq -r '.github.owner' "$CONFIG_FILE")
GH_REPO=$(jq -r '.github.repo' "$CONFIG_FILE")
if [[ -n "$GH_OWNER" && "$GH_OWNER" != "null" ]]; then
  pass "github.owner is set ($GH_OWNER)"
else
  err "github.owner is missing or empty"
fi
if [[ -n "$GH_REPO" && "$GH_REPO" != "null" ]]; then
  pass "github.repo is set ($GH_REPO)"
else
  err "github.repo is missing or empty"
fi

# Check deviations have all required fields
DEV_COUNT=$(jq -r '.deviations // [] | length' "$CONFIG_FILE")
if [[ "$DEV_COUNT" -gt 0 ]]; then
  for i in $(seq 0 $((DEV_COUNT - 1))); do
    STD=$(jq -r ".deviations[$i].standard" "$CONFIG_FILE")
    DEV=$(jq -r ".deviations[$i].deviation" "$CONFIG_FILE")
    JUST=$(jq -r ".deviations[$i].justification" "$CONFIG_FILE")
    if [[ -n "$STD" && "$STD" != "null" && -n "$DEV" && "$DEV" != "null" && -n "$JUST" && "$JUST" != "null" ]]; then
      pass "Deviation $i has all required fields"
    else
      err "Deviation $i is missing standard, deviation, or justification"
    fi
  done
fi

# --- Summary ---

echo ""
if [[ "$ERRORS" -eq 0 ]]; then
  echo "Result: PASS — $CONFIG_FILE is valid"
  exit 0
else
  echo "Result: FAIL — $ERRORS error(s) found"
  exit 1
fi
