#!/usr/bin/env bats

# CPT-156: two defects in skills/project/commands/status.md's role-detection
# bash snippet added by CPT-139:
#
#   Concern 1 (P2): `.sessions.roles: []` is treated the same as "roles
#   key absent" because `jq -r '.sessions.roles[]? // empty'` emits zero
#   lines in both cases. A project that explicitly declares "no expected
#   roles" silently falls through to the full MSA catalog.
#
#   Concern 2 (P3): Layer 2/3 uses `local project_type=""` at the top
#   level of the bash snippet. `local` is a function-only builtin and
#   bash rejects it at top level ("local: can only be used in a function",
#   exit 1). Under set -e the whole snippet aborts before role detection
#   completes.
#
# Fix: add a SESSIONS_ROLES_DECLARED sentinel driven by
# `jq -e '.sessions | has("roles")'`; gate the fallback on it; drop `local`.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
STATUS_MD="$REPO_DIR/skills/project/commands/status.md"

# Extract the FIRST `bash` fenced block after the "Derive the expected
# role set" narrative (the one with `ROLES=()`).
_extract_role_detection_block() {
  awk '
    /^```bash$/ { in_block=1; next }
    /^```$/     { if (in_block && seen_roles) exit; in_block=0; next }
    in_block && /ROLES=\(\)/ { seen_roles=1 }
    in_block && seen_roles  { print }
  ' "$STATUS_MD"
}

setup() {
  unset CLAUDE_CONFIG_DIR  # CPT-174: ensure tests never inherit ambient CLAUDE_CONFIG_DIR
  [ -f "$STATUS_MD" ]
  TMPDIR="$(mktemp -d)"
  # Fake HOME with a minimal MULTI_SESSION_ARCHITECTURE.md so the Layer 2/3
  # fallback has a file to grep.
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME/.claude"
  cat > "$HOME/.claude/MULTI_SESSION_ARCHITECTURE.md" <<'EOF'
| Role | Branch |
|------|--------|
| master | `session/master` |
| fixer | `session/fixer` |
| implementer | `session/implementer` |
EOF
}

teardown() {
  [[ "$TMPDIR" == /tmp/* || "$TMPDIR" == /var/folders/* || "$TMPDIR" == /private/* ]] && rm -rf "$TMPDIR"
}

# --- Run the extracted block with a given PROJECT_CONFIG.json and report
#     ROLES + exit status + stderr.

_run_block() {
  local project_config_json="$1"
  local workdir="$TMPDIR/proj-$$-$RANDOM"
  mkdir -p "$workdir"
  if [ -n "$project_config_json" ]; then
    printf '%s' "$project_config_json" > "$workdir/PROJECT_CONFIG.json"
  fi
  local block
  block=$(_extract_role_detection_block)

  run bash -c "cd '$workdir' && set -e; $block
# Emit the result for test inspection
printf 'ROLES=['
for r in \"\${ROLES[@]}\"; do printf '%s ' \"\$r\"; done
printf ']\n'
"
  rm -rf "$workdir"
}

# --- Concern 2: snippet must not use `local` at top level ---

@test "CPT-156: status.md role-detection block does not use top-level 'local'" {
  local block
  block=$(_extract_role_detection_block)
  [ -n "$block" ]
  if echo "$block" | grep -qE '^\s*local\s+[A-Za-z_]'; then
    echo "status.md role-detection block uses top-level 'local' (will fail under set -e)" >&2
    echo "$block" | grep -nE '^\s*local\s+[A-Za-z_]' >&2
    return 1
  fi
}

@test "CPT-156: extracted block runs cleanly under set -e (no 'local:' stderr)" {
  # Run with a full PROJECT_CONFIG.json that has .sessions.roles set.
  _run_block '{"sessions":{"roles":["master","fixer"]},"project":{"type":"software"}}'
  [ "$status" -eq 0 ]
  if echo "$output" | grep -q "local: can only be used in a function"; then
    echo "bash emitted 'local' error — block still uses top-level 'local'" >&2
    echo "$output" >&2
    return 1
  fi
}

# --- Concern 1: empty roles array ≠ key absent ---

@test "CPT-156: sessions.roles=[] yields ROLES=[] (not MSA fallback)" {
  _run_block '{"sessions":{"roles":[]}}'
  [ "$status" -eq 0 ]
  # Must see "ROLES=[]" literally — no roles were added from the empty
  # array, and the MSA fallback was correctly gated off because the
  # sessions.roles key WAS declared.
  if ! echo "$output" | grep -qE '^ROLES=\[\s*\]$'; then
    echo "empty-array case incorrectly fell through to MSA catalog" >&2
    echo "$output" >&2
    return 1
  fi
}

@test "CPT-156: sessions.roles absent yields MSA-derived ROLES (fallback)" {
  _run_block '{"sessions":{}}'
  [ "$status" -eq 0 ]
  # MSA fallback should populate from the minimal MSA.md — at least one
  # of master/fixer/implementer must appear.
  if ! echo "$output" | grep -qE '^ROLES=\[.*(master|fixer|implementer).*\]$'; then
    echo "absent-key case did not fall through to MSA fallback" >&2
    echo "$output" >&2
    return 1
  fi
}

@test "CPT-156: sessions.roles populated yields those roles verbatim" {
  _run_block '{"sessions":{"roles":["master","fixer"]}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ROLES=[master fixer ]"* ]]
}

# --- Concern 1 static: sentinel-driven logic appears in the block ---

@test "CPT-156: role-detection block uses jq has('roles') sentinel" {
  local block
  block=$(_extract_role_detection_block)
  echo "$block" | grep -qE "jq -e '\.sessions \| has\(\"roles\"\)'" || {
    echo "role-detection block does not use jq has('roles') sentinel — empty-array semantics still broken" >&2
    return 1
  }
}

@test "CPT-156: MSA fallback is gated on SESSIONS_ROLES_DECLARED sentinel" {
  local block
  block=$(_extract_role_detection_block)
  echo "$block" | grep -qE 'SESSIONS_ROLES_DECLARED.*!= *"1"' || {
    echo "MSA fallback is not gated on SESSIONS_ROLES_DECLARED — empty-array will still fall through" >&2
    return 1
  }
}
