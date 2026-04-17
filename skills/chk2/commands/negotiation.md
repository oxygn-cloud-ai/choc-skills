---
name: chk2:negotiation
description: "Test content negotiation security"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Write
---

# chk2:negotiation — Content Negotiation

Test content negotiation security on https://${TARGET:-myzr.io}. Append results to `SECURITY_CHECK.md`.

## Tests

```bash
# CN1: Content-Type mismatch — send various Accept headers to API
curl -sI "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"health"}' -H "Accept: text/html" -H "User-Agent: Mozilla/5.0" | grep -i content-type
curl -sI "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"health"}' -H "Accept: application/xml" -H "User-Agent: Mozilla/5.0" | grep -i content-type
curl -sI "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"health"}' -H "Accept: text/plain" -H "User-Agent: Mozilla/5.0" | grep -i content-type
curl -sI "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"health"}' -H "Accept: */*" -H "User-Agent: Mozilla/5.0" | grep -i content-type

# CN2: Polyglot file upload — attempt upload of GIF/JS polyglot to /upload
python3 -c "
import sys
# GIF89a header followed by JS payload
polyglot = b'GIF89a/*\x00\x00\x00\x00*/=1;alert(1);//'
sys.stdout.buffer.write(polyglot)
" > /tmp/polyglot.gif
curl -s -o /dev/null -w "%{http_code}" "https://${TARGET:-myzr.io}/upload" -X POST -F "file=@/tmp/polyglot.gif;type=image/gif" -H "User-Agent: Mozilla/5.0"
curl -s -o /dev/null -w "%{http_code}" "https://${TARGET:-myzr.io}/upload" -X POST -F "file=@/tmp/polyglot.gif;filename=polyglot.gif;type=text/javascript" -H "User-Agent: Mozilla/5.0"
rm -f /tmp/polyglot.gif

# CN3: Error response Content-Type — trigger errors and check Content-Type
curl -sI "https://${TARGET:-myzr.io}/nonexistent-path" -H "User-Agent: Mozilla/5.0" | grep -iE "content-type|content-security-policy"
curl -sI "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d "{invalid" -H "User-Agent: Mozilla/5.0" | grep -iE "content-type|content-security-policy"
curl -sI "https://${TARGET:-myzr.io}/api" -X DELETE -H "User-Agent: Mozilla/5.0" | grep -iE "content-type|content-security-policy"
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| CN1 | Content-Type mismatch | API consistently returns `application/json` regardless of Accept header. PASS if Content-Type stays `application/json`. FAIL if it mirrors the Accept header |
| CN2 | Polyglot file upload | Upload is rejected (4xx), served with safe Content-Type and `X-Content-Type-Options: nosniff`, or endpoint returns 404. PASS if rejected or safe. FAIL if served as `text/javascript` or without nosniff |
| CN3 | Error response Content-Type | Error responses have explicit Content-Type (`application/json` or `text/html`). If HTML, CSP header should be present. PASS if explicit type with protections. WARN if missing Content-Type or CSP on HTML errors |

## Output

Write to `SECURITY_CHECK.parts/negotiation.md`:

```markdown
### Negotiation

| # | Test | Result | Evidence |
|---|------|--------|----------|
| CN1 | Content-Type mismatch | {PASS/FAIL} | {Content-Type values for each Accept header} |
| CN2 | Polyglot file upload | {PASS/FAIL} | {HTTP status codes and Content-Type if served} |
| CN3 | Error response Content-Type | {PASS/WARN} | {Content-Type and CSP values on error responses} |
...
```

## After

Ask the user: **Do you want help fixing the content negotiation issues found?** If yes, invoke `/chk2:fix` with context about which negotiation tests failed.
