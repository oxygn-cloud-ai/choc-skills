#!/usr/bin/env bats

# Tests for scripts/generate-checksums.sh

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="${REPO_DIR}/scripts/generate-checksums.sh"
CHECKSUMS_FILE="${REPO_DIR}/CHECKSUMS.sha256"

setup() {
  # Snapshot the original file content (not a .bak file that could be left behind)
  if [ -f "$CHECKSUMS_FILE" ]; then
    ORIGINAL_CHECKSUMS="$(cat "$CHECKSUMS_FILE")"
  else
    ORIGINAL_CHECKSUMS=""
  fi
}

teardown() {
  # Restore original content — works even if the test failed or was killed
  if [ -n "$ORIGINAL_CHECKSUMS" ]; then
    printf '%s\n' "$ORIGINAL_CHECKSUMS" > "$CHECKSUMS_FILE"
  elif [ -f "$CHECKSUMS_FILE" ]; then
    rm -f "$CHECKSUMS_FILE"
  fi
}

@test "exits 0" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "creates CHECKSUMS.sha256" {
  bash "$SCRIPT"
  [ -f "$CHECKSUMS_FILE" ]
}

@test "output includes all three skill paths" {
  run bash "$SCRIPT"
  [[ "$output" == *"skills/chk1/SKILL.md"* ]]
  [[ "$output" == *"skills/chk2/SKILL.md"* ]]
  [[ "$output" == *"skills/rr/SKILL.md"* ]]
}

@test "checksums verify correctly" {
  bash "$SCRIPT"
  cd "$REPO_DIR"
  run shasum -a 256 --check "$CHECKSUMS_FILE"
  [ "$status" -eq 0 ]
}

@test "file is non-empty" {
  bash "$SCRIPT"
  [ -s "$CHECKSUMS_FILE" ]
}

@test "has at least 3 lines" {
  bash "$SCRIPT"
  local lines
  lines=$(wc -l < "$CHECKSUMS_FILE" | tr -d ' ')
  [ "$lines" -ge 3 ]
}
