---
name: chk2
version: 2.3.17
description: Adversarial security audit for web services. 211 checks across 30 categories. Outputs SECURITY_CHECK.md.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(curl *), Bash(which *), Bash(ls *), Write, AskUserQuestion
argument-hint: [all | quick | headers | tls | dns | cors | api | ws | waf | infra | brute | scale | disclosure | cookies | cache | smuggling | auth | transport | redirect | fingerprint | timing | compression | jwt | graphql | sse | ipv6 | reporting | hardening | negotiation | proxy | business | backend | fix | github | update | help | doctor | version]
---

# chk2 — Adversarial Security Audit

## Subcommands

Check $ARGUMENTS before proceeding. If it matches one of the following subcommands, execute that subcommand and stop.

### help

If $ARGUMENTS equals "help", "--help", or "-h", display the following usage guide and stop.

```
chk2 v2.3.17 — Adversarial Security Audit

USAGE
  /chk2                Run all test categories (~211 checks)
  /chk2 all            Same as above
  /chk2 quick          Fast passive-only subset (headers+tls+dns+cors)
  /chk2 <category>     Run a specific test category
  /chk2 fix            Deep resolution helper for failed checks
  /chk2 github         Log audit findings as GitHub Issues with P1-P4 priority
  /chk2 update         Update chk2 to the latest version
  /chk2 help           Display this usage guide
  /chk2 doctor         Check environment health
  /chk2 version        Show installed version

CATEGORIES — Core (131 checks)
  headers      HTTP security headers (14 checks)
  tls          TLS/SSL, ciphers, certs, renegotiation, H3 (12 checks)
  dns          DNS, DNSSEC, SPF, DMARC, subdomain takeover (15 checks)
  cors         CORS policy, WebSocket origin (8 checks)
  api          Injection, fuzzing, type confusion, param pollution (17 checks)
  ws           WebSocket security, subprotocol, cross-protocol (13 checks)
  waf          WAF rules, rate limiting, SSRF, bot mgmt (12 checks)
  infra        Cloudflare config, paths, error pages (12 checks)
  brute        Session enumeration, entropy (8 checks)
  scale        Connection limits, payload sizes, Slowloris, ReDoS (10 checks)
  disclosure   Information leakage, error handling (10 checks)

CATEGORIES — Extended (80 checks)
  cookies      Cookie security: HttpOnly, Secure, SameSite (5 checks)
  cache        Cache security and deception (5 checks)
  smuggling    HTTP request smuggling (4 checks)
  auth         Session fixation, IDOR, privilege escalation (7 checks)
  transport    HTTP/2, ALPN, Content-Type enforcement (5 checks)
  redirect     Open redirect and redirect chains (4 checks)
  fingerprint  COOP, COEP, CORP, CT, HSTS preload (6 checks)
  timing       Timing attacks and race conditions (4 checks)
  compression  BREACH, CRIME, decompression bombs (3 checks)
  jwt          JWT alg:none, confusion, expiration, kid (4 checks)
  graphql      Introspection, depth, batching, suggestions (4 checks)
  sse          SSE auth, connection limits, cross-origin (3 checks)
  ipv6         IPv6 policy consistency and WAF bypass (3 checks)
  reporting    Report-To, NEL, security.txt compliance (4 checks)
  hardening    ETag inode, ranges, header size, CRLF (5 checks)
  negotiation  Content-Type mismatch, polyglot, error types (3 checks)
  proxy        Preflight cache, CDN bypass, mesh leak (4 checks)
  business     Replay, cross-session, rate limit bypass (4 checks)
  backend      Error fingerprinting, favicon, timing (3 checks)

OUTPUT
  Results written to SECURITY_CHECK.md in the current repo root.
  Each test shows PASS, FAIL, or WARN with evidence.

TARGET
  https://myzr.io (configurable via CHK2_TARGET env var)

LOCATION
  ~/.claude/skills/chk2/SKILL.md
  ~/.claude/commands/chk2/*.md (sub-commands)
```

End of help output. Do not continue.

### doctor

If $ARGUMENTS equals "doctor", "--doctor", or "check", run environment diagnostics and stop.

