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
