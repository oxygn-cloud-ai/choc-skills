---
name: chk2:ipv6
description: "Test IPv6 security and WAF bypass"
allowed-tools: Read, Bash(dig *), Bash(curl *), Bash(echo *), Write
---

# chk2:ipv6 — IPv6 Security

Test IPv6-related security on https://myzr.io. Write results to `SECURITY_CHECK.parts/ipv6.md` (see **Output** for format).

## Tests

```bash
# Check if AAAA record exists
AAAA=$(dig myzr.io AAAA +short)
echo "AAAA record: ${AAAA:-none}"

# IP1: IPv6 policy consistency — compare IPv4 vs IPv6 response headers
if [ -n "$AAAA" ]; then
  echo "=== IPv4 headers ==="
  curl -4 -sI "https://myzr.io/" -H "User-Agent: Mozilla/5.0" --max-time 10

  echo "=== IPv6 headers ==="
  curl -6 -sI "https://myzr.io/" -H "User-Agent: Mozilla/5.0" --max-time 10
else
  echo "No AAAA record — IPv6 not configured"
fi
```

```bash
# IP2: IPv6 WAF bypass — send scanner UA over IPv6 and compare with IPv4
AAAA=$(dig myzr.io AAAA +short)
if [ -n "$AAAA" ]; then
  echo "=== IPv4 scanner UA ==="
  curl -4 -s -o /dev/null -w "%{http_code}" "https://myzr.io/" \
    -H "User-Agent: sqlmap/1.0" --max-time 10
  echo ""

  echo "=== IPv6 scanner UA ==="
  curl -6 -s -o /dev/null -w "%{http_code}" "https://myzr.io/" \
    -H "User-Agent: sqlmap/1.0" --max-time 10
  echo ""
else
  echo "No AAAA record — skipping IPv6 WAF test"
fi
```

```bash
# IP3: IPv6 address disclosure — check response headers and body for IPv6 addresses
HEADERS=$(curl -sI "https://myzr.io/" -H "User-Agent: Mozilla/5.0")
BODY=$(curl -s "https://myzr.io/" -H "User-Agent: Mozilla/5.0")
ERROR_BODY=$(curl -s "https://myzr.io/nonexistent-path-xyz" -H "User-Agent: Mozilla/5.0")

echo "=== Headers IPv6 check ==="
echo "$HEADERS" | grep -iE '[0-9a-fA-F]{1,4}(:[0-9a-fA-F]{1,4}){7}|([0-9a-fA-F]{1,4}:){1,7}:|::([0-9a-fA-F]{1,4}:){0,5}[0-9a-fA-F]{1,4}' || echo "No IPv6 addresses found in headers"

echo "=== Body IPv6 check ==="
echo "$BODY" | grep -iE '[0-9a-fA-F]{1,4}(:[0-9a-fA-F]{1,4}){7}|([0-9a-fA-F]{1,4}:){1,7}:|::([0-9a-fA-F]{1,4}:){0,5}[0-9a-fA-F]{1,4}' || echo "No IPv6 addresses found in body"

echo "=== Error page IPv6 check ==="
echo "$ERROR_BODY" | grep -iE '[0-9a-fA-F]{1,4}(:[0-9a-fA-F]{1,4}){7}|([0-9a-fA-F]{1,4}:){1,7}:|::([0-9a-fA-F]{1,4}:){0,5}[0-9a-fA-F]{1,4}' || echo "No IPv6 addresses found in error page"
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| IP1 | IPv6 policy consistency | Security headers (HSTS, CSP, X-Frame-Options, etc.) match between IPv4 and IPv6 responses (PASS if identical or no AAAA record) |
| IP2 | IPv6 WAF bypass | Scanner UA is blocked over IPv6 same as IPv4 (PASS if both blocked or no AAAA record) |
| IP3 | IPv6 address disclosure | No IPv6 addresses found in response headers, body, or error pages (PASS if none found) |

## Output

Write to `SECURITY_CHECK.parts/ipv6.md`:

```markdown
### IPv6

| # | Test | Result | Evidence |
|---|------|--------|----------|
| IP1 | IPv6 policy consistency | {PASS/FAIL} | {header comparison or no AAAA} |
| IP2 | IPv6 WAF bypass | {PASS/FAIL} | {IPv4 status vs IPv6 status or no AAAA} |
| IP3 | IPv6 address disclosure | {PASS/FAIL} | {whether IPv6 addresses found} |
```

## After — standalone only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` exists** (orchestrator dispatch). The orchestrator (`/chk2:all` / `/chk2:quick`) asks the user a single consolidated question after all waves complete — a per-category prompt from every sub-skill would pre-empt the CHK2-STATUS line and break the rate-limit circuit breaker.

Ask the user: **Do you want help fixing the IPv6 issues found?** If yes, invoke `/chk2:fix` with context about which IPv6 tests failed.

**Standalone merge** (CPT-126): check if `SECURITY_CHECK.parts/.orchestrated` exists. If it does NOT (standalone invocation, not dispatched by `/chk2:all` / `/chk2:quick`), also write the same content to `SECURITY_CHECK.md` using the Write tool so downstream `/chk2:fix` and `/chk2 github` can read it. If the marker IS present, skip this step — the orchestrator will merge all parts after its waves complete.

## Status signal — orchestrated only

**Skip this section entirely if `SECURITY_CHECK.parts/.orchestrated` does NOT exist** (standalone invocation). The CHK2-STATUS protocol is parsed only by the `/chk2:all` and `/chk2:quick` orchestrators — emitting it in standalone mode is noise. When the marker IS present, emit the line as the absolute final line of your response (no trailing prose).

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
