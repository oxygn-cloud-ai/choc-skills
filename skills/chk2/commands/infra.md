---
name: chk2:infra
description: "Test Cloudflare infrastructure security"
allowed-tools: Read, Bash(curl *), Bash(echo *), Bash(dig *), Write
---

# chk2:infra — Cloudflare Infrastructure

Test Cloudflare configuration and infrastructure security on https://myzr.io. Append results to `SECURITY_CHECK.md`.

## Tests

```bash
# Cloudflare trace
curl -s "https://myzr.io/cdn-cgi/trace"

# Error page origin leak
curl -s "https://myzr.io/nonexistent-triggers-error" -H "User-Agent: Mozilla/5.0" | grep -iE "runpod|proxy\.runpod|internal|origin|t0nq"

# Caching status
curl -sI "https://myzr.io/" -H "User-Agent: Mozilla/5.0" | grep -i cf-cache

# Alternative Cloudflare ports
for port in 8443 2053 2083 2087 2096; do
  curl -sk --connect-timeout 3 -o /dev/null -w "port $port => %{http_code}\n" "https://myzr.io:$port/"
done

# MCP source files (should be 404 now)
for f in index.js personality.js rationales.js package.json; do
  curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/mcp/$f" -H "User-Agent: Mozilla/5.0"
done

# Sensitive file paths
for p in /.env /config.json /package.json /.git/HEAD /.git/config /server.js /handler.js /engine.js /.well-known/security.txt; do
  curl -s -o /dev/null -w "%{http_code}" "https://myzr.io$p" -H "User-Agent: Mozilla/5.0"
done

# Path traversal
for p in "/../etc/passwd" "/..%2f..%2fetc/passwd" "/%2e%2e/%2e%2e/etc/passwd"; do
  curl -s -o /dev/null -w "%{http_code}" "https://myzr.io$p" -H "User-Agent: Mozilla/5.0"
done

# Host header injection
curl -sI "https://myzr.io/" -H "Host: evil.com" -H "User-Agent: Mozilla/5.0" | head -3

# Direct IP bypass
for ip in $(dig myzr.io A +short); do
  curl -sk --connect-timeout 3 -o /dev/null -w "$ip => %{http_code}\n" "https://$ip/" -H "Host: myzr.io"
done
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| I1 | CF trace warp off | `warp=off` in trace output |
| I2 | Error pages no origin leak | Error pages do NOT contain RunPod hostname or internal URLs |
| I3 | MCP source files removed | All `/mcp/*.js` return 404 |
| I4 | No .env exposed | `/.env` returns 404 |
| I5 | No .git exposed | `/.git/HEAD` returns 404 |
| I6 | No package.json exposed | `/package.json` returns 404 |
| I7 | No server source exposed | `/server.js`, `/handler.js` return 404 |
| I8 | Path traversal blocked | All traversal attempts return 400 or 404 |
| I9 | Host header injection blocked | `Host: evil.com` returns 403 (Cloudflare blocks) |
| I10 | Direct IP bypass blocked | Direct IP access doesn't serve site content |
| I11 | security.txt present | `/.well-known/security.txt` returns 200 (WARN if 404) |
| I12 | Alt ports not serving content | Ports 8443/2053/2083/2087/2096 return 521 or connection refused |

## Output

Write to `SECURITY_CHECK.parts/infra.md`:

```markdown
### Infrastructure

| # | Test | Result | Evidence |
|---|------|--------|----------|
| I1 | CF trace warp off | {PASS/FAIL} | {trace output} |
...
```

## After

Ask the user: **Do you want help fixing the infrastructure issues found?** If yes, invoke `/chk2:fix` with context about which infra tests failed.

## Status signal

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
