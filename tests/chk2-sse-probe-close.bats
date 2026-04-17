#!/usr/bin/env bats

# CPT-99: SE2 Phase 1 SSE discovery probe must close its response before
# Phase 2 opens concurrent connections on the same path. A stale probe
# holding a slot would undercount Phase 2's concurrent connections by
# one (e.g. report "19/20" against a 20-concurrency cap), producing a
# false-positive connection-limit measurement.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SSE_MD="${REPO_DIR}/skills/chk2/commands/sse.md"

# Extract the Phase 1 discovery loop (between the "Phase 1" comment and the
# "Phase 2" comment or "sse_path is None" branch). We inspect just this
# region so the test is specific to Phase 1 and not confused by Phase 2 usage.
phase1_block() {
  awk '/# Phase 1:/,/^if sse_path is None:/' "$SSE_MD"
}

@test "chk2 sse.md exists" {
  [ -f "$SSE_MD" ]
}

@test "chk2 sse.md Phase 1 contains a SSE discovery loop (sanity)" {
  phase1_block | grep -q "for path in"
  phase1_block | grep -q "sse_path = path"
  phase1_block | grep -q "urlopen(req"
}

@test "chk2 sse.md Phase 1 probe releases its response before break (CPT-99)" {
  # Either (a) use a context manager: `with urlopen(...) as resp:`
  # or       (b) explicit resp.close() on the success path before `break`
  local block
  block=$(phase1_block)
  if echo "$block" | grep -qE 'with[[:space:]]+urlopen\('; then
    return 0
  fi
  if echo "$block" | grep -qE 'resp\.close\(\)'; then
    return 0
  fi
  echo "Phase 1 probe does not close response before Phase 2 (expected 'with urlopen(...)' or 'resp.close()')" >&2
  return 1
}
