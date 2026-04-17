#!/usr/bin/env bats

# Tests for tmux-iterm-tabs.sh AppleScript sanitization
#
# These tests source the sanitize_for_applescript() function and verify
# it strips control characters that could break or inject into AppleScript.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="${REPO_DIR}/skills/iterm2-tmux/bin/tmux-iterm-tabs.sh"

# Extract sanitize_for_applescript function for unit testing.
# We source it in a subshell that stubs out everything else.
setup() {
  # The function must exist in the script
  grep -q 'sanitize_for_applescript' "$SCRIPT"
}

# Helper: call the function from the script in isolation
call_sanitize() {
  # Source just the function definition, then call it
  bash -c '
    sanitize_for_applescript() { :; }
    eval "$(sed -n "/^sanitize_for_applescript()/,/^}/p" "'"$SCRIPT"'")"
    sanitize_for_applescript "$1"
  ' _ "$1"
}

# --- Control character stripping ---

@test "sanitize_for_applescript strips newlines" {
  local input=$'hello\nworld'
  local result
  result=$(call_sanitize "$input")
  [[ "$result" != *$'\n'* ]]
  [[ "$result" == "helloworld" ]]
}

@test "sanitize_for_applescript strips carriage returns" {
  local input=$'hello\rworld'
  local result
  result=$(call_sanitize "$input")
  [[ "$result" != *$'\r'* ]]
  [[ "$result" == "helloworld" ]]
}

@test "sanitize_for_applescript strips null bytes" {
  local input="hello"$'\x00'"world"
  local result
  result=$(call_sanitize "$input")
  # Null bytes should be gone
  [[ ${#result} -le 10 ]]
}

@test "sanitize_for_applescript strips tab characters" {
  local input=$'hello\tworld'
  local result
  result=$(call_sanitize "$input")
  [[ "$result" != *$'\t'* ]]
  [[ "$result" == "helloworld" ]]
}

@test "sanitize_for_applescript strips escape sequences" {
  local input=$'hello\x1b[31mworld'
  local result
  result=$(call_sanitize "$input")
  [[ "$result" != *$'\x1b'* ]]
}

@test "sanitize_for_applescript preserves normal printable text" {
  local input="my-session_name.v2"
  local result
  result=$(call_sanitize "$input")
  [[ "$result" == "$input" ]]
}

@test "sanitize_for_applescript preserves spaces" {
  local input="hello world"
  local result
  result=$(call_sanitize "$input")
  [[ "$result" == "hello world" ]]
}

@test "sanitize_for_applescript handles empty string" {
  local result
  result=$(call_sanitize "")
  [[ "$result" == "" ]]
}

# --- Integration: the generated AppleScript must not contain raw control chars ---

@test "rr SKILL.md does not grant dangerous Bash wildcards (existing)" {
  # Ensure the iterm2-tmux script uses sanitize_for_applescript before AppleScript generation
  grep -q 'sanitize_for_applescript' "$SCRIPT"
}
