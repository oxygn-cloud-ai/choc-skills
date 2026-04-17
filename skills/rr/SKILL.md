---
name: rr
version: 5.3.10
description: "Risk register assessment for Chocolate Finance. Invoke with /rr followed by a ticket key (e.g. /rr RR-220) or /rr all for batch mode."
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(ls *), AskUserQuestion
argument-hint: [RR-NNN | all | board | status | monitor | fix | update | help | doctor | version]
---

# rr — Risk Register Assessment

## Pre-flight Checks

Before executing, silently verify:

1. **Reference files readable**: Check that `~/.claude/skills/rr/references/schemas/enums.schema.json` exists. If not:
   > **rr error**: Reference files not found at ~/.claude/skills/rr/references/. Run `/rr doctor` to diagnose.

2. **Sub-commands installed**: `ls ~/.claude/commands/rr/*.md` finds files. If not:
   > **rr warning**: Sub-command files not found in ~/.claude/commands/rr/. Running inline.

---

## Routing

Parse $ARGUMENTS and route:

| Argument | Action |
|----------|--------|
| (empty) | Invoke `/rr:help` |
| `help`, `--help`, `-h` | Invoke `/rr:help` |
| `doctor`, `--doctor`, `check` | Invoke `/rr:doctor` |
| `version`, `--version`, `-v` | Invoke `/rr:version` |
| `update`, `--update`, `upgrade` | Invoke `/rr:update` |
| Pattern matching `RR-\d+` (case-insensitive) | Invoke `/rr:review` passing the full $ARGUMENTS |
| `all` (with optional flags/filters after) | Invoke `/rr:all` passing everything after `all` |
| `status` | Invoke `/rr:status` |
| `monitor` | Invoke `/rr:monitor` |
| `board` | Invoke `/rr:board` — generate Board paper |
| `fix` | Invoke `/rr:fix` |
| `remove` | Invoke `/rr:remove` (hidden — testing only) |
| anything else | Invoke `/rr:help` |

If the sub-command `.md` files exist in `~/.claude/commands/rr/`, invoke them via the Skill tool. Otherwise, execute the logic inline using the workflow overview below.

---

## Configuration

| Environment Variable | Default | Purpose |
|---------------------|---------|---------|
| `RR_OUTPUT_DIR` | `~/rr-output` | Directory for individual risk output files |
| `RR_WORK_DIR` | `~/rr-work` | Batch mode working directory |
| `JIRA_CLOUD_ID` | (none) | Required — Atlassian Cloud ID for MCP and API calls |
| `JIRA_EMAIL` | (none) | Required for batch mode Jira REST API |
| `JIRA_API_KEY` | (none) | Required for batch mode Jira REST API |
| `RR_ASSIGNEE_ID` | (none) | Optional — Jira account ID for review ticket assignee |
| `SLACK_WEBHOOK_URL` | (none) | Optional Slack notification on batch completion |

---

## Quick Reference

| Field | Value |
|-------|-------|
| Jira Project | RR |
| Cloud ID | `$JIRA_CLOUD_ID` |
| Issue Types | Risk (parent), Review (child), Mitigation (child) |

### Rating Matrix

| Likelihood x Impact | Rating |
|---------------------|--------|
| High x High | **Critical** |
| High x Medium | High |
| High x Low | Medium |
| Medium x High | High |
| Medium x Medium | Medium |
| Medium x Low | Low |
| Low x High | Medium |
| Low x Medium | Low |
| Low x Low | Low |

### Enum Values

| Field | Allowed Values |
|-------|----------------|
| `likelihood` | Low, Medium, High |
| `impact` | Low, Medium, High |
| `rating` | Low, Medium, High, Critical |
| `risk_category` | A, B, C, D, ER, F, I, L, O, OO, P, T |
| `control_type` | Preventive, Detective, Corrective |
| `control_effectiveness` | Effective, Partially Effective, Ineffective, Uncertain |
| `assessment_status` | draft, adversarial_reviewed, rectified, final |

---

## Single Risk Workflow Overview

If sub-command files are not installed, use this inline fallback. Each step reads its detailed instructions from the reference files.

### Step 1 — Extract and Draft
Read: `~/.claude/skills/rr/references/workflow/step-1-extract.md`
Retrieve target risk from Jira, fetch child tickets, export to JSON, draft initial assessment.

### Step 2 — Adversarial Review
Read: `~/.claude/skills/rr/references/workflow/step-2-adversarial.md`
Challenge Assessment 1 against 8 criteria. Verify regulatory citations via web search.

### Step 3 — Rectified Assessment
Read: `~/.claude/skills/rr/references/workflow/step-3-rectify.md`
Address every challenge from Step 2. Track changes in `changes_from_previous`.

### Step 4 — Discussion
Read: `~/.claude/skills/rr/references/workflow/step-4-discussion.md`
Initiate discussion with user. Ask about unresolved points one at a time. Do NOT wait passively.

### Step 5 — Final Assessment
Read: `~/.claude/skills/rr/references/workflow/step-5-finalise.md`
Incorporate discussion outcomes. Produce final assessment. **Wait for user confirmation** before Step 6.

### Step 6 — Publish to Jira
Read: `~/.claude/skills/rr/references/workflow/step-6-publish.md`
Check for existing same-day Review. Create or update Review child ticket. Attach workflow files.

---

## File Naming Convention

All files saved to `${RR_OUTPUT_DIR:-~/rr-output}/`:

| Pattern | Example |
|---------|---------|
| `<key>_export.json` | `rr-220_export.json` |
| `<key>_<date>_assessment_1.json` | `rr-220_2026-04-02_assessment_1.json` |
| `<key>_<date>_adversarial_review.json` | `rr-220_2026-04-02_adversarial_review.json` |
| `<key>_<date>_assessment_2.json` | `rr-220_2026-04-02_assessment_2.json` |
| `<key>_<date>_discussion.json` | `rr-220_2026-04-02_discussion.json` |
| `<key>_<date>_assessment_final.json` | `rr-220_2026-04-02_assessment_final.json` |
| `<key>_<date>_jira_ticket.json` | `rr-220_2026-04-02_jira_ticket.json` |

- `<key>`: Lowercase with hyphen (e.g., `rr-220`)
- `<date>`: ISO format `yyyy-mm-dd`

---

## Validation

Before each step, validate the previous step's output:

1. JSON parses successfully
2. Required fields present
3. Enum values match allowed lists
4. Ratings follow the matrix

If validation fails, halt and report the error.

---

## Prohibited Actions

- Do not modify the parent Risk item
- Do not modify existing Mitigation or Review tickets
- Do not assign tickets unless instructed
- Do not fabricate regulatory citations
- Do not proceed past Step 5 without user confirmation
