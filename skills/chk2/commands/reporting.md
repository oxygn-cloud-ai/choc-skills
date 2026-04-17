---
name: chk2:reporting
description: "Test security reporting configuration"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Bash(printf *), Write
---

# chk2:reporting — Security Reporting Headers

Test for security reporting configuration on https://myzr.io. Write results to `SECURITY_CHECK.parts/reporting.md` (see **Output** for format).

## Tests

```bash
# RC1: Report-To header
curl -sI "https://myzr.io/" -H "User-Agent: Mozilla/5.0" | grep -iE "^(report-to|reporting-endpoints):"

# RC2: NEL header
curl -sI "https://myzr.io/" -H "User-Agent: Mozilla/5.0" | grep -i "^nel:"
```

```bash
# RC3 + RC4: security.txt — fetch once, check both PGP signature and Expires
SECTXT=""
SECTXT_PATH=""
for path in /.well-known/security.txt /security.txt; do
  content=$(curl -s "https://myzr.io$path" -H "User-Agent: Mozilla/5.0" -w "\nHTTP_STATUS:%{http_code}")
  status=$(echo "$content" | grep "HTTP_STATUS:" | cut -d: -f2)
  body=$(echo "$content" | sed '/HTTP_STATUS:/d')
  if [ "$status" = "200" ]; then
    SECTXT="$body"
    SECTXT_PATH="$path"
    echo "Found security.txt at $path"
    echo "$body"
    break
  fi
done

if [ -z "$SECTXT" ]; then
  echo "No security.txt found"
else
  # RC3: PGP signature check
  echo "=== PGP signature check ==="
  echo "$SECTXT" | grep -c "BEGIN PGP SIGNATURE" || echo "No PGP signature block"

  # RC4: Expires field check (reuses SECTXT from RC3 — no extra curl)
  # CPT-101: the raw Expires value is attacker-controlled (security.txt body),
  # so it MUST be delivered to python as stdin data, not interpolated into
  # the -c source. The previous `'$exp_date'` interpolation allowed a hostile
  # target to break out of the Python string literal and execute arbitrary
  # code on the auditor's workstation.
  echo "=== Expires field check ==="
  expires=$(echo "$SECTXT" | grep -i "^Expires:" | head -1)
  if [ -n "$expires" ]; then
    echo "Expires field: $expires"
    exp_date=$(echo "$expires" | sed 's/^Expires:[[:space:]]*//')
    printf '%s' "$exp_date" | python3 -c "
import sys
from datetime import datetime, timezone
raw = sys.stdin.read().strip()
try:
    exp = datetime.fromisoformat(raw.replace('Z', '+00:00'))
    now = datetime.now(timezone.utc)
    if exp < now:
        print(f'EXPIRED: {exp} is in the past')
    else:
        print(f'VALID: expires {exp}')
except Exception as e:
    print(f'PARSE ERROR: {e}')
"
  else
    echo "No Expires field found"
  fi
fi
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| RC1 | Report-To header | `Report-To` or `Reporting-Endpoints` header is present (WARN if absent) |
| RC2 | NEL header | `NEL` (Network Error Logging) header is present (WARN if absent) |
| RC3 | security.txt PGP signed | security.txt contains `BEGIN PGP SIGNATURE` block (WARN if unsigned or no security.txt) |
| RC4 | security.txt Expires valid | `Expires` field is present and date is in the future (WARN if expired or missing) |

## Output

Write to `SECURITY_CHECK.parts/reporting.md`:

```markdown
### Reporting

| # | Test | Result | Evidence |
|---|------|--------|----------|
| RC1 | Report-To header | {PASS/WARN} | {header value or absent} |
| RC2 | NEL header | {PASS/WARN} | {header value or absent} |
| RC3 | security.txt PGP signed | {PASS/WARN} | {whether PGP block found or no security.txt} |
| RC4 | security.txt Expires valid | {PASS/WARN} | {Expires value and validity} |
```

## After — standalone only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` exists** (orchestrator dispatch). The orchestrator (`/chk2:all` / `/chk2:quick`) asks the user a single consolidated question after all waves complete — a per-category prompt from every sub-skill would pre-empt the CHK2-STATUS line and break the rate-limit circuit breaker.

Ask the user: **Do you want help fixing the reporting issues found?** If yes, invoke `/chk2:fix` with context about which reporting tests failed.

**Standalone merge** (CPT-126): check if `SECURITY_CHECK.parts/.orchestrated` exists. If it does NOT (standalone invocation, not dispatched by `/chk2:all` / `/chk2:quick`), also write the same content to `SECURITY_CHECK.md` using the Write tool so downstream `/chk2:fix` and `/chk2 github` can read it. If the marker IS present, skip this step — the orchestrator will merge all parts after its waves complete.

## Status signal — orchestrated only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` does NOT exist** (standalone invocation). The CHK2-STATUS protocol is parsed only by the `/chk2:all` and `/chk2:quick` orchestrators — emitting it in standalone mode is noise. When the marker IS present, emit the line as the absolute final line of your response (no trailing prose).

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
