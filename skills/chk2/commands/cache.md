---
name: chk2:cache
description: "Test cache security and deception"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Write
---

# chk2:cache — Cache Security

Test cache security on https://${TARGET:-myzr.io}. Write results to `SECURITY_CHECK.parts/cache.md` (see **Output** for format).

## Tests

```bash
# Cache-Control on API responses
curl -sI "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"health"}' -H "User-Agent: Mozilla/5.0" | grep -iE "cache-control|pragma"

# Cache-Control on authenticated content (create session first)
SESSION=$(curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sessionId',''))" 2>/dev/null)
curl -sI "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d "{\"action\":\"poll\",\"sessionId\":\"$SESSION\"}" -H "User-Agent: Mozilla/5.0" | grep -iE "cache-control|pragma"

# Web cache deception — append static extensions to API path
curl -sI "https://${TARGET:-myzr.io}/api/health.css" -H "User-Agent: Mozilla/5.0" | head -10
curl -s "https://${TARGET:-myzr.io}/api/health.css" -H "User-Agent: Mozilla/5.0" | head -5
curl -sI "https://${TARGET:-myzr.io}/api/health.js" -H "User-Agent: Mozilla/5.0" | head -10
curl -s "https://${TARGET:-myzr.io}/api/health.js" -H "User-Agent: Mozilla/5.0" | head -5

# CDN cache-key correctness — different Origin headers
curl -sI "https://${TARGET:-myzr.io}/" -H "Origin: https://evil.com" -H "User-Agent: Mozilla/5.0" | grep -iE "cache-control|vary|cf-cache"
curl -sI "https://${TARGET:-myzr.io}/" -H "Origin: https://${TARGET:-myzr.io}" -H "User-Agent: Mozilla/5.0" | grep -iE "cache-control|vary|cf-cache"

# Pragma header on sensitive endpoints
curl -sI "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d "{\"action\":\"poll\",\"sessionId\":\"$SESSION\"}" -H "User-Agent: Mozilla/5.0" | grep -i pragma
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| CA1 | Cache-Control on API | API responses include `no-store`. WARN if missing |
| CA2 | No caching of authenticated content | Responses containing session data have `no-store` or `private`. FAIL if `public` |
| CA3 | Web cache deception | `/api/health.css` and `/api/health.js` do NOT return API JSON content. FAIL if they do |
| CA4 | CDN cache-key correctness | Different `Origin` headers produce separate cache entries (check `Vary` includes `Origin`). WARN if not |
| CA5 | Pragma no-cache | Sensitive endpoints include `Pragma: no-cache`. WARN if missing |

## Output

Write to `SECURITY_CHECK.parts/cache.md`:

```markdown
### Cache

| # | Test | Result | Evidence |
|---|------|--------|----------|
| CA1 | Cache-Control on API | {PASS/WARN} | {Cache-Control value} |
| CA2 | No caching of auth content | {PASS/FAIL} | {Cache-Control value} |
| CA3 | Web cache deception | {PASS/FAIL} | {response content-type and body} |
| CA4 | CDN cache-key correctness | {PASS/WARN} | {Vary header value} |
| CA5 | Pragma no-cache | {PASS/WARN} | {Pragma header value} |
...
```

## After

Ask the user: **Do you want help fixing the cache issues found?** If yes, invoke `/chk2:fix` with context about which cache tests failed.

## Status signal

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
