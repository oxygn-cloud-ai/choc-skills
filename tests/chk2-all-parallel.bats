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

# CPT-164/CPT-166: extracted helper — emit one `<heading>\t<start>\t<end>`
# record per Wave block in a markdown file. A Wave block ends at the NEXT
# Wave heading, the `**Between waves**` / `**Retry failures**` indented-bold
# anchors, or ANY heading of depth `##` or deeper (`##`, `###`, `####`, ...)
# — whichever comes first. Top-level `#` (doc title) is intentionally NOT an
# anchor. Falls back to EOF only if a Wave has no trailing anchor at all.
#
# Pre-CPT-164: the awk END branch always used `NR` (EOF) for the last Wave,
# inflating Wave 5's count with any post-dispatch bullets.
# Pre-CPT-166: the `^## ` anchor missed `### Troubleshooting`-style
# subsections — a subsection under the same `## ` parent would not
# terminate Wave 5, so its indented `/chk2:` bullets inflated the count.
_waves_from_md() {
  awk '
    /^[[:space:]]+\*\*Wave [0-9]+ / {
      if (prev) print prev_line "\t" prev + 1 "\t" NR - 1
      prev = NR
      prev_line = $0
      next
    }
    /^[[:space:]]+\*\*(Between waves|Retry failures)/ || /^##+[[:space:]]/ {
      if (prev) { print prev_line "\t" prev + 1 "\t" NR - 1; prev = 0 }
    }
    END {
      if (prev) print prev_line "\t" prev + 1 "\t" NR
    }
  ' "$1"
}

@test "chk2 all.md has exactly 6 categories per wave (CPT-94)" {
  # Parse each Wave block (from `**Wave N — ...**` to the next Wave or the
  # "Between waves" / "Retry failures" / next `## ` heading end-of-section
  # anchor) and count the `- /chk2:<cat>` bullet lines within. Each wave
  # must have exactly 6.
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
  done < <(_waves_from_md "$ALL_MD")
  if [ -n "$offenders" ]; then
    echo "wave(s) with wrong category count:$offenders" >&2
    return 1
  fi
}

# CPT-164 fixture-based regression tests for the Wave-range helper. These
# lock _waves_from_md's anchor semantics independently of skills/chk2/
# commands/all.md so future edits can't silently widen/narrow the scope.

@test "CPT-164: Wave block range stops at **Between waves anchor (fixture)" {
  local fixture
  fixture=$(mktemp)
  cat > "$fixture" <<'EOF'
   **Wave 5 — Heavy/rate-sensitive tests:**
   - `/chk2:cat1`
   - `/chk2:cat2`
   - `/chk2:cat3`
   - `/chk2:cat4`
   - `/chk2:cat5`
   - `/chk2:cat6`

   **Between waves — rate-limit circuit breaker:**
   - `/chk2:post-wave-prose-bullet`
EOF

  local record start end
  record=$(_waves_from_md "$fixture")
  start=$(echo "$record" | awk -F'\t' '{print $2}')
  end=$(echo "$record" | awk -F'\t' '{print $3}')
  local cat_count
  cat_count=$(sed -n "${start},${end}p" "$fixture" | grep -cE '^[[:space:]]+-[[:space:]]+`/chk2:')

  rm -f "$fixture"

  [ "$cat_count" -eq 6 ] || {
    echo "expected 6 Wave 5 bullets stopping at **Between waves; got $cat_count" >&2
    return 1
  }
}

@test "CPT-164: Wave block range stops at next ## heading (fixture)" {
  # Use INDENTED bullets in the post-anchor section — they match the
  # Wave-counter's `^[[:space:]]+-` grep, so without the anchor rule
  # they would over-inflate Wave 5's category count.
  local fixture
  fixture=$(mktemp)
  cat > "$fixture" <<'EOF'
   **Wave 5 — Heavy/rate-sensitive tests:**
   - `/chk2:cat1`
   - `/chk2:cat2`
   - `/chk2:cat3`
   - `/chk2:cat4`
   - `/chk2:cat5`
   - `/chk2:cat6`

## Troubleshooting

   - `/chk2:retry-flaky1`
   - `/chk2:retry-flaky2`
EOF

  local record start end
  record=$(_waves_from_md "$fixture")
  start=$(echo "$record" | awk -F'\t' '{print $2}')
  end=$(echo "$record" | awk -F'\t' '{print $3}')
  local cat_count
  cat_count=$(sed -n "${start},${end}p" "$fixture" | grep -cE '^[[:space:]]+-[[:space:]]+`/chk2:')

  rm -f "$fixture"

  [ "$cat_count" -eq 6 ] || {
    echo "expected 6 Wave 5 bullets stopping at ## Docs; got $cat_count (over-reach across section boundary)" >&2
    return 1
  }
}

