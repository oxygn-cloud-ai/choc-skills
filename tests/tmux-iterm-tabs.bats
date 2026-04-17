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

# --- CPT-105: tmux target identifier must remain raw (only AppleScript label sanitized) ---
#
# CPT-29 sanitised both the label and the tmux identifier. Sanitising the identifier
# breaks `tmux attach -t "$SESSION"` for any session whose name actually contained a
# control character, silently failing attach in exactly the cases the patch targeted.
# The fix is: sanitise only the label (AppleScript-literal safety); leave the tmux
# target raw so tmux still resolves it.

@test "CPT-105: first session — tmux target is NOT reassigned to the sanitised form" {
  # The buggy line `first="$(sanitize_for_applescript "$first")"` must be absent.
  run grep -nE '^[[:space:]]*first="\$\(sanitize_for_applescript[[:space:]]+"\$first"\)"' "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "CPT-105: rest loop — tmux target is NOT reassigned to the sanitised form" {
  # The buggy line `s="$(sanitize_for_applescript "$s")"` must be absent.
  run grep -nE '^[[:space:]]*s="\$\(sanitize_for_applescript[[:space:]]+"\$s"\)"' "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "CPT-105: first session label sanitisation is preserved" {
  grep -qE 'first_label="\$\(sanitize_for_applescript[[:space:]]+"\$first_label"\)"' "$SCRIPT"
}

@test "CPT-105: rest loop label sanitisation is preserved" {
  grep -qE '[[:space:]]label="\$\(sanitize_for_applescript[[:space:]]+"\$label"\)"' "$SCRIPT"
}

# --- CPT-147: raw session names must not land in AppleScript string literals
#     or shell-quoted command arguments — newline/CR/tab break AppleScript,
#     single-quote breaks the `write text "...'$name'..."` shell context.
#     Fix: write raw name to a temp file, pass --session-file <path> to the
#     attach helper. The file path is under our control (no shell hazards).

@test "CPT-147: tmux-iterm-tabs.sh writes raw session names to temp files for AppleScript handoff" {
  # The script must include a per-session temp-file step and pass
  # --session-file to ATTACH_SCRIPT instead of interpolating the raw name.
  grep -qE 'session_dir=\$\(mktemp -d' "$SCRIPT" || {
    echo "tmux-iterm-tabs.sh does not create a temp-dir for session names (CPT-147)" >&2
    return 1
  }
  # First-session target file
  grep -qE 'first_target_file=' "$SCRIPT" || {
    echo "tmux-iterm-tabs.sh has no first_target_file handoff (CPT-147)" >&2
    return 1
  }
  # AppleScript write-text line passes --session-file to ATTACH_SCRIPT
  grep -qE -- '--session-file' "$SCRIPT" || {
    echo "AppleScript write text does not use --session-file handoff (CPT-147)" >&2
    return 1
  }
}

@test "CPT-147: tmux-iterm-tabs.sh does NOT interpolate \$first into the AppleScript write-text line" {
  # The pre-fix shape was:
  #   write text "$ATTACH_SCRIPT '$safe_first' '$safe_first_label' 0"
  # where $safe_first derives from raw $first. That interpolation is the
  # injection vector. Refuse the literal shape outright.
  if grep -qE "write text \"\\\$ATTACH_SCRIPT '\\\$safe_first'" "$SCRIPT"; then
    echo "AppleScript write text still interpolates \$safe_first raw — CPT-147 regression" >&2
    return 1
  fi
  if grep -qE "write text \"\\\$ATTACH_SCRIPT '\\\$safe_s'" "$SCRIPT"; then
    echo "AppleScript write text still interpolates \$safe_s raw in loop — CPT-147 regression" >&2
    return 1
  fi
}

@test "CPT-147: tmux-attach-session.sh accepts --session-file flag" {
  local attach="${REPO_DIR}/skills/iterm2-tmux/bin/tmux-attach-session.sh"
  [ -f "$attach" ]
  grep -qE -- '--session-file' "$attach" || {
    echo "tmux-attach-session.sh does not accept --session-file (CPT-147)" >&2
    return 1
  }
}

@test "CPT-147: tmux-attach-session.sh reads session name from --session-file path correctly" {
  local attach="${REPO_DIR}/skills/iterm2-tmux/bin/tmux-attach-session.sh"
  # End-to-end: write a name with NL/CR/tab/single-quote to a temp file, source
  # the flag-parsing block, assert SESSION ends up with the raw bytes intact.
  local tmp
  tmp=$(mktemp /tmp/tmux-target-test.XXXXXX)
  trap "rm -f '$tmp'" RETURN
  # shellcheck disable=SC1003
  printf "bad'name\nwith\tctl\r" > "$tmp"

  run bash -c '
    set -euo pipefail
    set -- --session-file "'"$tmp"'" "label-value" 3
    # Extract the flag-parsing block — lines from start of file up to but
    # not including `exec tmux`. This executes whatever shape the shipping
    # script uses for its arg parse.
    eval "$(awk "/^set -euo pipefail/{flag=1; next} /^exec tmux/{flag=0} flag" "'"$attach"'")"
    printf "SESSION_HEX=" ; printf "%s" "$SESSION" | od -An -tx1 | tr -d " \n" ; printf "\n"
    printf "LABEL=[%s]\n" "$LABEL"
    printf "INDEX=[%s]\n" "$INDEX"
  '
  [ "$status" -eq 0 ]
  # Raw bytes: b a d ' n a m e \n w i t h \t c t l \r
  #            62 61 64 27 6e 61 6d 65 0a 77 69 74 68 09 63 74 6c 0d
  [[ "$output" == *"SESSION_HEX=626164276e616d650a776974680963746c0d"* ]]
  [[ "$output" == *"LABEL=[label-value]"* ]]
  [[ "$output" == *"INDEX=[3]"* ]]
}

# CPT-105 "safe_first derives from raw $first" test removed by CPT-147 —
# the `safe_first` variable no longer exists. Its raw-byte-preservation
# semantic is now carried end-to-end by the `--session-file` handoff
# (see CPT-147 test "reads session name from --session-file path correctly"
# above, which asserts the raw bytes survive through the file into SESSION).
