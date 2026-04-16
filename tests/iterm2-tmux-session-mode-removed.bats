#!/usr/bin/env bats

# CPT-43: Verify the orphaned --session mode is removed from
# skills/iterm2-tmux/bin/tmux-iterm-tabs.sh. Triager decision 2026-04-16:
# Option B (delete) over Option A (wire up). No caller exists anywhere in
# the repo, so the mode is dead code whose presence was a latent runtime-
# failure risk. This test locks the deletion in so the orphan doesn't
# creep back in.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="${REPO_DIR}/skills/iterm2-tmux/bin/tmux-iterm-tabs.sh"

@test "tmux-iterm-tabs.sh: --session flag is rejected as unknown argument (CPT-43)" {
  [ -f "$SCRIPT" ]
  run bash "$SCRIPT" --session someproject
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"unknown"* ]]
}

@test "tmux-iterm-tabs.sh: --help does not advertise --session (CPT-43)" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" != *"--session"* ]]
}

@test "tmux-iterm-tabs.sh: source does not contain --session mode artefacts (CPT-43)" {
  # The orphan mode's markers: the arg case, the variable, the mode block,
  # and the autostart lock tied to --session. All of these must be absent
  # from the script source after the cleanup.
  run grep -E '^[[:space:]]*--session\)' "$SCRIPT"
  [ "$status" -ne 0 ] || { echo "found --session) arg case still in script" >&2; return 1; }
  run grep -E 'TARGET_PROJECT' "$SCRIPT"
  [ "$status" -ne 0 ] || { echo "TARGET_PROJECT variable still referenced in script" >&2; return 1; }
  run grep -E 'iterm2-tmux-session-active' "$SCRIPT"
  [ "$status" -ne 0 ] || { echo "session-active lock sentinel still referenced in script" >&2; return 1; }
}
