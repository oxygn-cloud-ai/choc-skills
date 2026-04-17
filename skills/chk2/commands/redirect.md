---
name: chk2:redirect
description: "Test open redirect and redirect chain security"
allowed-tools: Read, Bash(curl *), Bash(echo *), Write
---

# chk2:redirect — Open Redirect and Redirect Chain Security

Test redirect security on https://${TARGET:-myzr.io}. Append results to `SECURITY_CHECK.md`.

## Tests

```bash
# RD1: Open redirect — common parameter names with evil destinations
curl -sI "https://${TARGET:-myzr.io}/?url=https://evil.com" -H "User-Agent: Mozilla/5.0" | grep -iE "location|HTTP/"
curl -sI "https://${TARGET:-myzr.io}/?next=//evil.com" -H "User-Agent: Mozilla/5.0" | grep -iE "location|HTTP/"
curl -sI "https://${TARGET:-myzr.io}/?redirect=//evil.com" -H "User-Agent: Mozilla/5.0" | grep -iE "location|HTTP/"
curl -sI "https://${TARGET:-myzr.io}/?return=https://evil.com" -H "User-Agent: Mozilla/5.0" | grep -iE "location|HTTP/"
curl -sI "https://${TARGET:-myzr.io}/?goto=https://evil.com" -H "User-Agent: Mozilla/5.0" | grep -iE "location|HTTP/"

# RD2: Host header redirect — inject evil.com as Host
curl -sI "https://${TARGET:-myzr.io}/" -H "Host: evil.com" -H "User-Agent: Mozilla/5.0" | grep -iE "location|HTTP/"

# RD3: X-Forwarded-Host redirect
curl -sI "https://${TARGET:-myzr.io}/" -H "X-Forwarded-Host: evil.com" -H "User-Agent: Mozilla/5.0" | grep -iE "location|HTTP/"

# RD4: Redirect chain — check HTTP to HTTPS is clean single redirect
curl -sIL "http://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" | grep -iE "HTTP/|location"
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| RD1 | No open redirect | None of `?url=`, `?next=`, `?redirect=`, `?return=`, `?goto=` with evil.com produce a `Location` header pointing to evil.com |
| RD2 | Host header redirect | `Host: evil.com` does not cause a redirect to evil.com |
| RD3 | X-Forwarded-Host | `X-Forwarded-Host: evil.com` does not cause a redirect to evil.com |
| RD4 | Redirect chain | `http://${TARGET:-myzr.io}/` redirects directly to `https://${TARGET:-myzr.io}/` in a single hop (no intermediate redirects) |

## Output

Write to `SECURITY_CHECK.parts/redirect.md`:

```markdown
### Redirect

| # | Test | Result | Evidence |
|---|------|--------|----------|
| RD1 | No open redirect | {PASS/FAIL} | {Location headers returned} |
| RD2 | Host header redirect | {PASS/FAIL} | {Location header if any} |
| RD3 | X-Forwarded-Host | {PASS/FAIL} | {Location header if any} |
| RD4 | Redirect chain | {PASS/FAIL} | {redirect hops observed} |
...
```

## After

Ask the user: **Do you want help fixing the redirect issues found?** If yes, invoke `/chk2:fix` with context about which redirect tests failed.

## Status signal

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
