#!/usr/bin/env bats

# CPT-133: CPT-91's compaction re-check was single-file (only step-1-extract
# heading verified once per risk, at the start of the 6-step workflow).
# Three concerns from chk1/Codex:
#   (1) Single-file heuristic misses compaction that evicted step-2/3/5/6
#       while leaving step-1 retrievable.
#   (2) Check-at-start misses compaction that happens mid-workflow (between
#       Step 2 and Step 5, for example).
#   (3) Raw numbering bug: the "Process Each Risk" list has two `3.` items.
#
# Fix: per-phase re-check (Option A in the ticket). Before each of the five
# step-file-backed phases, quote the corresponding heading; re-read on miss.
# Log entry annotated with step name so drift is observable per-phase.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ALL_MD="${REPO_DIR}/skills/rr/commands/all.md"

@test "rr/commands/all.md exists" {
  [ -f "$ALL_MD" ]
}

@test "Process Each Risk numbered list has no duplicate numbers (CPT-133 concern 3)" {
  # Extract the numbered list items at the top level inside "### Process Each Risk"
  # until the next `### ` heading, collecting only lines that start with
  # `^\d+\. ` (no indent).
  local numbers
  numbers=$(awk '/^### Process Each Risk/{inside=1; next} /^### Progress File Status Values/{inside=0} inside' "$ALL_MD" \
    | grep -E '^[0-9]+\. ' | sed -E 's/^([0-9]+)\. .*/\1/')
  [ -n "$numbers" ] || { echo "Process Each Risk block not found / empty list" >&2; return 1; }

  local dup_count
  dup_count=$(echo "$numbers" | sort | uniq -d | wc -l | tr -d ' ')
  if [ "$dup_count" -gt 0 ]; then
    echo "Process Each Risk numbered list has duplicate numbers: $(echo "$numbers" | tr '\n' ' ')" >&2
    echo "duplicates: $(echo "$numbers" | sort | uniq -d | tr '\n' ' ')" >&2
    return 1
  fi
}

@test "per-phase compaction re-check covers all 5 step-file-backed phases (CPT-133 concerns 1+2)" {
  # Each of step-1-extract, step-2-adversarial, step-3-rectify, step-5-finalise,
  # step-6-publish must be referenced in a re-check / verify / recall context
  # inside the per-phase workflow area (not just as a "use pre-loaded" bullet).
  local block
  block=$(awk '/^### Process Each Risk/{inside=1; next} /^### Progress File Status Values/{inside=0} inside' "$ALL_MD")
  [ -n "$block" ] || { echo "Process Each Risk block not found" >&2; return 1; }

  local step missing=0
  for step in step-1-extract step-2-adversarial step-3-rectify step-5-finalise step-6-publish; do
    # Must appear in a verification line (re-check / verify / retrievable /
    # recall / heading). A bare "use pre-loaded step-X content" reference is
    # NOT sufficient.
    if ! echo "$block" | grep -E "${step}" | grep -qiE 'recall|re-check|re.?read|verify|retriev|heading|still'; then
      echo "per-phase re-check missing for ${step}" >&2
      missing=$((missing + 1))
    fi
  done
  [ "$missing" -eq 0 ]
}

@test "compaction re-read log entry is annotated with step name (CPT-133)" {
  # CPT-91's log was "pre-load recovered by re-read" — generic, can't tell
  # which step drifted. CPT-133 requires a step annotation so observability
  # is useful.
  local block
  block=$(awk '/^### Process Each Risk/{inside=1; next} /^### Progress File Status Values/{inside=0} inside' "$ALL_MD")
  echo "$block" | grep -qE 'pre-load recovered by re-read:.*step' || {
    echo "re-read log entry is not step-annotated — use 'pre-load recovered by re-read: <step>' form so the step that drifted is visible in the log" >&2
    return 1
  }
}
