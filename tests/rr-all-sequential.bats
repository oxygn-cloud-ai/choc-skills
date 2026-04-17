#!/usr/bin/env bats

# Tests for skills/rr/commands/all.md — Sequential Mode structure.
#
# CPT-9: Verifies that workflow step files are read once in a setup phase,
# not re-read per risk in the processing loop. This prevents 6N redundant
# file reads for a register of N risks.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ALL_MD="${REPO_DIR}/skills/rr/commands/all.md"

@test "rr all.md exists" {
  [ -f "$ALL_MD" ]
}

@test "sequential mode has a pre-load section that reads all workflow step files before the per-risk loop" {
  # The file should contain a section that reads all 6 step files
  # BEFORE the "Process Each Risk" section begins.
  #
  # Strategy: extract everything between "Sequential Mode" and "Process Each Risk"
  # and verify it contains instructions to read step-1 through step-6.

  local setup_section
  setup_section=$(sed -n '/^## Sequential Mode/,/^### Process Each Risk/p' "$ALL_MD")

  # Must contain instructions to read all 6 workflow step files in the setup area
  echo "$setup_section" | grep -q 'step-1'
  echo "$setup_section" | grep -q 'step-2'
  echo "$setup_section" | grep -q 'step-3'
  echo "$setup_section" | grep -q 'step-5'
  echo "$setup_section" | grep -q 'step-6'
}

@test "per-risk loop does not instruct reading workflow step files individually (CPT-94 hardened)" {
  # The "Process Each Risk" section must NOT contain any instruction to
  # read individual step-N.md files inside the loop — files are pre-loaded
  # once in the setup phase and referenced from context thereafter.
  #
  # CPT-94: the previous shape had a nested-if outer gate that silently
  # allowed any NEW "read step-N.md" phrasing not matching the narrow
  # inner `^\s*- Step [0-9]:.*(read \`` anchor to pass. A future edit
  # introducing a different "(again read step-4.md)" wording slipped
  # through. Dropped the outer gate: ANY match of the regex in the loop
  # section is a regression.
  #
  # The per-phase compaction re-check lines (CPT-133) use the shape
  # `\`step-N.md\` heading is still retrievable (re-read on miss)` —
  # "re-read" appears AFTER the step-N.md filename on the same line, so
  # the regex `(read|Read).*step-[0-9].*\.md` does not match that prose.

  local loop_section
  loop_section=$(sed -n '/^### Process Each Risk/,/^### Progress File Status/p' "$ALL_MD")

  if echo "$loop_section" | grep -iqE '(read|Read).*step-[0-9].*\.md'; then
    echo "per-risk loop instructs reading a step-N.md file — should be pre-loaded" >&2
    echo "$loop_section" | grep -inE '(read|Read).*step-[0-9].*\.md' >&2
    return 1
  fi
}

@test "per-risk loop references pre-loaded workflow content instead of re-reading" {
  # The per-risk processing section should reference workflow steps as
  # already loaded/cached content, not as files to read fresh.

  local loop_section
  loop_section=$(sed -n '/^### Process Each Risk/,/^### Progress File Status/p' "$ALL_MD")

  # Should contain language indicating steps are already loaded / in context
  echo "$loop_section" | grep -qiE '(pre-loaded|already.*(loaded|read|in context)|cached|above|loaded above|from the setup phase)'
}

@test "sequential mode pre-load section appears before process each risk section" {
  # Structural check: the pre-load section must come before the per-risk loop.
  local preload_line process_line

  preload_line=$(grep -n 'Pre-[Ll]oad\|Pre-[Rr]ead\|Load Workflow' "$ALL_MD" | head -1 | cut -d: -f1)
  process_line=$(grep -n '### Process Each Risk' "$ALL_MD" | head -1 | cut -d: -f1)

  [ -n "$preload_line" ]
  [ -n "$process_line" ]
  [ "$preload_line" -lt "$process_line" ]
}
