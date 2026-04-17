#!/usr/bin/env bats

# CPT-146: CPT-102 swapped `echo -n` for `printf '%s'` in four call sites of
# skills/rr/commands/{remove,board}.md to close the ps-aux credential leak,
# but neither file's allowed-tools frontmatter was extended. Under CPT-32
# per-command enforcement, printf/base64/tr are tool-denied at the first
# auth line in the snippet and the command fails before reaching Jira.
# Same fix-introduces-new-silent-failure pattern as CPT-101 → CPT-136.
#
# This suite asserts that every shell command actually invoked in these two
# files is whitelisted in the file's allowed-tools frontmatter.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

_frontmatter() {
  head -20 "$1" | grep '^allowed-tools:' || true
}

# --- remove.md: body uses printf, base64, echo, wc, tr, curl, jq ---

@test "remove.md frontmatter includes Bash(printf *) (CPT-146)" {
  line=$(_frontmatter "$REPO_DIR/skills/rr/commands/remove.md")
  [[ "$line" == *"Bash(printf"* ]]
}

@test "remove.md frontmatter includes Bash(tr *) (CPT-146)" {
  # remove.md uses `tr -d '\n'` in auth line and `tr -d ' '` in wc pipeline.
  line=$(_frontmatter "$REPO_DIR/skills/rr/commands/remove.md")
  [[ "$line" == *"Bash(tr"* ]]
}

@test "remove.md frontmatter includes Bash(wc *) (CPT-146)" {
  # remove.md uses `echo ... | wc -w | tr -d ' '` to count keys.
  line=$(_frontmatter "$REPO_DIR/skills/rr/commands/remove.md")
  [[ "$line" == *"Bash(wc"* ]]
}

# --- board.md: body uses printf, base64, tr, curl, python3, etc. ---

@test "board.md frontmatter includes Bash(printf *) (CPT-146)" {
  line=$(_frontmatter "$REPO_DIR/skills/rr/commands/board.md")
  [[ "$line" == *"Bash(printf"* ]]
}

@test "board.md frontmatter includes Bash(base64 *) (CPT-146)" {
  line=$(_frontmatter "$REPO_DIR/skills/rr/commands/board.md")
  [[ "$line" == *"Bash(base64"* ]]
}

@test "board.md frontmatter includes Bash(tr *) (CPT-146)" {
  line=$(_frontmatter "$REPO_DIR/skills/rr/commands/board.md")
  [[ "$line" == *"Bash(tr"* ]]
}

# --- Cross-check: body uses printf → frontmatter must whitelist it ---

@test "every rr/commands/*.md that uses printf in its body whitelists Bash(printf *) (CPT-146)" {
  offenders=""
  for f in "$REPO_DIR"/skills/rr/commands/*.md; do
    name=$(basename "$f")
    body=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2' "$f")
    if printf '%s' "$body" | grep -qE '^[[:space:]]*printf |\|[[:space:]]*printf |[[:space:]]printf '; then
      line=$(_frontmatter "$f")
      if [[ "$line" != *"Bash(printf"* ]] && [[ "$line" != *"Bash(bash"* ]]; then
        offenders="$offenders $name"
      fi
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}
