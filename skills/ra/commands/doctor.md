---
name: ra:doctor
description: "Environment health check for ra"
allowed-tools: Read, Bash(which *), Bash(ls *), Bash(python3 *)
---

# ra:doctor — Environment Health Check

Run checks:
1. curl available: `which curl`
2. jq available: `which jq`
3. Env vars (report set/not set, NEVER display values): JIRA_EMAIL, JIRA_API_KEY
3b. Jira auth file: check if `~/.jira-auth` exists (used by `/ra:publish` for file attachments). WARN if missing.
4. Reference files exist:
   - `~/.claude/skills/ra/references/schemas/enums.schema.json`
   - `~/.claude/skills/ra/references/business-context.md`
   - `~/.claude/skills/ra/references/jira-config.md`
   - `~/.claude/skills/ra/references/quality-standards.md`
5. Workflow step files exist (6 files):
   - `~/.claude/skills/ra/references/workflow/step-1-interview.md`
   - `~/.claude/skills/ra/references/workflow/step-2-ingest.md`
   - `~/.claude/skills/ra/references/workflow/step-3-assess.md`
   - `~/.claude/skills/ra/references/workflow/step-4-adversarial.md`
   - `~/.claude/skills/ra/references/workflow/step-5-discuss.md`
   - `~/.claude/skills/ra/references/workflow/step-6-output.md`
6. Sub-commands: `ls ~/.claude/commands/ra/*.md` (expect 7 files)
7. Output directory writable: check `${RA_OUTPUT_DIR:-~/ra-output}` exists or can be created
8. Atlassian MCP connectivity: attempt search `project = RA AND issuetype = Epic` limit 1
9. Slack MCP connectivity: non-blocking WARN if not available

Output format:
```
ra doctor — Environment Health Check

  [PASS] curl: /usr/bin/curl
  [PASS] jq: /usr/bin/jq
  [PASS] JIRA_EMAIL: set
  [WARN] JIRA_API_KEY: not set
  [PASS] reference files: 4 files found
  [PASS] workflow steps: 6 files found
  [PASS] sub-commands: 7 files in ~/.claude/commands/ra/
  [PASS] output directory: writable
  [PASS] Atlassian MCP: connected
  [WARN] Slack MCP: not available
  [PASS] version: 1.0.0

  Result: N passed, N warnings, N failed
```
