# chk2:all — Run All Security Checks

Run every test category against https://myzr.io using parallel Agent dispatch. Write results to `SECURITY_CHECK.md` in the repo root.

## Instructions

1. Initialize `SECURITY_CHECK.md` with the header:
```markdown
# Security Check — myzr.io

**Date**: {current date and time UTC}
**Tests run**: all
**Target**: https://myzr.io
```

2. Dispatch categories in parallel waves using the Agent tool. Each wave launches up to 6 concurrent Agent calls. Each Agent runs one category skill and appends its results to `SECURITY_CHECK.md`.

   **Wave 1 — Passive reconnaissance (no active probing):**
   Launch these 6 categories as parallel Agent calls:
   - `/chk2:headers`
   - `/chk2:tls`
   - `/chk2:dns`
   - `/chk2:ipv6`
   - `/chk2:reporting`
   - `/chk2:disclosure`

   **Wave 2 — Configuration and policy checks:**
   Launch these 6 categories as parallel Agent calls:
   - `/chk2:cors`
   - `/chk2:cookies`
   - `/chk2:cache`
   - `/chk2:hardening`
   - `/chk2:negotiation`
   - `/chk2:compression`

   **Wave 3 — Active probing (moderate request volume):**
   Launch these 6 categories as parallel Agent calls:
   - `/chk2:transport`
   - `/chk2:redirect`
   - `/chk2:fingerprint`
   - `/chk2:proxy`
   - `/chk2:backend`
   - `/chk2:smuggling`

   **Wave 4 — Authentication and session tests:**
   Launch these 6 categories as parallel Agent calls:
   - `/chk2:auth`
   - `/chk2:jwt`
   - `/chk2:brute`
   - `/chk2:business`
   - `/chk2:graphql`
   - `/chk2:sse`

   **Wave 5 — Heavy/rate-sensitive tests (higher request volume):**
   Launch these 6 categories as parallel Agent calls:
   - `/chk2:api`
   - `/chk2:ws`
   - `/chk2:waf`
   - `/chk2:infra`
   - `/chk2:scale`
   - `/chk2:timing`

   **Between waves:** Check for rate-limit signals (429 or 1015 responses). If any Agent in the wave reported a rate limit, wait 65 seconds before starting the next wave. If 3 consecutive waves trigger rate limits, abort remaining waves and report that the target is rate-limiting — do not continue sending requests.

3. After all waves complete, append a summary table and recommendations section to `SECURITY_CHECK.md`:

```markdown
## Summary

| Category | Pass | Fail | Warn | Total |
|----------|------|------|------|-------|
| ... |

**Overall**: X passed, Y failed, Z warnings out of N tests

## Recommendations

{Numbered list of actionable fixes for FAIL/WARN items, ordered by severity}
```

4. Ask the user:

> **Do you want help fixing the issues found?** If yes, I'll walk through each FAIL and WARN item with specific code changes and Cloudflare config steps.

If the user says yes, invoke `/chk2:fix`.
