# chk2:cors — CORS and Origin Validation

Test CORS policy and WebSocket origin validation on https://myzr.io. Append results to `SECURITY_CHECK.md`.

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

Append to `SECURITY_CHECK.md`:

```markdown
### CORS

| # | Test | Result | Evidence |
|---|------|--------|----------|
| C1 | CORS not wildcard | {PASS/FAIL} | {header value} |
...
```

## After

**Skip this section when invoked from `/chk2:all` (batch mode).** Only ask when run as a standalone category check.

Ask the user: **Do you want help fixing the CORS issues found?** If yes, invoke `/chk2:fix` with context about which CORS tests failed.
