#!/usr/bin/env bats

# Tests that skill subcommand files follow the colon-naming convention.
#
# CLAUDE.md: "All subcommands must be colon commands (skill:subcommand)
# with their own command file."
#
# The name: frontmatter field must use "skill:sub", not "skill-sub".

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "subcommand name: fields use colons, not dashes" {
  local errors=0
  local file name skill_name cmd_name

  for file in "${REPO_DIR}"/skills/*/commands/*.md; do
    [ -f "$file" ] || continue

    # Skip files without YAML frontmatter (some skills use header-only format)
    head -1 "$file" | grep -q '^---$' || continue

    # Extract the name: field from YAML frontmatter
    name=$(awk '/^---$/{n++; next} n==1 && /^name:/{print $2; exit} n>=2{exit}' "$file")
    [ -n "$name" ] || continue

    # The skill name is the grandparent directory
    skill_name=$(basename "$(dirname "$(dirname "$file")")")

    # The name must start with "skill:" not "skill-"
    if [[ "$name" == "${skill_name}-"* ]]; then
      cmd_name="${name#"${skill_name}-"}"
      echo "FAIL: $file has name: ${name} — should be ${skill_name}:${cmd_name}" >&2
      errors=$((errors + 1))
    elif [[ "$name" != "${skill_name}:"* ]]; then
      echo "FAIL: $file has name: ${name} — must start with ${skill_name}:" >&2
      errors=$((errors + 1))
    fi
  done

  [ "$errors" -eq 0 ]
}
