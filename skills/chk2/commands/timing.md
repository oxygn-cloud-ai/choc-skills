---
name: chk2:timing
description: "Test timing attacks and race conditions"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Write
---

# chk2:timing — Timing Attacks and Race Conditions

Test for timing-based vulnerabilities on https://myzr.io. Write results to `SECURITY_CHECK.parts/timing.md` (see **Output** for format).

## Tests

```bash
# TM1: Constant-time session lookup — compare valid vs invalid session IDs
# First create a valid session
VALID_SID=$(curl -s "https://myzr.io/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sessionId',''))")

# Time 5 requests with valid session ID
echo "Valid session timings:"
for i in $(seq 1 5); do
  curl -s -o /dev/null -w "%{time_total}\n" "https://myzr.io/api" -X POST \
    -H "Content-Type: application/json" \
    -d "{\"action\":\"game-state\",\"sessionId\":\"$VALID_SID\"}" \
    -H "User-Agent: Mozilla/5.0"
done

# Time 5 requests with invalid session ID
echo "Invalid session timings:"
for i in $(seq 1 5); do
  curl -s -o /dev/null -w "%{time_total}\n" "https://myzr.io/api" -X POST \
    -H "Content-Type: application/json" \
    -d '{"action":"game-state","sessionId":"nonexistent-session-id-00000"}' \
    -H "User-Agent: Mozilla/5.0"
done
```

```bash
# TM2: Timing leak on pair codes
# Time 5 requests with a plausible pair code
echo "Plausible pair code timings:"
for i in $(seq 1 5); do
  curl -s -o /dev/null -w "%{time_total}\n" "https://myzr.io/api" -X POST \
    -H "Content-Type: application/json" \
    -d '{"action":"join-game","pairCode":"AAAA"}' \
    -H "User-Agent: Mozilla/5.0"
done

# Time 5 requests with an obviously invalid pair code
echo "Invalid pair code timings:"
for i in $(seq 1 5); do
  curl -s -o /dev/null -w "%{time_total}\n" "https://myzr.io/api" -X POST \
    -H "Content-Type: application/json" \
    -d '{"action":"join-game","pairCode":"ZZZZZZZZZZ"}' \
    -H "User-Agent: Mozilla/5.0"
done
```

```python
import json, time, asyncio, concurrent.futures
from urllib.request import Request, urlopen

# TM3: Race condition on game actions — send 10 identical actions simultaneously
req = Request('https://myzr.io/api', data=json.dumps({'action':'new-game'}).encode(),
              headers={'Content-Type':'application/json','User-Agent':'Mozilla/5.0'})
resp = json.loads(urlopen(req).read())
sid = resp['sessionId']

def send_action():
    r = Request('https://myzr.io/api',
                data=json.dumps({'action':'createSkill','sessionId':sid,'skill':'TestSkill'}).encode(),
                headers={'Content-Type':'application/json','User-Agent':'Mozilla/5.0'})
    try:
        return json.loads(urlopen(r).read())
    except Exception as e:
        return {'error': str(e)}

with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
    results = list(executor.map(lambda _: send_action(), range(10)))

successes = sum(1 for r in results if 'error' not in r and r.get('success', True))
print(f"TM3: {successes}/10 simultaneous actions succeeded")

# TM4: Idempotency on creation — send 10 concurrent new-game requests
def create_game():
    r = Request('https://myzr.io/api',
                data=json.dumps({'action':'new-game'}).encode(),
                headers={'Content-Type':'application/json','User-Agent':'Mozilla/5.0'})
    try:
        return json.loads(urlopen(r).read())
    except Exception as e:
        return {'error': str(e)}

with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
    results = list(executor.map(lambda _: create_game(), range(10)))

unique_sessions = len(set(r.get('sessionId','') for r in results if 'sessionId' in r))
print(f"TM4: {unique_sessions} unique sessions from 10 concurrent requests")
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| TM1 | Constant-time session lookup | Median response time difference between valid and invalid session IDs is <=50ms (WARN if >50ms). Use the median of the 5 samples per side rather than the mean so a single CDN-jitter outlier does not flip the verdict (CPT-106). |
| TM2 | Timing leak on pair codes | Median response time difference between plausible and invalid pair codes is <=50ms (WARN if >50ms). Use the median of the 5 samples per side rather than the mean so a single CDN-jitter outlier does not flip the verdict (CPT-106). |
| TM3 | Race condition on game actions | Only 1 of 10 simultaneous identical actions is processed (PASS if deduplicated) |
| TM4 | Idempotency on creation | 10 concurrent new-game requests do NOT all create separate sessions (WARN if all 10 create unique sessions) |

## Output

Write to `SECURITY_CHECK.parts/timing.md`:

```markdown
### Timing

| # | Test | Result | Evidence |
|---|------|--------|----------|
| TM1 | Constant-time session lookup | {PASS/WARN} | {median valid vs median invalid ms, delta} |
| TM2 | Timing leak on pair codes | {PASS/WARN} | {median plausible vs median invalid ms, delta} |
| TM3 | Race condition on game actions | {PASS/WARN} | {N of 10 succeeded} |
| TM4 | Idempotency on creation | {PASS/WARN} | {N unique sessions from 10 concurrent} |
```

## After — standalone only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` exists** (orchestrator dispatch). The orchestrator (`/chk2:all` / `/chk2:quick`) asks the user a single consolidated question after all waves complete — a per-category prompt from every sub-skill would pre-empt the CHK2-STATUS line and break the rate-limit circuit breaker.

Ask the user: **Do you want help fixing the timing issues found?** If yes, invoke `/chk2:fix` with context about which timing tests failed.

**Standalone merge** (CPT-126): check if `SECURITY_CHECK.parts/.orchestrated` exists. If it does NOT (standalone invocation, not dispatched by `/chk2:all` / `/chk2:quick`), also write the same content to `SECURITY_CHECK.md` using the Write tool so downstream `/chk2:fix` and `/chk2 github` can read it. If the marker IS present, skip this step — the orchestrator will merge all parts after its waves complete.

## Status signal — orchestrated only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` does NOT exist** (standalone invocation). The CHK2-STATUS protocol is parsed only by the `/chk2:all` and `/chk2:quick` orchestrators — emitting it in standalone mode is noise. When the marker IS present, emit the line as the absolute final line of your response (no trailing prose).

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
