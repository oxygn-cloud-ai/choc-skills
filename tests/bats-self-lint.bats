#!/usr/bin/env bats

# CPT-162 + CPT-165 + CPT-167 + CPT-168 + CPT-169: bats-self-lint.
#
# The bats `run` helper captures both stdout and stderr into `$output`
# by default, and does NOT spawn a shell for plain `run <cmd>` — argv is
# exec'd directly. Any shell metacharacter at the top level of `run`
# (`2>&1`, `<file`, `>file`, `|`, `;`) is parsed as an argv token, not
# as a shell construct. This looks right but silently breaks the test.
#
# Inside `run bash -c "..."` or `run sh -c "..."`, these constructs
# INSIDE the quoted string are legitimate — the spawned shell performs
# them. The lints below only flag top-level occurrences.
#
# ============================================================
# History: grep-chain → tokenizer (CPT-169 refactor)
# ============================================================
#
# CPT-162 shipped `run ... 2>&1` at EOL.
# CPT-165 widened to trailing-comment `2>&1 # ...` and added
#   separate `run cmd <file` lint (grep + filter-step).
# CPT-167 fixed CPT-165 false-positive on `<<EOF` heredocs and
#   `run bash -c 'cmd <file'` — char-class widening + bash-c filter.
# CPT-168 fixed CPT-167 false-negative on `run bash -c 'cmd' _ <file`
#   — added candidate_b regex for top-level redirect after close-quote.
# CPT-169 fixed CPT-168 false-positive on escaped quotes inside
#   `bash -c "... \"x\" <file"` — CPT-168's `"[^"]*"` regex treated
#   `\"` as a close-quote. That's the 5th Codex-caught defect in a row.
#
# CPT-169 refactored the whole `<file` lint to an awk tokenizer
# (tests/lib/bats-run-lint.awk) that tracks quote state (single vs
# double vs escaped) properly. The tokenizer:
#   - skips leading whitespace
#   - requires line to start with `run `
#   - walks char-by-char tracking state 0 (outside), 1 (single-quote),
#     2 (double-quote)
#   - inside double-quote, `\X` is a 2-char escape unit (fixes the
#     CPT-169 `\"` mis-tokenization)
#   - inside single-quote, no escaping (POSIX shell semantics)
#   - collects top-level tokens
#   - flags if ANY top-level token T has:
#       length(T) >= 2
#       AND T[0] == '<'
#       AND T[1] not in {'|', '(', '<'}
#     Exclusions mirror CPT-168's char-class `[^ |(<]` exactly.
#
# The `2>&1` lint remains grep-based — the regex shape is simple and
# hasn't spawned a refinement chain.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
TESTS_DIR="${REPO_DIR}/tests"
TOKENIZER="${REPO_DIR}/tests/lib/bats-run-lint.awk"

