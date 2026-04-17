---
name: chk2:headers
description: "Test HTTP security headers"
allowed-tools: Read, Bash(curl *), Bash(echo *), Write
---

# chk2:headers — HTTP Security Headers

Test HTTP security headers on https://myzr.io. Append results to `SECURITY_CHECK.md`.

## Tests

Run these commands and evaluate results:

```bash
# Full response headers
curl -sI "https://myzr.io/" -H "User-Agent: Mozilla/5.0"

# HTTP redirect check
curl -sI "http://myzr.io/" | head -5
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| H1 | HTTPS redirect | `http://myzr.io/` returns 301 or 302 with `Location: https://` |
| H2 | HSTS present | `strict-transport-security` header exists |
| H3 | HSTS max-age | max-age >= 31536000 (1 year) |
| H4 | HSTS includeSubDomains | `includeSubDomains` directive present |
| H5 | HSTS preload | `preload` directive present |
| H6 | X-Frame-Options | `DENY` or `SAMEORIGIN` |
| H7 | X-Content-Type-Options | `nosniff` |
| H8 | Referrer-Policy | `no-referrer` or `strict-origin-when-cross-origin` or `same-origin` |
| H9 | Content-Security-Policy | CSP header present |
| H10 | CSP no unsafe-inline scripts | `script-src` does not contain `'unsafe-inline'` |
| H11 | CSP no unsafe-eval | `script-src` does not contain `'unsafe-eval'` |
| H12 | No server version leak | `server` header does not include version numbers |
| H13 | No X-Powered-By | `x-powered-by` header absent |
| H14 | CORS not wildcard | `access-control-allow-origin` is NOT `*` |

## Output

Write to `SECURITY_CHECK.parts/headers.md`:

```markdown
### Headers

| # | Test | Result | Evidence |
|---|------|--------|----------|
| H1 | HTTPS redirect | {PASS/FAIL} | {status code and location} |
...
```

## After

Ask the user: **Do you want help fixing the header issues found?** If yes, invoke `/chk2:fix` with context about which header tests failed.

## Status signal

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
