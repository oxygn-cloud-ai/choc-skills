#!/usr/bin/env bats

# CPT-162 + CPT-165 + CPT-167 + CPT-168: bats-self-lint.
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
# CPT-162 covered `2>&1` at end-of-line. CPT-165 extends:
#  - trailing-comment variant `run ... 2>&1  # capture stderr`
#  - bare stdin redirect `run cmd <file`
# CPT-167 extends the `<file` lint to:
#  - exclude `<<` (heredoc marker) via char-class tightening
#  - exclude lines with `run (bash|sh) -c` via a post-grep filter step
#    (the `<` is then inside a quoted shell string, which the inner
#    shell performs — legitimate usage, not the argv-as-literal bug)
# CPT-168 re-captures the case CPT-167's filter over-suppressed:
#  - `run bash -c '...' _ <file` — redirect AFTER the closing quote of
#    the inner shell script is still top-level argv (argv-as-literal
#    bug). Added as a second candidate regex (candidate_b) that the
#    filter doesn't drop.
#
# Regex shapes (all anchored to start-of-line):
#
#   2>&1:          ^[[:space:]]*run[[:space:]].*[[:space:]]2>&1[[:space:]]*(#.*)?$
#   <file cand_a:  ^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(<][^ |]*([[:space:]].*)?(#.*)?$
#                  filter OUT:   run[[:space:]]+(bash|sh)[[:space:]]+-c
#   <file cand_b:  ^[[:space:]]*run[[:space:]]+(bash|sh)[[:space:]]+-c[[:space:]]+'[^']*'.*[[:space:]]<[^ |(<]
#                  (single-quoted script; double-quoted variant via separate regex)
#
# The `<` lint excludes `< <(...)` process substitution by requiring the
# char immediately after `<` to be non-space non-paren. It also excludes
# `<<` (heredoc) via `<` in the char class. The `bash|sh -c` filter
# drops lines where `<` is inside the quoted script; candidate_b
# re-captures the narrow case where `<` appears AFTER the close-quote.
#
# Chain note: CPT-162 → 165 → 167 → 168 has been four successive Codex
# refinements. If this grows again, replace the grep-chain with a small
# awk/python tokenizer that actually tracks quote state.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
TESTS_DIR="${REPO_DIR}/tests"

