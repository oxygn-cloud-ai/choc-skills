#!/usr/bin/env bats

# CPT-88: chk2:all parallel waves race on SECURITY_CHECK.md. Fix = each
# category writes to its own part file (SECURITY_CHECK.parts/<name>.md);
# orchestrator concatenates in fixed order after all waves complete.
#
# These tests are structural — they assert the design contract in the
# markdown files that Claude executes.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
CMD_DIR="$REPO_DIR/skills/chk2/commands"

# Every chk2 sub-skill EXCEPT the orchestrators/utilities.
CATEGORY_NAMES=(
  api auth backend brute business cache compression cookies cors
  disclosure dns fingerprint graphql hardening headers infra ipv6 jwt
  negotiation proxy redirect reporting scale smuggling sse timing tls
  transport waf ws
)

@test "category sub-skills count is 30" {
  [ ${#CATEGORY_NAMES[@]} -eq 30 ]
}

@test "no category sub-skill appends to SECURITY_CHECK.md (race-prone)" {
  local failed=()
  for name in "${CATEGORY_NAMES[@]}"; do
    local f="$CMD_DIR/$name.md"
    [ -f "$f" ] || { failed+=("$name: missing"); continue; }
    if grep -qE "Append to \`SECURITY_CHECK\.md\`" "$f"; then
      failed+=("$name")
    fi
  done
  if [ ${#failed[@]} -gt 0 ]; then
    echo "Still appending to SECURITY_CHECK.md: ${failed[*]}" >&2
    return 1
  fi
}

@test "each category sub-skill writes to its own SECURITY_CHECK.parts/<name>.md" {
  local failed=()
  for name in "${CATEGORY_NAMES[@]}"; do
    local f="$CMD_DIR/$name.md"
    [ -f "$f" ] || { failed+=("$name: missing"); continue; }
    if ! grep -qE "SECURITY_CHECK\.parts/${name}\.md" "$f"; then
      failed+=("$name")
    fi
  done
  if [ ${#failed[@]} -gt 0 ]; then
    echo "Missing part-file target: ${failed[*]}" >&2
    return 1
  fi
}

@test "all.md creates the SECURITY_CHECK.parts/ directory" {
  grep -qE "SECURITY_CHECK\.parts" "$CMD_DIR/all.md"
}

@test "all.md concatenates part files into SECURITY_CHECK.md after all waves" {
  # Post-wave step should reference concatenating the parts before the Summary
  grep -qE "concat|merge|combine" "$CMD_DIR/all.md"
  grep -qE "SECURITY_CHECK\.parts/" "$CMD_DIR/all.md"
}

@test "quick.md also uses the parts-file pattern (consistency)" {
  grep -qE "SECURITY_CHECK\.parts" "$CMD_DIR/quick.md"
}
