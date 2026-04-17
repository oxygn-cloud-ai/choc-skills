#!/usr/bin/env bats

# CPT-83 Phase 3.0: pure helpers + JSON schema for the Jira-backed progress
# registry. No Jira side effects — the bats suite stubs all inputs and
# asserts on pure computations.
#
# Phase 3.1 (follow-up) adds the bootstrap script that actually creates the
# Jira tickets. Phase 3.2 (follow-up) wires /project:audit + loop.md to
# use the registry at runtime.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
LIB="${REPO_DIR}/skills/project/bin/_progress-registry.sh"
SCHEMA="${REPO_DIR}/skills/project/schemas/progress-registry.schema.json"

# Source the library into every test's shell so functions are callable
# directly without `bash -c` gymnastics. The sourcing is guarded so the
# "file exists" test still runs even before the lib is created.
setup() {
  if [ -f "$LIB" ]; then
    # shellcheck disable=SC1090
    source "$LIB"
  fi
}

# --- File presence ---

@test "progress-registry (CPT-83.0): helper library exists at skills/project/bin/_progress-registry.sh" {
  [ -f "$LIB" ] || { echo "info: missing $LIB"; return 1; }
}

@test "progress-registry (CPT-83.0): JSON schema exists at skills/project/schemas/progress-registry.schema.json" {
  [ -f "$SCHEMA" ] || { echo "info: missing $SCHEMA"; return 1; }
}

# --- JSON Schema semantics ---

@test "progress-registry (CPT-83.0): schema validates canonical example" {
  command -v python3 >/dev/null 2>&1 || skip "python3 required"
  python3 -c "import jsonschema" 2>/dev/null || skip "jsonschema required"

  local tmp="$BATS_TEST_TMPDIR/good.json"
  cat > "$tmp" <<'EOF'
{
  "version": 1,
  "lastUpdated": "2026-04-17T02:30:00Z",
  "roles": {
    "master":      {"currentProgressTicket": "CPT-90", "archivedTickets": [], "cycleCount": 0, "lastCycleAt": null},
    "planner":     {"currentProgressTicket": "CPT-91", "archivedTickets": [], "cycleCount": 0, "lastCycleAt": null},
    "implementer": {"currentProgressTicket": "CPT-92", "archivedTickets": [], "cycleCount": 0, "lastCycleAt": null},
    "fixer":       {"currentProgressTicket": "CPT-93", "archivedTickets": [], "cycleCount": 0, "lastCycleAt": null},
    "merger":      {"currentProgressTicket": "CPT-94", "archivedTickets": [], "cycleCount": 0, "lastCycleAt": null},
    "chk1":        {"currentProgressTicket": "CPT-95", "archivedTickets": [], "cycleCount": 0, "lastCycleAt": null},
    "chk2":        {"currentProgressTicket": "CPT-96", "archivedTickets": [], "cycleCount": 0, "lastCycleAt": null},
    "performance": {"currentProgressTicket": "CPT-97", "archivedTickets": [], "cycleCount": 0, "lastCycleAt": null},
    "playtester":  {"currentProgressTicket": "CPT-98", "archivedTickets": [], "cycleCount": 0, "lastCycleAt": null},
    "reviewer":    {"currentProgressTicket": "CPT-99", "archivedTickets": [], "cycleCount": 0, "lastCycleAt": null},
    "triager":     {"currentProgressTicket": "CPT-100", "archivedTickets": [], "cycleCount": 0, "lastCycleAt": null}
  }
}
EOF

  run python3 -c "
import json, sys
from jsonschema import validate
with open('$SCHEMA') as f: schema = json.load(f)
with open('$tmp') as f: data = json.load(f)
validate(instance=data, schema=schema)
print('OK')
"
  [ "$status" -eq 0 ] || { echo "info: $output"; return 1; }
  [[ "$output" == *OK* ]]
}