@test "CPT-162: no bats test uses bare-top-level 'run ... 2>&1' (bats captures stderr already)" {
  [ -d "$TESTS_DIR" ]

  # CPT-165 widened: allow an optional trailing `# comment` after the
  # `2>&1`. bats still parses `2>&1` as argv regardless of the comment.
  local offenders
  offenders=$(grep -nE '^[[:space:]]*run[[:space:]].*[[:space:]]2>&1[[:space:]]*(#.*)?$' "$TESTS_DIR"/*.bats || true)

  if [ -n "$offenders" ]; then
    echo "CPT-162: the following lines use bare 'run ... 2>&1' at the top level." >&2
    echo "bats already captures stdout+stderr into \$output — the redirection is a no-op" >&2
    echo "and is parsed as an argument to the command, not a shell redirection." >&2
    echo "Drop the trailing '2>&1':" >&2
    echo "$offenders" >&2
    return 1
  fi
}

@test "CPT-169: no bats test uses bare-top-level 'run ... <file' (tokenizer-based)" {
  [ -d "$TESTS_DIR" ]
  [ -f "$TOKENIZER" ]

  # Awk tokenizer walks each `run ...` line with quote-state tracking
  # and flags top-level argv tokens starting with `<`. See the awk
  # script for the full flag rule and exclusions.
  local offenders
  offenders=$(awk -f "$TOKENIZER" "$TESTS_DIR"/*.bats || true)

  if [ -n "$offenders" ]; then
    echo "CPT-169: the following lines use bare-top-level 'run ... <file'." >&2
    echo "bats does not invoke a shell for plain 'run <cmd>', so '<file' is argv, not stdin." >&2
    echo "If you need stdin redirection, wrap in 'run bash -c \"... <file\"' (with '<' INSIDE the quoted script):" >&2
    echo "$offenders" >&2
    return 1
  fi
}

# --- Fixture meta-tests: prove the tokenizer matches the shapes it
#     advertises to catch/allow. Each fixture writes the input line
#     to a temp file, runs the tokenizer, and asserts offender presence
#     or absence.

_tokenize_line() {
  # Usage: _tokenize_line <line> → echoes awk tokenizer's offenders output.
  local line="$1"
  local tmp
  tmp=$(mktemp)
  printf '%s\n' "$line" > "$tmp"
  awk -f "$TOKENIZER" "$tmp" || true
  rm -f "$tmp"
}

# --- CPT-165-equivalent cases (still must pass under the tokenizer) ---

@test "CPT-165 (via tokenizer): flags 'run cat <input.txt'" {
  [ -n "$(_tokenize_line '  run cat <input.txt')" ]
}

@test "CPT-165 (via tokenizer): flags 'run some-cmd <input.txt other-arg'" {
  [ -n "$(_tokenize_line '  run some-cmd <input.txt other-arg')" ]
}

@test "CPT-165 (via tokenizer): does NOT flag 'run cat < <(printf x)' (process substitution)" {
  [ -z "$(_tokenize_line '  run cat < <(printf x)')" ]
}

@test "CPT-165 (via tokenizer): does NOT flag 'run test \"a<b\"' (< inside quotes)" {
  [ -z "$(_tokenize_line '  run test "a<b"')" ]
}

# --- CPT-167-equivalent cases (heredoc + interior redirect inside bash -c) ---

@test "CPT-167 (via tokenizer): does NOT flag 'run bash -c \"cat <<EOF\"' (heredoc inside double-quotes)" {
  [ -z "$(_tokenize_line '  run bash -c "cat <<EOF"')" ]
}

@test "CPT-167 (via tokenizer): does NOT flag 'run bash -c '\\''cat <input.txt'\\''' (interior redirect in single-quotes)" {
  [ -z "$(_tokenize_line "  run bash -c 'cat <input.txt'")" ]
}

@test "CPT-167 (via tokenizer): does NOT flag 'run sh -c '\\''cat <data.txt'\\''' (sh -c variant)" {
  [ -z "$(_tokenize_line "  run sh -c 'cat <data.txt'")" ]
}

# --- CPT-168-equivalent cases (top-level redirect AFTER close-quote of bash -c) ---

@test "CPT-168 (via tokenizer): flags 'run bash -c <single-quoted-script> _ <input.txt'" {
  [ -n "$(_tokenize_line "  run bash -c 'cat \"\$1\"' _ <input.txt")" ]
}

@test "CPT-168 (via tokenizer): flags 'run bash -c <double-quoted-script> _ <input.txt'" {
  [ -n "$(_tokenize_line '  run bash -c "cat input" _ <input.txt')" ]
}

@test "CPT-168 (via tokenizer): does NOT flag 'run bash -c <script>' with NO trailing redirect" {
  [ -z "$(_tokenize_line "  run bash -c 'echo hello'")" ]
}

# --- CPT-169 cases: escape-handling in double-quoted bash -c scripts ---

@test "CPT-169 (via tokenizer): does NOT flag 'run bash -c \"printf \\\"x\\\" <input.txt\"' (escaped quotes inside double-quoted script)" {
  # The defect CPT-168's regex had: `"[^"]*"` treated `\"` as close-quote
  # and broke tokenization. The tokenizer handles `\X` as an escape unit
  # inside double quotes, so the outer `"..."` span correctly contains
  # the escaped `\"x\"` and `<input.txt`.
  local line='  run bash -c "printf \"x\" <input.txt"'
  [ -z "$(_tokenize_line "$line")" ]
}

@test "CPT-169 (via tokenizer): still flags 'run bash -c \"echo hi\" _ <input.txt' (escape-fix doesn't over-correct)" {
  # Baseline after the escape fix: a real trailing top-level redirect
  # after a double-quoted bash -c script must still be caught.
  local line='  run bash -c "echo hi" _ <input.txt'
  [ -n "$(_tokenize_line "$line")" ]
}

@test "CPT-169 (via tokenizer): does NOT flag 'run bash -c \"echo \\\"x\\\"\"' (escaped quotes, no redirect)" {
  # Escaped quotes close cleanly at the outer `"` — tokenizer shouldn't
  # wrongly interpret the inner `\"` as opening/closing state changes.
  local line='  run bash -c "echo \"x\""'
  [ -z "$(_tokenize_line "$line")" ]
}

@test "CPT-169 (via tokenizer): does NOT flag 'run bash -c \"echo \\\\\"' (escaped backslash, no redirect)" {
  # Edge: `\\` should be an escape unit (literal backslash). Tokenizer
  # should consume both chars together.
  local line='  run bash -c "echo \\"'
  [ -z "$(_tokenize_line "$line")" ]
}

# --- Tokenizer unit tests: exact output format + exclusion rules ---

@test "CPT-169 (tokenizer unit): offender output includes filename:lineno:text" {
  # Grep -n-compatible format so error rendering stays uniform.
  local tmp
  tmp=$(mktemp)
  printf '%s\n' '  run cat <input.txt' > "$tmp"
  local out
  out=$(awk -f "$TOKENIZER" "$tmp")
  rm -f "$tmp"
  [[ "$out" == *":1:"* ]]
  [[ "$out" == *"<input.txt"* ]]
}

@test "CPT-169 (tokenizer unit): bare '<' token (len 1) is not flagged" {
  # Regression guard for CPT-168's `[^ |(<]` floor which required a
  # character AFTER `<`. `run cat <` alone has a token "<" of length 1
  # which the tokenizer shouldn't flag — same semantic as the grep.
  local line='  run cat <'
  [ -z "$(_tokenize_line "$line")" ]
}

@test "CPT-169 (tokenizer unit): '<<EOF' token is not flagged (heredoc exclusion)" {
  # Matches CPT-168's `[^ |(<]` second-char exclusion: tokens starting
  # with `<<` are skipped (heredoc at top level of run is exotic;
  # matching CPT-168 behaviour keeps scope narrow).
  local line='  run cat <<EOF'
  [ -z "$(_tokenize_line "$line")" ]
}

@test "CPT-169 (tokenizer unit): '<(proc)' token is not flagged (process-sub exclusion)" {
  local line='  run cmd <(printf x)'
  [ -z "$(_tokenize_line "$line")" ]
}

@test "CPT-169 (tokenizer unit): comment at top level terminates tokenization" {
  # `#` outside quotes marks a bash comment — tokenizer must stop so
  # `<file` inside a comment isn't flagged.
  local line='  run cmd arg  # later words mention <file'
  [ -z "$(_tokenize_line "$line")" ]
}

@test "CPT-169 (tokenizer unit): line not starting with 'run ' is ignored" {
  local line='  echo "run cat <file"'
  [ -z "$(_tokenize_line "$line")" ]
}

# --- CPT-170 fixtures: shell-syntax edge cases in the tokenizer ---

@test "CPT-170 (tokenizer): flags 'run<TAB>cat <input.txt' (tab separator after run)" {
  # POSIX shell accepts ANY whitespace (space or tab) after a command.
  # Pre-CPT-170 the tokenizer required a literal space and silently
  # skipped tab-separated `run\tcat <file` — a false negative.
  local line; line=$(printf '  run\tcat <input.txt')
  [ -n "$(_tokenize_line "$line")" ]
}

@test "CPT-170 (tokenizer): flags 'run bash -c \"echo hi\"#suffix _ <input.txt' (# inside a word)" {
  # POSIX shell: `#` starts a comment only when it's at the beginning
  # of a new word. `"echo hi"#suffix` is a single word joining a
  # quoted substring and a literal `#suffix`. Pre-CPT-170 the
  # tokenizer's unconditional `if (c == "#") break` terminated parsing
  # at the `#`, missing the top-level `<input.txt` bug.
  local line='  run bash -c "echo hi"#suffix _ <input.txt'
  [ -n "$(_tokenize_line "$line")" ]
}

@test "CPT-170 (tokenizer): 'run cmd # comment with <file' still NOT flagged (real comment still works)" {
  # Baseline: a legitimate top-level bash comment must still terminate
  # parsing so `<file` inside the comment isn't spuriously flagged.
  # The fix only changes `#` handling mid-word, not at word-start.
  local line='  run cmd arg  # later words mention <file'
  [ -z "$(_tokenize_line "$line")" ]
}

@test "CPT-170 (tokenizer): 'run cmd#weird <file' flags the real <file redirect" {
  # Word containing `#` at top level is treated as a single literal
  # token. The trailing `<file` is still a top-level redirect bug.
  local line='  run cmd#weird <input.txt'
  [ -n "$(_tokenize_line "$line")" ]
}

@test "CPT-170 (tokenizer): plain 'run\tcmd arg' with no redirect is NOT flagged" {
  # Tab-after-run acceptance mustn't over-correct — a plain tab-spaced
  # run line with no redirect must still pass the lint.
  local line; line=$(printf '  run\tcmd arg')
  [ -z "$(_tokenize_line "$line")" ]
}

# --- CPT-171 fixtures: shell-operator boundaries also start comments.
#
# POSIX shell: `#` starts a comment when preceded by whitespace OR by a
# shell operator (`;`, `|`, `&`, `(`, `)`). CPT-170's `token == ""`
# guard only handled the whitespace case. These fixtures lock operator
# boundaries.

@test "CPT-171 (tokenizer): 'run cmd;# comment mentioning <file' NOT flagged (semicolon boundary)" {
  # Semi-colon is an operator boundary — `#` after it starts a comment.
  # Pre-CPT-171 the `;` was appended to the current token so `token` was
  # `"cmd;"` when `#` was hit; guard failed; `<file` later was flagged.
  local line='  run cmd;# comment with <file'
  [ -z "$(_tokenize_line "$line")" ]
}

@test "CPT-171 (tokenizer): 'run cmd|#comment <file' NOT flagged (pipe boundary)" {
  local line='  run cmd|#comment <file'
  [ -z "$(_tokenize_line "$line")" ]
}

@test "CPT-171 (tokenizer): 'run cmd&& # comment <file' NOT flagged (space + # word-start after operator)" {
  # Current CPT-170 fix already handles space + `#`; this fixture
  # guards against operator handling accidentally breaking it.
  local line='  run cmd && # comment with <file'
  [ -z "$(_tokenize_line "$line")" ]
}

@test "CPT-171 (tokenizer): 'run cmd; real-cmd <input.txt' FLAGGED (operator boundary, no comment, real redirect)" {
  # Baseline: after `;`, the real `<input.txt` redirect is still a top-
  # level argv-as-literal bug. Operator flush mustn't swallow real
  # redirects on the other side of the operator.
  local line='  run cmd; real-cmd <input.txt'
  [ -n "$(_tokenize_line "$line")" ]
}

@test "CPT-171 (tokenizer): 'run cmd1|cmd2 <input.txt' FLAGGED (pipe, then real redirect)" {
  # Pipe at top level is bats-broken anyway (argv literal), but even
  # so, a `<file` AFTER the pipe is still a real redirect bug.
  local line='  run cmd1|cmd2 <input.txt'
  [ -n "$(_tokenize_line "$line")" ]
}

# --- CPT-172 fixtures: $(...) and $((...)) are single shell words.
#
# CPT-171's blanket `)` operator flush broke command substitution
# `$(cmd)` and arithmetic expansion `$((expr))`. Inside them the whole
# span is ONE token, so `$(printf x)#suffix` is `x#suffix` after
# expansion, and `#` there is NOT a comment start.

@test "CPT-172 (tokenizer): 'run echo \$(printf x)#suffix _ <input.txt' FLAGGED (cmd-subst is single word)" {
  # Pre-CPT-172 the `)` flushed, then `#` hit token=="" and broke;
  # `<input.txt` was never reached and the bug silently passed.
  local line='  run echo $(printf x)#suffix _ <input.txt'
  [ -n "$(_tokenize_line "$line")" ]
}

@test "CPT-172 (tokenizer): 'run echo \$((1+2))#suffix _ <input.txt' FLAGGED (arithmetic is single word)" {
  # Arithmetic expansion uses `$((` / `))`. Depth tracking naturally
  # handles the matched pairs: entering on `$(` goes to depth 1, the
  # second `(` bumps to 2, matching `))` brings depth back to 0.
  local line='  run echo $((1+2))#suffix _ <input.txt'
  [ -n "$(_tokenize_line "$line")" ]
}

@test "CPT-172 (tokenizer): nested \$(echo \$(date))#suffix <file FLAGGED (nested cmd-subst)" {
  # Nested $(... $(...) ...) — the outer `)` shouldn't flush until
  # the inner `$()` is fully closed.
  local line='  run echo $(echo $(date))#suffix <input.txt'
  [ -n "$(_tokenize_line "$line")" ]
}

@test "CPT-172 (tokenizer): plain '(cmd) # comment <file' NOT flagged (subshell + word-start #)" {
  # Bare `(cmd)` is a subshell — `)` IS a real operator boundary, and
  # `# comment` after whitespace is a legitimate comment. The `(` at
  # position 0 of token would trigger the subshell-operator flush
  # (cs_depth is 0 since no preceding `$`).
  local line='  run (cmd) # comment with <file'
  [ -z "$(_tokenize_line "$line")" ]
}

@test "CPT-172 (tokenizer): 'run echo \$(printf x) <input.txt' FLAGGED (plain redirect after cmd-subst)" {
  # Baseline guard: redirect AFTER a correctly-tokenized cmd-subst,
  # with a space separator, is still the argv-as-literal bug.
  local line='  run echo $(printf x) <input.txt'
  [ -n "$(_tokenize_line "$line")" ]
}

@test "CPT-172 (tokenizer): 'run echo \$(printf x)' with NO redirect is NOT flagged" {
  # Sanity — cmd-subst at top level with no redirect must still pass.
  local line='  run echo $(printf x)'
  [ -z "$(_tokenize_line "$line")" ]
}