**Checks:**
1. Verify `curl` is available: `which curl`
2. Verify `dig` is available: `which dig`
3. Verify `openssl` is available: `which openssl`
4. Verify `python3` is available: `which python3`
5. Verify `websockets` python package: `python3 -c "import websockets" 2>&1`
6. Verify `jq` is available: `which jq` (required by `/chk2 auth` AU3 concurrent-session pipeline; missing jq silently produces zero AU3 evidence)
7. Verify target is reachable: `curl -s --max-time 10 --connect-timeout 5 -o /dev/null -w "%{http_code}" https://myzr.io/`
8. Verify sub-command files exist: `ls ~/.claude/commands/chk2/*.md`
9. Report installed skill version

Format:
```
chk2 doctor — Environment Health Check

  [PASS] curl: /usr/bin/curl
  [PASS] dig: /usr/bin/dig
  [PASS] openssl: /usr/bin/openssl
  [PASS] python3: /usr/bin/python3
  [PASS] websockets: installed
  [PASS] jq: /usr/bin/jq
  [PASS] target reachable: https://myzr.io/ (200)
  [PASS] sub-commands: 35 files in ~/.claude/commands/chk2/
  [PASS] version: X.Y.Z

  Result: N passed, N warnings, N failed
```

End of doctor output. Do not continue.

### version

If $ARGUMENTS equals "version", "--version", or "-v", output the version and stop.

```
chk2 v2.3.17
```

End of version output. Do not continue.

---

## Pre-flight Checks

Before executing, silently verify:

1. **curl available**: `which curl`. If not found:
   > **chk2 error**: curl is not installed or not in PATH.

