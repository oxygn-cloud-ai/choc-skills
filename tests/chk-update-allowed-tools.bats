#!/usr/bin/env bats

# CPT-115: CPT-19 rewrote the chk1/chk2 `update` bash blocks to use
# `echo "…" | tr ' ' '\n' | xargs -P 4 -I{} curl ...` for parallel
# sub-command fetches, but didn't extend the per-command `allowed-tools`
# frontmatter to cover the three new helpers. Under CPT-32's per-command
# enforcement, `/chk1 update` and `/chk2 update` hit tool-denied errors
# on xargs / echo / tr and fail to fetch any sub-command files.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
CHK1_UPDATE="${REPO_DIR}/skills/chk1/commands/update.md"
CHK2_UPDATE="${REPO_DIR}/skills/chk2/commands/update.md"

# Extract just the allowed-tools line from the YAML frontmatter.
_allowed_tools_line() {
  awk '/^---/{n++; next} n==1' "$1" | grep -E '^allowed-tools:'
}

@test "chk1 and chk2 update command files exist (sanity)" {
  [ -f "$CHK1_UPDATE" ]
  [ -f "$CHK2_UPDATE" ]
}

@test "chk1:update allowed-tools covers xargs, echo, tr (CPT-115)" {
  local line
  line=$(_allowed_tools_line "$CHK1_UPDATE")
  [ -n "$line" ] || { echo "chk1:update has no allowed-tools line" >&2; return 1; }
  for cmd in xargs echo tr; do
    echo "$line" | grep -qE "Bash\(${cmd} \*\)" || {
      echo "chk1:update allowed-tools missing Bash(${cmd} *): $line" >&2
      return 1
    }
  done
}

@test "chk2:update allowed-tools covers xargs, echo, tr (CPT-115)" {
  local line
  line=$(_allowed_tools_line "$CHK2_UPDATE")
  [ -n "$line" ] || { echo "chk2:update has no allowed-tools line" >&2; return 1; }
  for cmd in xargs echo tr; do
    echo "$line" | grep -qE "Bash\(${cmd} \*\)" || {
      echo "chk2:update allowed-tools missing Bash(${cmd} *): $line" >&2
      return 1
    }
  done
}

@test "chk1/chk2 update.md bash bodies still invoke xargs/echo/tr (sanity contract)" {
  # Guard against a future refactor that removes the parallel pipeline
  # without also shrinking the allowed-tools list — in that case the
  # frontmatter tests above would still pass but would be protecting
  # nothing. Keeping this "body uses pipeline" contract visible prevents
  # silent drift.
  for f in "$CHK1_UPDATE" "$CHK2_UPDATE"; do
    grep -qE '\| tr ' "$f" || { echo "$f no longer uses tr (pipeline changed?)" >&2; return 1; }
    grep -qE 'xargs -P' "$f" || { echo "$f no longer uses xargs -P (pipeline changed?)" >&2; return 1; }
  done
}