@test "progress-registry (CPT-83.0): schema rejects missing version" {
  command -v python3 >/dev/null 2>&1 || skip "python3 required"
  python3 -c "import jsonschema" 2>/dev/null || skip "jsonschema required"

  run python3 -c "
import json, sys
from jsonschema import validate, ValidationError
with open('$SCHEMA') as f: schema = json.load(f)
data = {'lastUpdated': '2026-04-17T02:30:00Z', 'roles': {}}
try: validate(instance=data, schema=schema); print('OK')
except ValidationError: print('REJECT')
"
  [[ "$output" == *REJECT* ]] || { echo "info: schema accepted missing version: $output"; return 1; }
}

@test "progress-registry (CPT-83.0): schema rejects invalid role name" {
  command -v python3 >/dev/null 2>&1 || skip "python3 required"
  python3 -c "import jsonschema" 2>/dev/null || skip "jsonschema required"

  run python3 -c "
import json, sys
from jsonschema import validate, ValidationError
with open('$SCHEMA') as f: schema = json.load(f)
data = {'version': 1, 'lastUpdated': '2026-04-17T02:30:00Z',
        'roles': {'not-a-real-role': {'currentProgressTicket': 'X', 'archivedTickets': [], 'cycleCount': 0, 'lastCycleAt': None}}}
try: validate(instance=data, schema=schema); print('OK')
except ValidationError: print('REJECT')
"
  [[ "$output" == *REJECT* ]] || { echo "info: schema accepted unknown role: $output"; return 1; }
}

# --- Pure helper functions ---

@test "progress-registry (CPT-83.0): registry_extract_json pulls json fenced block out of description" {
  local desc
  desc=$(cat <<'EOF'
# Pinned Session Progress Registry

Some narrative text.

```json
{"version": 1, "roles": {}}
```

More text.
EOF
  )
  run registry_extract_json "$desc"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"version": 1'* ]] && [[ "$output" == *'"roles"'* ]]
}

