#!/usr/bin/env bats

# CPT-148: CPT-137's walk-up loop handles absolute nested paths correctly
# (`$HOME/new/deeply/nested/rr-work`) but also silently accepts RELATIVE
# RR_WORK_DIR values. The walk-up climbs until it hits `.` (always a
# valid existing directory), realpath canonicalizes it to `$PWD`, and the
# relative segments get rewritten to `$PWD/<relative>`. If $PWD happens
# to live under $HOME, the downstream `"$RESOLVED_HOME"/*` case guard
# accepts the path and operations run in an unintended location.
#
# Fix: reject any RR_WORK_DIR that doesn't start with `/` up front, BEFORE
# the walk-up loop. Preserves the original intent of the case guard
# ("must be under $HOME or /tmp") and surfaces user typos as clear errors
# instead of silently resolving them against $PWD.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
PREPARE_SH="$REPO_DIR/skills/rr/bin/rr-prepare.sh"
FINALIZE_SH="$REPO_DIR/skills/rr/bin/rr-finalize.sh"

setup() {
  [ -f "$PREPARE_SH" ]
  [ -f "$FINALIZE_SH" ]
}

# Each script has required env vars for Jira — we only want to hit the
# WORK_DIR validation, not actually call Jira. We set dummy values for the
# required vars; the FATAL should fire from the WORK_DIR check before any
# Jira call is attempted.
_run_with_rr_work_dir() {
  local script="$1"
  local rr_work_dir="$2"
  local cwd="${3:-$HOME}"
  run bash -c "cd '$cwd' && JIRA_EMAIL=dummy JIRA_API_KEY=dummy RR_WORK_DIR='$rr_work_dir' bash '$script' 2>&1"
}

# --- Fixture shape 1: bare relative name (`foo/bar`) ---

@test "CPT-148: rr-prepare.sh rejects RR_WORK_DIR=foo/bar with FATAL" {
  _run_with_rr_work_dir "$PREPARE_SH" "foo/bar"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FATAL"* ]]
  [[ "$output" == *"absolute path"* ]]
}

@test "CPT-148: rr-finalize.sh rejects RR_WORK_DIR=foo/bar with FATAL" {
  _run_with_rr_work_dir "$FINALIZE_SH" "foo/bar"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FATAL"* ]]
  [[ "$output" == *"absolute path"* ]]
}

# --- Fixture shape 2: parent-traversal relative (`../foo`) ---

@test "CPT-148: rr-prepare.sh rejects RR_WORK_DIR=../foo with FATAL" {
  _run_with_rr_work_dir "$PREPARE_SH" "../foo"
  [ "$status" -ne 0 ]
  [[ "$output" == *"absolute path"* ]]
}

@test "CPT-148: rr-finalize.sh rejects RR_WORK_DIR=../foo with FATAL" {
  _run_with_rr_work_dir "$FINALIZE_SH" "../foo"
  [ "$status" -ne 0 ]
  [[ "$output" == *"absolute path"* ]]
}

# --- Fixture shape 3: explicit CWD prefix (`./foo`) ---

@test "CPT-148: rr-prepare.sh rejects RR_WORK_DIR=./foo with FATAL" {
  _run_with_rr_work_dir "$PREPARE_SH" "./foo"
  [ "$status" -ne 0 ]
  [[ "$output" == *"absolute path"* ]]
}

# --- Fixture shape 4: bare name (`foo`) ---

@test "CPT-148: rr-prepare.sh rejects RR_WORK_DIR=foo with FATAL" {
  _run_with_rr_work_dir "$PREPARE_SH" "foo"
  [ "$status" -ne 0 ]
  [[ "$output" == *"absolute path"* ]]
}

# --- Sanity: the CPT-148 check does NOT break absolute paths under /tmp ---

@test "CPT-148: absolute /tmp path passes the CPT-148 check" {
  # Use a /tmp path that doesn't exist — this should pass CPT-148 and
  # proceed to downstream validation (which will either succeed or fail
  # for OTHER reasons like missing JIRA credentials, not because of the
  # CPT-148 absolute-path check).
  local tmpdir
  tmpdir="$(mktemp -d)/rr-work"
  _run_with_rr_work_dir "$PREPARE_SH" "$tmpdir"

  # The output must NOT contain the CPT-148 absolute-path error. It may
  # still FATAL for other reasons (e.g. missing curl), but not for the
  # path-shape reason.
  if echo "$output" | grep -q "must be an absolute path"; then
    echo "absolute /tmp path was incorrectly rejected by CPT-148 check" >&2
    echo "$output" >&2
    return 1
  fi

  rm -rf "$(dirname "$tmpdir")"
}

# --- Static: both scripts have the CPT-148 absolute-path gate before the walk-up ---

@test "CPT-148: rr-prepare.sh contains the absolute-path case guard" {
  # The case guard `case "$WORK_DIR" in /*) ;; *) ... exit 1 ;; esac` must
  # appear BEFORE the _rr_resolve_work_dir_with_missing_tail function
  # definition (line ~44 in the current file). We check ordering via
  # line numbers.
  local gate_line walkup_line
  gate_line=$(grep -nE '\*\) echo "FATAL: RR_WORK_DIR must be an absolute path' "$PREPARE_SH" | head -1 | cut -d: -f1)
  walkup_line=$(grep -nE '^_rr_resolve_work_dir_with_missing_tail\(\)' "$PREPARE_SH" | head -1 | cut -d: -f1)
  [ -n "$gate_line" ] || { echo "CPT-148 gate missing in rr-prepare.sh" >&2; return 1; }
  [ -n "$walkup_line" ] || { echo "walk-up function missing in rr-prepare.sh" >&2; return 1; }
  [ "$gate_line" -lt "$walkup_line" ] || {
    echo "CPT-148 gate (line $gate_line) must precede walk-up function (line $walkup_line)" >&2
    return 1
  }
}

@test "CPT-148: rr-finalize.sh contains the absolute-path case guard" {
  local gate_line walkup_line
  gate_line=$(grep -nE '\*\) echo "FATAL: RR_WORK_DIR must be an absolute path' "$FINALIZE_SH" | head -1 | cut -d: -f1)
  walkup_line=$(grep -nE '^_rr_resolve_work_dir_with_missing_tail\(\)' "$FINALIZE_SH" | head -1 | cut -d: -f1)
  [ -n "$gate_line" ] || { echo "CPT-148 gate missing in rr-finalize.sh" >&2; return 1; }
  [ -n "$walkup_line" ] || { echo "walk-up function missing in rr-finalize.sh" >&2; return 1; }
  [ "$gate_line" -lt "$walkup_line" ] || {
    echo "CPT-148 gate (line $gate_line) must precede walk-up function (line $walkup_line)" >&2
    return 1
  }
}
