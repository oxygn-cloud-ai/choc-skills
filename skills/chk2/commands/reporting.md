---
name: chk2:reporting
description: "Test security reporting configuration"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Write
---

# chk2:reporting — Security Reporting Headers

Test for security reporting configuration on https://myzr.io. Append results to `SECURITY_CHECK.md`.

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
  echo "=== Expires field check ==="
  expires=$(echo "$SECTXT" | grep -i "^Expires:" | head -1)
  if [ -n "$expires" ]; then
    echo "Expires field: $expires"
    exp_date=$(echo "$expires" | sed 's/^Expires:[[:space:]]*//')
    python3 -c "
from datetime import datetime, timezone
try:
    exp = datetime.fromisoformat('$exp_date'.replace('Z', '+00:00'))
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

Append to `SECURITY_CHECK.md`:

```markdown
### Reporting

| # | Test | Result | Evidence |
|---|------|--------|----------|
| RC1 | Report-To header | {PASS/WARN} | {header value or absent} |
| RC2 | NEL header | {PASS/WARN} | {header value or absent} |
| RC3 | security.txt PGP signed | {PASS/WARN} | {whether PGP block found or no security.txt} |
| RC4 | security.txt Expires valid | {PASS/WARN} | {Expires value and validity} |
```

## After

Ask the user: **Do you want help fixing the reporting issues found?** If yes, invoke `/chk2:fix` with context about which reporting tests failed.
