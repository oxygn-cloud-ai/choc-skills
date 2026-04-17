#!/usr/bin/env bats

# CPT-155: _publish_one.sh's _cleanup must only remove the lock dir
# that THIS worker acquired.
#
# CPT-140 unified lock + attempt_headers cleanup into a single _cleanup
# function and installed `trap _cleanup EXIT` at the TOP of the script —
# before the mkdir lock-acquisition attempt. When a second xargs worker
# hits ALREADY_PUBLISHING and exit 0s, its trap fires and runs
# `rm -rf "$LOCK_DIR/${risk_key}.lock"` — deleting the lock that the
# FIRST worker is still holding. A third worker can then acquire the
# lock and publish the same risk concurrently with the first.
#
# Fix: gate the lock rm in _cleanup on a LOCK_ACQUIRED=1 sentinel set
# only inside the mkdir-succeeded branch. attempt_headers rm stays
# unconditional because that tempfile is never shared between workers.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/skills/rr/bin/_publish_one.sh"

setup() {
  [ -f "$SCRIPT" ]
  TMPDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR"
}

# --- non-owner cleanup (the P1 bug) ---

@test "CPT-155: non-owner _cleanup (LOCK_ACQUIRED=0) preserves another worker's lock" {
  # Simulate worker B: LOCK_DIR is set, the lock for RR-TEST is already held
  # by worker A (pre-existing directory), B is about to exit from the
  # ALREADY_PUBLISHING branch so its LOCK_ACQUIRED stays 0.

  local risk_key="RR-TEST"
  mkdir "$TMPDIR/${risk_key}.lock"  # Worker A holds this

  run bash -c '
    set -euo pipefail
    LOCK_DIR="'"$TMPDIR"'"
    risk_key="'"$risk_key"'"
    LOCK_ACQUIRED=0
    attempt_headers=""
    # Source _cleanup from the real script
    eval "$(sed -n "/^_cleanup()/,/^}/p" "'"$SCRIPT"'")"
    _cleanup
  '
  [ "$status" -eq 0 ]

  # Lock must still exist — worker A owns it.
  [ -d "$TMPDIR/${risk_key}.lock" ]
}

# --- owner cleanup (normal path, must still remove lock) ---

@test "CPT-155: owner _cleanup (LOCK_ACQUIRED=1) removes the lock" {
  local risk_key="RR-TEST"
  mkdir "$TMPDIR/${risk_key}.lock"

  run bash -c '
    set -euo pipefail
    LOCK_DIR="'"$TMPDIR"'"
    risk_key="'"$risk_key"'"
    LOCK_ACQUIRED=1
    attempt_headers=""
    eval "$(sed -n "/^_cleanup()/,/^}/p" "'"$SCRIPT"'")"
    _cleanup
  '
  [ "$status" -eq 0 ]

  # Owner cleanup must remove the lock.
  [ ! -e "$TMPDIR/${risk_key}.lock" ]
}

# --- attempt_headers cleanup must stay unconditional ---
# (that tempfile is created per-worker, never shared across workers)

@test "CPT-155: non-owner _cleanup still removes attempt_headers tempfile" {
  local risk_key="RR-TEST"
  local tmpfile
  tmpfile=$(mktemp "$TMPDIR/headers.XXXXXX")
  [ -f "$tmpfile" ]

  run bash -c '
    set -euo pipefail
    LOCK_DIR="'"$TMPDIR"'"
    risk_key="'"$risk_key"'"
    LOCK_ACQUIRED=0
    attempt_headers="'"$tmpfile"'"
    eval "$(sed -n "/^_cleanup()/,/^}/p" "'"$SCRIPT"'")"
    _cleanup
  '
  [ "$status" -eq 0 ]

  # attempt_headers tempfile must be removed regardless of LOCK_ACQUIRED.
  [ ! -e "$tmpfile" ]
}

# --- the script must actually SET LOCK_ACQUIRED=1 inside the mkdir branch ---

@test "CPT-155: _publish_one.sh sets LOCK_ACQUIRED=1 inside the mkdir-succeeded branch" {
  # Static check: the body of the `mkdir "$LOCK_DIR/${risk_key}.lock"` success
  # path must assign LOCK_ACQUIRED=1 before falling through.
  # Pattern: any line matching LOCK_ACQUIRED=1 must exist in the script.
  grep -qE '^[[:space:]]*LOCK_ACQUIRED=1[[:space:]]*$' "$SCRIPT"
}

# --- and must declare LOCK_ACQUIRED=0 up front ---

@test "CPT-155: _publish_one.sh declares LOCK_ACQUIRED=0 before the trap" {
  # LOCK_ACQUIRED=0 must appear BEFORE the `trap _cleanup EXIT` line, so
  # the sentinel is defined if the script exits before the mkdir attempt.
  local init_line trap_line
  init_line=$(grep -nE '^[[:space:]]*LOCK_ACQUIRED=0[[:space:]]*$' "$SCRIPT" | head -1 | cut -d: -f1)
  trap_line=$(grep -nE '^trap _cleanup EXIT' "$SCRIPT" | head -1 | cut -d: -f1)
  [ -n "$init_line" ]
  [ -n "$trap_line" ]
  [ "$init_line" -lt "$trap_line" ]
}