2. **jq available (only for `auth` and `all`)**: if `$ARGUMENTS` is empty, `all`, or starts with `auth`, run `which jq`. If not found (and only in that case):
   > **chk2 error**: jq is not installed or not in PATH. `/chk2 auth` AU3 depends on jq; running without it silently drops concurrent-session evidence. Install jq and re-run.
   >
   > Other categories (`/chk2 headers`, `/chk2 tls`, `/chk2 dns`, `/chk2 fix`, `/chk2 update`, etc.) don't use jq and are not blocked by this check. Run `/chk2 doctor` to see jq status regardless of which category you're running (CPT-135: scoped from CPT-98's over-broad pre-flight).

3. **Target reachable**: `curl -s --max-time 10 --connect-timeout 5 -o /dev/null -w "%{http_code}" https://myzr.io/` returns 200. If not:
   > **chk2 error**: Target https://myzr.io/ is not reachable (HTTP {code}). Check the server is running.

4. **Sub-commands installed**: `ls ~/.claude/commands/chk2/*.md` finds files. If not:
   > **chk2 warning**: Sub-command files not found in ~/.claude/commands/chk2/. Running inline.

---

## Routing

The target URL is `https://myzr.io` unless the environment variable `CHK2_TARGET` is set.

Parse $ARGUMENTS and route:

| Argument | Action |
|----------|--------|
| (empty) or `all` | Run all categories (see All section below) |
| `quick` | Run headers, tls, dns, cors only (skip WS tests in cors) |
| `headers` | Run Headers category |
| `tls` | Run TLS category |
| `dns` | Run DNS category |
| `cors` | Run CORS category |
| `api` | Run API category |
| `ws` | Run WebSocket category |
| `waf` | Run WAF category |
| `infra` | Run Infrastructure category |
| `brute` | Run Brute Force category |
| `scale` | Run Scaling category |
| `disclosure` | Run Disclosure category |
| `cookies` | Run Cookies category |
| `cache` | Run Cache category |
| `smuggling` | Run Smuggling category |
| `auth` | Run Auth category |
| `transport` | Run Transport category |
| `redirect` | Run Redirect category |
| `fingerprint` | Run Fingerprint category |
| `hardening` | Run Hardening category |
| `negotiation` | Run Negotiation category |
| `proxy` | Run Proxy category |
| `business` | Run Business Logic category |
| `backend` | Run Backend category |
| `timing` | Run Timing category |
| `compression` | Run Compression category |
| `jwt` | Run JWT/Token Security category |
| `graphql` | Run GraphQL category |
| `sse` | Run SSE Security category |
| `ipv6` | Run IPv6 Security category |
| `reporting` | Run Reporting & Compliance category |
| `fix` | Run Fix helper (reads existing SECURITY_CHECK.md) |
| `github` | Run `/chk2:github` — log findings to GitHub Issues |
| `update` | Run `/chk2:update` — update chk2 to the latest version |

If the sub-command `.md` files exist in `~/.claude/commands/chk2/`, invoke them via the Skill tool. Otherwise, execute the tests inline using the definitions below.

---

## Sub-skill → orchestrator contract (CHK2-STATUS)

When a category sub-skill runs under `/chk2:all` (via the Agent tool), it **must** end its response with exactly one final line so the orchestrator's rate-limit circuit breaker can track wave state:

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete

The orchestrator parses only the last `CHK2-STATUS:` line in each sub-agent's return text — free-text mentions of "429" inside evidence are not signals. After each wave, the orchestrator increments a `rate_limited_streak` counter on a `RATE_LIMITED` wave, resets it to 0 on an `OK` wave, and aborts remaining waves once the streak reaches 3.

## Output Format

All results are written to `SECURITY_CHECK.md` in the repo root.

Initialize with:
```markdown
# Security Check — myzr.io

**Date**: {current UTC date and time}
**Tests run**: {category or "all"}
**Target**: https://myzr.io
```

Each category appends:
```markdown
### {Category Name}

| # | Test | Result | Evidence |
|---|------|--------|----------|
| {id} | {test name} | PASS/FAIL/WARN | {brief evidence} |
```

After all categories, append:
```markdown
## Summary

| Category | Pass | Fail | Warn | Total |
|----------|------|------|------|-------|
| ... |

**Overall**: X passed, Y failed, Z warnings out of N tests

## Recommendations

{Numbered list of actionable fixes for FAIL/WARN items, ordered by severity}
```

---

## After Every Run

After completing any test category (or all), ask the user:

> **Do you want help fixing the issues found?** If yes, I'll walk through each FAIL and WARN item with specific code changes, Cloudflare config steps, and verification commands.

If the user says yes, invoke `/chk2:fix` (or run the fix logic inline if sub-commands aren't installed).

---

## Rate Limit Handling

If any test returns HTTP 429 or Cloudflare error 1015:
1. Log: `[RATE LIMITED] Waiting 65 seconds...`
2. Wait 65 seconds
3. Retry the request once
4. If still rate limited, mark the test as `WARN — rate limited, could not test`

---

## Test Category Definitions

If sub-command files are not installed, use these inline definitions. Each category lists the tests to run, the pass conditions, and the output format. See the sub-command files in `~/.claude/commands/chk2/` for the full test specifications — they are the authoritative source.

### Headers (14 checks)
Test HTTP security headers via `curl -sI`. Check HSTS, CSP, X-Frame-Options, CORS, referrer policy, etc.

### TLS (12 checks)
Test TLS versions via `openssl s_client`. Check SSLv3/TLS1.0/1.1 disabled, TLS1.2/1.3 enabled, cipher strength, OCSP, renegotiation, client certs, HTTP/3.

### DNS (15 checks)
Test DNS records via `dig`. Check DNSSEC, SPF, DMARC, NS, CAA, subdomain takeover, zone transfer, MX, DANE.

### CORS (8 checks)
Test CORS headers and WebSocket origin validation. Check wildcard, preflight, evil origin on WS.

### API (17 checks)
Fuzz API with type confusion, NoSQL injection, prototype pollution, command injection, template injection, unknown actions, malformed payloads, parameter pollution, XXE, path traversal.

### WebSocket (13 checks)
Test WS origin validation, connection limits, message flood, invalid types, binary frames, oversized messages, subprotocol enforcement, cross-protocol attacks.

### WAF (12 checks)
Test scanner UA blocking, rate limiting threshold, HTTP method restrictions, SSRF prevention, bot management, payload inspection.

### Infrastructure (12 checks)
Check CF trace, error page origin leak, source file exposure, sensitive paths, path traversal, host header injection, direct IP bypass.

### Brute Force (8 checks)
Test session ID and pair code entropy, weak ID rejection, enumeration resistance.

### Scaling (10 checks)
Test large payloads, deep nesting, concurrent sessions, WS connection limits, WS message rate, Slowloris, ReDoS, connection exhaustion.

### Disclosure (10 checks)
Test error page content, stack traces, health endpoint info, game data authentication, version headers, method handling.

### Cookies (5 checks)
Test cookie security flags: HttpOnly, Secure, SameSite attributes, sensitive data in cookie values, Domain scope.

### Cache (5 checks)
Test cache security: Cache-Control on API, authenticated content caching, web cache deception, CDN cache-key correctness, Pragma header.

### Smuggling (4 checks)
Test HTTP request smuggling defenses: CL.TE desync, TE.CL desync, duplicate Content-Length, HTTP/2 downgrade safety.

### Auth (7 checks)
Test authentication and session security: session fixation, invalidation, concurrent limits, timeout, IDOR, mass assignment, privilege escalation.

### Transport (5 checks)
Test transport layer: HTTP/2 support, ALPN negotiation, HTTP/1.0 handling, Content-Type enforcement, Content-Length validation.

### Redirect (4 checks)
Test redirect security: open redirect via query params, Host header redirect, X-Forwarded-Host redirect, redirect chain cleanliness.

### Fingerprint (6 checks)
Test fingerprinting-resistance headers: Permissions-Policy, COOP, COEP, CORP, Certificate Transparency SCT, HSTS preload status.

### Hardening (5 checks)
Test server hardening: ETag inode leak, Accept-Ranges abuse, request header size limits, HTTP trailer injection, CRLF response header injection.

### Negotiation (3 checks)
Test content negotiation security: Content-Type mismatch on API, polyglot file upload, error response Content-Type consistency.

### Proxy (4 checks)
Test proxy/CDN behavior: CORS preflight cache poisoning, CDN cache key normalization, service mesh header leaks, load balancer fingerprinting.

### Business Logic (4 checks)
Test business logic: replay attacks, cross-session state leakage, concurrent rate limit bypass, predictable resource IDs.

### Backend (3 checks)
Test backend fingerprinting: error behavior patterns, default favicon hash, timing-based detection.

### Timing (4 checks)
Test timing security: constant-time session lookup, timing leak on pair codes, race conditions on game actions, idempotency on creation.

### Compression (3 checks)
Test compression attacks: BREACH via HTTP compression on authenticated responses, CRIME via TLS-level compression, decompression bomb resistance.

### JWT (4 checks)
Test JWT/token security: alg:none bypass, RS256-to-HS256 confusion, expiration enforcement, kid header injection.

### GraphQL (4 checks)
Test GraphQL security: introspection disabled, query depth limiting, batch query abuse, field suggestion information leak.

### SSE (3 checks)
Test Server-Sent Events security: authentication required, connection limits, cross-origin access control.

### IPv6 (3 checks)
Test IPv6 security: policy consistency with IPv4, WAF bypass prevention, IPv6 address disclosure in headers.

### Reporting (4 checks)
Test security reporting: Report-To/Reporting-Endpoints header, NEL header, security.txt PGP signature, security.txt Expires validity.

### Fix
Read existing SECURITY_CHECK.md. For every FAIL and WARN, provide deep resolution: exact Cloudflare dashboard paths, copy-pasteable server code, DNS records, and verification commands. Group by effort level (instant / quick / deeper).

### Github
Read existing SECURITY_CHECK.md and create a GitHub Issue for every FAIL and WARN finding, with P1-P4 priority labels and category labels. Skips findings that already have an open issue (comments instead). See `~/.claude/commands/chk2/github.md` for full details.

### Update
Update chk2 to the latest version from the GitHub repo. Uses `~/.claude/skills/chk2/.source-repo` if present, otherwise falls back to a curl-based update. See `~/.claude/commands/chk2/update.md` for full details.
