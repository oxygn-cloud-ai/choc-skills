# Step 6 — Publish to Jira

## Overview

Create or update a Review child ticket in Jira with the final assessment.

**Input:** `<key>_<date>_assessment_final.json`
**Output:** `<key>_<date>_jira_ticket.json` (Schema: jira-ticket.schema.json)

---

## Check for Existing Same-Day Review

The child tickets were retrieved in Step 1b. Scan for any ticket where:
- Issue type is Review (id 12686)
- Summary contains `Review:` and today's date

### JQL Query
```jql
project = RR AND parent = <parent-key> AND issuetype = Review
```

Check the retrieved tickets for a summary matching: `Review: <yyyy>, <Mmm> <dd>`

---

## Render Final Assessment to Markdown

Convert the final assessment JSON to markdown for the Jira description field.

### Rendering Template

```markdown
## Risk Assessment: <risk_id> – <risk_name>

**Risk Statement:** <risk_statement>

**Risk Category:** <risk_category_name>

**Assessment Date:** <assessment_date>

---

### Context

<context.narrative>

**Business Relevance:**
<context.business_relevance as bullet list>

**Materiality:** <context.materiality_rationale>

---

### Applicable Regulatory Framework

<for each instrument>
1. **<instrument_name>** (<version_date>, <status>)
   <relevance>
</for each>

---

### Inherent Risk Assessment

| Dimension | Rating | Rationale |
|-----------|--------|-----------|
| Likelihood | <likelihood> | <likelihood_rationale> |
| Impact | <impact> | <impact_rationale> |
| **Rating** | **<rating>** | |

---

### Existing Controls

<for each control>
**<id>: <description>**
- Type: <control_type>
- Effectiveness: <effectiveness>
- <effectiveness_rationale if present>
- <gaps if present>
</for each>

---

### Residual Risk Assessment

| Dimension | Rating | Rationale |
|-----------|--------|-----------|
| Likelihood | <likelihood> | <likelihood_rationale> |
| Impact | <impact> | <impact_rationale> |
| **Rating** | **<rating>** | |

<control_effect_summary>

---

### Recommendations

<for each recommendation>
**<id>:** <action>
- Priority: <priority>
- Regulatory Basis: <regulatory_basis>
- Suggested Owner: <suggested_owner if present>
</for each>

---

### Evidences

**Sources Used:**
<bullet list of sources>

**Sources Unavailable:**
<bullet list>

**Caveats:**
<bullet list>
```

---

## Create Jira Ticket JSON

Determine the quarterly label based on assessment month:
- January, February, March → `Q1-Risk-Review`
- April, May, June → `Q2-Risk-Review`
- July, August, September → `Q3-Risk-Review`
- October, November, December → `Q4-Risk-Review`

```json
{
  "ticket_metadata": {
    "parent_key": "RR-220",
    "existing_ticket_key": null,
    "operation": "create",
    "review_date": "2026-03-29",
    "cloud_id": "81a55da4-28c8-4a49-8a47-03a98a73f152",
    "project_key": "RR",
    "issue_type_name": "Review",
    "issue_type_id": "12686"
  },
  "jira_fields": {
    "summary": "Review: 2026, Mar 29",
    "parent": "RR-220",
    "assignee_account_id": "712020:fd08a63d-8c2c-4412-8761-834339d9475c",
    "duedate": "2026-03-29",
    "customfield_10015": "2026-03-29",
    "labels": ["Q1-Risk-Review"]
  },
  "rendered_description": "<full markdown render>",
  "assessment_summary": {
    "risk_id": "RR-220",
    "risk_name": "...",
    "risk_category": "T",
    "inherent_risk": {
      "likelihood": "Medium",
      "impact": "High",
      "rating": "High"
    },
    "residual_risk": {
      "likelihood": "Low",
      "impact": "High",
      "rating": "Medium"
    },
    "controls_count": 5,
    "recommendations_count": 3,
    "critical_recommendations": 1,
    "key_findings": [
      "Inherent risk High due to...",
      "Controls partially effective",
      "Requires additional mitigation for..."
    ],
    "evidences_summary": "Based on Jira register, web search, and user-provided information. Internal policy documentation not available."
  },
  "attachments": [
    {
      "filename": "rr-220_export.json",
      "step": "1c",
      "file_path": "$RR_OUTPUT_DIR/rr-220_export.json",
      "attached": false,
      "attachment_method": "curl_api"
    },
    ...
  ]
}
```

