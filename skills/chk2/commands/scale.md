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
