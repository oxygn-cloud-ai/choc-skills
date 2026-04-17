#!/usr/bin/env bats

# CPT-106: CPT-18's sample reduction (5 → 3) pushed TM1/TM2/BF3 below the
# noise floor of a CDN-fronted target — a single slow response swings a
# 3-sample mean past the 50 ms PASS/WARN threshold, flipping the verdict
# on CDN jitter rather than application behaviour. The remediation is to
# (a) restore sample count to 5, and (b) state "median" as the comparison
# statistic so the downstream auditor uses a robust stat.

CHK2_DIR="skills/chk2/commands"
TIMING_MD="${CHK2_DIR}/timing.md"
BACKEND_MD="${CHK2_DIR}/backend.md"

@test "chk2 timing.md exists (sanity)" {
  [ -f "$TIMING_MD" ]
}

@test "timing.md TM1/TM2 use 5 samples per side, not 3 (CPT-106)" {
  # Refuse the regression shape and require the restored-stable shape.
  if grep -qE 'for i in \$\(seq 1 3\)' "$TIMING_MD"; then
    echo "TM1/TM2 still use 3 samples per side — below the CDN noise floor" >&2
    return 1
  fi
  # Four `seq 1 5` loops expected: TM1 valid, TM1 invalid, TM2 plausible, TM2 invalid
  local count
  count=$(grep -cE 'for i in \$\(seq 1 5\)' "$TIMING_MD")
  [ "$count" -ge 4 ] || { echo "expected >=4 'seq 1 5' timing loops in TM1/TM2, got $count" >&2; return 1; }
}

@test "timing.md Checks table specifies median not mean (CPT-106)" {
  # Downstream auditor reads this text to decide which statistic to apply.
  # "Median" resists single-outlier CDN swings; "average"/"mean" does not.
  awk '/^\|[[:space:]]*TM[12]/,/^$/' "$TIMING_MD" | grep -qiE 'median'
}

@test "backend.md BF3 uses 5 iterations, not 3 (CPT-106)" {
  if grep -qE 'range\(3\)' "$BACKEND_MD"; then
    echo "BF3 still uses range(3) — CDN jitter can invalidate the timing sample" >&2
    return 1
  fi
  grep -qE 'range\(5\)' "$BACKEND_MD"
}

@test "reporting.md RC3+RC4 merged block has exactly one curl call (CPT-106 / CPT-18 carryover)" {
  # Replaces the vacuous pre-CPT-106 test that sed'd '^# RC4' (never matched
  # post-merge and silently passed regardless of content). Now checks the
  # merged block directly: from the '# RC3 + RC4:' header through the
  # closing outer `fi`, exactly one curl call must exist (the shared SECTXT
  # fetch). A future edit that reintroduces a dedicated RC4 curl would
  # drive the count to >=2 and fail this test.
  local reporting="${CHK2_DIR}/reporting.md"
  [ -f "$reporting" ] || skip "reporting.md not found"
  local curls
  curls=$(sed -n '/# RC3 + RC4:/,/^fi[[:space:]]*$/p' "$reporting" | grep -c 'curl ')
  [ "$curls" -eq 1 ] || { echo "expected exactly 1 curl in RC3+RC4 merged block, got $curls" >&2; return 1; }
}
