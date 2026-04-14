# chk2:waf — WAF Rules and Rate Limiting

Test Cloudflare WAF and rate limiting on https://myzr.io. Append results to `SECURITY_CHECK.md`.

## Tests

```bash
# Scanner User-Agents
curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/" -H "User-Agent: sqlmap/1.0"
curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/" -H "User-Agent: nikto"
curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/" -H "User-Agent: nmap"
curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/" -H "User-Agent: masscan"
curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/" -H "User-Agent: dirbuster"

# Rate limiting on API (send until 429 or max 35)
for i in $(seq 1 35); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/api" -X POST \
    -H "Content-Type: application/json" \
    -d '{"action":"game-action","sessionId":"test","gameAction":"createSkill"}' \
    -H "User-Agent: Mozilla/5.0")
  if [ "$code" = "429" ]; then echo "Rate limited at $i"; break; fi
done

# HTTP method restrictions
for method in PUT DELETE PATCH TRACE; do
  curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/api" -X $method -H "User-Agent: Mozilla/5.0"
done
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| F1 | sqlmap UA blocked | Returns 403 |
| F2 | nikto UA blocked | Returns 403 (WARN if 200 — requires paid plan) |
| F3 | nmap UA blocked | Returns 403 (WARN if 200 — requires paid plan) |
| F4 | masscan UA blocked | Returns 403 (WARN if 200) |
| F5 | dirbuster UA blocked | Returns 403 (WARN if 200) |
| F6 | API rate limited | 429 returned before 35 requests |
| F7 | Rate limit threshold | Triggers at reasonable level (<=15 requests) |
| F8 | PUT method rejected | Returns 404 or 405 |
| F9 | DELETE method rejected | Returns 404 or 405 |
| F10 | TRACE method disabled | Returns 404 or 405 (FAIL if 200) |
| F11 | SSRF probe resistance | Internal/metadata URLs in API fields do not trigger server-side requests |
| F12 | Bot management beyond UA | Requests without typical browser headers (no Accept, no Accept-Language) are flagged |

### F11-F12 Additional Tests

```bash
# F11 — SSRF probes
for url in "http://169.254.169.254/latest/meta-data/" "http://127.0.0.1:8080/" "http://localhost/" "http://[::1]/" "http://0.0.0.0/"; do
  curl -s "https://myzr.io/api" -X POST -H "Content-Type: application/json" \
    -d "{\"action\":\"health\",\"callback\":\"${url}\"}" -H "User-Agent: Mozilla/5.0" --max-time 5
done

# F12 — Bot management beyond UA
# Request with no browser-like headers
curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/" --max-time 10
# Compare with browser-like request
curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" \
  -H "Accept: text/html,application/xhtml+xml" \
  -H "Accept-Language: en-US,en;q=0.9" \
  -H "Accept-Encoding: gzip, deflate, br" --max-time 10
```

## Output

Append to `SECURITY_CHECK.md`:

```markdown
### WAF

| # | Test | Result | Evidence |
|---|------|--------|----------|
| F1 | sqlmap UA blocked | {PASS/FAIL} | {HTTP status} |
...
```

## After

**Skip this section when invoked from `/chk2:all` (batch mode).** Only ask when run as a standalone category check.

Ask the user: **Do you want help fixing the WAF issues found?** If yes, invoke `/chk2:fix` with context about which WAF tests failed.
