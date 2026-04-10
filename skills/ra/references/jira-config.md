# Jira Configuration

Technical configuration for the RA (Risk Assessments) project in Jira.

---

## Connection Details

| Parameter | Value |
|-----------|-------|
| **Atlassian Cloud ID** | `81a55da4-28c8-4a49-8a47-03a98a73f152` |
| **Project Key** | `RA` |
| **Project Name** | Risk Assessments |
| **Project ID** | `12400` |

---

## Issue Types

| Issue Type | Jira ID | Hierarchy Level | Purpose |
|------------|---------|-----------------|---------|
| **Epic** | `13217` | 1 (top) | Assessment — one per /ra invocation. Contains subject summary, scope, overall risk profile. |
| **Task** | `13215` | 0 (middle) | Finding — one per identified risk. Contains category, inherent rating, projected residual, rationale. |
| **Sub-task** | `13216` | -1 (bottom) | Recommended Mitigation — under each Finding. Contains title, priority, owner, implementation steps. |

---

## Risk Category Prefixes

| Prefix | Category |
|--------|----------|
| `A` | Audit |
| `B` | Business Continuity Management |
| `C` | Compliance |
| `D` | Product / Design |
| `ER` | Expansion Risk |
| `F` | Financial |
| `I` | Investment |
| `L` | Legal |
| `O` | Operational |
| `OO` | Other Operational |
| `P` | People |
| `T` | Technology |

---

## Priority Levels

| Priority |
|----------|
| Critical |
| High |
| Medium |
| Low |

---

## Default Assignee

All Assessment epics must be assigned to:

| Field | Value |
|-------|-------|
| **Name** | James Shanahan |
| **Account ID** | `712020:fd08a63d-8c2c-4412-8761-834339d9475c` |

---

## Quarterly Labels

Assessment epics must include a quarterly label:

| Assessment Month | Label |
|------------------|-------|
| January–March | `Q1-Risk-Assessment` |
| April–June | `Q2-Risk-Assessment` |
| July–September | `Q3-Risk-Assessment` |
| October–December | `Q4-Risk-Assessment` |

---

## Common JQL Queries

### All assessments
```jql
project = RA AND issuetype = Epic ORDER BY created DESC
```

### Findings for an assessment
```jql
project = RA AND parent = <epic-key> AND issuetype = Task
```

### Mitigations for a finding
```jql
project = RA AND parent = <task-key> AND issuetype = Sub-task
```

### Check for existing assessment by subject
```jql
project = RA AND issuetype = Epic AND summary ~ "<subject-slug>"
```

---

## API Tool Usage

### Create Assessment Epic
```
mcp__plugin_atlassian_atlassian__createJiraIssue
Parameters:
  cloudId: "81a55da4-28c8-4a49-8a47-03a98a73f152"
  projectKey: "RA"
  issueTypeName: "Epic"
  summary: "<assessment-title>"
  description: "<rendered-markdown>"
  assignee_account_id: "712020:fd08a63d-8c2c-4412-8761-834339d9475c"
  contentFormat: "markdown"
  responseContentFormat: "markdown"
  additional_fields:
    labels: ["<Qn-Risk-Assessment>"]
```

### Create Finding Task
```
mcp__plugin_atlassian_atlassian__createJiraIssue
Parameters:
  cloudId: "81a55da4-28c8-4a49-8a47-03a98a73f152"
  projectKey: "RA"
  issueTypeName: "Task"
  parent: "<epic-key>"
  summary: "<finding-title>"
  description: "<rendered-markdown>"
  contentFormat: "markdown"
  responseContentFormat: "markdown"
```

### Create Mitigation Sub-task
```
mcp__plugin_atlassian_atlassian__createJiraIssue
Parameters:
  cloudId: "81a55da4-28c8-4a49-8a47-03a98a73f152"
  projectKey: "RA"
  issueTypeName: "Sub-task"
  parent: "<task-key>"
  summary: "<mitigation-title>"
  description: "<rendered-markdown>"
  contentFormat: "markdown"
  responseContentFormat: "markdown"
```

---

## File Attachment via curl

Use the Bash tool to attach all 6 JSON files to the Assessment Epic:

```bash
curl -s -X POST \
  -u "${JIRA_EMAIL}:${JIRA_API_KEY}" \
  -H "X-Atlassian-Token: no-check" \
  -F "file=@${OUTPUT_DIR}/01_interview.json" \
  -F "file=@${OUTPUT_DIR}/02_ingest.json" \
  -F "file=@${OUTPUT_DIR}/03_assessment.json" \
  -F "file=@${OUTPUT_DIR}/04_discussion.json" \
  -F "file=@${OUTPUT_DIR}/assessment_final.json" \
  -F "file=@${OUTPUT_DIR}/jira_publication.json" \
  "https://chocfin.atlassian.net/rest/api/3/issue/<epic-key>/attachments"
```

Requires `JIRA_EMAIL` and `JIRA_API_KEY` environment variables.

### Attachment Error Codes

| HTTP Code | Meaning | Action |
|-----------|---------|--------|
| 200 | Success | Continue |
| 401 | Authentication failed | Verify JIRA_EMAIL and JIRA_API_KEY |
| 403 | Permission denied | Verify attach permission on ticket |
| 404 | Ticket not found | Verify ticket key |
| 413 | File too large | Jira Cloud limit is 10MB per file |

---

## Idempotency Rules

Before creating an Assessment Epic, search for existing assessments with the same subject:

```jql
project = RA AND issuetype = Epic AND summary ~ "<subject-slug>"
```

- If found: warn user and ask whether to create a new assessment or update existing
- Never silently duplicate assessments
