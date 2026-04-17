---
name: chk2:disclosure
description: "Test information leakage"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Write
---

# chk2:disclosure — Information Disclosure

Test for information leakage on https://myzr.io. Append results to `SECURITY_CHECK.md`.

## Tests

```bash
# 404 error page content — check for origin hostname, stack traces
curl -s "https://myzr.io/nonexistent-path" -H "User-Agent: Mozilla/5.0"

# Invalid JSON error — check for stack traces
curl -s "https://myzr.io/api" -X POST -H "Content-Type: application/json" -d "{invalid" -H "User-Agent: Mozilla/5.0"

# Health endpoint — check what info is exposed
curl -s "https://myzr.io/api" -X POST -H "Content-Type: application/json" -d '{"action":"health"}' -H "User-Agent: Mozilla/5.0"

# Game data endpoint — check if public
curl -s "https://myzr.io/api" -X POST -H "Content-Type: application/json" -d '{"action":"game-data"}' -H "User-Agent: Mozilla/5.0" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Keys:', list(d.keys())); print('Quotes:', len(d.get('quotes',[]))); print('Models:', len(d.get('modelNames',[])))" 2>&1

# Response headers — check for version info
curl -sI "https://myzr.io/" -H "User-Agent: Mozilla/5.0" | grep -iE "x-powered-by|x-aspnet|x-debug|x-runtime|x-version|server"

# Install script — check if still served
curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/install.sh" -H "User-Agent: Mozilla/5.0"

# robots.txt — check for hidden paths
curl -s "https://myzr.io/robots.txt" -H "User-Agent: Mozilla/5.0"
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| L1 | 404 pages no origin leak | Error page does NOT contain RunPod hostname, internal IPs, or origin URLs |
| L2 | 404 pages no stack trace | Error page does NOT contain `at Object.`, file paths, or line numbers |
| L3 | Invalid JSON no stack trace | Response is clean JSON error, not HTML with debug info |
| L4 | Health endpoint minimal | Returns only `{"status":"ok"}` or similar minimal response |
| L5 | Game data not public | Requires session ID (WARN if accessible without auth) |
| L6 | No version headers | No `X-Powered-By`, `X-AspNet-Version`, or similar headers |
| L7 | Server header clean | `server` is just `cloudflare` with no version |
| L8 | robots.txt no sensitive paths | Does not disallow `/admin`, `/debug`, `/api/internal` or similar |
| L9 | Install script status | Should return 404 if removed, or 200 if intentionally public |
| L10 | Error consistency | All error paths return JSON, not mixed HTML/JSON |

## Output

Write to `SECURITY_CHECK.parts/disclosure.md`:

```markdown
### Disclosure

| # | Test | Result | Evidence |
|---|------|--------|----------|
| L1 | 404 no origin leak | {PASS/FAIL} | {whether hostname found} |
...
```

## After

Ask the user: **Do you want help fixing the disclosure issues found?** If yes, invoke `/chk2:fix` with context about which disclosure tests failed.
