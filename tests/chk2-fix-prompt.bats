#!/usr/bin/env bats

# Tests for CPT-12: chk2 category fix prompt suppression in batch mode.
#
# Verifies that each category command file skips its per-category fix prompt
# when invoked from /chk2:all (batch mode), and only all.md shows the prompt.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
CMD_DIR="${REPO_DIR}/skills/chk2/commands"

# The 30 test category files (excluding all, quick, fix, github, update)
discover_categories() {
  local excluded="all quick fix github update help doctor version"
  for f in "${CMD_DIR}"/*.md; do
    local name
    name="$(basename "$f" .md)"
    case " $excluded " in
      *" $name "*) continue ;;
    esac
    echo "$name"
  done
}

@test "every category file has a batch-mode guard on its fix prompt" {
  local failures=()
  while IFS= read -r cat; do
    local file="${CMD_DIR}/${cat}.md"
    # The file should mention skipping the fix prompt in batch/all mode
    if ! grep -qiE '(batch|chk2:all|all mode|skip.*fix.*prompt|skip.*after|do not ask)' "$file"; then
      failures+=("$cat")
    fi
  done < <(discover_categories)

  if [ ${#failures[@]} -gt 0 ]; then
    echo "Categories missing batch-mode guard: ${failures[*]}" >&2
    return 1
  fi
}

@test "all.md retains the fix prompt at the end" {
  grep -qiE '(chk2:fix|want help fixing|Do you want)' "${CMD_DIR}/all.md"
}

@test "all.md fix prompt appears only once (not per-category)" {
  local count
  count=$(grep -ciE 'chk2:fix' "${CMD_DIR}/all.md")
  [ "$count" -le 2 ]
}
