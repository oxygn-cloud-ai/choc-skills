# chk2:scale — Scaling and Resource Limits

Test connection limits and payload handling on https://myzr.io. Append results to `SECURITY_CHECK.md`.

If you hit rate limits (429 or 1015), wait 65 seconds before continuing.

Use MODERATE payloads only — do not send 1MB+ or 500+ message floods.

## Tests

```bash
# Large JSON body (50KB)
curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/api" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"action\":\"health\",\"padding\":\"$(python3 -c "print('X'*50000)")\"}" \
  -H "User-Agent: Mozilla/5.0"

# Deeply nested JSON (50 levels)
python3 -c "
import json
d = {'action':'health'}
for i in range(50):
    d = {'nested': d}
print(json.dumps(d))" | curl -s "https://myzr.io/api" -X POST -H "Content-Type: application/json" -d @- -H "User-Agent: Mozilla/5.0"

# Rapid session creation (10 in quick succession)
for i in $(seq 1 10); do
  curl -s -o /dev/null -w "%{http_code} " "https://myzr.io/api" -X POST \
    -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0"
done
```

WebSocket tests (python3):
```python
# WS: concurrent connections to same session (try 10)
# WS: rapid messages (50 messages in quick succession)
# WS: 10KB message
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| S1 | 50KB payload handled | Returns error or 413, doesn't crash (WARN if 200) |
| S2 | Deep nesting handled | Returns error, doesn't crash or hang |
| S3 | Session creation throttled | Rate limited before 10 sessions |
| S4 | WS connection limit | Server caps at <=5 per session (WARN if >5) |
| S5 | WS rapid messages | 50 messages don't crash (WARN if no rate limiting) |
| S6 | WS 10KB message | Handled gracefully (WARN if silently accepted) |
| RE1 | Slowloris resistance | Partial HTTP requests with slow headers are terminated within timeout |
| RE2 | Hash collision DoS | JSON with 10,000 keys is rejected or processed in < 1 second |
| RE3 | ReDoS via input fields | Crafted backtracking inputs (50+ repeated chars) don't cause slow responses |
| RE4 | Chunked transfer abuse | Extremely slow chunked transfer (1 byte per second) is terminated |

### RE1-RE4 Additional Tests

```python
# RE1 — Slowloris (concurrent connections via ThreadPoolExecutor)
import socket, ssl, time, concurrent.futures
context = ssl.create_default_context()
def slowloris_conn(i):
    try:
        s = socket.create_connection(('myzr.io', 443), timeout=10)
        ss = context.wrap_socket(s, server_hostname='myzr.io')
        ss.send(b'GET / HTTP/1.1\r\nHost: myzr.io\r\nUser-Agent: Mozilla/5.0\r\n')
        time.sleep(3)
        ss.send(b'X-Test: partial\r\n')
        time.sleep(3)
        ss.send(b'X-Test2: still-open\r\n')
        ss.close()
        return f'{i}: still open after 6s'
    except Exception as e:
        return f'{i}: closed ({type(e).__name__})'
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
    results = list(executor.map(slowloris_conn, range(5)))
for r in results: print(r)
```

```bash
# RE2 — HashDoS
python3 -c "
import json
payload = {f'k{i}': 'v' for i in range(10000)}
payload['action'] = 'health'
print(json.dumps(payload))
" | curl -s -o /dev/null -w "%{http_code} %{time_total}s" "https://myzr.io/api" \
  -X POST -H "Content-Type: application/json" -H "User-Agent: Mozilla/5.0" -d @- --max-time 15

# RE3 — ReDoS
REDOS_PAYLOAD=$(python3 -c "print('a' * 50 + '!')")
curl -s -o /dev/null -w "%{http_code} %{time_total}s" "https://myzr.io/api" \
  -X POST -H "Content-Type: application/json" -H "User-Agent: Mozilla/5.0" \
  -d "{\"action\":\"word\",\"sessionId\":\"test\",\"word\":\"${REDOS_PAYLOAD}\"}" --max-time 10

# RE4 — Chunked transfer abuse
python3 -c "
import socket, ssl, time
ctx = ssl.create_default_context()
s = ctx.wrap_socket(socket.create_connection(('myzr.io', 443)), server_hostname='myzr.io')
s.send(b'POST /api HTTP/1.1\r\nHost: myzr.io\r\nTransfer-Encoding: chunked\r\nContent-Type: application/json\r\n\r\n')
for i in range(10):
    s.send(b'1\r\na\r\n')
    time.sleep(1)
s.send(b'0\r\n\r\n')
print(s.recv(4096).decode()[:200])
s.close()
"
```

## Output

Append to `SECURITY_CHECK.md`:

```markdown
### Scaling

| # | Test | Result | Evidence |
|---|------|--------|----------|
| S1 | 50KB payload handled | {PASS/WARN/FAIL} | {HTTP status} |
...
```

## After

Ask the user: **Do you want help fixing the scaling issues found?** If yes, invoke `/chk2:fix` with context about which scaling tests failed.
