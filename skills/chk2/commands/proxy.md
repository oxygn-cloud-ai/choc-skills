# chk2:proxy — Proxy and CDN Behavior

Test proxy, CDN, and service mesh behavior on https://${TARGET:-myzr.io}. Append results to `SECURITY_CHECK.md`.

## Tests

```bash
# PB1: CORS preflight cache poisoning — OPTIONS with evil origin
curl -sI "https://${TARGET:-myzr.io}/api" -X OPTIONS -H "Origin: https://evil.com" -H "Access-Control-Request-Method: POST" -H "User-Agent: Mozilla/5.0" | grep -iE "access-control-allow-origin|vary|cache-control|age|cf-cache"

# PB2: CDN cache key normalization — compare encoded/case/trailing variants
curl -s -o /dev/null -w "%{http_code}" "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"health"}' -H "User-Agent: Mozilla/5.0"
curl -s -o /dev/null -w "%{http_code}" "https://${TARGET:-myzr.io}/%61%70%69" -X POST -H "Content-Type: application/json" -d '{"action":"health"}' -H "User-Agent: Mozilla/5.0"
curl -s -o /dev/null -w "%{http_code}" "https://${TARGET:-myzr.io}/API" -X POST -H "Content-Type: application/json" -d '{"action":"health"}' -H "User-Agent: Mozilla/5.0"
curl -s -o /dev/null -w "%{http_code}" "https://${TARGET:-myzr.io}/api/" -X POST -H "Content-Type: application/json" -d '{"action":"health"}' -H "User-Agent: Mozilla/5.0"
curl -s -o /dev/null -w "%{http_code}" "https://${TARGET:-myzr.io}/./api" -X POST -H "Content-Type: application/json" -d '{"action":"health"}' -H "User-Agent: Mozilla/5.0"

# PB3: Service mesh header leak — check for infrastructure headers
curl -sI "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" | grep -iE "x-envoy|x-istio|x-linkerd|x-b3-|x-request-id"
curl -sI "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d '{"action":"health"}' -H "User-Agent: Mozilla/5.0" | grep -iE "x-envoy|x-istio|x-linkerd|x-b3-|x-request-id"

# PB4: Load balancer fingerprinting — 10 requests, compare server headers
for i in $(seq 1 10); do
  curl -sI "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" | grep -iE "^server:|^via:|^x-served-by:" | tr '\r' ' '
  echo "---"
done
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| PB1 | CORS preflight cache poisoning | Evil origin is NOT reflected in `Access-Control-Allow-Origin`, OR `Vary` includes `Origin`, OR response is not cached (no long `max-age`). FAIL if evil origin reflected + no Vary: Origin + long cache TTL |
| PB2 | CDN cache key normalization | All path variants (`/api`, `/%61%70%69`, `/API`, `/api/`, `/./api`) return the same status code. WARN if different status codes indicate inconsistent path normalization |
| PB3 | Service mesh header leak | No `x-envoy-*`, `x-istio-*`, `x-linkerd-*`, `x-b3-*`, or `x-request-id` headers in responses. FAIL if any found |
| PB4 | Load balancer fingerprinting | All 10 requests return identical `Server`, `Via`, and `X-Served-By` values. WARN if multiple distinct backend identifiers visible |

## Output

Append to `SECURITY_CHECK.md`:

```markdown
### Proxy

| # | Test | Result | Evidence |
|---|------|--------|----------|
| PB1 | CORS preflight cache poisoning | {PASS/FAIL} | {ACAO value, Vary header, cache headers} |
| PB2 | CDN cache key normalization | {PASS/WARN} | {status codes for each path variant} |
| PB3 | Service mesh header leak | {PASS/FAIL} | {leaked headers or "none found"} |
| PB4 | Load balancer fingerprinting | {PASS/WARN} | {unique server identifiers seen} |
...
```

## After

**Skip this section when invoked from `/chk2:all` (batch mode).** Only ask when run as a standalone category check.

Ask the user: **Do you want help fixing the proxy/CDN issues found?** If yes, invoke `/chk2:fix` with context about which proxy tests failed.
