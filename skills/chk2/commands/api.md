---
name: chk2:api
description: "Test API injection, fuzzing, and type confusion"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Write
---

# chk2:api — API Fuzzing, Injection, Type Confusion

Test API input validation on https://myzr.io. Write results to `SECURITY_CHECK.parts/api.md` (see **Output** for format).

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
| A13 | HTTP parameter pollution | Duplicate JSON keys `{"action":"health","action":"admin"}` handled safely — last wins or error |
| A14 | Unicode normalization attack | Cyrillic homoglyphs in action names rejected (e.g., Cyrillic `а` for Latin `a`) |
| A15 | JSON key bombing | Extremely long key name (1000+ chars) rejected with 400/413 |
| A16 | Null byte injection | Null bytes in fields `{"action":"health\u0000admin"}` rejected |
| A17 | Response Content-Type correct | All API responses return `Content-Type: application/json`, never `text/html` |

### A13-A17 Additional Tests

```bash
# A13 — HTTP parameter pollution
curl -s "https://myzr.io/api" -X POST -H "Content-Type: application/json" \
  -d '{"action":"health","action":"admin"}' -H "User-Agent: Mozilla/5.0"

# A14 — Unicode normalization (Cyrillic 'а' U+0430 for Latin 'a')
curl -s "https://myzr.io/api" -X POST -H "Content-Type: application/json" \
  -d '{"action":"heаlth"}' -H "User-Agent: Mozilla/5.0"

# A15 — JSON key bombing
python3 -c "import json; print(json.dumps({'a'*1000: 'v', 'action': 'health'}))" | \
  curl -s "https://myzr.io/api" -X POST -H "Content-Type: application/json" \
  -H "User-Agent: Mozilla/5.0" -d @-

# A16 — Null byte injection
curl -s "https://myzr.io/api" -X POST -H "Content-Type: application/json" \
  -d '{"action":"health\u0000admin"}' -H "User-Agent: Mozilla/5.0"

# A17 — Response Content-Type
curl -sI "https://myzr.io/api" -X POST -H "Content-Type: application/json" \
  -d '{"action":"health"}' -H "User-Agent: Mozilla/5.0" | grep -i "^content-type:"
```

## Output

Write to `SECURITY_CHECK.parts/api.md`:

```markdown
### API

| # | Test | Result | Evidence |
|---|------|--------|----------|
| A1 | Non-string sessionId rejected | {PASS/FAIL} | {response} |
...
```

## After

Ask the user: **Do you want help fixing the API issues found?** If yes, invoke `/chk2:fix` with context about which API tests failed.

## Status signal

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
