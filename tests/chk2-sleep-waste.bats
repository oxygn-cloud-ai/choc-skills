#!/usr/bin/env bats
# Tests for CPT-16: chk2 serial sleep and subprocess waste elimination

CHK2_DIR="skills/chk2/commands"

@test "scale.md RE1 Slowloris uses ThreadPoolExecutor for concurrent connections" {
  [ -f "$CHK2_DIR/scale.md" ] || skip "scale.md not found"
  run grep 'ThreadPoolExecutor' "$CHK2_DIR/scale.md"
  [ "$status" -eq 0 ]
  # Should NOT have serial for loop around sleep
  run grep -c 'for i in range(5):' "$CHK2_DIR/scale.md"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
}

@test "auth.md AU3 uses jq instead of python3 for JSON parsing" {
  [ -f "$CHK2_DIR/auth.md" ] || skip "auth.md not found"
  # AU3 loop should use jq, not python3 -c
  run grep -A 3 'AU3.*Concurrent' "$CHK2_DIR/auth.md"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'jq'
  # Should NOT pipe to python3 -c for JSON parsing in the loop
  run grep -c 'seq 1 22.*python3 -c' "$CHK2_DIR/auth.md"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
}

@test "sse.md SE2 discovers valid SSE path before concurrent test" {
  [ -f "$CHK2_DIR/sse.md" ] || skip "sse.md not found"
  # Should have path discovery phase before concurrent connections
  run grep -i 'discover.*path\|probe.*path\|find.*path\|Phase 1\|valid path' "$CHK2_DIR/sse.md"
  [ "$status" -eq 0 ]
  # Should still use ThreadPoolExecutor for the concurrent phase
  run grep 'ThreadPoolExecutor' "$CHK2_DIR/sse.md"
  [ "$status" -eq 0 ]
}
