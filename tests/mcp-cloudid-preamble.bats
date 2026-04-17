#!/usr/bin/env bats

# CPT-103: CPT-27 replaced hardcoded Atlassian Cloud IDs with the
# `$JIRA_CLOUD_ID` env-var placeholder across rr + ra. The change is
# correct in shell contexts (bin/*.sh, doctor) where shell expansion
# works. It's broken in MCP call-spec blocks embedded in markdown —
# the MCP layer does not expand shell variables, so Claude can pass
# the literal string `"$JIRA_CLOUD_ID"` as the cloudId parameter and
# Atlassian rejects it as an invalid UUID.
#
# Fix (ticket Option A, lowest-friction): every file that uses
# `cloudId: "$JIRA_CLOUD_ID"` in an MCP call spec must carry an
# explicit "substitution contract" preamble that directs Claude to
# expand the env var before calling the MCP tool.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# Files that embed `cloudId: "$JIRA_CLOUD_ID"` in an MCP call spec.
# Hardcoded so a future file addition with the same pattern but no
# preamble is caught as a new drift (the list is the contract — new
# entries should come with the fix included).
FILES_WITH_CLOUDID_SPEC=(
  "skills/rr/references/jira-config.md"
  "skills/rr/references/matter-jira-config.md"
  "skills/rr/references/workflow/step-1-extract.md"
  "skills/rr/references/workflow/step-6-publish.md"
  "skills/rr/commands/board.md"
  "skills/ra/references/jira-config.md"
  "skills/ra/references/workflow/step-2-ingest.md"
  "skills/ra/commands/publish.md"
)

@test "every file using cloudId \$JIRA_CLOUD_ID in an MCP call spec carries a substitution-contract preamble (CPT-103)" {
  local drift=()
  for rel in "${FILES_WITH_CLOUDID_SPEC[@]}"; do
    local abs="${REPO_DIR}/${rel}"
    [ -f "$abs" ] || { drift+=("$rel: file missing"); continue; }

    # Sanity: the file must actually use the placeholder (so the test
    # fails visibly if the file stops being relevant — avoids silently
    # guarding an unrelated file).
    grep -q '\$JIRA_CLOUD_ID' "$abs" || {
      drift+=("$rel: no \$JIRA_CLOUD_ID reference — remove from FILES_WITH_CLOUDID_SPEC list or restore the placeholder")
      continue
    }

    # The preamble must state BOTH: (a) MCP layer does not expand shell
    # variables, (b) Claude must substitute before calling. Accept any
    # phrasing that hits the two concepts.
    if ! grep -qiE 'MCP.*(not expand|does not|won.?t).*shell|shell variable.*(not expand|literal)' "$abs"; then
      drift+=("$rel: missing 'MCP does not expand shell vars' clarification")
      continue
    fi
    if ! grep -qiE 'substitute|before calling|must expand|echo "?\$JIRA_CLOUD_ID' "$abs"; then
      drift+=("$rel: missing 'Claude must substitute the env var before calling' instruction")
      continue
    fi
  done

  if [ ${#drift[@]} -gt 0 ]; then
    printf '%s\n' "${drift[@]}" >&2
    return 1
  fi
}

@test "no new file introduces cloudId \$JIRA_CLOUD_ID without being in the FILES_WITH_CLOUDID_SPEC list (CPT-103 drift guard)" {
  # Discover ANY file in skills/rr or skills/ra using the pattern and
  # check it's tracked. Prevents a future commit from adding another
  # MCP call spec with the same shape but forgetting the preamble.
  local drift=()
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local rel="${f#${REPO_DIR}/}"
    local tracked=0
    for known in "${FILES_WITH_CLOUDID_SPEC[@]}"; do
      [ "$rel" = "$known" ] && { tracked=1; break; }
    done
    [ "$tracked" -eq 1 ] && continue
    # Skip schema (just a field description, no MCP call spec) and non-.md
    case "$rel" in
      *.schema.json|*/cpt-jira-config.md) continue ;;
    esac
    # Only flag if the pattern is an MCP call-spec form: `cloudId: "$JIRA_CLOUD_ID"`
    # (table entries like `| Cloud ID | $JIRA_CLOUD_ID |` are OK — they're docs,
    # not call specs).
    if grep -qE 'cloudId:[[:space:]]*"\$JIRA_CLOUD_ID"' "$f"; then
      drift+=("$rel: uses cloudId: \"\$JIRA_CLOUD_ID\" but is not in FILES_WITH_CLOUDID_SPEC — add it and ensure the preamble is present")
    fi
  done < <(grep -rlE 'cloudId:[[:space:]]*"\$JIRA_CLOUD_ID"' "${REPO_DIR}/skills/rr" "${REPO_DIR}/skills/ra" 2>/dev/null)

  if [ ${#drift[@]} -gt 0 ]; then
    printf '%s\n' "${drift[@]}" >&2
    return 1
  fi
}
