# Step 1 — Extract and Draft Assessment

## Overview

This step retrieves the target risk from Jira, exports it, and produces the initial draft assessment.

**Outputs:**
- `<key>_export.json` (Schema: jira-export.schema.json)
- `<key>_<date>_assessment_1.json` (Schema: assessment.schema.json)

---

## 1a. Identify and Retrieve the Target Risk

The user will provide one of:
- A specific ticket key (e.g., `RR-220`)
- A risk description or scenario to match against the register
- A batch instruction (e.g., 'review all Technology risks')

### If ticket key provided:

```
mcp__claude_ai_Atlassian__getJiraIssue
Parameters:
  cloudId: "$JIRA_CLOUD_ID"
  issueIdOrKey: "<key>"
  responseContentFormat: "markdown"
```

Or search:

```
mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql
Parameters:
  cloudId: "$JIRA_CLOUD_ID"
  jql: "project = RR AND key = <key>"
  fields: ["summary", "description", "status", "issuetype", "priority", "created", "parent"]
  responseContentFormat: "markdown"
```

### If description/scenario provided:

Search the register using JQL or Rovo Search to identify matching parent Risk item(s). Present matches for user confirmation before proceeding.

### If `/rr all` command:

**FIRST: Check for existing progress file**

Use the Read tool to read `$RR_OUTPUT_DIR/rr-progress.md`

**If progress file exists with pending items:**
- Parse the table to find first `🔄 current` or `⏳ pending` risk
- Resume from that risk (do not re-query Jira for full list)
- Confirm with user: "Resuming batch from RR-XXX (Y/N completed). Continue?"

**If progress file does not exist or user specifies `--reset`:**

1. Query all top-level Risk items:

```
mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql
Parameters:
  cloudId: "$JIRA_CLOUD_ID"
  jql: "project = RR AND issuetype = Risk ORDER BY key ASC"
  fields: ["summary", "status", "priority"]
  maxResults: 100
  responseContentFormat: "markdown"
```

2. Create `$RR_OUTPUT_DIR/rr-progress.md`:

```markdown
# RR Batch Review Progress

**Started:** <timestamp>
**Filter:** all | <category>
**Total:** <count> risks

## Progress

| # | Key | Category | Summary | Status | Completed |
|---|-----|----------|---------|--------|-----------|
| 1 | RR-XXX | T | ... | 🔄 current | |
| 2 | RR-XXX | C | ... | ⏳ pending | |
...

## Session Log
```

3. Present count and ask for confirmation before starting

4. If `/rr all <category>` provided, filter by prefix:

```jql
project = RR AND issuetype = Risk AND summary ~ "<prefix>*" ORDER BY key ASC
```

**After completing each risk (Step 6):**
- Update progress file: change `🔄 current` → `✅ done` + timestamp
- Mark next risk as `🔄 current`
- Append to session log

---

## 1b. Retrieve Child Tickets

Fetch all child tickets (Reviews, Mitigations) of the parent Risk:

```
mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql
Parameters:
  cloudId: "$JIRA_CLOUD_ID"
  jql: "project = RR AND parent = <parent-key> ORDER BY created DESC"
  fields: ["summary", "description", "status", "issuetype", "created"]
  responseContentFormat: "markdown"
```

---

## 1c. Export to JSON

Create the Jira export JSON conforming to `jira-export.schema.json`:

```json
{
  "export_metadata": {
    "exported_at": "2026-03-29",
    "exported_at_time": "14:30:00",
    "source_ticket": "RR-220",
    "cloud_id": "$JIRA_CLOUD_ID",
    "project_key": "RR"
  },
  "parent_risk": {
    "key": "RR-220",
    "summary": "...",
    "description": "...",
    "status": "Open",
    "priority": "High Risk",
    "category": "T",
    "issue_type_id": "12724",
    "created": "...",
    "updated": "..."
  },
  "child_tickets": [...]
}
```

**Save as:** `<key>_export.json`

---

## 1d. Conduct Draft Assessment

### Reference Files to Load

Before drafting, read:
1. `references/business-context.md` — Chocolate Finance facts
2. `references/regulatory-framework.md` — Applicable instruments
3. `references/schemas/assessment.schema.json` — Output structure

### Assessment Process

1. **Derive category** from ticket key prefix (e.g., `T` → Technology)
2. **Identify applicable regulations** from regulatory-framework.md
3. **Search web** for any regulatory updates or relevant recent events
4. **Apply business context** from business-context.md
5. **Assess inherent risk** using the rating matrix
6. **Enumerate controls** from:
   - Mitigation child tickets
   - Regulatory obligations (must exist by law)
   - Standard LFMC control environments (inferred)
7. **Assess residual risk** after controls
8. **Generate recommendations** grounded in regulatory requirements
9. **Document evidences** — be explicit about what was unavailable

### Output Structure

Create JSON conforming to `assessment.schema.json` with:

```json
{
  "metadata": {
    "ticket_key": "RR-220",
    "assessment_date": "2026-03-29",
    "iteration": 1,
    "status": "draft",
    "previous_iteration_ref": null,
    "assessor": "Claude (Anthropic)"
  },
  "sections": {
    "header": {...},
    "context": {...},
    "regulatory_framework": [...],
    "inherent_risk": {...},
    "existing_controls": [...],
    "residual_risk": {...},
    "recommendations": [...],
    "evidences": {...}
  }
}
```

**Save as:** `<key>_<date>_assessment_1.json`

---

## Validation

Before proceeding to Step 2, verify:

1. All required fields are present
2. All enum values match allowed lists:
   - `likelihood`: Low, Medium, High
   - `impact`: Low, Medium, High
   - `rating`: Low, Medium, High, Critical
   - `control_type`: Preventive, Detective, Corrective
   - `control_effectiveness`: Effective, Partially Effective, Ineffective, Uncertain
3. Rating derivations match the matrix
4. At least one regulatory instrument is cited
5. Evidences section is complete

---

## Present to User

Render both JSON files to markdown and present:
1. The Jira export summary
2. The draft assessment

Do not create a Jira ticket at this stage.
