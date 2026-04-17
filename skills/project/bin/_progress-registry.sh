#!/usr/bin/env bash
# _progress-registry.sh — pure helpers for the Jira-backed progress registry.
#
# CPT-83 Phase 3.0: sourceable library with deterministic functions for
# reading/writing/validating the registry shape. No Jira round-trips —
# MCP calls are the caller's responsibility. This library is bats-testable
# without hitting live Jira.
#
# Phase 3.1 (follow-up) adds scripts/init-progress-registry.sh that actually
# creates the 12 Jira tickets (1 registry + 11 progress-per-role). Phase 3.2
# wires /project:audit + per-role loops/loop.md to use these helpers via
# the Atlassian MCP.
#
# Usage:
#   source ~/.local/bin/_progress-registry.sh
#   json=$(registry_extract_json "<description-string>")
#   registry_validate_json "$json" || die "invalid registry"
#   ticket=$(registry_get_role_ticket "$json" master)
#   body=$(registry_format_cycle_comment master 12 idle "..." "2026-04-17T02:35:00Z" 23)
#   registry_needs_rollover 512000 300 && echo rollover
#   new_sum=$(registry_new_ticket_summary master 1)
#
# Non-exec on macOS if sourced; chmod +x is harmless but not required.

# --- Constants (exposed for callers; override via env for testing) ---

REGISTRY_ROLLOVER_MAX_BYTES="${REGISTRY_ROLLOVER_MAX_BYTES:-512000}"   # 500 KB soft+hard cap
REGISTRY_ROLLOVER_MAX_COMMENTS="${REGISTRY_ROLLOVER_MAX_COMMENTS:-300}" # 300-comment soft cap

# Resolve the installed schema path. Schema ships alongside SKILL.md so we look
# first in the installed location, then fall back to the skill source tree for
# dev/test scenarios.
_registry_schema_path() {
  local p
  for p in \
    "${HOME}/.claude/skills/project/schemas/progress-registry.schema.json" \
    "$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/project/schemas" 2>/dev/null && pwd)/progress-registry.schema.json" \
    "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/schemas/progress-registry.schema.json"
  do
    [ -n "$p" ] && [ -f "$p" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

# registry_extract_json <description-string>
#
# Extract the ```json fenced block from a Jira issue description. Registry
# descriptions wrap the JSON map in a fenced code block for parseability.
# Exits 0 with the JSON on stdout if found; exits 1 with empty stdout if not.
registry_extract_json() {
  local input="$1"
  # Match the first ```json ... ``` block. Uses awk rather than sed -n so we
  # don't depend on GNU sed's -z flag (macOS sed lacks it).
  local extracted
  extracted=$(printf '%s\n' "$input" | awk '
    /^```json[[:space:]]*$/ { inside=1; next }
    /^```[[:space:]]*$/     { if (inside) exit }
    inside                  { print }
  ')
  if [ -z "$extracted" ]; then
    return 1
  fi
  printf '%s\n' "$extracted"
}

# registry_validate_json <json-string>
#
# Validate a JSON string against the registry schema. Exits 0 if valid,
# non-zero otherwise. Requires python3 + jsonschema module (same hard deps
# as scripts/validate-config.sh).
registry_validate_json() {
  local json="$1"
  local schema
  schema=$(_registry_schema_path) || {
    printf 'registry_validate_json: schema not found (expected at ~/.claude/skills/project/schemas/ or skills/project/schemas/)\n' >&2
    return 2
  }
  if ! command -v python3 >/dev/null 2>&1; then
    printf 'registry_validate_json: python3 not found (hard dependency)\n' >&2
    return 2
  fi
  local tmp; tmp=$(mktemp)
  printf '%s' "$json" > "$tmp"
  python3 - "$schema" "$tmp" <<'PYEOF'
import json, sys
try:
    from jsonschema import validate, ValidationError
except ImportError:
    print('jsonschema not installed', file=sys.stderr)
    sys.exit(2)
schema_path, data_path = sys.argv[1], sys.argv[2]
with open(schema_path) as f: schema = json.load(f)
try:
    with open(data_path) as f: data = json.load(f)
except json.JSONDecodeError as e:
    print(f'JSONDecodeError: {e}', file=sys.stderr)
    sys.exit(1)
try:
    validate(instance=data, schema=schema)
except ValidationError as e:
    print(f'ValidationError: {e.message}', file=sys.stderr)
    sys.exit(1)
PYEOF
  local rc=$?
  rm -f "$tmp"
  return "$rc"
}

# registry_get_role_ticket <json> <role>
#
# Return the currentProgressTicket for <role> on stdout. Empty + exit 1 if
# role is absent or json malformed.
registry_get_role_ticket() {
  local json="$1" role="$2"
  if ! command -v jq >/dev/null 2>&1; then
    printf 'registry_get_role_ticket: jq not found (hard dependency)\n' >&2
    return 2
  fi
  local result
  result=$(printf '%s' "$json" | jq -r --arg r "$role" '.roles[$r].currentProgressTicket // empty' 2>/dev/null)
  if [ -z "$result" ]; then
    return 1
  fi
  printf '%s\n' "$result"
}

# registry_format_cycle_comment <role> <cycle_num> <status> <since_last> <next_eta_utc> <ctx_pct>
#
# Produce the structured cycle comment body per CPT-74 §3.3. Output is a
# multi-line markdown block suitable for posting as a Jira comment.
registry_format_cycle_comment() {
  local role="$1" cycle_num="$2" status="$3" since_last="$4" next_eta_utc="$5" ctx_pct="$6"
  local ts
  ts=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
  cat <<EOF
[$ts] $role cycle #$cycle_num

Status: $status

Since last cycle:
  - $since_last

Next cycle scheduled: $next_eta_utc
Context utilisation at end of cycle: ${ctx_pct}%
EOF
}

# registry_needs_rollover <byte_size> <comment_count>
#
# Strict-greater-than check against REGISTRY_ROLLOVER_MAX_BYTES (default
# 500 KB) and REGISTRY_ROLLOVER_MAX_COMMENTS (default 300). Exits 0 (roll)
# if either cap is exceeded; exits 1 (don't roll) otherwise.
# Boundary semantics: "exactly at the cap" does NOT trigger rollover —
# only strictly-greater does. Matches CPT-74 §3.3: "Roll when EITHER cap is hit"
# where "hit" in this implementation means "exceeded".
registry_needs_rollover() {
  local bytes="$1" comments="$2"
  if [ "$bytes" -gt "$REGISTRY_ROLLOVER_MAX_BYTES" ]; then
    return 0
  fi
  if [ "$comments" -gt "$REGISTRY_ROLLOVER_MAX_COMMENTS" ]; then
    return 0
  fi
  return 1
}

# registry_new_ticket_summary <role> <n>
#
# Format the summary string for a new rolled-over progress ticket.
# Convention: "Progress: <role> #<n+1>" so the ticket numbering aligns with
# CPT-74 §3.3's "Progress: master #1", "Progress: master #2" pattern.
registry_new_ticket_summary() {
  local role="$1" current_n="$2"
  printf 'Progress: %s #%d\n' "$role" $((current_n + 1))
}
