# Jira Configuration

Technical configuration for the RR (Risk Register) project in Jira.

---

## Connection Details

| Parameter | Value |
|-----------|-------|
| **Atlassian Cloud ID** | `81a55da4-28c8-4a49-8a47-03a98a73f152` |
| **Project Key** | `RR` |
| **Project Name** | Risk Register |

---

## Issue Types

| Issue Type | Jira ID | Hierarchy Level | Purpose |
|------------|---------|-----------------|---------|
| **Risk** | `12724` | 1 (parent) | The risk item itself. Each represents a discrete risk in the register. |
| **Review** | `12686` | 0 (child) | Time-stamped risk assessment. Created as a child of a Risk item. |
| **Mitigation** | `12722` | 0 (child) | A control, action, or remediation linked to a Risk item. |

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
| High Risk |
| Medium Risk |
| Low Risk |

---

## Default Assignee

All Review tickets must be assigned to:

| Field | Value |
|-------|-------|
| **Name** | James Shanahan |
| **Account ID** | `712020:fd08a63d-8c2c-4412-8761-834339d9475c` |

---

## Quarterly Labels

Review tickets must include a quarterly label based on the assessment date:

| Assessment Month | Label |
|------------------|-------|
| January, February, March | `Q1-Risk-Review` |
| April, May, June | `Q2-Risk-Review` |
| July, August, September | `Q3-Risk-Review` |
| October, November, December | `Q4-Risk-Review` |

---

## Statuses

| Status | Notes |
|--------|-------|
| Open (To Do) | Default status |

---

## Common JQL Queries

### Retrieve a specific risk by key
```jql
project = RR AND key = <key>
```

### Retrieve all children of a parent risk
```jql
project = RR AND parent = <parent-key> ORDER BY created DESC
```

### Find existing same-day Review
```jql
project = RR AND parent = <parent-key> AND issuetype = Review AND summary ~ "Review: <yyyy>, <Mmm> <dd>"
```

### Search by category prefix
```jql
project = RR AND issuetype = Risk AND summary ~ "<prefix>*"
```
Example: `summary ~ "T*"` for all Technology risks.

---

## API Tool Usage

### Retrieve Issue
```
mcp__claude_ai_Atlassian__getJiraIssue
Parameters:
  cloudId: "81a55da4-28c8-4a49-8a47-03a98a73f152"
  issueIdOrKey: "<ticket-key>"
  responseContentFormat: "markdown"
```

### Search Issues
```
mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql
Parameters:
  cloudId: "81a55da4-28c8-4a49-8a47-03a98a73f152"
  jql: "<query>"
  fields: ["summary", "description", "status", "issuetype", "priority", "created", "parent"]
  responseContentFormat: "markdown"
```

### Create Review Ticket
```
mcp__claude_ai_Atlassian__createJiraIssue
Parameters:
  cloudId: "81a55da4-28c8-4a49-8a47-03a98a73f152"
  projectKey: "RR"
  issueTypeName: "Review"
  parent: "<parent-risk-key>"
  summary: "Review: <yyyy>, <Mmm> <dd>"
  description: "<rendered-markdown>"
  assignee_account_id: "712020:fd08a63d-8c2c-4412-8761-834339d9475c"
  contentFormat: "markdown"
  responseContentFormat: "markdown"
  additional_fields:
    duedate: "<yyyy-MM-dd>"           # Assessment date
    customfield_10015: "<yyyy-MM-dd>"         # Start date (same as assessment date)
    labels: ["<Qn Risk Review>"]      # Q1/Q2/Q3/Q4 based on month
```

### Update Review Ticket
```
mcp__claude_ai_Atlassian__editJiraIssue
Parameters:
  cloudId: "81a55da4-28c8-4a49-8a47-03a98a73f152"
  issueIdOrKey: "<review-ticket-key>"
  fields: { "description": "<rendered-markdown>" }
  contentFormat: "markdown"
  responseContentFormat: "markdown"
```

---

## File Attachment via curl

Use the Bash tool to attach files to Jira tickets:

```bash
curl -s -X POST \
  -u "${JIRA_EMAIL}:${JIRA_API_KEY}" \
  -H "X-Atlassian-Token: no-check" \
  -F "file=@${RR_OUTPUT_DIR}/<key>_export.json" \
  -F "file=@${RR_OUTPUT_DIR}/<key>_<date>_assessment_1.json" \
  -F "file=@${RR_OUTPUT_DIR}/<key>_<date>_adversarial_review.json" \
  -F "file=@${RR_OUTPUT_DIR}/<key>_<date>_assessment_2.json" \
  -F "file=@${RR_OUTPUT_DIR}/<key>_<date>_discussion.json" \
  -F "file=@${RR_OUTPUT_DIR}/<key>_<date>_assessment_final.json" \
  "https://chocfin.atlassian.net/rest/api/3/issue/<review-ticket-key>/attachments"
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
