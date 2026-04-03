# rr:doctor — Environment Health Check

Run these checks and report results. Do not proceed to any other action after.

## Checks

1. Verify `curl` is available: `which curl`
2. Verify `jq` is available: `which jq`
3. Verify `python3` is available: `which python3`
4. Check `rich` is installed: `python3 -c "import rich" 2>/dev/null`
5. Check env vars (report set/not set, **never display values**):
   - `JIRA_EMAIL`
   - `JIRA_API_KEY`
6. Check reference files exist:
   - `ls ~/.claude/skills/rr/references/schemas/enums.schema.json`
   - `ls ~/.claude/skills/rr/references/business-context.md`
   - `ls ~/.claude/skills/rr/references/jira-config.md`
   - `ls ~/.claude/skills/rr/references/workflow/step-1-extract.md`
   - `ls ~/.claude/skills/rr/references/workflow/step-2-adversarial.md`
   - `ls ~/.claude/skills/rr/references/workflow/step-3-rectify.md`
   - `ls ~/.claude/skills/rr/references/workflow/step-4-discussion.md`
   - `ls ~/.claude/skills/rr/references/workflow/step-5-finalise.md`
   - `ls ~/.claude/skills/rr/references/workflow/step-6-publish.md`
7. Check orchestrator scripts exist:
   - `ls ~/.claude/skills/rr/orchestrator/rr-prepare.sh`
   - `ls ~/.claude/skills/rr/orchestrator/rr-finalize.sh`
   - `ls ~/.claude/skills/rr/orchestrator/sub-agent-prompt.md`
   - `ls ~/.claude/skills/rr/orchestrator/monitor.py`
8. Check sub-command files exist:
   - `ls ~/.claude/commands/rr/*.md`
9. Try Atlassian MCP connectivity: attempt `mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql` with JQL `project = RR AND issuetype = Risk` limit 1

## Output Format

```
rr doctor — Environment Health Check

  [PASS] curl: /usr/bin/curl
  [PASS] jq: /usr/bin/jq
  [PASS] python3: /usr/bin/python3
  [PASS] rich: installed
  [PASS] JIRA_EMAIL: set
  [WARN] JIRA_API_KEY: not set
  [PASS] reference files: 9 files found
  [PASS] orchestrator: 4 files found
  [PASS] sub-commands: N files in ~/.claude/commands/rr/
  [PASS] Atlassian MCP: connected (1 result)
  [PASS] version: 4.0.0

  Result: N passed, N warnings, N failed
```

End of doctor output. Do not continue.
