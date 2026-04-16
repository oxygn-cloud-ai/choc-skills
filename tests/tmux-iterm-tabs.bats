#!/usr/bin/env bats

# Smoke tests for skills/iterm2-tmux/bin/tmux-iterm-tabs.sh.
#
# Fast, portable checks — every test below runs the script directly out of the
# repo (no install step needed) and covers the paths that do NOT require
# macOS, iTerm2, or a live tmux session. The last block is skipped on hosts
# where iTerm2 isn't running so CI on Linux stays green.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="${REPO_DIR}/skills/iterm2-tmux/bin/tmux-iterm-tabs.sh"

# --- Arg parsing ------------------------------------------------------------

@test "iterm-tabs: --help prints usage mentioning --session" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--session"* ]]
}

@test "iterm-tabs: --session with no value exits 1" {
  run "$SCRIPT" --session
  [ "$status" -eq 1 ]
  [[ "$output" == *"--session requires"* ]]
}

@test "iterm-tabs: unknown argument exits 1" {
  run "$SCRIPT" --bogus-flag
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown argument"* ]]
}

# --- Autostart opt-in gate --------------------------------------------------

@test "iterm-tabs: autostart exits 0 silently when AUTOSTART_ENABLED unset" {
  # Must exit before any preflight (tmux / iTerm2) checks so it's safe on
  # Linux/CI. Also asserts zero stdout/stderr so the .zshrc snippet's
  # `>/dev/null 2>&1` redirection never hides a surprise message.
  run env -u AUTOSTART_ENABLED "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "iterm-tabs: autostart exits 0 silently when AUTOSTART_ENABLED=false" {
  run env AUTOSTART_ENABLED=false "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "iterm-tabs: autostart with AUTOSTART_ENABLED=true passes the opt-in gate" {
  # We verify the gate lets traffic through by asserting the script either
  # (a) reaches preflight and fails on missing deps (Linux/CI), or
  # (b) is skipped entirely here because running the full autostart path on
  #     a fully-wired macOS host would spam real iTerm2 tabs.
  if command -v tmux >/dev/null && pgrep -qf "iTerm"; then
    skip "tmux + iTerm2 present — skipping to avoid side-effect tabs"
  fi
  run env AUTOSTART_ENABLED=true "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"not running"* ]]
}

# --- --session window-mode (requires macOS + iTerm2 + tmux) -----------------

@test "iterm-tabs: --session <nonexistent> exits 1 with clear error" {
  [ "$(uname -s)" = "Darwin" ] || skip "macOS-only (AppleScript path)"
  command -v tmux >/dev/null || skip "tmux required"
  pgrep -qf "iTerm" || skip "iTerm2 not running"

  local bogus="nonexistent-session-$$-$(date +%s)"
  run "$SCRIPT" --session "$bogus"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}
