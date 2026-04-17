---
name: chk2:hardening
description: "Test server hardening"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Write
---

# chk2:hardening — Server Hardening

Test server hardening on https://${TARGET:-myzr.io}. Write results to `SECURITY_CHECK.parts/hardening.md` (see **Output** for format).

## Tests

```bash
# SH1: ETag inode leak — Apache-style ETag exposes inode-size-timestamp
curl -sI "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" | grep -i etag

# SH2: Accept-Ranges abuse — send 10 overlapping byte ranges in one request
curl -sI "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" -H "Range: bytes=0-50, 40-90, 80-130, 120-170, 160-210, 200-250, 240-290, 280-330, 320-370, 360-410" -o /dev/null -w "%{http_code}"

# SH3: Request header size limit — send ~64KB header
curl -sI "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" -H "X-Overflow: $(python3 -c "print('A'*65000)")" -o /dev/null -w "%{http_code}"

# SH4: HTTP trailer injection — chunked request with Trailer header
curl -s "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" -H "Transfer-Encoding: chunked" -H "Trailer: X-Injected" --data-raw $'5\r\nhello\r\n0\r\nX-Injected: evil-value\r\n\r\n' -D - -o /dev/null 2>&1 | grep -i x-injected

# SH5: CRLF response header injection — %0d%0a in URL path and query
curl -sI "https://${TARGET:-myzr.io}/%0d%0aX-Injected:%20evil" -H "User-Agent: Mozilla/5.0"
curl -sI "https://${TARGET:-myzr.io}/?param=%0d%0aX-Injected:%20evil" -H "User-Agent: Mozilla/5.0"
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| SH1 | ETag inode leak | ETag does NOT match Apache inode format `"hex-hex-hex"` (three hex segments separated by dashes). FAIL if inode pattern detected |
| SH2 | Accept-Ranges abuse | Server does NOT honor all 10 overlapping ranges as 206 multipart response. WARN if all honored as 206 |
| SH3 | Request header size limit | Server returns 431 (Request Header Fields Too Large) or 400. PASS if rejected. FAIL if 200 |
| SH4 | HTTP trailer injection | Response does NOT contain `X-Injected` header. PASS if trailer ignored or stripped |
| SH5 | CRLF response header injection | Response does NOT contain `X-Injected` header from either path or query injection. PASS if CRLF sequences are sanitized |

## Output

Write to `SECURITY_CHECK.parts/hardening.md`:

```markdown
### Hardening

| # | Test | Result | Evidence |
|---|------|--------|----------|
| SH1 | ETag inode leak | {PASS/FAIL} | {ETag value or "not present"} |
| SH2 | Accept-Ranges abuse | {PASS/WARN} | {HTTP status code returned} |
| SH3 | Request header size limit | {PASS/FAIL} | {HTTP status code returned} |
| SH4 | HTTP trailer injection | {PASS/FAIL} | {whether X-Injected header appeared} |
| SH5 | CRLF header injection | {PASS/FAIL} | {whether injected header appeared in path or query test} |
...
```

## After

Ask the user: **Do you want help fixing the hardening issues found?** If yes, invoke `/chk2:fix` with context about which hardening tests failed.

**Standalone merge** (CPT-126): check if `SECURITY_CHECK.parts/.orchestrated` exists. If it does NOT (standalone invocation, not dispatched by `/chk2:all` / `/chk2:quick`), also write the same content to `SECURITY_CHECK.md` using the Write tool so downstream `/chk2:fix` and `/chk2 github` can read it. If the marker IS present, skip this step — the orchestrator will merge all parts after its waves complete.

## Status signal

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
