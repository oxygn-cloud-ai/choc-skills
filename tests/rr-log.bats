#!/usr/bin/env bats

# Tests for rr-prepare.sh and rr-finalize.sh log() behavior when
# the work directory doesn't exist yet (CPT-38).

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "rr-prepare.sh produces clean error when WORK_DIR does not exist" {
  # Run without JIRA credentials to trigger early exit via check_env/die.
  # The log() and die() functions must not produce tee errors.
  export RR_WORK_DIR="/tmp/rr-test-nonexistent-$$"
  [ ! -d "$RR_WORK_DIR" ]  # Ensure it truly doesn't exist
  run bash -c "bash '$REPO_DIR/skills/rr/bin/rr-prepare.sh' 2>&1"
  # stderr+stdout must NOT contain tee errors
  [[ "$output" != *"tee:"* ]]
  [[ "$output" == *"FATAL"* ]]
}

@test "rr-finalize.sh produces clean error when WORK_DIR does not exist" {
  export RR_WORK_DIR="/tmp/rr-test-nonexistent-$$"
  [ ! -d "$RR_WORK_DIR" ]
  run bash -c "bash '$REPO_DIR/skills/rr/bin/rr-finalize.sh' 2>&1"
  # Should fail (missing creds or dir), but stderr must NOT contain tee errors
  [[ "$output" != *"tee:"* ]]
}
