#!/usr/bin/env bats

# CPT-118: CPT-33 advertised that `_publish_one.sh` honours the HTTP
# Retry-After header on 429/503/529 but actually only parsed a
# `.retryAfter` JSON body field via jq. Jira sends rate-limit hints in
# the Retry-After RESPONSE HEADER, so the body lookup returns empty and
# the code falls back to the 2/4/8s exponential backoff — under parallel
# xargs workers that ignores the server-mandated delay and exhausts
# MAX_PUBLISH_RETRIES prematurely.
#
# Fix contract: capture headers with `curl -D` (or `--dump-header`),
# parse `Retry-After:` case-insensitively, use that value if numeric,
# then fall back to body `.retryAfter`, then to exp backoff.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
PUBLISH="${REPO_DIR}/skills/rr/bin/_publish_one.sh"

@test "_publish_one.sh exists (sanity)" {
  [ -f "$PUBLISH" ]
}

@test "_publish_one.sh captures HTTP response headers (CPT-118)" {
  # Must use curl -D or --dump-header (not just --write-out status).
  grep -qE 'curl[^|]*(-D |--dump-header )' "$PUBLISH" || {
    echo "_publish_one.sh does not capture response headers via curl -D / --dump-header" >&2
    return 1
  }
}

@test "_publish_one.sh parses Retry-After header case-insensitively (CPT-118)" {
  # Extract the 429/503/529 case arm and inspect its body.
  local block
  block=$(awk '/429\|503\|529\)/,/^[[:space:]]*;;[[:space:]]*$/' "$PUBLISH")
  [ -n "$block" ] || { echo "could not locate 429/503/529 case arm" >&2; return 1; }

  # Must reference the Retry-After header (case-insensitive grep on the
  # header file), e.g. `grep -i '^Retry-After:'` or `grep -iE '^[Rr]etry-?[Aa]fter'`.
  echo "$block" | grep -qiE 'Retry-After|retry-after' || {
    echo "429/503/529 arm does not parse the Retry-After header" >&2
    return 1
  }
}

@test "_publish_one.sh retries with header value, not just body .retryAfter (CPT-118)" {
  # The header-sourced value must feed retry_after BEFORE the body fallback.
  # Detect the ordering: a reference to Retry-After should appear before
  # the body `.retryAfter // empty` jq expression, indicating header takes
  # precedence.
  local header_line_num body_line_num
  header_line_num=$(grep -niE 'Retry-After|retry-after' "$PUBLISH" | head -1 | cut -d: -f1)
  body_line_num=$(grep -n '\.retryAfter // empty' "$PUBLISH" | head -1 | cut -d: -f1)
  [ -n "$header_line_num" ] || { echo "no Retry-After parse found" >&2; return 1; }
  if [ -n "$body_line_num" ]; then
    [ "$header_line_num" -lt "$body_line_num" ] || {
      echo "Retry-After header parse must precede body fallback (.retryAfter)" >&2
      return 1
    }
  fi
}

# --- CPT-140: CPT-118 introduced two P1 regressions —
#   1. The new `trap 'rm -f "$attempt_headers"' EXIT` installed AFTER the
#      lock-cleanup trap REPLACES it (bash trap semantics). Every batch
#      publish from rr-finalize.sh leaks $LOCK_DIR/${risk_key}.lock;
#      subsequent runs hit the ALREADY_PUBLISHING early-return for every
#      already-attempted risk.
#   2. `grep -i Retry-After | tail -1 | sed ...` pipeline is unguarded.
#      When the header is absent (common for 503/529 and many 429
#      responses), grep exits 1, pipefail propagates, set -e aborts the
#      script — the body/exp-backoff fallback path is never reached.

@test "_publish_one.sh does NOT install a second EXIT trap that clobbers lock cleanup (CPT-140)" {
  # There should be AT MOST one `trap ... EXIT` in the script. If there are
  # multiple, the second one wins under bash trap semantics and the lock
  # cleanup silently stops running.
  count=$(grep -cE '^[[:space:]]*trap[[:space:]]+.*EXIT' "$PUBLISH")
  [ "$count" -le 1 ] || {
    echo "Found $count 'trap ... EXIT' calls in _publish_one.sh — the second will clobber the first (CPT-140)." >&2
    grep -nE '^[[:space:]]*trap[[:space:]]+.*EXIT' "$PUBLISH" >&2
    return 1
  }
}

@test "_publish_one.sh installs a unified cleanup function (CPT-140)" {
  # The fix shape is: one cleanup function that removes BOTH the lock dir
  # and the attempt_headers tempfile, registered via a single trap.
  # Require a function name that starts with _cleanup (underscore-prefixed
  # convention already used in the rr bin scripts).
  grep -qE '^[[:space:]]*_cleanup\s*\(\)' "$PUBLISH" || {
    echo "_publish_one.sh does not define a unified _cleanup() function" >&2
    return 1
  }
  # The function body must reference BOTH resources.
  body=$(awk '/^[[:space:]]*_cleanup[[:space:]]*\(\)/{flag=1} flag; /^[[:space:]]*}[[:space:]]*$/{if(flag){exit}}' "$PUBLISH")
  [ -n "$body" ] || { echo "_cleanup body not found" >&2; return 1; }
  echo "$body" | grep -q 'LOCK_DIR' || { echo "_cleanup does not remove the lock dir" >&2; return 1; }
  echo "$body" | grep -q 'attempt_headers' || { echo "_cleanup does not remove the attempt_headers tempfile" >&2; return 1; }
  # The single trap must reference _cleanup.
  grep -qE "trap[[:space:]]+['\"]?_cleanup" "$PUBLISH" || {
    echo "Single EXIT trap does not invoke _cleanup" >&2
    return 1
  }
}

@test "_publish_one.sh guards the Retry-After grep pipeline against missing-header exit-1 (CPT-140)" {
  # The grep | tail | sed pipeline MUST end with `|| true` (or equivalent
  # guard) so grep's exit-1 on missing-header doesn't propagate under
  # `set -euo pipefail` and abort the script before the fallback path runs.
  # The pipeline may be split across continuation lines — inspect the
  # retry_after_header assignment as one logical statement.
  stmt=$(awk '
    /retry_after_header=\$\(/ {inside=1}
    inside {print}
    inside && /\)/ && !/^\s*#/ {exit}
  ' "$PUBLISH")
  [ -n "$stmt" ] || { echo "could not locate retry_after_header assignment" >&2; return 1; }
  echo "$stmt" | grep -qE '\|\|[[:space:]]+true' || {
    echo "retry_after_header= pipeline is not guarded with '|| true' — grep exit-1 will abort under set -e pipefail (CPT-140)" >&2
    echo "statement found:" >&2
    echo "$stmt" >&2
    return 1
  }
}
