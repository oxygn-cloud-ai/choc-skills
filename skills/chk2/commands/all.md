# chk2:all — Run All Security Checks

Run every test category against https://myzr.io sequentially. Write results to `SECURITY_CHECK.md` in the repo root.

## Instructions

1. Initialize `SECURITY_CHECK.md` with the header:
```markdown
# Security Check — myzr.io

**Date**: {current date and time UTC}
**Tests run**: all
**Target**: https://myzr.io
```

2. Run each category in order by invoking each sub-skill:
   - `/chk2:headers`
   - `/chk2:tls`
   - `/chk2:dns`
   - `/chk2:cors`
   - `/chk2:api`
   - `/chk2:ws`
   - `/chk2:waf`
   - `/chk2:infra`
   - `/chk2:brute`
   - `/chk2:scale`
   - `/chk2:disclosure`

   If you hit a rate limit (429 or 1015), wait 65 seconds before continuing.

3. After all categories complete, append a summary table and recommendations section to `SECURITY_CHECK.md`:

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
