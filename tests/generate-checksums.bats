#!/usr/bin/env bats

# Tests for scripts/generate-checksums.sh.
#
# PARALLEL-UNSAFE: These tests modify the real CHECKSUMS.sha256 in the repo
# root and rely on serial execution for the snapshot/restore pattern in
# setup/teardown. Do not run with `bats --jobs N`.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="${REPO_DIR}/scripts/generate-checksums.sh"
CHECKSUMS_FILE="${REPO_DIR}/CHECKSUMS.sha256"

# Discover all installable skills (same filter the script uses).
discover_skills() {
  local dir name
  for dir in "${REPO_DIR}"/skills/*/; do
    name="$(basename "$dir")"
    [[ "$name" == _* ]] && continue
    [ -f "${dir}/SKILL.md" ] || continue
    printf '%s\n' "$name"
  done
}

setup() {
  # Snapshot the original file content (not a .bak file that could be left behind)
  if [ -f "$CHECKSUMS_FILE" ]; then
    ORIGINAL_CHECKSUMS="$(cat "$CHECKSUMS_FILE")"
  else
    ORIGINAL_CHECKSUMS=""
  fi

  SKILLS=()
  while IFS= read -r name; do
    SKILLS+=("$name")
  done < <(discover_skills)
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

@test "output includes every skill path" {
  run bash "$SCRIPT"
  local skill
  for skill in "${SKILLS[@]}"; do
    [[ "$output" == *"skills/${skill}/SKILL.md"* ]] || {
      echo "Missing skills/${skill}/SKILL.md in checksum output" >&2
      return 1
    }
  done
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

@test "has one line per skill" {
  bash "$SCRIPT"
  local lines
  lines=$(wc -l < "$CHECKSUMS_FILE" | tr -d ' ')
  [ "$lines" -eq "${#SKILLS[@]}" ] || {
    echo "Expected ${#SKILLS[@]} checksum lines, got $lines" >&2
    return 1
  }
}