@test "CPT-162: no bats test uses bare-top-level 'run ... 2>&1' (bats captures stderr already)" {
  [ -d "$TESTS_DIR" ]

  # CPT-165: widened to allow an optional trailing `# comment` after the
  # `2>&1`. The pre-CPT-165 end-anchor `[[:space:]]*$` missed
  # `run cmd 2>&1  # capture stderr` — bats still parses `2>&1` as argv
  # regardless of the comment; the comment is just ignored by bash.
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

@test "CPT-165: no bats test uses bare-top-level 'run ... <file' (bats does not redirect stdin)" {
  [ -d "$TESTS_DIR" ]

  # Top-level `<file` in `run cmd <file` passes the literal `<file`
  # string as argv[N], NOT as a stdin redirection — bats doesn't invoke
  # a shell for plain `run`. If the test author wants stdin redirection,
  # they need `run bash -c "cmd <file"` (the spawned shell performs it).
  #
  # `[^ |(<]` after the first `<` excludes:
  #   - space (handles `< <(...)` process-substitution form)
  #   - `|` (handles rare pipe-in-middle cases)
  #   - `(` (belt-and-braces for process subst)
  #   - `<` (CPT-167: excludes `<<EOF`-style heredoc marker; the second
  #     `<` of `<<` is part of the heredoc syntax inside a quoted
  #     shell string, not a stdin-redirect-as-argv bug)
  # `[^ |]*` after the first char keeps filename-like tokens glued to
  # the `<`; the optional trailing `([[:space:]].*)?` allows more argv
  # after, and `(#.*)?$` allows an end-of-line bash comment.
  #
  # CPT-167 post-grep filter (candidate_a): offenders are filtered to
  # drop any line matching `run[[:space:]]+(bash|sh)[[:space:]]+-c`.
  # Those lines typically have `<` embedded INSIDE a quoted shell
  # script passed to an inner shell — the redirect is performed by
  # the inner shell, which is the correct pattern.
  #
  # CPT-168 re-capture (candidate_b): the CPT-167 filter was too
  # coarse — it also dropped lines where `<file` appears AFTER the
  # closing quote of the bash-c script, e.g.
  #   run bash -c 'cat "$1"' _ <input.txt
  # Here `<input.txt` is a top-level argv literal, exactly the bug
  # the lint exists to catch. Candidate B re-captures those by
  # matching lines with a full `run (bash|sh) -c '...'` (or `"..."`)
  # span followed by `[[:space:]]<[^ |(<]`. Two separate regexes
  # (single-quoted, double-quoted) avoid ERE backreferences which
  # aren't portable across grep implementations.

  local candidates_a offenders_a candidates_b_sq candidates_b_dq offenders
  candidates_a=$(grep -nE '^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(<][^ |]*([[:space:]].*)?(#.*)?$' "$TESTS_DIR"/*.bats || true)
  offenders_a=$(echo "$candidates_a" | grep -vE 'run[[:space:]]+(bash|sh)[[:space:]]+-c' || true)
  # Single-quoted bash-c script with trailing top-level redirect after close-quote.
  candidates_b_sq=$(grep -nE "^[[:space:]]*run[[:space:]]+(bash|sh)[[:space:]]+-c[[:space:]]+'[^']*'.*[[:space:]]<[^ |(<]" "$TESTS_DIR"/*.bats || true)
  # Double-quoted bash-c script with trailing top-level redirect after close-quote.
  candidates_b_dq=$(grep -nE '^[[:space:]]*run[[:space:]]+(bash|sh)[[:space:]]+-c[[:space:]]+"[^"]*".*[[:space:]]<[^ |(<]' "$TESTS_DIR"/*.bats || true)
  offenders=$(printf '%s\n%s\n%s\n' "$offenders_a" "$candidates_b_sq" "$candidates_b_dq" | sed '/^$/d' | sort -u)

  if [ -n "$offenders" ]; then
    echo "CPT-165/CPT-168: the following lines use bare-top-level 'run ... <file'." >&2
    echo "bats does not invoke a shell for plain 'run <cmd>', so '<file' is argv, not stdin." >&2
    echo "If you need stdin redirection, wrap in 'run bash -c \"... <file\"' (with '<' INSIDE the quoted script):" >&2
    echo "$offenders" >&2
    return 1
  fi
}

# --- CPT-165 fixture-based meta-tests: prove the regexes actually match
#     the shapes they're advertised to catch. Without these, the grep-
#     across-tests tests pass only because no current test is an
#     offender; they can't prove the regex would catch a future one.

@test "CPT-165: regex catches 'run ... 2>&1 # comment' (fixture)" {
  local line='  run bash "$INSTALLER" --flag 2>&1  # capture stderr'
  run bash -c "printf '%s\n' '$line' | grep -qE '^[[:space:]]*run[[:space:]].*[[:space:]]2>&1[[:space:]]*(#.*)?\$'"
  [ "$status" -eq 0 ]
}

@test "CPT-165: regex catches 'run ... 2>&1' at plain EOL (fixture, backwards compat)" {
  local line='  run bash "$INSTALLER" --flag 2>&1'
  run bash -c "printf '%s\n' '$line' | grep -qE '^[[:space:]]*run[[:space:]].*[[:space:]]2>&1[[:space:]]*(#.*)?\$'"
  [ "$status" -eq 0 ]
}

@test "CPT-165: regex does NOT flag 'run bash -c \"... 2>&1\"' (fixture)" {
  # The 2>&1 is INSIDE a quoted bash -c string; the line ends with `"`,
  # not `2>&1`. The end-anchored regex must not match.
  local line='  run bash -c "echo x 2>&1"'
  run bash -c "printf '%s\n' '$line' | grep -qE '^[[:space:]]*run[[:space:]].*[[:space:]]2>&1[[:space:]]*(#.*)?\$'"
  [ "$status" -ne 0 ]
}

@test "CPT-165: regex catches 'run cmd <file' (fixture)" {
  local line='  run cat <input.txt'
  run bash -c "printf '%s\n' '$line' | grep -qE '^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(<][^ |]*([[:space:]].*)?(#.*)?\$'"
  [ "$status" -eq 0 ]
}

@test "CPT-165: regex catches 'run cmd <file extra-arg' (fixture)" {
  local line='  run some-cmd <input.txt other-arg'
  run bash -c "printf '%s\n' '$line' | grep -qE '^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(<][^ |]*([[:space:]].*)?(#.*)?\$'"
  [ "$status" -eq 0 ]
}

@test "CPT-165: regex does NOT flag 'run cmd < <(process-sub)' (fixture)" {
  # Process substitution `< <(...)` has a SPACE after the first `<`.
  # The `[^ |(]` char class excludes space, so the regex doesn't match.
  local line='  run cat < <(printf x)'
  run bash -c "printf '%s\n' '$line' | grep -qE '^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(<][^ |]*([[:space:]].*)?(#.*)?\$'"
  [ "$status" -ne 0 ]
}

@test "CPT-165: regex does NOT flag line with '<' that isn't a redirect (fixture)" {
  # A `<` that isn't preceded by space wouldn't normally be a redirect.
  # The `[[:space:]]<` anchor requires a preceding space.
  local line='  run test "a<b"'
  run bash -c "printf '%s\n' '$line' | grep -qE '^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(<][^ |]*([[:space:]].*)?(#.*)?\$'"
  [ "$status" -ne 0 ]
}

# --- CPT-167 fixtures: heredoc + bash-c-quoted-redirect exemptions.
#
# Concern 1 (heredoc): `run bash -c 'cat <<EOF ... EOF'`. The `<<` is a
# heredoc marker inside the quoted shell script. Pre-CPT-167 the
# `[^ |(]` char class accepted the second `<`, so `<<EOF` matched and
# was falsely flagged. CPT-167 adds `<` to the exclusion, turning the
# class into `[^ |(<]` — the second `<` of `<<` is now excluded at
# candidate stage.
#
# Concern 2 (bash-c quoted `<file`): `run bash -c 'cat <input.txt'`.
# The `<` is inside a quoted string that the inner shell performs; not
# the argv-as-literal bug. The new char class alone doesn't exclude
# this — regex engines don't track quotes. CPT-167 adds a post-grep
# filter step that drops any line matching `run (bash|sh) -c`.

@test "CPT-167: regex does NOT flag 'run bash -c \"cat <<EOF\"' (heredoc fixture)" {
  local line="  run bash -c 'cat <<EOF'"
  run bash -c "printf '%s\n' \"$line\" | grep -qE '^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(<][^ |]*([[:space:]].*)?(#.*)?\$'"
  [ "$status" -ne 0 ]  # Excluded at candidate stage by `[^ |(<]`.
}

@test "CPT-167: regex does NOT flag 'run bash -c \"cmd <input\"' — candidate-stage plus filter (fixture)" {
  # This one DOES match the candidate regex (no <<), but the post-grep
  # filter for `run (bash|sh) -c` drops it. Exercise the full two-step.
  local line="  run bash -c 'cat <input.txt'"
  local candidates offenders
  candidates=$(printf '%s\n' "$line" | grep -nE '^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(<][^ |]*([[:space:]].*)?(#.*)?$' || true)
  offenders=$(echo "$candidates" | grep -vE 'run[[:space:]]+(bash|sh)[[:space:]]+-c' || true)
  [ -z "$offenders" ]
}

@test "CPT-167: regex does NOT flag 'run sh -c \"cat <data\"' — filter handles sh too (fixture)" {
  local line="  run sh -c 'cat <data.txt'"
  local candidates offenders
  candidates=$(printf '%s\n' "$line" | grep -nE '^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(<][^ |]*([[:space:]].*)?(#.*)?$' || true)
  offenders=$(echo "$candidates" | grep -vE 'run[[:space:]]+(bash|sh)[[:space:]]+-c' || true)
  [ -z "$offenders" ]
}

@test "CPT-167: regex + filter DOES still flag plain 'run cat <input.txt' (fixture, regression guard)" {
  # Baseline: the CPT-165 anti-pattern must still be caught after the
  # CPT-167 widening. No `bash -c` / `sh -c`, no `<<`, so candidate
  # matches and filter doesn't drop.
  local line='  run cat <input.txt'
  local candidates offenders
  candidates=$(printf '%s\n' "$line" | grep -nE '^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(<][^ |]*([[:space:]].*)?(#.*)?$' || true)
  offenders=$(echo "$candidates" | grep -vE 'run[[:space:]]+(bash|sh)[[:space:]]+-c' || true)
  [ -n "$offenders" ]
}

# --- CPT-168 fixtures: re-capture top-level `<file` that appears AFTER
#     the closing quote of a `bash -c '...'` or `bash -c "..."` script.
#     CPT-167's filter dropped these wholesale; candidate_b restores.

@test "CPT-168: candidate_b DOES flag 'run bash -c <single-quoted> _ <file' (top-level redirect after close-quote)" {
  # The argv-as-literal bug CPT-167's filter over-suppressed. `_` is a
  # conventional placeholder for $0 when passing positional args to
  # bash -c; `<input.txt` is then a top-level redirect (argv literal
  # under bats) that the inner shell never sees.
  local line="  run bash -c 'cat \"\$1\"' _ <input.txt"
  run bash -c "printf '%s\n' \"$line\" | grep -qE \"^[[:space:]]*run[[:space:]]+(bash|sh)[[:space:]]+-c[[:space:]]+'[^']*'.*[[:space:]]<[^ |(<]\""
  [ "$status" -eq 0 ]  # MATCH — re-captured.
}

@test "CPT-168: candidate_b DOES flag 'run bash -c <double-quoted> _ <file' (double-quoted variant)" {
  # Use a simpler double-quoted bash -c script to avoid nested-escape tangle.
  local line='  run bash -c "cat input" _ <input.txt'
  if echo "$line" | grep -qE '^[[:space:]]*run[[:space:]]+(bash|sh)[[:space:]]+-c[[:space:]]+"[^"]*".*[[:space:]]<[^ |(<]'; then
    :  # matched — pass
  else
    echo "double-quoted bash-c with trailing redirect should match candidate_b" >&2
    echo "line: $line" >&2
    return 1
  fi
}

@test "CPT-168: candidate_b does NOT flag 'run bash -c <script>' with NO trailing redirect" {
  # Sanity — a plain `bash -c 'cmd'` with no trailing `<` must not match
  # the re-capture regex. (The filter drops it at candidate_a stage.)
  local line="  run bash -c 'echo hello'"
  run bash -c "printf '%s\n' \"$line\" | grep -qE \"^[[:space:]]*run[[:space:]]+(bash|sh)[[:space:]]+-c[[:space:]]+'[^']*'.*[[:space:]]<[^ |(<]\""
  [ "$status" -ne 0 ]
}

@test "CPT-168: candidate_b does NOT flag 'run bash -c <cmd-with-interior-<file>' (redirect stays inside quoted script)" {
  # The old CPT-167 case that must still pass through — `<` is inside
  # the quoted script; no `<` after the close-quote.
  local line="  run bash -c 'cat <input.txt'"
  run bash -c "printf '%s\n' \"$line\" | grep -qE \"^[[:space:]]*run[[:space:]]+(bash|sh)[[:space:]]+-c[[:space:]]+'[^']*'.*[[:space:]]<[^ |(<]\""
  [ "$status" -ne 0 ]
}