@test "CPT-166: Wave block range stops at ### subheading (fixture)" {
  # Pre-CPT-166 the `^## ` anchor required EXACTLY two `#`s, so a
  # `### Troubleshooting` post-Wave-5 subsection wouldn't terminate the
  # block; its indented `/chk2:foo` bullets would inflate Wave 5's count
  # the same way post-## bullets did. The `^##+[[:space:]]` anchor
  # catches any depth `##+`.
  local fixture
  fixture=$(mktemp)
  cat > "$fixture" <<'EOF'
   **Wave 5 — Heavy/rate-sensitive tests:**
   - `/chk2:cat1`
   - `/chk2:cat2`
   - `/chk2:cat3`
   - `/chk2:cat4`
   - `/chk2:cat5`
   - `/chk2:cat6`

### Troubleshooting

   - `/chk2:retry-flaky-a`
   - `/chk2:retry-flaky-b`
EOF

  local record start end
  record=$(_waves_from_md "$fixture")
  start=$(echo "$record" | awk -F'\t' '{print $2}')
  end=$(echo "$record" | awk -F'\t' '{print $3}')
  local cat_count
  cat_count=$(sed -n "${start},${end}p" "$fixture" | grep -cE '^[[:space:]]+-[[:space:]]+`/chk2:')

  rm -f "$fixture"

  [ "$cat_count" -eq 6 ] || {
    echo "expected 6 Wave 5 bullets stopping at ### Troubleshooting; got $cat_count (anchor doesn't cover subheadings)" >&2
    return 1
  }
}

@test "CPT-166: Wave block range stops at #### deeper subheading too (fixture)" {
  # `^##+[[:space:]]` should catch any heading depth >= 2.
  local fixture
  fixture=$(mktemp)
  cat > "$fixture" <<'EOF'
   **Wave 5 — Heavy/rate-sensitive tests:**
   - `/chk2:cat1`
   - `/chk2:cat2`
   - `/chk2:cat3`
   - `/chk2:cat4`
   - `/chk2:cat5`
   - `/chk2:cat6`

#### Deeply Nested Subsection

   - `/chk2:extra-a`
   - `/chk2:extra-b`
EOF

  local record start end
  record=$(_waves_from_md "$fixture")
  start=$(echo "$record" | awk -F'\t' '{print $2}')
  end=$(echo "$record" | awk -F'\t' '{print $3}')
  local cat_count
  cat_count=$(sed -n "${start},${end}p" "$fixture" | grep -cE '^[[:space:]]+-[[:space:]]+`/chk2:')

  rm -f "$fixture"

  [ "$cat_count" -eq 6 ]
}

@test "CPT-166: top-level # doc-title heading does NOT terminate a Wave (fixture)" {
  # The anchor deliberately requires `##+` (two or more hashes), not `#+`,
  # so a document's single `# Title` at the start doesn't truncate
  # processing prematurely. This fixture puts a `# Foo` line AFTER Wave 5
  # content — a contrived case, but proves the anchor isn't overly greedy.
  local fixture
  fixture=$(mktemp)
  cat > "$fixture" <<'EOF'
   **Wave 5 — Heavy/rate-sensitive tests:**
   - `/chk2:cat1`
   - `/chk2:cat2`
# Not-a-real-section-header
   - `/chk2:cat3`
   - `/chk2:cat4`
   - `/chk2:cat5`
   - `/chk2:cat6`
EOF

  local record start end
  record=$(_waves_from_md "$fixture")
  start=$(echo "$record" | awk -F'\t' '{print $2}')
  end=$(echo "$record" | awk -F'\t' '{print $3}')
  local cat_count
  cat_count=$(sed -n "${start},${end}p" "$fixture" | grep -cE '^[[:space:]]+-[[:space:]]+`/chk2:')

  rm -f "$fixture"

  [ "$cat_count" -eq 6 ]
}

@test "CPT-164: Wave with no trailing anchor still uses EOF as end (fixture)" {
  # Regression guard: the EOF fallback must still work when a Wave has no
  # anchor after it (e.g. a test fixture that intentionally omits the
  # **Between waves** / ## closer).
  local fixture
  fixture=$(mktemp)
  cat > "$fixture" <<'EOF'
   **Wave 5 — Heavy/rate-sensitive tests:**
   - `/chk2:cat1`
   - `/chk2:cat2`
   - `/chk2:cat3`
   - `/chk2:cat4`
   - `/chk2:cat5`
   - `/chk2:cat6`
EOF

  local record start end
  record=$(_waves_from_md "$fixture")
  start=$(echo "$record" | awk -F'\t' '{print $2}')
  end=$(echo "$record" | awk -F'\t' '{print $3}')
  local cat_count
  cat_count=$(sed -n "${start},${end}p" "$fixture" | grep -cE '^[[:space:]]+-[[:space:]]+`/chk2:')

  rm -f "$fixture"

  [ "$cat_count" -eq 6 ]
}
