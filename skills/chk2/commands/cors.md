---
name: chk2:cors
description: "Test CORS policy and WebSocket origin validation"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Write
---

# chk2:cors — CORS and Origin Validation

Test CORS policy and WebSocket origin validation on https://myzr.io. Write results to `SECURITY_CHECK.parts/cors.md` (see **Output** for format).

## Tests

```bash
# CORS headers on normal request
curl -sI "https://myzr.io/" -H "User-Agent: Mozilla/5.0" | grep -i access-control

# CORS headers on API
curl -sI "https://myzr.io/api" -X POST -H "Content-Type: application/json" -d '{"action":"health"}' -H "User-Agent: Mozilla/5.0" | grep -i access-control

# Preflight with evil origin
curl -sI "https://myzr.io/api" -X OPTIONS -H "Origin: https://evil.com" -H "Access-Control-Request-Method: POST" -H "User-Agent: Mozilla/5.0"

# Preflight with correct origin
curl -sI "https://myzr.io/api" -X OPTIONS -H "Origin: https://myzr.io" -H "Access-Control-Request-Method: POST" -H "User-Agent: Mozilla/5.0"

# Vary header includes Origin
curl -sI "https://myzr.io/" -H "User-Agent: Mozilla/5.0" | grep -i vary
```

Then use python3 for WebSocket origin testing:
```python
import asyncio, websockets, json
from urllib.request import Request, urlopen

async def test():
    # Create session
    req = Request('https://myzr.io/api', data=json.dumps({'action':'new-game'}).encode(),
                  headers={'Content-Type':'application/json','User-Agent':'Mozilla/5.0'})
    resp = json.loads(urlopen(req).read())
    sid = resp['sessionId']

    # Evil origin
    try:
        async with websockets.connect(f'wss://myzr.io/ws/{sid}', origin='https://evil.com') as ws:
            await asyncio.wait_for(ws.recv(), timeout=3)
            print('FAIL: evil origin connected')
    except:
        print('PASS: evil origin blocked')

    # Correct origin
    try:
        async with websockets.connect(f'wss://myzr.io/ws/{sid}', origin='https://myzr.io') as ws:
            msg = await asyncio.wait_for(ws.recv(), timeout=3)
            print(f'PASS: correct origin connected ({len(msg)} bytes)')
    except Exception as e:
        print(f'FAIL: correct origin rejected: {e}')

    # No origin header
    try:
        async with websockets.connect(f'wss://myzr.io/ws/{sid}') as ws:
            msg = await asyncio.wait_for(ws.recv(), timeout=3)
            print(f'WARN: no-origin connected ({len(msg)} bytes)')
    except:
        print('PASS: no-origin blocked')

asyncio.run(test())
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| C1 | CORS not wildcard | `access-control-allow-origin` is NOT `*` |
| C2 | CORS specific origin | Header is `https://myzr.io` |
| C3 | Vary includes Origin | `Vary` header contains `Origin` |
| C4 | Preflight rejects evil origin | OPTIONS with `Origin: evil.com` does not return `access-control-allow-origin: evil.com` |
| C5 | Preflight accepts correct origin | OPTIONS with `Origin: myzr.io` returns proper CORS headers |
| C6 | WS rejects evil origin | WebSocket upgrade from `evil.com` returns 403 |
| C7 | WS accepts correct origin | WebSocket from `myzr.io` connects and receives state |
| C8 | WS rejects no-origin | WebSocket with no Origin header is blocked (WARN if allowed) |

## Output

Write to `SECURITY_CHECK.parts/cors.md`:

```markdown
### CORS

| # | Test | Result | Evidence |
|---|------|--------|----------|
| C1 | CORS not wildcard | {PASS/FAIL} | {header value} |
...
```

## After — standalone only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` exists** (orchestrator dispatch). The orchestrator (`/chk2:all` / `/chk2:quick`) asks the user a single consolidated question after all waves complete — a per-category prompt from every sub-skill would pre-empt the CHK2-STATUS line and break the rate-limit circuit breaker.

Ask the user: **Do you want help fixing the CORS issues found?** If yes, invoke `/chk2:fix` with context about which CORS tests failed.

**Standalone merge** (CPT-126): check if `SECURITY_CHECK.parts/.orchestrated` exists. If it does NOT (standalone invocation, not dispatched by `/chk2:all` / `/chk2:quick`), also write the same content to `SECURITY_CHECK.md` using the Write tool so downstream `/chk2:fix` and `/chk2 github` can read it. If the marker IS present, skip this step — the orchestrator will merge all parts after its waves complete.

## Status signal — orchestrated only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` does NOT exist** (standalone invocation). The CHK2-STATUS protocol is parsed only by the `/chk2:all` and `/chk2:quick` orchestrators — emitting it in standalone mode is noise. When the marker IS present, emit the line as the absolute final line of your response (no trailing prose).

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
