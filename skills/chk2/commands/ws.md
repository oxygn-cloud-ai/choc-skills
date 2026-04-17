---
name: chk2:ws
description: "Test WebSocket security"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Write
---

# chk2:ws — WebSocket Security

Test WebSocket security on https://myzr.io. Append results to `SECURITY_CHECK.md`.

Requires python3 with `websockets` package. Create a fresh game session first via API.

If you hit rate limits (429 or 1015), wait 65 seconds before continuing.

## Tests

Use python3 with asyncio and websockets:

```python
import asyncio, websockets, json, time
from urllib.request import Request, urlopen

async def test():
    # Create session
    req = Request('https://myzr.io/api', data=json.dumps({'action':'new-game'}).encode(),
                  headers={'Content-Type':'application/json','User-Agent':'Mozilla/5.0'})
    resp = json.loads(urlopen(req).read())
    sid = resp['sessionId']

    # W1: Evil origin blocked
    # W2: Correct origin connects
    # W3: Max concurrent connections (try 10)
    # W4: Invalid JSON message handling
    # W5: Invalid message types (admin, eval, __proto__, constructor)
    # W6: Binary frame handling
    # W7: Rapid messages (50 messages)
    # W8: Oversized message (10KB — moderate)
    # W9: Empty message
    # W10: Bogus session ID rejected
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| W1 | Evil origin blocked | WS upgrade from `https://evil.com` returns 403 |
| W2 | Correct origin connects | WS from `https://myzr.io` connects and receives fullState |
| W3 | Connection limit | Server limits connections per session to <=5 (WARN if >5) |
| W4 | Invalid JSON handled | Server doesn't crash, connection stays alive |
| W5 | Invalid types handled | Unknown message types don't crash server (WARN if all silently accepted without disconnect) |
| W6 | Binary frames handled | Server handles gracefully (disconnect OK, crash not OK) |
| W7 | Rapid message handling | 50 messages don't crash server (WARN if no WS rate limiting) |
| W8 | Oversized message | 10KB message doesn't crash server (WARN if accepted without limit) |
| W9 | Empty message | Doesn't crash server |
| W10 | Bogus session rejected | WS upgrade to `/ws/fakesession` returns 404 |
| WD1 | Subprotocol abuse | Unknown subprotocols (mqtt, soap, admin, debug) are rejected on WS upgrade |
| WD2 | Post-revocation connection reuse | WS connection is terminated or re-validated after session invalidation |
| WD3 | Cross-protocol/h2c upgrade | h2c cleartext HTTP/2 upgrade via `Upgrade: h2c` header is rejected (not 101) |

### WD1-WD3 Additional Tests

```python
# WD1 — Subprotocol abuse
import asyncio, websockets
async def test_subprotocols():
    for proto in ['mqtt', 'soap', 'xmpp', 'binary', 'admin', 'debug']:
        try:
            ws = await websockets.connect(
                f'wss://myzr.io/ws/{sid}',
                subprotocols=[proto],
                extra_headers={'User-Agent': 'Mozilla/5.0'},
                open_timeout=5
            )
            print(f'{proto}: ACCEPTED (subprotocol={ws.subprotocol})')
            await ws.close()
        except Exception as e:
            print(f'{proto}: REJECTED ({type(e).__name__})')
asyncio.run(test_subprotocols())
```

```bash
# WD3 — h2c cleartext upgrade
curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/" \
  -H "Upgrade: h2c" \
  -H "Connection: Upgrade, HTTP2-Settings" \
  -H "HTTP2-Settings: AAMAAABkAAQCAAAAAAIAAAAA" \
  -H "User-Agent: Mozilla/5.0" --max-time 5
# PASS if NOT 101. FAIL if 101 (h2c upgrade accepted).
```

## Output

Write to `SECURITY_CHECK.parts/ws.md`:

```markdown
### WebSocket

| # | Test | Result | Evidence |
|---|------|--------|----------|
| W1 | Evil origin blocked | {PASS/FAIL} | {HTTP status on upgrade} |
...
```

## After

Ask the user: **Do you want help fixing the WebSocket issues found?** If yes, invoke `/chk2:fix` with context about which WS tests failed.
