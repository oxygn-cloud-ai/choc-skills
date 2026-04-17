---
name: chk2:smuggling
description: "Test HTTP request smuggling defenses"
allowed-tools: Read, Bash(curl *), Bash(echo *), Write
---

# chk2:smuggling — HTTP Request Smuggling

Test HTTP request smuggling defenses on https://${TARGET:-myzr.io}. Write results to `SECURITY_CHECK.parts/smuggling.md` (see **Output** for format).

## Tests

```bash
# SM1: CL.TE desync — conflicting Content-Length and Transfer-Encoding
curl -s -o /dev/null -w "%{http_code}" "https://${TARGET:-myzr.io}/" \
  -X POST \
  -H "Content-Length: 6" \
  -H "Transfer-Encoding: chunked" \
  -H "User-Agent: Mozilla/5.0" \
  -d $'0\r\n\r\nG'

# SM2: TE.CL desync — reverse direction
curl -s -o /dev/null -w "%{http_code}" "https://${TARGET:-myzr.io}/" \
  -X POST \
  -H "Transfer-Encoding: chunked" \
  -H "Content-Length: 3" \
  -H "User-Agent: Mozilla/5.0" \
  -d $'1\r\nA\r\n0\r\n\r\n'

# SM3: Duplicate Content-Length headers
curl -s -o /dev/null -w "%{http_code}" "https://${TARGET:-myzr.io}/" \
  -X POST \
  -H "Content-Length: 5" \
  -H "Content-Length: 10" \
  -H "User-Agent: Mozilla/5.0" \
  -d "hello"

# SM4: HTTP/2 downgrade with smuggling payload
curl -s -o /dev/null -w "%{http_code}" --http2 "https://${TARGET:-myzr.io}/" \
  -X POST \
  -H "Transfer-Encoding: chunked" \
  -H "User-Agent: Mozilla/5.0" \
  -d $'0\r\n\r\nGET /admin HTTP/1.1\r\nHost: ${TARGET:-myzr.io}\r\n\r\n'
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| SM1 | CL.TE desync | Server returns 400 Bad Request or rejects the ambiguous request |
| SM2 | TE.CL desync | Server returns 400 Bad Request or rejects the ambiguous request |
| SM3 | Duplicate Content-Length | Server returns 400 Bad Request when given two conflicting CL headers |
| SM4 | HTTP/2 downgrade safe | curl --http2 with smuggling payload is rejected or returns 400 |

## Output

Write to `SECURITY_CHECK.parts/smuggling.md`:

```markdown
### Smuggling

| # | Test | Result | Evidence |
|---|------|--------|----------|
| SM1 | CL.TE desync | {PASS/FAIL} | {HTTP status code returned} |
| SM2 | TE.CL desync | {PASS/FAIL} | {HTTP status code returned} |
| SM3 | Duplicate Content-Length | {PASS/FAIL} | {HTTP status code returned} |
| SM4 | HTTP/2 downgrade safe | {PASS/FAIL} | {HTTP status code returned} |
...
```

## After — standalone only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` exists** (orchestrator dispatch). The orchestrator (`/chk2:all` / `/chk2:quick`) asks the user a single consolidated question after all waves complete — a per-category prompt from every sub-skill would pre-empt the CHK2-STATUS line and break the rate-limit circuit breaker.

Ask the user: **Do you want help fixing the smuggling issues found?** If yes, invoke `/chk2:fix` with context about which smuggling tests failed.

**Standalone merge** (CPT-126): check if `SECURITY_CHECK.parts/.orchestrated` exists. If it does NOT (standalone invocation, not dispatched by `/chk2:all` / `/chk2:quick`), also write the same content to `SECURITY_CHECK.md` using the Write tool so downstream `/chk2:fix` and `/chk2 github` can read it. If the marker IS present, skip this step — the orchestrator will merge all parts after its waves complete.

## Status signal — orchestrated only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` does NOT exist** (standalone invocation). The CHK2-STATUS protocol is parsed only by the `/chk2:all` and `/chk2:quick` orchestrators — emitting it in standalone mode is noise. When the marker IS present, emit the line as the absolute final line of your response (no trailing prose).

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
