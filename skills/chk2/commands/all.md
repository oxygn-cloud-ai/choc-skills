---
name: chk2:all
description: "Run all security check categories"
allowed-tools: Read, Write, Bash(mkdir *), Bash(cat *), Bash(rm *), AskUserQuestion
---

# chk2:all — Run All Security Checks

Run every test category against https://myzr.io using parallel Agent dispatch. Final results are assembled into `SECURITY_CHECK.md` in the repo root.

## Why per-category part files

Parallel Agent waves (six concurrent writers) cannot safely share a single `SECURITY_CHECK.md` — concurrent Read-modify-Write would silently lose findings (CPT-88). Each sub-skill therefore writes its section to `SECURITY_CHECK.parts/<category>.md` (one writer per file, no race). The orchestrator merges the parts into `SECURITY_CHECK.md` in a fixed, deterministic order after all waves complete.

## Instructions

1. Initialize the output tree:
   - Create the parts directory: `mkdir -p SECURITY_CHECK.parts`
   - Remove any stale per-category files from a previous run: `rm -f SECURITY_CHECK.parts/*.md`
   - Start a fresh `SECURITY_CHECK.md` with the header:
```markdown
# Security Check — myzr.io

**Date**: {current date and time UTC}
**Tests run**: all
**Target**: https://myzr.io
```

2. Dispatch categories in parallel waves using the Agent tool. Each wave launches up to 6 concurrent Agent calls. Each Agent runs one category skill and writes its section to `SECURITY_CHECK.parts/<category>.md` (its own file — no concurrent-write race).

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

3. **Merge per-category part files into SECURITY_CHECK.md** in wave order, deterministically:

   ```bash
   for category in headers tls dns ipv6 reporting disclosure \
                   cors cookies cache hardening negotiation compression \
                   transport redirect fingerprint proxy backend smuggling \
                   auth jwt brute business graphql sse \
                   api ws waf infra scale timing; do
     part="SECURITY_CHECK.parts/${category}.md"
     if [ -f "$part" ]; then
       cat "$part" >> SECURITY_CHECK.md
       echo "" >> SECURITY_CHECK.md
     fi
   done
   ```

   Aborted/skipped waves will have no part files — their categories are simply absent from the merged output, and step 4 below records them as SKIPPED in the summary.

4. After merging, append a summary table and recommendations section to `SECURITY_CHECK.md`:

```markdown
## Summary

| Category | Pass | Fail | Warn | Total |
|----------|------|------|------|-------|
| ... |

**Overall**: X passed, Y failed, Z warnings out of N tests

## Recommendations

{Numbered list of actionable fixes for FAIL/WARN items, ordered by severity}
```

5. Ask the user:

> **Do you want help fixing the issues found?** If yes, I'll walk through each FAIL and WARN item with specific code changes and Cloudflare config steps.

If the user says yes, invoke `/chk2:fix`.
