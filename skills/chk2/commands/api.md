# chk2:api — API Fuzzing, Injection, Type Confusion

Test API input validation on https://myzr.io. Append results to `SECURITY_CHECK.md`.

If you hit rate limits (429 or 1015), wait 65 seconds before continuing.

## Tests

```bash
# Type confusion — non-string sessionId
curl -s POST /api {"action":"game-action","sessionId":123,"gameAction":"createSkill"}
curl -s POST /api {"action":"game-action","sessionId":true,"gameAction":"createSkill"}
curl -s POST /api {"action":"game-action","sessionId":[],"gameAction":"createSkill"}
curl -s POST /api {"action":"game-action","sessionId":null,"gameAction":"createSkill"}

# Type confusion — non-string action
curl -s POST /api {"action":["game-action"]}
curl -s POST /api {"action":123}

# NoSQL injection
curl -s POST /api {"action":"poll","sessionId":{"$gt":""}}
curl -s POST /api {"action":"poll","sessionId":{"$ne":null}}

# Prototype pollution
curl -s POST /api {"action":"new-game","__proto__":{"isAdmin":true}}
curl -s POST /api {"action":"new-game","constructor":{"prototype":{"isAdmin":true}}}
# Then verify no pollution:
curl -s POST /api {"action":"health"}

# Command injection in gameAction
curl -s POST /api {"action":"game-action","sessionId":"test","gameAction":"createSkill; ls /"}
curl -s POST /api {"action":"game-action","sessionId":"test","gameAction":"createSkill && cat /etc/passwd"}
curl -s POST /api {"action":"game-action","sessionId":"test","gameAction":"$(whoami)"}

# Template injection
curl -s POST /api {"action":"game-action","sessionId":"test","gameAction":"{{7*7}}"}
curl -s POST /api {"action":"game-action","sessionId":"test","gameAction":"${7*7}"}

# Unknown actions
for act in admin debug eval exec shell config env restart shutdown delete-all reset dump sql; do test; done

# Malformed payloads
POST /api with: "not json", [1,2,3], {}, empty body

# Session ID path traversal
curl -s POST /api {"action":"poll","sessionId":"../../../etc/passwd"}
curl -s POST /api {"action":"poll","sessionId":"..%2f..%2fetc%2fpasswd"}

# Word endpoint injection
curl -s POST /api {"action":"word","sessionId":"test","word":"<script>alert(1)</script>"}
curl -s POST /api {"action":"word","sessionId":"test","word":"${7*7}"}
curl -s POST /api {"action":"word","sessionId":"test","word":"__proto__"}
```

All requests use: `curl -s "https://myzr.io/api" -X POST -H "Content-Type: application/json" -H "User-Agent: Mozilla/5.0" -d '{payload}'`

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| A1 | Non-string sessionId rejected | Returns `{"error":"Invalid request"}` |
| A2 | Non-string action rejected | Returns `{"error":"Invalid request"}` or `{"error":"Unknown action"}` |
| A3 | NoSQL operators rejected | Returns `{"error":"Invalid request"}`, not data |
| A4 | Prototype pollution no effect | `health` returns normal `{"status":"ok"}` after pollution attempts |
| A5 | Command injection rejected | Returns error, no execution evidence |
| A6 | Template injection rejected | Returns error, not evaluated expression |
| A7 | Unknown actions rejected | All return `{"error":"Unknown action"}` |
| A8 | Invalid JSON rejected | Returns `{"error":"Invalid request"}` |
| A9 | Empty body rejected | Returns `{"error":"Invalid request"}` |
| A10 | Session traversal rejected | Returns `{"error":"Session not found"}`, no file content |
| A11 | Word XSS payload accepted safely | Returns `{"ok":true}` or error — no reflected content |
| A12 | No stack traces in errors | No error responses contain file paths, line numbers, or `at Object.` |

## Output

Append to `SECURITY_CHECK.md`:

```markdown
### API

| # | Test | Result | Evidence |
|---|------|--------|----------|
| A1 | Non-string sessionId rejected | {PASS/FAIL} | {response} |
...
```

## After

Ask the user: **Do you want help fixing the API issues found?** If yes, invoke `/chk2:fix` with context about which API tests failed.
