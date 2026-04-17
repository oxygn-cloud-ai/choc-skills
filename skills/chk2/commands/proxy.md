---
name: chk2:proxy
description: "Test proxy and CDN behavior"
allowed-tools: Read, Bash(curl *), Bash(echo *), Write
---

# chk2:proxy — Proxy and CDN Behavior

Test proxy, CDN, and service mesh behavior on https://${TARGET:-myzr.io}. Write results to `SECURITY_CHECK.parts/proxy.md` (see **Output** for format).

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

Write to `SECURITY_CHECK.parts/proxy.md`:

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

## After — standalone only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` exists** (orchestrator dispatch). The orchestrator (`/chk2:all` / `/chk2:quick`) asks the user a single consolidated question after all waves complete — a per-category prompt from every sub-skill would pre-empt the CHK2-STATUS line and break the rate-limit circuit breaker.

Ask the user: **Do you want help fixing the proxy/CDN issues found?** If yes, invoke `/chk2:fix` with context about which proxy tests failed.

**Standalone merge** (CPT-126): check if `SECURITY_CHECK.parts/.orchestrated` exists. If it does NOT (standalone invocation, not dispatched by `/chk2:all` / `/chk2:quick`), also write the same content to `SECURITY_CHECK.md` using the Write tool so downstream `/chk2:fix` and `/chk2 github` can read it. If the marker IS present, skip this step — the orchestrator will merge all parts after its waves complete.

## Status signal — orchestrated only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` does NOT exist** (standalone invocation). The CHK2-STATUS protocol is parsed only by the `/chk2:all` and `/chk2:quick` orchestrators — emitting it in standalone mode is noise. When the marker IS present, emit the line as the absolute final line of your response (no trailing prose).

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
