---
name: chk2:transport
description: "Test transport layer: HTTP/2, ALPN, Content-Type"
allowed-tools: Read, Bash(curl *), Bash(openssl *), Bash(echo *), Write
---

# chk2:transport — Transport Layer Security

Test transport layer configuration on https://${TARGET:-myzr.io}. Write results to `SECURITY_CHECK.parts/transport.md` (see **Output** for format).

## Tests

```bash
# TR1: HTTP/2 support
curl -sI --http2 "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" | head -1

# TR2: ALPN h2 negotiation
echo | openssl s_client -connect ${TARGET:-myzr.io}:443 -servername ${TARGET:-myzr.io} -alpn h2 2>/dev/null | grep -i "ALPN"

# TR3: HTTP/1.0 handling
curl -sI --http1.0 "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" | head -5

# TR4: Content-Type enforcement — send text/plain to JSON API
curl -s "https://${TARGET:-myzr.io}/api" -X POST \
  -H "Content-Type: text/plain" \
  -d '{"action":"health"}' \
  -H "User-Agent: Mozilla/5.0"

# TR5: Content-Length validation — wrong Content-Length
curl -s "https://${TARGET:-myzr.io}/api" -X POST \
  -H "Content-Type: application/json" \
  -H "Content-Length: 999" \
  -d '{"action":"health"}' \
  -H "User-Agent: Mozilla/5.0"
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| TR1 | HTTP/2 support | Response starts with `HTTP/2`. WARN if only HTTP/1.1 |
| TR2 | ALPN h2 negotiation | openssl reports `ALPN protocol: h2`. PASS if h2 negotiated |
| TR3 | No HTTP/1.0 issues | `curl --http1.0` returns a proper response (not a crash or hang) |
| TR4 | Content-Type enforcement | Sending `text/plain` to JSON API returns 415 Unsupported Media Type or a JSON error. PASS if rejected or handled gracefully |
| TR5 | Content-Length validation | Wrong `Content-Length` returns an error or the server handles it safely. PASS if error returned |

## Output

Write to `SECURITY_CHECK.parts/transport.md`:

```markdown
### Transport

| # | Test | Result | Evidence |
|---|------|--------|----------|
| TR1 | HTTP/2 support | {PASS/WARN} | {protocol in response line} |
| TR2 | ALPN h2 negotiation | {PASS/FAIL} | {ALPN result} |
| TR3 | No HTTP/1.0 issues | {PASS/FAIL} | {response status} |
| TR4 | Content-Type enforcement | {PASS/FAIL} | {response to text/plain} |
| TR5 | Content-Length validation | {PASS/FAIL} | {response to wrong CL} |
...
```

## After

Ask the user: **Do you want help fixing the transport issues found?** If yes, invoke `/chk2:fix` with context about which transport tests failed.

**Standalone merge** (CPT-126): check if `SECURITY_CHECK.parts/.orchestrated` exists. If it does NOT (standalone invocation, not dispatched by `/chk2:all` / `/chk2:quick`), also write the same content to `SECURITY_CHECK.md` using the Write tool so downstream `/chk2:fix` and `/chk2 github` can read it. If the marker IS present, skip this step — the orchestrator will merge all parts after its waves complete.

## Status signal

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
