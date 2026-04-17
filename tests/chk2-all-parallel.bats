#!/usr/bin/env bats

# Tests for skills/chk2/commands/all.md — Parallel dispatch structure.
#
# CPT-8: Verifies that chk2:all dispatches categories in parallel waves
# using Agent tool calls, rather than running all 30 sequentially.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ALL_MD="${REPO_DIR}/skills/chk2/commands/all.md"

@test "chk2 all.md exists" {
  [ -f "$ALL_MD" ]
}

@test "chk2 all.md uses parallel waves or batches for category dispatch" {
  # The file should mention waves, batches, or parallel execution
  grep -qiE '(wave|batch|parallel|concurrent)' "$ALL_MD"
}

@test "chk2 all.md references Agent tool for parallel dispatch" {
  # Parallel execution requires using the Agent tool
  grep -qiE 'agent' "$ALL_MD"
}

@test "chk2 all.md does not list all 30 categories in a single sequential list" {
  # The old pattern was a single numbered list of 30 /chk2:* invocations.
  # After the fix, categories should be grouped into waves, not a flat list.
  # Count consecutive /chk2: lines — should not have 30 in a row.
  local max_consecutive=0
  local current=0
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^\s*-\s+`/chk2:' ; then
      current=$((current + 1))
    else
      if [ "$current" -gt "$max_consecutive" ]; then
        max_consecutive=$current
      fi
      current=0
    fi
  done < "$ALL_MD"
  # Check final streak
  if [ "$current" -gt "$max_consecutive" ]; then
    max_consecutive=$current
  fi
  # No single streak of more than 10 sequential category invocations
  [ "$max_consecutive" -le 10 ]
}

@test "chk2 all.md includes all 30 categories across all waves" {
  # Every category must still be present somewhere in the file
  local categories=(headers tls dns cors api ws waf infra brute scale
    disclosure cookies cache smuggling auth transport redirect fingerprint
    timing compression jwt graphql sse ipv6 reporting hardening negotiation
    proxy business backend)

  for cat in "${categories[@]}"; do
    grep -q "chk2:${cat}" "$ALL_MD"
  done
}

@test "chk2 all.md has rate-limit handling between waves" {
  # Should mention rate limiting or 429 handling in the context of waves
  grep -qiE '(rate.?limit|429|circuit.?break|between waves|after.*wave)' "$ALL_MD"
}
