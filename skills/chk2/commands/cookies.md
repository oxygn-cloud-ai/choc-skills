---
name: chk2:cookies
description: "Test cookie security flags"
allowed-tools: Read, Bash(curl *), Bash(echo *), Write
---

# chk2:cookies — Cookie Security

Test cookie security on https://${TARGET:-myzr.io}. Append results to `SECURITY_CHECK.md`.

## Tests

```bash
# Grab all Set-Cookie headers from main page
curl -sI "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" | grep -i set-cookie

# Grab Set-Cookie headers from API (create a session)
curl -sI "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | grep -i set-cookie

# Full verbose cookie inspection
curl -sv "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" 2>&1 | grep -i "set-cookie"

# Check cookie values for PII patterns
curl -sI "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" | grep -i set-cookie | grep -iE "@|email|user|name|{|}"

# Check Domain attribute scope
curl -sI "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" | grep -i set-cookie | grep -i "domain="
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| CK1 | HttpOnly on session cookies | Every `Set-Cookie` header includes `HttpOnly` flag |
| CK2 | Secure flag | Every `Set-Cookie` header includes `Secure` flag |
| CK3 | SameSite attribute | Every `Set-Cookie` header includes `SameSite`. WARN if `SameSite=None`, FAIL if absent |
| CK4 | No sensitive data in cookies | Cookie values do not contain JSON objects, email addresses, or PII patterns. WARN if found |
| CK5 | Cookie scope | `Domain` attribute is not overly broad (e.g., `Domain=.${TARGET:-myzr.io}` on non-auth cookies). WARN if broad |

## Output

Append to `SECURITY_CHECK.md`:

```markdown
### Cookies

| # | Test | Result | Evidence |
|---|------|--------|----------|
| CK1 | HttpOnly on session cookies | {PASS/FAIL} | {cookie names missing HttpOnly} |
| CK2 | Secure flag | {PASS/FAIL} | {cookie names missing Secure} |
| CK3 | SameSite attribute | {PASS/FAIL/WARN} | {SameSite values found} |
| CK4 | No sensitive data in cookies | {PASS/WARN} | {pattern matches if any} |
| CK5 | Cookie scope | {PASS/WARN} | {Domain values found} |
...
```

## After

Ask the user: **Do you want help fixing the cookie issues found?** If yes, invoke `/chk2:fix` with context about which cookie tests failed.