@test "progress-registry (CPT-83.0): registry_extract_json returns empty (exit 1) on no-json input" {
  run registry_extract_json "No JSON here, just text."
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "progress-registry (CPT-83.0): registry_validate_json exits 0 on valid input" {
  command -v python3 >/dev/null 2>&1 || skip "python3 required"
  python3 -c "import jsonschema" 2>/dev/null || skip "jsonschema required"

  local valid='{"version": 1, "lastUpdated": "2026-04-17T02:30:00Z", "roles": {"master": {"currentProgressTicket": "CPT-1", "archivedTickets": [], "cycleCount": 0, "lastCycleAt": null}}}'
  run registry_validate_json "$valid"
  [ "$status" -eq 0 ] || { echo "info: validate failed on valid input: $output"; return 1; }
}

@test "progress-registry (CPT-83.0): registry_validate_json exits non-zero on invalid input" {
  command -v python3 >/dev/null 2>&1 || skip "python3 required"
  python3 -c "import jsonschema" 2>/dev/null || skip "jsonschema required"

  local invalid='{"lastUpdated": "X"}'  # missing version, missing roles
  run registry_validate_json "$invalid"
  [ "$status" -ne 0 ] || { echo "info: validate accepted invalid input"; return 1; }
}

@test "progress-registry (CPT-83.0): registry_get_role_ticket returns expected key" {
  local j='{"version": 1, "roles": {"master": {"currentProgressTicket": "CPT-90"}}}'
  run registry_get_role_ticket "$j" master
  [ "$status" -eq 0 ]
  [ "$output" = "CPT-90" ]
}

@test "progress-registry (CPT-83.0): registry_get_role_ticket returns empty for absent role" {
  local j='{"version": 1, "roles": {"master": {"currentProgressTicket": "CPT-90"}}}'
  run registry_get_role_ticket "$j" missing
  # Exit 0 or 1 is fine; output MUST be empty
  [ -z "$output" ] || { echo "info: expected empty; got: $output"; return 1; }
}

@test "progress-registry (CPT-83.0): registry_format_cycle_comment contains all 6 required fields" {
  run registry_format_cycle_comment master 12 idle "checked CI, 2 green 1 in_progress" "2026-04-17T02:35:00Z" 23
  [ "$status" -eq 0 ]
  # Required field markers per CPT-74 §3.3 canonical example
  [[ "$output" == *"cycle #12"* ]] || { echo "info: cycle marker missing: $output"; return 1; }
  [[ "$output" == *"master"* ]] || { echo "info: role marker missing"; return 1; }
  [[ "$output" == *"idle"* ]] || { echo "info: status missing"; return 1; }
  [[ "$output" == *"checked CI"* ]] || { echo "info: since-last missing"; return 1; }
  [[ "$output" == *"2026-04-17T02:35:00Z"* ]] || { echo "info: next-eta missing"; return 1; }
  [[ "$output" == *"23"* ]] || { echo "info: ctx_pct missing"; return 1; }
}

@test "progress-registry (CPT-83.0): registry_needs_rollover false when under both thresholds" {
  run registry_needs_rollover 1000 5
  [ "$status" -eq 1 ]
}

@test "progress-registry (CPT-83.0): registry_needs_rollover true when over byte threshold" {
  # 500 KB = 512000 bytes; over threshold
  run registry_needs_rollover 600000 5
  [ "$status" -eq 0 ]
}

@test "progress-registry (CPT-83.0): registry_needs_rollover true when over comment-count threshold" {
  run registry_needs_rollover 1000 301
  [ "$status" -eq 0 ]
}

@test "progress-registry (CPT-83.0): registry_needs_rollover false at exact threshold (strictly greater)" {
  # 500 KB exact = 512000; 300 comments exact. Boundary should NOT roll.
  run registry_needs_rollover 512000 300
  [ "$status" -eq 1 ] || { echo "info: threshold should be strict-greater"; return 1; }
}

@test "progress-registry (CPT-83.0): registry_new_ticket_summary formats 'Progress: <role> #<n+1>'" {
  run registry_new_ticket_summary master 1
  [ "$status" -eq 0 ]
  [ "$output" = "Progress: master #2" ]
}

# --- Installer wiring ---

@test "progress-registry (CPT-83.0): install.sh copies bin/*.sh to ~/.local/bin/ (catches _progress-registry.sh)" {
  # The installer iterates bin/*.sh and copies each. _progress-registry.sh
  # lives in bin/ so the loop picks it up automatically.
  grep -q 'for file in ".*BIN_SOURCE.*"/\*\.sh' "${REPO_DIR}/skills/project/install.sh" \
    || grep -q 'BIN_SOURCE.*\*\.sh' "${REPO_DIR}/skills/project/install.sh" \
    || { echo "info: install.sh does not iterate bin/*.sh"; return 1; }
  # And the bin source file itself must exist (double-check so the glob
  # actually finds something).
  [ -f "${REPO_DIR}/skills/project/bin/_progress-registry.sh" ] \
    || { echo "info: bin/_progress-registry.sh missing"; return 1; }
}

@test "progress-registry (CPT-83.0): install.sh installs schemas/ dir" {
  grep -q 'schemas' "${REPO_DIR}/skills/project/install.sh" \
    || { echo "info: install.sh has no schemas/ install step"; return 1; }
}

# --- Docs ---

@test "progress-registry (CPT-83.0): docs/progress-registry.md exists and covers key topics" {
  local DOC="${REPO_DIR}/skills/project/docs/progress-registry.md"
  [ -f "$DOC" ] || { echo "info: missing $DOC"; return 1; }
  grep -qi 'topology\|pinned registry\|read pattern\|write pattern\|rollover\|MEMORY.md' "$DOC" \
    || { echo "info: docs don't cover required topics"; return 1; }
}
