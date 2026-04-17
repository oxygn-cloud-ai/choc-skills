---
name: chk2:sse
description: "Test SSE security"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Write
---

# chk2:sse — Server-Sent Events Security

Test for SSE-related vulnerabilities on https://myzr.io. Write results to `SECURITY_CHECK.parts/sse.md` (see **Output** for format).

## Tests

```bash
# SE1: SSE authentication — check common SSE endpoints without auth
for path in /events /sse /stream /api/events /api/sse /api/stream; do
  status=$(curl -s -o /dev/null -w "%{http_code}" "https://myzr.io$path" \
    -H "Accept: text/event-stream" \
    -H "User-Agent: Mozilla/5.0" \
    --max-time 5)
  echo "$path: $status"
done
```

```python
import concurrent.futures
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

# SE2: SSE connection limit — discover valid path first, then test concurrency on that path only
# Phase 1: Probe paths sequentially to find one that responds (avoids 20x redundant 404 probes).
# The probe response MUST be closed before Phase 2 opens concurrent connections on the same
# path — otherwise a stale probe holds a connection slot and Phase 2 undercounts by one
# (CPT-99). `with urlopen(...) as resp` guarantees closure on every exit path, including break.
sse_path = None
for path in ['/events', '/sse', '/stream', '/api/events']:
    try:
        req = Request(f'https://myzr.io{path}',
                      headers={'Accept': 'text/event-stream', 'User-Agent': 'Mozilla/5.0'})
        with urlopen(req, timeout=5) as resp:
            sse_path = path
        break
    except HTTPError as e:
        if e.code != 404:
            sse_path = path
            break
    except (URLError, Exception):
        continue

if sse_path is None:
    print("SE2: No SSE endpoint found (all paths 404/unreachable)")
else:
    # Phase 2: Concurrent connections on the discovered path
    def open_sse(i):
        try:
            req = Request(f'https://myzr.io{sse_path}',
                          headers={'Accept': 'text/event-stream', 'User-Agent': 'Mozilla/5.0'})
            resp = urlopen(req, timeout=5)
            return {'status': resp.status, 'connected': True}
        except HTTPError as e:
            return {'status': e.code, 'connected': False}
        except (URLError, Exception) as e:
            return {'status': 0, 'connected': False, 'error': str(e)}

    with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
        results = list(executor.map(open_sse, range(20)))

    connected = sum(1 for r in results if r.get('connected'))
    statuses = set(r.get('status') for r in results)
    print(f"SE2: {connected}/20 SSE connections to {sse_path} succeeded, statuses: {statuses}")
```

```bash
# SE3: SSE cross-origin — check CORS on SSE endpoints with evil origin
for path in /events /sse /stream /api/events; do
  cors=$(curl -sI "https://myzr.io$path" \
    -H "Accept: text/event-stream" \
    -H "Origin: https://evil.example.com" \
    -H "User-Agent: Mozilla/5.0" \
    --max-time 5 | grep -i "access-control-allow-origin")
  status=$(curl -s -o /dev/null -w "%{http_code}" "https://myzr.io$path" \
    -H "Accept: text/event-stream" \
    -H "Origin: https://evil.example.com" \
    -H "User-Agent: Mozilla/5.0" \
    --max-time 5)
  echo "$path: status=$status cors='$cors'"
done
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| SE1 | SSE authentication | All SSE endpoints return 401, 403, or 404 without auth (PASS if no unauthenticated access) |
| SE2 | SSE connection limit | Server limits concurrent SSE connections or endpoints return 404 (PASS if limited or no SSE endpoint) |
| SE3 | SSE cross-origin | Evil origin is NOT reflected in `Access-Control-Allow-Origin`, or endpoints return 404 (PASS if not reflected or no endpoint) |

## Output

Write to `SECURITY_CHECK.parts/sse.md`:

```markdown
### SSE

| # | Test | Result | Evidence |
|---|------|--------|----------|
| SE1 | SSE authentication | {PASS/FAIL} | {HTTP status per path} |
| SE2 | SSE connection limit | {PASS/WARN} | {N of 20 connections succeeded} |
| SE3 | SSE cross-origin | {PASS/FAIL} | {CORS header values per path} |
```

## After

Ask the user: **Do you want help fixing the SSE issues found?** If yes, invoke `/chk2:fix` with context about which SSE tests failed.

**Standalone merge** (CPT-126): check if `SECURITY_CHECK.parts/.orchestrated` exists. If it does NOT (standalone invocation, not dispatched by `/chk2:all` / `/chk2:quick`), also write the same content to `SECURITY_CHECK.md` using the Write tool so downstream `/chk2:fix` and `/chk2 github` can read it. If the marker IS present, skip this step — the orchestrator will merge all parts after its waves complete.

## Status signal

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
