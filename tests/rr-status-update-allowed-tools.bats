#!/usr/bin/env bats

# CPT-111: rr:status frontmatter (post-CPT-32) didn't cover the echo/wc/tr
# commands its body uses to compute published/failed/results counters. Under
# enforcement those commands get denied and the user loses the progress
# totals — the most useful section of `/rr status`'s output.
#
# Secondary: rr:update.md carried `Bash(bash *)` (unscoped) while its sibling
# chk2:update.md uses `Bash(bash install.sh *)` (scoped). That weakens
# CPT-25's "no unscoped bash" intent. Tighten rr:update to match.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
STATUS_MD="${REPO_DIR}/skills/rr/commands/status.md"
UPDATE_MD="${REPO_DIR}/skills/rr/commands/update.md"

# Extract just the allowed-tools line from the YAML frontmatter.
_allowed_tools_line() {
  awk '/^---/{n++; next} n==1' "$1" | grep -E '^allowed-tools:'
}

@test "rr:status and rr:update command files exist" {
  [ -f "$STATUS_MD" ]
  [ -f "$UPDATE_MD" ]
}

@test "rr:status allowed-tools covers echo, wc, tr (CPT-111)" {
  local line
  line=$(_allowed_tools_line "$STATUS_MD")
  [ -n "$line" ] || { echo "rr:status has no allowed-tools line" >&2; return 1; }

  # Body uses: echo "Results: $(ls … | wc -l | tr -d ' ')" and similar.
  # Each of the three needs a matching pattern.
  for cmd in echo wc tr; do
    echo "$line" | grep -qE "Bash\(${cmd} \*\)" || {
      echo "rr:status allowed-tools missing Bash(${cmd} *): $line" >&2
      return 1
    }
  done
}

@test "rr:update allowed-tools is scoped to install.sh, not generic bash (CPT-111 secondary)" {
  local line
  line=$(_allowed_tools_line "$UPDATE_MD")
  [ -n "$line" ] || { echo "rr:update has no allowed-tools line" >&2; return 1; }

  # Must not have the wide Bash(bash *) pattern.
  if echo "$line" | grep -qE 'Bash\(bash \*\)'; then
    echo "rr:update still has wide Bash(bash *) — CPT-25 consistency regression: $line" >&2
    return 1
  fi

  # Must have scoped bash install.sh or the direct ./install.sh pattern (either
  # satisfies the update body's only invocation shape).
  echo "$line" | grep -qE 'Bash\(bash install\.sh \*\)|Bash\(\./install\.sh \*\)|Bash\(\*/install\.sh \*\)'
}
