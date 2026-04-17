---
name: chk2:auth
description: "Test authentication and session security"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Write
---

# chk2:auth — Authentication and Session Security

Test authentication and session security on https://${TARGET:-myzr.io}. Write results to `SECURITY_CHECK.parts/auth.md` (see **Output** for format).

## Tests

```bash
# AU1: Session fixation — create two games, compare session IDs
SID1=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sessionId',''))" 2>/dev/null)
SID2=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sessionId',''))" 2>/dev/null)
echo "SID1=$SID1"
echo "SID2=$SID2"
echo "Unique: $([ "$SID1" != "$SID2" ] && echo YES || echo NO)"

# AU2: Session invalidation — poll old session after creating new one
OLD_SID=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sessionId',''))" 2>/dev/null)
# Create a new session (simulating re-auth)
NEW_SID=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sessionId',''))" 2>/dev/null)
# Try polling with old session
curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d "{\"action\":\"poll\",\"sessionId\":\"$OLD_SID\"}" -H "User-Agent: Mozilla/5.0"

# AU3: Concurrent session limits — create 20+ sessions (uses jq instead of python3 to avoid 22 interpreter startups)
for i in $(seq 1 22); do
  curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | jq -r --arg i "$i" '"\($i): \(.sessionId // "DENIED" | .[:8])... status=\(.status // "?")"' 2>/dev/null
done

# AU4: Session timeout — create session and note for manual timeout check
TIMEOUT_SID=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sessionId',''))" 2>/dev/null)
echo "Session for timeout check: $TIMEOUT_SID (poll again after expected timeout period)"

# AU5: IDOR — create 2 sessions, try cross-session action
VICTIM_SID=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sessionId',''))" 2>/dev/null)
ATTACKER_SID=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sessionId',''))" 2>/dev/null)
# Try to poll victim session using attacker context
curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d "{\"action\":\"poll\",\"sessionId\":\"$VICTIM_SID\",\"attackerSession\":\"$ATTACKER_SID\"}" -H "User-Agent: Mozilla/5.0"

# AU6: Mass assignment — send elevated fields in new-game
curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game","isAdmin":true,"role":"admin","privileges":"superuser"}' -H "User-Agent: Mozilla/5.0"

# AU7: Privilege escalation — try admin/debug/eval actions
curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"admin"}' -H "User-Agent: Mozilla/5.0"
curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"debug"}' -H "User-Agent: Mozilla/5.0"
curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"eval","code":"1+1"}' -H "User-Agent: Mozilla/5.0"
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| AU1 | Session fixation | Two new-game calls produce unique, different session IDs |
| AU2 | Session invalidation | Old session poll is rejected after new session is created (note: depends on server design) |
| AU3 | Concurrent session limits | Server limits concurrent sessions. WARN if all 22 are accepted |
| AU4 | Session timeout | Session becomes invalid after expected inactivity period (note for manual verification) |
| AU5 | IDOR | Cross-session action fails or returns only data belonging to the specified sessionId. FAIL if attacker can access victim data |
| AU6 | Mass assignment | `isAdmin`, `role`, `privileges` fields in new-game are ignored; response shows no elevated permissions |
| AU7 | Privilege escalation | `action:admin`, `action:debug`, `action:eval` all return error or unknown-action response |

## Output

Write to `SECURITY_CHECK.parts/auth.md`:

```markdown
### Auth

| # | Test | Result | Evidence |
|---|------|--------|----------|
| AU1 | Session fixation | {PASS/FAIL} | {whether IDs are unique} |
| AU2 | Session invalidation | {PASS/FAIL/WARN} | {old session poll result} |
| AU3 | Concurrent session limits | {PASS/WARN} | {number of sessions accepted} |
| AU4 | Session timeout | {MANUAL} | {session ID for later check} |
| AU5 | IDOR | {PASS/FAIL} | {cross-session response} |
| AU6 | Mass assignment | {PASS/FAIL} | {response to elevated fields} |
| AU7 | Privilege escalation | {PASS/FAIL} | {responses to admin/debug/eval} |
...
```

## After — standalone only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` exists** (orchestrator dispatch). The orchestrator (`/chk2:all` / `/chk2:quick`) asks the user a single consolidated question after all waves complete — a per-category prompt from every sub-skill would pre-empt the CHK2-STATUS line and break the rate-limit circuit breaker.

Ask the user: **Do you want help fixing the auth issues found?** If yes, invoke `/chk2:fix` with context about which auth tests failed.

**Standalone merge** (CPT-126): check if `SECURITY_CHECK.parts/.orchestrated` exists. If it does NOT (standalone invocation, not dispatched by `/chk2:all` / `/chk2:quick`), also write the same content to `SECURITY_CHECK.md` using the Write tool so downstream `/chk2:fix` and `/chk2 github` can read it. If the marker IS present, skip this step — the orchestrator will merge all parts after its waves complete.

## Status signal — orchestrated only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` does NOT exist** (standalone invocation). The CHK2-STATUS protocol is parsed only by the `/chk2:all` and `/chk2:quick` orchestrators — emitting it in standalone mode is noise. When the marker IS present, emit the line as the absolute final line of your response (no trailing prose).

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
