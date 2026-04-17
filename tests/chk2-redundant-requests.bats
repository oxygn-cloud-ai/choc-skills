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
  # RC4 should reference the variable from RC3 (SECTXT) not make its own curl calls
  # Count curl calls in RC4 section
  rc4_curls=$(sed -n '/^# RC4/,/^```$/p' "$CHK2_DIR/reporting.md" | grep -c 'curl ' || true)
  [ "$rc4_curls" -eq 0 ]
}

# --- Finding 3: backend.md BF3 reduces request count ---

@test "backend.md BF3 timing uses 3 iterations not 5" {
  [ -f "$CHK2_DIR/backend.md" ] || skip "backend.md not found"
  # Should use range(3) not range(5) to reduce from 25 to 15 requests
  run grep -c 'range(5)' "$CHK2_DIR/backend.md"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
  run grep 'range(3)' "$CHK2_DIR/backend.md"
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

# --- Finding 5: timing.md uses parallel or fewer sequential requests ---

@test "timing.md TM1-TM2 use 3 iterations not 5" {
  [ -f "$CHK2_DIR/timing.md" ] || skip "timing.md not found"
  # Should use seq 1 3 not seq 1 5 for the timing measurements
  run grep -c 'seq 1 5' "$CHK2_DIR/timing.md"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
}

# --- Finding 6: scale.md RE4 has socket timeout ---

@test "scale.md RE4 chunked transfer has socket timeout" {
  [ -f "$CHK2_DIR/scale.md" ] || skip "scale.md not found"
  # Should have settimeout on the socket
  run grep -i 'settimeout\|socket.*timeout' "$CHK2_DIR/scale.md"
  [ "$status" -eq 0 ]
}
