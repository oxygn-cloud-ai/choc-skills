#!/usr/bin/env bats

# CPT-149: CPT-103 added an "IMPORTANT: MCP call-spec variable substitution"
# preamble to 8 rr/ra files instructing Claude to substitute $JIRA_CLOUD_ID
# (and $RR_ASSIGNEE_ID) with `echo "$JIRA_CLOUD_ID"` before calling MCP
# tools. The preamble is unactionable under CPT-32 per-command enforcement
# unless the command's allowed-tools permit some mechanism to READ env vars.
#
# The 5 commands whose execution path encounters the preamble (directly via
# their own body, or transitively via a reference file they load):
#   rr/SKILL.md                        (inline workflow fallback)
#   rr/commands/review.md              (loads references/workflow/step-1-extract.md, references/jira-config.md, references/workflow/step-6-publish.md)
#   rr/commands/board.md               (own body + references/matter-jira-config.md)
#   ra/commands/publish.md             (own body + references/jira-config.md)
#   ra/commands/assess.md              (loads references/workflow/step-2-ingest.md)
#
# Each must have Bash(echo *), Bash(printenv *), Bash(env *), or bare Bash
# in allowed-tools so the preamble's instruction can actually execute.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

_has_env_reader() {
  local line="$1"
  [[ "$line" == *"Bash(echo"* ]] || \
  [[ "$line" == *"Bash(printenv"* ]] || \
  [[ "$line" == *"Bash(env "* ]] || \
  [[ "$line" == *"Bash(bash"* ]]
}

_assert_reader() {
  local file="$1"
  local line
  line=$(head -20 "$file" | grep '^allowed-tools:' || true)
  _has_env_reader "$line" || {
    echo "$file allowed-tools lacks an env-reading primitive (CPT-149)" >&2
    echo "  allowed-tools: $line" >&2
    return 1
  }
}

@test "rr/SKILL.md allows env-var reading for MCP substitution (CPT-149)" {
  _assert_reader "$REPO_DIR/skills/rr/SKILL.md"
}

@test "rr/commands/review.md allows env-var reading for MCP substitution (CPT-149)" {
  _assert_reader "$REPO_DIR/skills/rr/commands/review.md"
}

@test "rr/commands/board.md allows env-var reading for MCP substitution (CPT-149)" {
  _assert_reader "$REPO_DIR/skills/rr/commands/board.md"
}

@test "ra/commands/publish.md allows env-var reading for MCP substitution (CPT-149)" {
  _assert_reader "$REPO_DIR/skills/ra/commands/publish.md"
}

@test "ra/commands/assess.md allows env-var reading for MCP substitution (CPT-149)" {
  _assert_reader "$REPO_DIR/skills/ra/commands/assess.md"
}

# --- Generic cross-check: any command file whose body carries the CPT-103
#     preamble MUST have an env-reader. Reference files are not checked
#     directly (they have no frontmatter); their loaders are covered by
#     the per-file sentinels above.

@test "every rr/ra command file carrying the MCP substitution preamble has an env-reader (CPT-149)" {
  offenders=""
  for f in "$REPO_DIR"/skills/rr/commands/*.md "$REPO_DIR"/skills/ra/commands/*.md; do
    name=$(basename "$f")
    if grep -q 'MCP call-spec variable substitution' "$f"; then
      line=$(head -20 "$f" | grep '^allowed-tools:' || true)
      if ! _has_env_reader "$line"; then
        offenders="$offenders $(dirname "$f" | xargs basename)/$name"
      fi
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}
