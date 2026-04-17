---
name: ra:publish
description: "Publish a completed assessment to Jira RA project"
allowed-tools: Read, Grep, Glob, Bash(curl *), Bash(jq *), Bash(ls *), Bash(mkdir *), Bash(echo *), Write, AskUserQuestion
---

# ra:publish — Publish Assessment to Jira

## IMPORTANT: MCP call-spec variable substitution (CPT-103)

The MCP call specs below reference `$JIRA_CLOUD_ID` (and `$RR_ASSIGNEE_ID`) as placeholders. **The MCP layer does not expand shell variables** — parameter strings are passed literally. Before calling any MCP tool, Claude MUST substitute the placeholder with the value from the corresponding environment variable (e.g. via `echo "$JIRA_CLOUD_ID"`). Do NOT pass the literal string `"$JIRA_CLOUD_ID"` as the `cloudId` parameter.

Context from user: $ARGUMENTS

## Parse Arguments
- `--dry-run` flag: preview without creating tickets
- Optional: path to assessment directory (default: most recent in RA_OUTPUT_DIR)

## Configuration
Read: `~/.claude/skills/ra/references/jira-config.md`

## Pre-requisites
1. `assessment_final.json` must exist in the specified directory
2. JIRA_EMAIL and JIRA_API_KEY must be set (read from ~/.jira-auth file if available, same pattern as rr)

## Publication Flow

### 1. Read Assessment
Read `assessment_final.json` from the output directory.

### 2. Check Idempotency
Search Jira: `project = RA AND issuetype = Epic AND summary ~ "<subject-slug>"`
If found: warn user and ask whether to create new or update existing.

### 3. Dry Run (if --dry-run)
Display what would be created:
- 1 Epic: "Assessment: <title>"
- N Tasks: "Finding: <finding-title>" (one per finding)
- M Sub-tasks: "Mitigation: <mitigation-title>" (under respective findings)
- 6 attachments to Epic
Stop here if dry run.

### 4. Create Epic
```
mcp__plugin_atlassian_atlassian__createJiraIssue
  cloudId: "$JIRA_CLOUD_ID"
  projectKey: "RA"
  issueTypeName: "Epic"
  summary: "Assessment: <title>"
  description: <rendered markdown of assessment summary>
  assignee_account_id: "$RR_ASSIGNEE_ID"
  contentFormat: "markdown"
  additional_fields:
    labels: ["<Qn-Risk-Assessment>"]
```

### 5. Create Finding Tasks
For each finding in assessment_final.json:
```
mcp__plugin_atlassian_atlassian__createJiraIssue
  projectKey: "RA"
  issueTypeName: "Task"
  parent: "<epic-key>"
  summary: "Finding: <finding-title>"
  description: <rendered markdown of finding details including inherent risk, projected residual, epistemic basis>
```

### 6. Create Mitigation Sub-tasks
For each mitigation under each finding:
```
mcp__plugin_atlassian_atlassian__createJiraIssue
  projectKey: "RA"
  issueTypeName: "Sub-task"
  parent: "<task-key>"
  summary: "Mitigation: <mitigation-title>"
  description: <rendered markdown with priority, owner, steps, assumptions, expected effect, confidence>
```

### 7. Attach Files
Attach all 6 JSON files (01_interview, 02_ingest, 03_assessment, 04_discussion, assessment_final, jira_publication) to the Epic via curl.

Read auth from `~/.jira-auth` file (JIRA_EMAIL and JIRA_API_KEY):
```bash
JIRA_AUTH=$(cat ~/.jira-auth 2>/dev/null)
# File format: email:api_key
```

### 8. Write Receipt
Write `jira_publication.json` to the output directory with epic key, finding keys, mitigation keys, attachment status.

### 9. Confirmation
Display: Epic key, Finding keys, Mitigation keys, attachment status, link to Epic in Jira.

## Markdown Rendering

Use these rating badges:
| Rating | Badge |
|--------|-------|
| Critical | :red_circle: Critical |
| High | :orange_circle: High |
| Medium | :yellow_circle: Medium |
| Low | :green_circle: Low |
