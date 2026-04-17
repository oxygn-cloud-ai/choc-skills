#!/usr/bin/env bats
# Tests for CPT-18: chk2 categories — eliminate redundant HTTP requests

CHK2_DIR="skills/chk2/commands"

# --- Finding 1: fingerprint.md single curl for FP1-FP4 ---

@test "fingerprint.md FP1-FP4 share a single curl call not 5 separate" {
  [ -f "$CHK2_DIR/fingerprint.md" ] || skip "fingerprint.md not found"
  # Count curl calls to the root URL for headers (not FP5/FP6 which are different)
  # Should have at most 1 curl -sI for the combined FP1-FP4 check, plus FP5 openssl + FP6 API
  count=$(grep -c 'curl -sI.*https://.*/' "$CHK2_DIR/fingerprint.md" || true)
  [ "$count" -le 1 ]
}

# --- Finding 2: reporting.md RC4 reuses RC3 content ---

@test "reporting.md RC4 reuses security.txt from RC3 not a separate curl" {
  [ -f "$CHK2_DIR/reporting.md" ] || skip "reporting.md not found"
  # CPT-106: the prior `^# RC4` sed range matched nothing after CPT-18 merged
  # RC3+RC4 (the heading is indented inside an else-branch, so `^` doesn't hit)
  # and the test silently passed regardless of content. Switched to inspecting
  # the merged block directly — from the "# RC3 + RC4:" header through the
  # closing outer `fi` — and asserting exactly one curl call.
  local merged_curls
  merged_curls=$(sed -n '/# RC3 + RC4:/,/^fi[[:space:]]*$/p' "$CHK2_DIR/reporting.md" | grep -c 'curl ' || true)
  [ "$merged_curls" -eq 1 ] || { echo "expected exactly 1 curl in RC3+RC4 merged block, got $merged_curls" >&2; return 1; }
}

# --- Finding 3: backend.md BF3 iteration count (CPT-18 baseline → CPT-106 correction) ---

@test "backend.md BF3 timing uses 5 iterations (CPT-106 corrected CPT-18)" {
  [ -f "$CHK2_DIR/backend.md" ] || skip "backend.md not found"
  # CPT-18 reduced BF3 from 5→3 iterations for perf. CPT-106 showed 3 samples
  # sits below the noise floor of a CDN-fronted target — single-outlier swings
  # can invalidate the timing measurement. Restored to 5, which is the same
  # runtime cost as the pre-CPT-18 code but stable against jitter.
  run grep -c 'range(3)' "$CHK2_DIR/backend.md"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
  run grep 'range(5)' "$CHK2_DIR/backend.md"
  [ "$status" -eq 0 ]
}

# --- Finding 4: waf.md F6 has --max-time per request ---

@test "waf.md F6 rate limit test has --max-time on each curl" {
  [ -f "$CHK2_DIR/waf.md" ] || skip "waf.md not found"
  # The seq 1 35 loop should have --max-time
  run sed -n '/seq 1 35/,/done/p' "$CHK2_DIR/waf.md"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'max-time'
}

# --- Finding 5: timing.md TM1-TM2 iteration count (CPT-18 baseline → CPT-106 correction) ---

@test "timing.md TM1-TM2 use 5 iterations per side (CPT-106 corrected CPT-18)" {
  [ -f "$CHK2_DIR/timing.md" ] || skip "timing.md not found"
  # CPT-18 reduced TM1/TM2 from 5→3 iterations per side for perf. CPT-106
  # showed 3 samples sit below the noise floor of a CDN-fronted target —
  # single slow responses can move the mean by more than the 50 ms PASS/WARN
  # threshold, flipping verdicts on jitter. Restored to 5 samples per side
  # and switched the Checks table to "median" so the downstream auditor
  # uses a robust statistic.
  run grep -c 'for i in \$(seq 1 3)' "$CHK2_DIR/timing.md"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
  run grep -c 'for i in \$(seq 1 5)' "$CHK2_DIR/timing.md"
  # Four timing loops: TM1 valid, TM1 invalid, TM2 plausible, TM2 invalid
  [ "$output" -ge 4 ] || { echo "expected >=4 'seq 1 5' timing loops, got $output" >&2; return 1; }
}

# --- Finding 6: scale.md RE4 has socket timeout ---

@test "scale.md RE4 chunked transfer has socket timeout" {
  [ -f "$CHK2_DIR/scale.md" ] || skip "scale.md not found"
  # Should have settimeout on the socket
  run grep -i 'settimeout\|socket.*timeout' "$CHK2_DIR/scale.md"
  [ "$status" -eq 0 ]
}
