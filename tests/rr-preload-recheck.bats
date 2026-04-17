#!/usr/bin/env bats

# CPT-91: rr:all pre-load optimization (CPT-9) silently degrades under
# Claude Code auto-compaction. The pre-loaded step content is supposed
# to stay in context for the full batch run, but auto-compaction can
# summarise or drop it without warning. Per-risk loop then executes
# against a stale / empty view of the step.
#
# Fix: add a lightweight re-check instruction at the top of the per-risk
# loop. If the pre-loaded content is no longer retrievable, re-read the
# step files.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ALL_MD="$REPO_DIR/skills/rr/commands/all.md"

@test "rr:all pre-load section mentions auto-compaction risk" {
  # The pre-load section should acknowledge that compaction can drop
  # the loaded content, so future readers understand why the re-check
  # step exists.
  grep -qiE 'compact|auto-compact' "$ALL_MD"
}

@test "rr:all per-risk loop has a re-check / fallback step before using pre-loaded content" {
  # There should be an explicit instruction to verify the pre-loaded
  # content is still in context (or re-read on miss) before the per-risk
  # loop uses it.
  grep -qiE "re-read|recall.*step|verify.*pre-load|check.*pre-load|if.*pre-load.*(lost|missing|dropped)" "$ALL_MD"
}

@test "rr:all documents that savings are per-session, not per-register" {
  # The original CHANGELOG claim was "174 wasted reads on a 30-risk
  # register" — that's only realised inside one uninterrupted session.
  # The doc should acknowledge this scope.
  grep -qiE 'per.session|per session|one session|single session|context capacity' "$ALL_MD"
}
