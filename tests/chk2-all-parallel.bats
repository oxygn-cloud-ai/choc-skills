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

# --- CPT-94: the CPT-8 tests above are structural (shape-of-markdown) and
# under-specify the 5-waves × 6-categories design the rate-limit pacing
# depends on. `max_consecutive <= 10` passes for 3 waves of 10, 15 waves
# of 2, etc. — all of which break the pacing window chk2:all was built
# around. Tighten to assert the exact wave count and per-wave category
# count documented in commands/all.md.

@test "chk2 all.md declares exactly 5 waves (CPT-94)" {
  local wave_count
  wave_count=$(grep -cE '^[[:space:]]+\*\*Wave [0-9]+ ' "$ALL_MD")
  if [ "$wave_count" -ne 5 ]; then
    echo "expected exactly 5 waves; found $wave_count" >&2
    grep -nE '^[[:space:]]+\*\*Wave [0-9]+ ' "$ALL_MD" >&2
    return 1
  fi
}

@test "chk2 all.md has exactly 6 categories per wave (CPT-94)" {
  # Parse each Wave block (from `**Wave N — ...**` to the next Wave or the
  # "Between waves" / "Retry failures" end-of-section anchor) and count
  # the `- /chk2:<cat>` bullet lines within. Each wave must have exactly 6.
  local wave_idx=0
  local offenders=""
  while IFS=$'\t' read -r wave_line start end; do
    wave_idx=$((wave_idx + 1))
    local block
    block=$(sed -n "${start},${end}p" "$ALL_MD")
    local cat_count
    cat_count=$(echo "$block" | grep -cE '^[[:space:]]+-[[:space:]]+`/chk2:')
    if [ "$cat_count" -ne 6 ]; then
      offenders="$offenders wave${wave_idx}=${cat_count}"
    fi
  done < <(
    # Line numbers of each "**Wave N —" heading, paired with the start
    # of the next Wave (or a far-out sentinel). Delimiter: tab.
    awk '
      /^[[:space:]]+\*\*Wave [0-9]+ /{
        if (prev) print prev_line "\t" prev + 1 "\t" NR - 1
        prev = NR
        prev_line = $0
      }
      END {
        if (prev) print prev_line "\t" prev + 1 "\t" NR
      }
    ' "$ALL_MD"
  )
  if [ -n "$offenders" ]; then
    echo "wave(s) with wrong category count:$offenders" >&2
    return 1
  fi
}
