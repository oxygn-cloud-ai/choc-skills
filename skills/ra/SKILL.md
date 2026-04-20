---
name: ra
version: 1.0.9
description: "Bespoke risk assessment for Chocolate Finance. Invoke with /ra to start an interactive assessment, or /ra:publish to push results to Jira."
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(curl *), Bash(jq *), Bash(git *), Bash(shasum *), Bash(ls *), Bash(mkdir *), Bash(echo *), Bash(printf *), Bash(date *), Bash(cat *), Write, Edit, Agent, AskUserQuestion, WebSearch, WebFetch
argument-hint: [assess | publish | status | update | help | doctor | version]
---

# ra — Bespoke Risk Assessment

## Pre-flight Checks
1. Reference files readable: check `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/ra/references/schemas/enums.schema.json` exists
2. Sub-commands installed: `ls ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/ra/*.md`

## Routing

Parse $ARGUMENTS and route:

| Argument | Action |
|----------|--------|
| (empty) | Invoke `/ra:help` |
| `help`, `--help`, `-h` | Invoke `/ra:help` |
| `doctor`, `--doctor`, `check` | Invoke `/ra:doctor` |
| `version`, `--version`, `-v` | Invoke `/ra:version` |
| `update`, `--update`, `upgrade` | Invoke `/ra:update` |
| `assess` | Invoke `/ra:assess` |
| `publish` (with optional flags) | Invoke `/ra:publish` passing flags |
| `status` | Invoke `/ra:status` |
| anything else | Invoke `/ra:help` |

## Configuration

| Environment Variable | Default | Purpose |
|---------------------|---------|---------|
| `RA_OUTPUT_DIR` | `~/ra-output` | Directory for assessment output files |
| `JIRA_CLOUD_ID` | (none) | Required — Atlassian Cloud ID for MCP and API calls |
| `JIRA_EMAIL` | (none) | Required for Jira publication |
| `JIRA_API_KEY` | (none) | Required for Jira publication |
| `RR_ASSIGNEE_ID` | (none) | Optional — Jira account ID for ticket assignee |

## Quick Reference

| Field | Value |
|-------|-------|
| Jira Project | RA |
| Cloud ID | `$JIRA_CLOUD_ID` |
| Issue Types | Epic (Assessment), Task (Finding), Sub-task (Mitigation) |

### Rating Matrix

|                  | **High Likelihood** | **Medium Likelihood** | **Low Likelihood** |
|------------------|--------------------|-----------------------|--------------------|
| **High Impact**  | Critical           | High                  | Medium             |
| **Medium Impact**| High               | Medium                | Low                |
| **Low Impact**   | Medium             | Low                   | Low                |

### Enum Values

| Field | Allowed Values |
|-------|----------------|
| `likelihood` | Low, Medium, High |
| `impact` | Low, Medium, High |
| `risk_rating` | Low, Medium, High, Critical |
| `risk_category` | A, B, C, D, ER, F, I, L, O, OO, P, T |
| `control_type` | Preventive, Detective, Corrective |
| `control_effectiveness` | Effective, Partially Effective, Ineffective, Uncertain |
| `assessment_status` | draft, adversarial_reviewed, rectified, discussed, final |
| `confidence_level` | high, medium, low |
| `epistemic_type` | fact, user_claim, assumption, unknown |
| `subject_type` | document_review, planned_change, issue_incident, concept |
| `source_reliability` | high, medium, low, unknown |

## Assessment Workflow Overview

### Step 1 — Interview
Read: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/ra/references/workflow/step-1-interview.md`

Execute: adaptive conversation to understand the subject, confirm scope, gather materials.

### Step 2 — Ingest
Read: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/ra/references/workflow/step-2-ingest.md`

Execute: fetch, normalise, record provenance, build subject brief.

### Step 3 — Assess
Read: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/ra/references/workflow/step-3-assess.md`

Execute: categorise risks, rate using matrix, epistemic classification, mitigations, projected residual risk.

### Step 4 — Adversarial Review
Read: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/ra/references/workflow/step-4-adversarial.md`

Execute: challenge against 11 criteria, verify regulatory citations, rectify assessment.

### Step 5 — Discuss
Read: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/ra/references/workflow/step-5-discuss.md`

Execute: present findings to user, walk through each finding, handle deferred items.

### Step 6 — Output
Read: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/ra/references/workflow/step-6-output.md`

Execute: finalise all files, write assessment_final.json.

## File Naming Convention

All files saved to `${RA_OUTPUT_DIR:-~/ra-output}/<date>_<subject-slug>/`:
- `01_interview.json`
- `02_ingest.json`
- `03_assessment.json`
- `04_discussion.json`
- `assessment_final.json`
- `jira_publication.json` (created by /ra:publish)

## Prohibited Actions
- Do not fabricate regulatory citations
- Do not use ratings that don't follow the matrix
- Do not proceed past Step 5 without user confirmation
- Do not publish to Jira during assess workflow (separate command)
