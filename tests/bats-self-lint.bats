#!/usr/bin/env bats

# CPT-162 + CPT-165: bats-self-lint.
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
#
# Regex shapes (all anchored to start/end-of-line so quoted-string uses
# inside `run bash -c "..."` — which end in `"` then optional args — are
# not flagged):
#
#   2>&1:         ^[[:space:]]*run[[:space:]].*[[:space:]]2>&1[[:space:]]*(#.*)?$
#   <file:        ^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(][^ |]*([[:space:]].*)?(#.*)?$
#
# The `<` lint excludes `< <(...)` process substitution by requiring the
# char immediately after `<` to be non-space non-paren. It does not
# perfectly distinguish `run cmd <file` from `run bash -c 'cmd <file'`
# (the `<` inside a single-quoted string) — accepted trade-off. No
# current test uses that shape; if it appears, the author can add
# `# noqa: CPT-165` handling or wrap differently.

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
  # `[^ |(]` after `<` excludes `< <(...)` process-substitution form
  # (rare but legitimate inside bash -c). `[^ |]*` after the first char
  # keeps filename-like tokens glued to the `<`; the optional trailing
  # `([[:space:]].*)?` allows more argv after, and `(#.*)?$` allows an
  # end-of-line bash comment.
  local offenders
  offenders=$(grep -nE '^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(][^ |]*([[:space:]].*)?(#.*)?$' "$TESTS_DIR"/*.bats || true)

  if [ -n "$offenders" ]; then
    echo "CPT-165: the following lines use bare 'run ... <file' at the top level." >&2
    echo "bats does not invoke a shell for plain 'run <cmd>', so '<file' is argv, not stdin." >&2
    echo "If you need stdin redirection, wrap in 'run bash -c \"... <file\"':" >&2
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
  run bash -c "printf '%s\n' '$line' | grep -qE '^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(][^ |]*([[:space:]].*)?(#.*)?\$'"
  [ "$status" -eq 0 ]
}

@test "CPT-165: regex catches 'run cmd <file extra-arg' (fixture)" {
  local line='  run some-cmd <input.txt other-arg'
  run bash -c "printf '%s\n' '$line' | grep -qE '^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(][^ |]*([[:space:]].*)?(#.*)?\$'"
  [ "$status" -eq 0 ]
}

@test "CPT-165: regex does NOT flag 'run cmd < <(process-sub)' (fixture)" {
  # Process substitution `< <(...)` has a SPACE after the first `<`.
  # The `[^ |(]` char class excludes space, so the regex doesn't match.
  local line='  run cat < <(printf x)'
  run bash -c "printf '%s\n' '$line' | grep -qE '^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(][^ |]*([[:space:]].*)?(#.*)?\$'"
  [ "$status" -ne 0 ]
}

@test "CPT-165: regex does NOT flag line with '<' that isn't a redirect (fixture)" {
  # A `<` that isn't preceded by space wouldn't normally be a redirect.
  # The `[[:space:]]<` anchor requires a preceding space.
  local line='  run test "a<b"'
  run bash -c "printf '%s\n' '$line' | grep -qE '^[[:space:]]*run[[:space:]].*[[:space:]]<[^ |(][^ |]*([[:space:]].*)?(#.*)?\$'"
  [ "$status" -ne 0 ]
}
