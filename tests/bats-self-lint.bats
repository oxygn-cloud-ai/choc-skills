#!/usr/bin/env bats

# CPT-162: bats-self-lint.
#
# The bats `run` helper captures both stdout and stderr into `$output`
# by default. Writing `run cmd ... 2>&1` at the top level of `run` is
# at best a no-op; at worst it looks intentional and masks real bugs
# (the `2>&1` is parsed by bats as an argument to the program under
# test, not as a shell redirection — bats does not invoke a shell for
# plain `run <cmd>`).
#
# Inside `run bash -c "..."` or `run sh -c "..."`, a `2>&1` INSIDE the
# quoted string is a legitimate redirection performed by the spawned
# shell, and is fine.
#
# Lint rule: at the start of a line (ignoring whitespace), `run <words>
# 2>&1` at end-of-line is forbidden. The regex
#     ^\s*run\s.*\s2>&1\s*$
# matches exactly that bare-top-level shape.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
TESTS_DIR="${REPO_DIR}/tests"

@test "CPT-162: no bats test uses bare-top-level 'run ... 2>&1' (bats captures stderr already)" {
  [ -d "$TESTS_DIR" ]

  # Collect any offending lines across all .bats files in tests/.
  # Matches only when 2>&1 is at end-of-line AFTER whitespace, with the
  # line starting with `run ` at the top level of a bats test — i.e.
  # NOT inside a `bash -c "..."` string (the closing quote would come
  # after 2>&1 in that case).
  local offenders
  offenders=$(grep -nE '^[[:space:]]*run[[:space:]].*[[:space:]]2>&1[[:space:]]*$' "$TESTS_DIR"/*.bats || true)

  if [ -n "$offenders" ]; then
    echo "CPT-162: the following lines use bare 'run ... 2>&1' at the top level." >&2
    echo "bats already captures stdout+stderr into \$output — the redirection is a no-op" >&2
    echo "and is parsed as an argument to the command, not a shell redirection." >&2
    echo "Drop the trailing '2>&1':" >&2
    echo "$offenders" >&2
    return 1
  fi
}
