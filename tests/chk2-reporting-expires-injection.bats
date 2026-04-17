#!/usr/bin/env bats

# CPT-101: chk2 reporting.md RC4 `Expires:` field must not interpolate
# server-controlled data into `python3 -c` source. Prior code wrapped
# `$exp_date` in single-quoted Python literals; an attacker-controlled
# `security.txt` body could break out via `' + __import__('os').popen('…') + '`
# and execute arbitrary commands on the auditor's workstation.
#
# The fix is stdin (or env-var) delivery so the value is data, not source.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
REPORTING_MD="${REPO_DIR}/skills/chk2/commands/reporting.md"

@test "chk2 reporting.md exists" {
  [ -f "$REPORTING_MD" ]
}

@test "chk2 reporting.md RC4 does not interpolate \$exp_date into python3 -c source (CPT-101)" {
  # The exact injectable pattern from the ticket:
  #   fromisoformat('$exp_date'.replace(...))
  # If we still see that form, the RCE is live.
  if grep -qE "fromisoformat\('\\\$exp_date'" "$REPORTING_MD"; then
    echo "reporting.md still embeds \$exp_date inside a python3 -c source string — remote-controlled content can execute arbitrary code" >&2
    return 1
  fi

  # More general guard: no python3 -c block anywhere in reporting.md should
  # interpolate a shell variable named *_date or *exp* that traces from an
  # HTTP response.
  if grep -qE "python3 -c \"[^\"]*'\\\$exp_date'" "$REPORTING_MD"; then
    echo "reporting.md: python3 -c still interpolates \$exp_date" >&2
    return 1
  fi
}

@test "chk2 reporting.md RC4 uses stdin or env-var delivery for Expires value (CPT-101)" {
  # Positive assertion: after the fix, near the Expires check, the file must
  # show one of:
  #   (a) `printf … | python3 -c "…sys.stdin.read()…"`
  #   (b) `EXP_DATE="$exp_date" python3 -c "…os.environ['EXP_DATE']…"`
  # Inspect a generous window around the Expires fence so the positive form
  # doesn't depend on exact indentation.
  local block
  block=$(sed -n '/expires=.*SECTXT.*Expires:/,/^fi[[:space:]]*$/p' "$REPORTING_MD")
  [ -n "$block" ] || { echo "could not locate RC4 Expires block" >&2; return 1; }
  echo "$block" | grep -qE '(sys\.stdin\.read|os\.environ)'
}

@test "RC4 Expires handling is injection-proof at runtime (CPT-101)" {
  # Extract the Expires-check subblock from reporting.md, pre-set SECTXT to
  # a hostile fixture, execute the block as a standalone bash script, and
  # confirm the injection payload does not create its sentinel file.
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"

  local sentinel harness
  sentinel="$(mktemp -u -t cpt101.XXXXXX)"
  rm -f "$sentinel"

  # Hostile SECTXT. The payload shape — `' + __import__('os').system('touch …') + '` —
  # is exactly what CPT-101 warns about. Under the fix, the value is treated
  # as data (stdin or env-var), so the sentinel file must NOT be created.
  local hostile
  hostile="Expires: 2026-01-01'+__import__('os').system('touch ${sentinel}')+'Z"
  export SECTXT="$hostile"

  harness="$(mktemp -t cpt101-harness.XXXXXX)"
  # Extract the Expires check region. sed range from the `expires=` line to
  # the next un-indented `fi` (which closes the outer if-SECTXT block). Then
  # strip the trailing un-indented `fi` line because the standalone harness
  # has no outer `if`.
  sed -n '/expires=.*SECTXT.*Expires:/,/^fi[[:space:]]*$/p' "$REPORTING_MD" \
    | sed '/^fi[[:space:]]*$/d' > "$harness"

  # Sanity: harness must have content, else the test is vacuous
  [ -s "$harness" ] || { rm -f "$harness" "$sentinel"; echo "harness extraction produced no content" >&2; return 1; }

  bash "$harness" >/dev/null 2>&1 || true

  local verdict=0
  if [ -e "$sentinel" ]; then
    echo "RCE detected: $sentinel was created by the python3 -c invocation" >&2
    verdict=1
  fi
  rm -f "$sentinel" "$harness"
  [ "$verdict" -eq 0 ]
}
