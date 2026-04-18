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
  # The per-phase compaction re-check lines (CPT-133/CPT-157) use the
  # sanctioned recovery phrase `re-read <step-N.md> on miss`. The
  # leading `(^|[^a-zA-Z-])` alternation in the regex explicitly excludes
  # `read` preceded by a letter OR by `-`, so both `re-read` (hyphenated)
  # and `reread` (closed-up) forms of the recovery prose are allowed.
  # Any UNHYPHENATED `read step-N.md` instruction with a word-boundary
  # preceding `read` (start-of-line, space, punctuation) is still caught
  # as the 6N-reread anti-pattern.
  # CPT-164: added initial `(^|[^-])` order-independence fix.
  # CPT-166: broadened `[^-]` → `[^a-zA-Z-]` so `reread` (no hyphen) is
  # also correctly not flagged — previously `re` satisfied `[^-]` and the
  # compact-word form slipped past the intended exclusion.

  local loop_section
  loop_section=$(sed -n '/^### Process Each Risk/,/^### Progress File Status/p' "$ALL_MD")

  if echo "$loop_section" | grep -iqE '(^|[^a-zA-Z-])(read|Read).*step-[0-9].*\.md'; then
    echo "per-risk loop instructs reading a step-N.md file — should be pre-loaded" >&2
    echo "$loop_section" | grep -inE '(^|[^a-zA-Z-])(read|Read).*step-[0-9].*\.md' >&2
    return 1
  fi
}

# CPT-164 fixture-based regression tests for the re-read-exclusion boundary.
# These lock the regex semantics in isolation so future edits to the regex
# can't silently widen/narrow what counts as the per-risk-read anti-pattern.

@test "CPT-164: 're-read step-N.md on miss' prose is NOT flagged (regex fixture)" {
  # Legitimate CPT-133/CPT-157 recovery prose — `re-read` has a `-` before
  # `read`, so the (^|[^-]) alternation excludes it.
  local line='on miss, re-read step-5-finalise.md'
  run bash -c "printf '%s\n' '$line' | grep -iqE '(^|[^a-zA-Z-])(read|Read).*step-[0-9].*\\.md'"
  [ "$status" -ne 0 ]  # No match — prose is allowed.
}

@test "CPT-164: 'read step-N.md' prose IS flagged (regex fixture)" {
  # The actual anti-pattern — unhyphenated `read` preceding `step-N.md`.
  local line='Step 5: read step-5-finalise.md before starting.'
  run bash -c "printf '%s\n' '$line' | grep -iqE '(^|[^a-zA-Z-])(read|Read).*step-[0-9].*\\.md'"
  [ "$status" -eq 0 ]  # Match — anti-pattern caught.
}

@test "CPT-164: 'Read step-N.md' at start of line IS flagged (regex fixture)" {
  # Covers the ^ branch of the alternation.
  local line='Read step-3-rectify.md'
  run bash -c "printf '%s\n' '$line' | grep -iqE '(^|[^a-zA-Z-])(read|Read).*step-[0-9].*\\.md'"
  [ "$status" -eq 0 ]
}

@test "CPT-164: backtick-wrapped 'step-N.md heading is still retrievable (re-read on miss)' prose is NOT flagged (regex fixture)" {
  # The shipped CPT-133 prose form — re-read appears AFTER the filename.
  # The existing regex already handled this via position; the new regex
  # must still not flag it.
  local line='Verify `step-1-extract.md` heading is still retrievable (re-read on miss), then extract...'
  run bash -c "printf '%s\n' '$line' | grep -iqE '(^|[^a-zA-Z-])(read|Read).*step-[0-9].*\\.md'"
  [ "$status" -ne 0 ]
}

@test "CPT-166: 'reread step-N.md' (no hyphen) prose is NOT flagged (regex fixture)" {
  # The compact-word form of the sanctioned recovery phrase. Pre-CPT-166
  # the `[^-]` class accepted the `e` in `reread`, so the regex matched
  # and flagged this legitimate prose. The `[^a-zA-Z-]` class excludes
  # letters too, so this now passes through as intended.
  local line='on miss, reread step-5-finalise.md'
  run bash -c "printf '%s\n' '$line' | grep -iqE '(^|[^a-zA-Z-])(read|Read).*step-[0-9].*\\.md'"
  [ "$status" -ne 0 ]
}

@test "CPT-166: 'Reread step-N.md' at start of line is NOT flagged (regex fixture)" {
  # Start-of-line variant of the compact-word form. `^` matches position 0,
  # then `(read|Read)` needs to match at position 0 — but the line starts
  # with `R` for `Reread`, so the regex engine tries matching at position
  # 0. With -i flag, `read|Read` would match 'Re' no wait — 'Re' doesn't
  # equal 'read'. Let me trace again: at position 0 we have 'R', then 'e',
  # then 'r', then 'e', then 'a', then 'd'. `(read|Read)` matches starting
  # at position 2 (the second 'r'): 'read'. At position 2, preceding char
  # is 'e' (letter). `[^a-zA-Z-]` rejects 'e'. No match. Good.
  local line='Reread step-3-rectify.md on miss'
  run bash -c "printf '%s\n' '$line' | grep -iqE '(^|[^a-zA-Z-])(read|Read).*step-[0-9].*\\.md'"
  [ "$status" -ne 0 ]
}

@test "CPT-166: 'reading step-N.md' (gerund instruction) IS still flagged (regex fixture)" {
  # `reading` starts with `read` at position 0. The `^` branch matches
  # at position 0, then `read` matches 'read' (letters 0-3). The regex
  # then continues with `.*step-[0-9].*\.md` which matches 'ing step-5'.
  # This catches the gerund form of the anti-pattern instruction.
  local line='reading step-5-finalise.md'
  run bash -c "printf '%s\n' '$line' | grep -iqE '(^|[^a-zA-Z-])(read|Read).*step-[0-9].*\\.md'"
  [ "$status" -eq 0 ]
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
