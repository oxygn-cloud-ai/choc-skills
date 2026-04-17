---
name: chk2:cookies
description: "Test cookie security flags"
allowed-tools: Read, Bash(curl *), Bash(echo *), Write
---

# chk2:cookies — Cookie Security

Test cookie security on https://${TARGET:-myzr.io}. Write results to `SECURITY_CHECK.parts/cookies.md` (see **Output** for format).

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

Write to `SECURITY_CHECK.parts/cookies.md`:

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

## After — standalone only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` exists** (orchestrator dispatch). The orchestrator (`/chk2:all` / `/chk2:quick`) asks the user a single consolidated question after all waves complete — a per-category prompt from every sub-skill would pre-empt the CHK2-STATUS line and break the rate-limit circuit breaker.

Ask the user: **Do you want help fixing the cookie issues found?** If yes, invoke `/chk2:fix` with context about which cookie tests failed.

**Standalone merge** (CPT-126): check if `SECURITY_CHECK.parts/.orchestrated` exists. If it does NOT (standalone invocation, not dispatched by `/chk2:all` / `/chk2:quick`), also write the same content to `SECURITY_CHECK.md` using the Write tool so downstream `/chk2:fix` and `/chk2 github` can read it. If the marker IS present, skip this step — the orchestrator will merge all parts after its waves complete.

## Status signal — orchestrated only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` does NOT exist** (standalone invocation). The CHK2-STATUS protocol is parsed only by the `/chk2:all` and `/chk2:quick` orchestrators — emitting it in standalone mode is noise. When the marker IS present, emit the line as the absolute final line of your response (no trailing prose).

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
