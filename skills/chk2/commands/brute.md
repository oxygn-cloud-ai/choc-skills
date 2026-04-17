---
name: chk2:brute
description: "Test session enumeration and brute force resistance"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Write
---

# chk2:brute — Session Enumeration and Brute Force

Test session ID and pair code entropy on https://myzr.io. Write results to `SECURITY_CHECK.parts/brute.md` (see **Output** for format).

If you hit rate limits (429 or 1015), wait 65 seconds before continuing.

## Tests

```bash
# Create 5 sessions, analyze entropy
for i in $(seq 1 5); do
  curl -s "https://myzr.io/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0"
done

# Guess common/weak session IDs
for sid in "00000000000000000000000000000000" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "11111111111111111111111111111111" "admin" "test" "1" "0" ""; do
  curl -s "https://myzr.io/api" -X POST -H "Content-Type: application/json" -d "{\"action\":\"poll\",\"sessionId\":\"$sid\"}" -H "User-Agent: Mozilla/5.0"
done

# Guess sequential session IDs (if hex, try incrementing)
# Take first session ID from creation, try nearby values

# Pair code as session ID
# (use a pair code from session creation)
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| B1 | Session ID length | IDs are 32+ hex chars (128+ bits) |
| B2 | Session ID randomness | No sequential or predictable pattern across 5 sessions |
| B3 | Pair code length | Pair codes are 22+ chars (128+ bits) |
| B4 | Pair code randomness | No sequential or predictable pattern |
| B5 | Weak IDs rejected | `00000...`, `aaaa...`, `admin`, `test`, empty — all return `Session not found` |
| B6 | Pair code not usable as session ID | Pair code in sessionId field returns `Session not found` |
| B7 | No information leakage on miss | Error response is identical for all invalid IDs (no timing/content difference) |
| B8 | Session creation rate limited | Creating many sessions triggers 429 |

## Output

Write to `SECURITY_CHECK.parts/brute.md`:

```markdown
### Brute Force

| # | Test | Result | Evidence |
|---|------|--------|----------|
| B1 | Session ID length | {PASS/FAIL} | {example ID length} |
...
```

## After — standalone only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` exists** (orchestrator dispatch). The orchestrator (`/chk2:all` / `/chk2:quick`) asks the user a single consolidated question after all waves complete — a per-category prompt from every sub-skill would pre-empt the CHK2-STATUS line and break the rate-limit circuit breaker.

Ask the user: **Do you want help fixing the brute force issues found?** If yes, invoke `/chk2:fix` with context about which tests failed.

**Standalone merge** (CPT-126): check if `SECURITY_CHECK.parts/.orchestrated` exists. If it does NOT (standalone invocation, not dispatched by `/chk2:all` / `/chk2:quick`), also write the same content to `SECURITY_CHECK.md` using the Write tool so downstream `/chk2:fix` and `/chk2 github` can read it. If the marker IS present, skip this step — the orchestrator will merge all parts after its waves complete.

## Status signal — orchestrated only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` does NOT exist** (standalone invocation). The CHK2-STATUS protocol is parsed only by the `/chk2:all` and `/chk2:quick` orchestrators — emitting it in standalone mode is noise. When the marker IS present, emit the line as the absolute final line of your response (no trailing prose).

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
