---
name: chk2:business
description: "Test business logic security"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Write
---

# chk2:business — Business Logic

Test business logic security on https://${TARGET:-myzr.io}. Write results to `SECURITY_CHECK.parts/business.md` (see **Output** for format).

## Tests

```bash
# BL1: Replay attack — capture a valid game-action response, replay exact same request
SESSION=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sessionId',''))" 2>/dev/null)
# Perform an action
RESP1=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d "{\"action\":\"poll\",\"sessionId\":\"$SESSION\"}" -H "User-Agent: Mozilla/5.0")
# Replay the exact same request
RESP2=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d "{\"action\":\"poll\",\"sessionId\":\"$SESSION\"}" -H "User-Agent: Mozilla/5.0")
echo "First:  $RESP1"
echo "Replay: $RESP2"

# BL2: Cross-session state leakage — create 2 sessions, check isolation
SESSION_A=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sessionId',''))" 2>/dev/null)
SESSION_B=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sessionId',''))" 2>/dev/null)
# Poll session A
STATE_A=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d "{\"action\":\"poll\",\"sessionId\":\"$SESSION_A\"}" -H "User-Agent: Mozilla/5.0")
# Poll session B — check it doesn't contain session A's data
STATE_B=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d "{\"action\":\"poll\",\"sessionId\":\"$SESSION_B\"}" -H "User-Agent: Mozilla/5.0")
echo "Session A ID: $SESSION_A"
echo "Session B ID: $SESSION_B"
echo "State A: $STATE_A"
echo "State B: $STATE_B"
```

```python
import json, urllib.request, concurrent.futures

TARGET = "myzr.io"

# BL3: Concurrent rate limit bypass — burst from multiple "identities"
user_agents = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
    "Mozilla/5.0 (X11; Linux x86_64)",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)",
    "curl/7.88.1",
]

def create_session(ua):
    req = urllib.request.Request(
        f"https://{TARGET}/api",
        data=json.dumps({"action": "new-game"}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": ua},
    )
    try:
        resp = urllib.request.urlopen(req, timeout=10)
        return resp.status, ua
    except urllib.error.HTTPError as e:
        return e.code, ua

results = []
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
    # Send 5 concurrent requests with different UAs
    futures = [pool.submit(create_session, ua) for ua in user_agents]
    for f in concurrent.futures.as_completed(futures):
        code, ua = f.result()
        results.append((code, ua))
        print(f"  Status {code} — UA: {ua[:40]}")

rate_limited = [r for r in results if r[0] == 429]
print(f"\nRate limited: {len(rate_limited)}/{len(results)}")
if len(rate_limited) == 0:
    print("WARN: No rate limiting observed across different UAs")

# BL4: Predictable resource IDs — create 5 sessions, check for patterns
session_ids = []
for i in range(5):
    req = urllib.request.Request(
        f"https://{TARGET}/api",
        data=json.dumps({"action": "new-game"}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"},
    )
    try:
        resp = json.loads(urllib.request.urlopen(req, timeout=10).read())
        sid = resp.get("sessionId", "")
        session_ids.append(sid)
        print(f"  Session {i+1}: {sid}")
    except Exception as e:
        print(f"  Session {i+1}: ERROR — {e}")

# Check for sequential patterns
if len(session_ids) >= 2:
    lengths = set(len(s) for s in session_ids)
    print(f"\nLengths: {lengths}")
    # Check if IDs are sequential (try int and hex)
    try:
        nums = [int(s, 16) for s in session_ids]
        diffs = [nums[i+1] - nums[i] for i in range(len(nums)-1)]
        print(f"Hex diffs: {diffs}")
        if all(d == diffs[0] for d in diffs) and diffs[0] < 1000:
            print("FAIL: Session IDs appear sequential")
        else:
            print("PASS: Session IDs appear random")
    except ValueError:
        # Not hex, check string similarity
        common_prefix = len(session_ids[0])
        for s in session_ids[1:]:
            cp = 0
            for a, b in zip(session_ids[0], s):
                if a == b:
                    cp += 1
                else:
                    break
            common_prefix = min(common_prefix, cp)
        print(f"Common prefix length: {common_prefix}/{len(session_ids[0])}")
        if common_prefix > len(session_ids[0]) * 0.8:
            print("WARN: Session IDs share long common prefix")
        else:
            print("PASS: Session IDs appear random")
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| BL1 | Replay attack | Replayed request is handled safely — either idempotent (same response) or rejected with an error. PASS if safe. FAIL if replay causes duplicate state changes or unintended side effects |
| BL2 | Cross-session state leakage | Session B state does NOT contain Session A's session ID, pair code, or player-specific data. PASS if sessions are fully isolated |
| BL3 | Concurrent rate limit bypass | Rate limiting applies regardless of User-Agent. WARN if rate limit is per-UA only (all different UAs succeed while same UA gets blocked) |
| BL4 | Predictable resource IDs | Session IDs are not sequential or predictable. PASS if IDs appear random with no discernible pattern. FAIL if sequential or short common prefix |

## Output

Write to `SECURITY_CHECK.parts/business.md`:

```markdown
### Business Logic

| # | Test | Result | Evidence |
|---|------|--------|----------|
| BL1 | Replay attack | {PASS/FAIL} | {replay behavior observed} |
| BL2 | Cross-session state leakage | {PASS/FAIL} | {whether session data leaked} |
| BL3 | Concurrent rate limit bypass | {PASS/WARN} | {rate limit results per UA} |
| BL4 | Predictable resource IDs | {PASS/FAIL} | {session ID pattern analysis} |
...
```

## After

Ask the user: **Do you want help fixing the business logic issues found?** If yes, invoke `/chk2:fix` with context about which business logic tests failed.

## Status signal

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
