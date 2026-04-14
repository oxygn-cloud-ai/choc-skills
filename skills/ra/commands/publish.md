---
name: ra:publish
description: "Publish a completed assessment to Jira RA project"
allowed-tools: Read, Grep, Glob, Bash(curl *), Bash(jq *), Bash(ls *), Bash(mkdir *), Write, AskUserQuestion
---

# ra:publish — Publish Assessment to Jira

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
  cloudId: "81a55da4-28c8-4a49-8a47-03a98a73f152"
  projectKey: "RA"
  issueTypeName: "Epic"
  summary: "Assessment: <title>"
  description: <rendered markdown of assessment summary>
  assignee_account_id: "712020:fd08a63d-8c2c-4412-8761-834339d9475c"
  contentFormat: "markdown"
  additional_fields:
    labels: ["<Qn-Risk-Assessment>"]
```

### 5. Create Finding Tasks (Wave 2 — parallel)

Create ALL finding tasks in a single message with parallel MCP tool calls. All findings are independent and share the same parent (the Epic key from step 4).

For each finding in assessment_final.json, call in parallel:
```
mcp__plugin_atlassian_atlassian__createJiraIssue
  projectKey: "RA"
  issueTypeName: "Task"
  parent: "<epic-key>"
  summary: "Finding: <finding-title>"
  description: <rendered markdown of finding details including inherent risk, projected residual, epistemic basis>
```

Collect all returned finding keys and map them to their findings for step 6.

### 6. Create Mitigation Sub-tasks (Wave 3 — parallel)

Create ALL mitigation sub-tasks across ALL findings in a single message with parallel MCP tool calls. Each mitigation needs its parent finding key (from step 5) but mitigations are independent of each other.

For each mitigation under each finding, call in parallel:
```
mcp__plugin_atlassian_atlassian__createJiraIssue
  projectKey: "RA"
  issueTypeName: "Sub-task"
  parent: "<task-key>"
  summary: "Mitigation: <mitigation-title>"
  description: <rendered markdown with priority, owner, steps, assumptions, expected effect, confidence>
```

**Wave summary:** The full publication uses 3 sequential waves instead of 41+ sequential calls:
- Wave 1: Create Epic (1 call)
- Wave 2: Create all Finding Tasks in parallel (N calls)
- Wave 3: Create all Mitigation Sub-tasks in parallel (M calls)

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
