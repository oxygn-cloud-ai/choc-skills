# MATTER Project — Jira Configuration

Technical configuration for the Decision Matters (MATTER) Jira project, used for Board Resolutions.

## Connection Details

| Parameter | Value |
|-----------|-------|
| **Atlassian Cloud ID** | `$JIRA_CLOUD_ID` |
| **Project Key** | `MATTER` |
| **Project Name** | Board Resolutions for Chocolate Group |

## Issue Types

| Issue Type | ID | Purpose |
|------------|-----|---------|
| **Resolution Voting** | `11633` | Board resolutions requiring formal vote |

## Required Fields

| Field | Type | Notes |
|-------|------|-------|
| Summary | text | e.g., `Board Risk Oversight Paper: Q1 2026` |
| Issue Type | select | Always `Resolution Voting` |
| Project | select | Always `MATTER` |
| Due Date | date | 14 calendar days from creation (voting deadline) |
| Affiliates | multi-checkbox (`customfield_11617`) | Select applicable entities |

## Optional Fields

| Field | Custom Field ID | Type | Purpose |
|-------|----------------|------|---------|
| Description of Resolution | `customfield_12019` | rich text | Full resolution content |

## Affiliates

The Affiliates field (`customfield_11617`) is a multi-checkbox. For Board Risk Oversight Papers, select **all entities** as the risk register covers the group:

- Chocolate Parent
- Chocfin SG
- Chocfin HK
- Chocfin JP
- Chocfin UAE
- ChocTech

## Summary Format

For Board Risk Oversight Papers:
```
Board Risk Oversight Paper: Q[N] [YYYY]
```

Example: `Board Risk Oversight Paper: Q1 2026`

## Ticket Workflow

| Status | Meaning |
|--------|---------|
| CREATE | Drafting — editable by Company Secretary |
| PLEASE VOTE | Active voting period — Directors vote |
| DONE VOTING | Locked for audit |
| CANCELLED | Resolution withdrawn |

## API Usage

### Create via MCP Tool

```
mcp__claude_ai_Atlassian__createJiraIssue
  cloudId: "$JIRA_CLOUD_ID"
  projectKey: "MATTER"
  issueTypeName: "Resolution Voting"
  summary: "Board Risk Oversight Paper: Q1 2026"
  description: "<board paper markdown — main body>"
  contentFormat: "markdown"
  additional_fields:
    duedate: "<yyyy-MM-dd, 14 days from today>"
    customfield_11617: [all affiliate values]
```

### Attach Files via REST API

```bash
curl -s -X POST \
  -u "${JIRA_EMAIL}:${JIRA_API_KEY}" \
  -H "X-Atlassian-Token: no-check" \
  -F "file=@<filepath>" \
  "https://chocfin.atlassian.net/rest/api/3/issue/<ticket-key>/attachments"
```

## Default Assignee

James Shanahan — Account ID: `$RR_ASSIGNEE_ID`

## Notes

- The MATTER project is distinct from the RR project. RR holds individual risk items; MATTER holds formal Board resolutions.
- Resolution Voting tickets go through a formal voting workflow. Directors vote For/Against/Abstain.
- Legal content fields are auto-populated per affiliate by Jira automation. For Board risk papers, the primary content goes in the description field.
- If the Affiliates field ID changes, discover it at runtime via `getJiraIssueTypeMetaWithFields` for the Resolution Voting issue type.
