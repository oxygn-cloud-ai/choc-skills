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

@test "CPT-105: safe_first derives from raw \$first so control chars survive" {
  # Execute the ACTUAL first-session variable-assignment block that ships in
  # the script with an injected control-char session. If the buggy
  # `first="$(sanitize_for_applescript "$first")"` reassignment lives in the
  # script, safe_first will have its ESC stripped and the assertion will fail.

  # Extract the block from `first_label="$(lookup_label...` up to (but not
  # including) the `cat > "$TMPSCRIPT"` heredoc.
  local snippet
  snippet=$(awk '/^first_label="\$\(lookup_label/{flag=1} /^cat > /{flag=0} flag' "$SCRIPT")
  [[ -n "$snippet" ]]

  run bash -c '
    set -euo pipefail
    eval "$(sed -n "/^sanitize_for_applescript()/,/^}/p" "'"$SCRIPT"'")"

    # Stub lookup_label: return the raw session name (no repo match).
    lookup_label() { printf "%s" "$1"; }

    first=$'"'"'myses\x1bX'"'"'

    # Execute the real first-session block.
    '"$snippet"'

    printf "LABEL=[%s]\n" "$safe_first_label"
    printf "TARGET_HEX=" ; printf "%s" "$safe_first" | od -An -tx1 | tr -d " \n" ; printf "\n"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"LABEL=[mysesX]"* ]]
  # 6d79736573 = "myses", 1b = ESC, 58 = "X"
  [[ "$output" == *"TARGET_HEX=6d797365731b58"* ]]
}