**Save as:** `<key>_<date>_jira_ticket.json`

---

## Execute Jira Operation

### If Creating New Review:

```
mcp__claude_ai_Atlassian__createJiraIssue
Parameters:
  cloudId: "81a55da4-28c8-4a49-8a47-03a98a73f152"
  projectKey: "RR"
  issueTypeName: "Review"
  parent: "<parent-key>"
  summary: "Review: <yyyy>, <Mmm> <dd>"
  description: "<rendered_description>"
  assignee_account_id: "712020:fd08a63d-8c2c-4412-8761-834339d9475c"
  contentFormat: "markdown"
  responseContentFormat: "markdown"
  additional_fields:
    duedate: "<yyyy-MM-dd>"
    customfield_10015: "<yyyy-MM-dd>"
    labels: ["<Qn-Risk-Review>"]
```

Where:
- `duedate` and `customfield_10015` (Start date) = the assessment date
- `labels` = quarterly label based on assessment month (Q1/Q2/Q3/Q4-Risk-Review)

### If Updating Existing Review:

```
mcp__claude_ai_Atlassian__editJiraIssue
Parameters:
  cloudId: "81a55da4-28c8-4a49-8a47-03a98a73f152"
  issueIdOrKey: "<existing-review-key>"
  fields: { "description": "<rendered_description>" }
  contentFormat: "markdown"
  responseContentFormat: "markdown"
```

Do not change the summary or any other field when updating. Only replace the description.

---

## Attach Files

Attach all JSON files from the workflow to the Review ticket.

### Attachment List

| File | Step |
|------|------|
| `<key>_export.json` | 1c |
| `<key>_<date>_assessment_1.json` | 1d |
| `<key>_<date>_adversarial_review.json` | 2 |
| `<key>_<date>_assessment_2.json` | 3 |
| `<key>_<date>_discussion.json` | 4 |
| `<key>_<date>_assessment_final.json` | 5 |
| `<key>_<date>_jira_ticket.json` | 6 |

### Attachment Method

## File Attachment via curl

Use the Bash tool to attach files via Jira REST API:

```bash
curl -s -X POST \
  -u "${JIRA_EMAIL}:${JIRA_API_KEY}" \
  -H "X-Atlassian-Token: no-check" \
  -F "file=@${RR_OUTPUT_DIR}/<filename>" \
  "https://chocfin.atlassian.net/rest/api/3/issue/<review-ticket-key>/attachments"
```

If files exceed size limits, inform the user which files require manual attachment.

---

## Confirmation

After creation or update, confirm:

1. Ticket key (created or updated)
2. Operation performed (create vs update)
3. Brief summary of the final assessment outcome:
   - Inherent risk rating
   - Residual risk rating
   - Number of recommendations
   - Key findings

Example:

> ✅ **Review ticket created: RR-221**
> 
> **Summary:**
> - Inherent Risk: 🟠 High (Medium likelihood × High impact)
> - Residual Risk: 🟡 Medium (Low likelihood × High impact)
> - Recommendations: 3 (1 Critical, 2 Medium)
> 
> **Key Finding:** Control gaps in incident response require immediate attention.
> 
> All 7 workflow files attached to the ticket.

---

## Update Progress File (Batch Mode Only)

If running `/rr all`, update the progress file after each completed risk:

### 1. Read current progress file

Use the Read tool to read `$RR_OUTPUT_DIR/rr-progress.md`

### 2. Update completed risk row

Use the `Edit tool` to change:
```
| N | RR-XXX | T | Summary... | 🔄 current | |
```
To:
```
| N | RR-XXX | T | Summary... | ✅ done | 2026-03-30 14:35 |
```

### 3. Mark next risk as current

Use the `Edit tool` to change:
```
| N+1 | RR-YYY | C | Summary... | ⏳ pending | |
```
To:
```
| N+1 | RR-YYY | C | Summary... | 🔄 current | |
```

### 4. Append to session log

Add entry showing completed risk and any notes.

### 5. Check context and advise user

After updating progress:

```
✅ RR-XXX complete — Review ticket RR-YYY created

Progress: 5/47 (11%)
Next: RR-ZZZ

[Continue to next risk? Context at ~60%]
```

If context is high (~80%+):

```
⚠️ Context limit approaching.

Progress saved. Completed this session: 5 risks
To continue: Start new chat → /rr all

Review will resume from RR-ZZZ.
```
