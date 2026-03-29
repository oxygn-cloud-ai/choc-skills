---
name: chk2
version: 1.0.0
description: Adversarial security audit for web services. Tests headers, TLS, DNS, CORS, API injection, WebSocket, WAF, infrastructure, brute force, scaling, and information disclosure. Outputs SECURITY_CHECK.md.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(*), Write, Agent, AskUserQuestion
argument-hint: [all | quick | headers | tls | dns | cors | api | ws | waf | infra | brute | scale | disclosure | fix | help | doctor | version]
---

# chk2 — Adversarial Security Audit

## Subcommands

Check $ARGUMENTS before proceeding. If it matches one of the following subcommands, execute that subcommand and stop.

### help

If $ARGUMENTS equals "help", "--help", or "-h", display the following usage guide and stop.

```
chk2 v1.0.0 — Adversarial Security Audit

USAGE
  /chk2                Run all test categories (~100 checks)
  /chk2 all            Same as above
  /chk2 quick          Fast passive-only subset (headers+tls+dns+cors)
  /chk2 <category>     Run a specific test category
  /chk2 fix            Deep resolution helper for failed checks
  /chk2 help           Display this usage guide
  /chk2 doctor         Check environment health
  /chk2 version        Show installed version

CATEGORIES
  headers      HTTP security headers (14 checks)
  tls          TLS/SSL versions, ciphers, certs (9 checks)
  dns          DNS, DNSSEC, SPF, DMARC (10 checks)
  cors         CORS policy, WebSocket origin (8 checks)
  api          Injection, fuzzing, type confusion (12 checks)
  ws           WebSocket security deep dive (10 checks)
  waf          WAF rules, rate limiting (10 checks)
  infra        Cloudflare config, paths, error pages (12 checks)
  brute        Session enumeration, entropy (8 checks)
  scale        Connection limits, payload sizes (6 checks)
  disclosure   Information leakage, error handling (10 checks)

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
6. Verify target is reachable: `curl -s -o /dev/null -w "%{http_code}" https://myzr.io/`
7. Verify sub-command files exist: `ls ~/.claude/commands/chk2/*.md`
8. Report installed skill version

Format:
```
chk2 doctor — Environment Health Check

  [PASS] curl: /usr/bin/curl
  [PASS] dig: /usr/bin/dig
  [PASS] openssl: /usr/bin/openssl
  [PASS] python3: /usr/bin/python3
  [PASS] websockets: installed
  [PASS] target reachable: https://myzr.io/ (200)
  [PASS] sub-commands: 14 files in ~/.claude/commands/chk2/
  [PASS] version: 1.0.0

  Result: N passed, N warnings, N failed
```

End of doctor output. Do not continue.

### version

If $ARGUMENTS equals "version", "--version", or "-v", output the version and stop.

```
chk2 v1.0.0
```

End of version output. Do not continue.

---

## Pre-flight Checks

Before executing, silently verify:

1. **curl available**: `which curl`. If not found:
   > **chk2 error**: curl is not installed or not in PATH.

2. **Target reachable**: `curl -s -o /dev/null -w "%{http_code}" https://myzr.io/` returns 200. If not:
   > **chk2 error**: Target https://myzr.io/ is not reachable (HTTP {code}). Check the server is running.

3. **Sub-commands installed**: `ls ~/.claude/commands/chk2/*.md` finds files. If not:
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
| `fix` | Run Fix helper (reads existing SECURITY_CHECK.md) |

If the sub-command `.md` files exist in `~/.claude/commands/chk2/`, invoke them via the Skill tool. Otherwise, execute the tests inline using the definitions below.

---

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

### TLS (9 checks)
Test TLS versions via `openssl s_client`. Check SSLv3/TLS1.0/1.1 disabled, TLS1.2/1.3 enabled, cipher strength, OCSP.

### DNS (10 checks)
Test DNS records via `dig`. Check DNSSEC, SPF, DMARC, NS, CAA.

### CORS (8 checks)
Test CORS headers and WebSocket origin validation. Check wildcard, preflight, evil origin on WS.

### API (12 checks)
Fuzz API with type confusion, NoSQL injection, prototype pollution, command injection, template injection, unknown actions, malformed payloads.

### WebSocket (10 checks)
Test WS origin validation, connection limits, message flood, invalid types, binary frames, oversized messages.

### WAF (10 checks)
Test scanner UA blocking, rate limiting threshold, HTTP method restrictions.

### Infrastructure (12 checks)
Check CF trace, error page origin leak, source file exposure, sensitive paths, path traversal, host header injection, direct IP bypass.

### Brute Force (8 checks)
Test session ID and pair code entropy, weak ID rejection, enumeration resistance.

### Scaling (6 checks)
Test large payloads, deep nesting, concurrent sessions, WS connection limits, WS message rate.

### Disclosure (10 checks)
Test error page content, stack traces, health endpoint info, game data authentication, version headers, method handling.

### Fix
Read existing SECURITY_CHECK.md. For every FAIL and WARN, provide deep resolution: exact Cloudflare dashboard paths, copy-pasteable server code, DNS records, and verification commands. Group by effort level (instant / quick / deeper).
