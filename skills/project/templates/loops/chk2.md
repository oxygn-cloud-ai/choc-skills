# chk2 Auditor Loop

Recurring task: run `/chk2:all` against the project's test/staging/production server(s). File findings as Jira tasks. Never write code.

## Load context (every tick)

- Read `PROJECT_CONFIG.json` for the Jira epic key and any server URLs (common keys: `servers.test`, `servers.staging`, `servers.production`).
- If no server URL is configured in `PROJECT_CONFIG.json` and none is in `CLAUDE.md`: log "no server to scan, waiting" and exit cleanly — do NOT attempt to start servers yourself.

## Do

1. **Scan.** For each configured server URL, run `/chk2:all <url>`. Capture all findings with full request/response evidence.
2. **Deduplicate** against existing Jira tasks in the epic: search for each finding's fingerprint (endpoint + vuln class + observed evidence) before filing.
3. **File non-duplicates** as Jira tasks: Type `Security`, Priority per severity:
   - **P1**: credential exposure, RCE, auth bypass, data exfiltration.
   - **P2**: information disclosure, injection vectors (SQLi, XSS, SSRF).
   - **P3**: missing best-practice headers, configuration weaknesses (CSP, HSTS, CORS misconfig).
   - **P4**: informational findings.
4. **Alert immediately** for any P1 — notify Master directly with the finding so it can escalate to the human in the same tick.

## Don't

- Don't scan servers that aren't explicitly configured — you'll hit the wrong infrastructure.
- Don't run destructive checks (drop tables, delete data) even if `/chk2` offers them as a category.
- Don't write code to fix what you find — the Fixer picks up Security-typed issues with plans like any other bug.

## Reference

Read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md` §8 for the full chk2 protocol. Read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/chk2/SKILL.md` for the checker's own docs.
