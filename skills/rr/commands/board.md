---
name: rr:board
description: "Generate board risk oversight paper from completed assessments"
allowed-tools: Read, Grep, Glob, Bash(ls *), Bash(python3 *), Bash(curl *), Bash(bash *), Write, AskUserQuestion
---

# rr:board — Board Risk Oversight Paper

Context from user: $ARGUMENTS

## Parse Arguments

Parse flags from $ARGUMENTS:

- `--qtr:Q1` (or Q2, Q3, Q4) — Quarter for the paper (**REQUIRED**)
- `--year:2026` — Year override (default: current year)
- `--publish` — Skip user confirmation and publish directly to Jira
- `--dry-run` — Generate paper but do not publish to Jira

If `--qtr` is not specified, report error and stop:
> **rr error**: Quarter is required. Usage: `/rr board --qtr:Q1`

## Pre-flight Checks

Verify assessment data exists:
```bash
ls ${RR_WORK_DIR:-~/rr-work}/individual/*.json 2>/dev/null | wc -l
```
If 0: report error and stop:
> No assessment data found at `~/rr-work/individual/`. Run `/rr all` first to generate assessments.

## Phase 1: Data Aggregation

Run the aggregation script via Bash tool:

```bash
python3 ~/.claude/skills/rr/bin/rr-board-aggregate.py \
  --work-dir "${RR_WORK_DIR:-$HOME/rr-work}" \
  --quarter "<Q1|Q2|Q3|Q4>" \
  --year "<YYYY>"
```

If the script fails (non-zero exit), report the error output and stop.

Read the output file:
`${RR_WORK_DIR:-~/rr-work}/board-statistics.json`

## Phase 2: Board Paper Generation

### Read Reference Files

Read ALL of these files using the Read tool:

1. `~/.claude/skills/rr/references/board-paper-template.md` — Paper structure and rules
2. `~/.claude/skills/rr/references/business-context.md` — Chocolate Finance facts
3. `~/.claude/skills/rr/references/regulatory-framework.md` — MAS/SFC instruments
4. `~/.claude/skills/rr/references/quality-standards.md` — Assessment methodology

### Read Critical/High Risk Assessments

For each risk in `critical_high_residual_risks[]` from the statistics, read the full individual assessment:
```
${RR_WORK_DIR:-~/rr-work}/individual/<risk_key>.json
```

### Generate the Board Paper

Follow the template structure EXACTLY (11 main sections + 4 appendices). All rules from the template apply:

- All statistics from `board-statistics.json` — do NOT recompute
- All business assertions grounded in `business-context.md`
- All regulatory references from `regulatory-framework.md`
- British English throughout
- Formal board-paper tone
- Markdown formatting (renders in Jira ADF)
- Blockquotes for formal resolutions
- Tables for quantitative data

### Save Locally

Write the complete paper (all sections including appendices) to:
```
${RR_WORK_DIR:-~/rr-work}/board-paper-<Q>-<YYYY>.md
```

Example: `~/rr-work/board-paper-Q1-2026.md`

## Phase 3: User Review

If `--dry-run` flag is set:
  Report the file location and key metrics, then stop:
  ```
  Board paper generated (dry run — not published).

  File: ~/rr-work/board-paper-Q1-2026.md
  Statistics: ~/rr-work/board-statistics.json

  Key metrics:
    Total risks: N
    Critical (residual): N
    High (residual): N
    Controls: N (X% Uncertain)
    Recommendations: N
  ```
  Stop here. Do not proceed to Phase 4.

If `--publish` flag is NOT set:
  Tell the user the paper has been generated and saved.
  Ask: **"Board paper saved to ~/rr-work/board-paper-Q1-2026.md. Publish to MATTER project as a Resolution Voting ticket? (yes/no)"**

  If user says no: report the file location and stop.

## Phase 4: Jira Publication

### Read MATTER Configuration

Read: `~/.claude/skills/rr/references/matter-jira-config.md`

### Calculate Due Date

Due date = today + 14 calendar days, in `yyyy-MM-dd` format.

### Create Resolution Voting Ticket

Use MCP tool to create the ticket:

```
mcp__claude_ai_Atlassian__createJiraIssue
  cloudId: "$JIRA_CLOUD_ID"
  projectKey: "MATTER"
  issueTypeName: "Resolution Voting"
  summary: "Board Risk Oversight Paper: <Q> <YYYY>"
  description: <Board paper markdown — Sections 0 through 10 (main body only, NOT appendices)>
  contentFormat: "markdown"
  responseContentFormat: "markdown"
  additional_fields: {
    "duedate": "<due date>",
    "customfield_11617": [
      {"value": "Chocolate Parent"},
      {"value": "Chocfin SG"},
      {"value": "Chocfin HK"},
      {"value": "Chocfin JP"},
      {"value": "Chocfin UAE"},
      {"value": "ChocTech"}
    ]
  }
```

**If description is too large** (HTTP 400 or field limit error):
- Put only Sections 0-2 (Document Control, Resolutions, Executive Summary) in the description
- Note that the full paper is attached as a file

### Attach Files

After ticket creation, attach the full paper and statistics via Bash:

```bash
# Read JIRA_AUTH from dedicated credentials file if it exists,
# otherwise require JIRA_EMAIL and JIRA_API_KEY env vars
AUTH_CRED_FILE="$HOME/.claude/skills/rr/.jira-auth"
if [ -f "$AUTH_CRED_FILE" ]; then
  JIRA_AUTH=$(cat "$AUTH_CRED_FILE")
elif [ -n "${JIRA_EMAIL:-}" ] && [ -n "${JIRA_API_KEY:-}" ]; then
  JIRA_AUTH=$(echo -n "${JIRA_EMAIL}:${JIRA_API_KEY}" | base64 | tr -d '\n')
else
  echo "Error: Set JIRA_EMAIL and JIRA_API_KEY env vars, or create $AUTH_CRED_FILE" >&2
  exit 1
fi
curl -s -X POST \
  -H "Authorization: Basic $JIRA_AUTH" \
  -H "X-Atlassian-Token: no-check" \
  -F "file=@${RR_WORK_DIR:-$HOME/rr-work}/board-paper-<Q>-<YYYY>.md" \
  "https://chocfin.atlassian.net/rest/api/3/issue/<TICKET-KEY>/attachments" && \
curl -s -X POST \
  -H "Authorization: Basic $JIRA_AUTH" \
  -H "X-Atlassian-Token: no-check" \
  -F "file=@${RR_WORK_DIR:-$HOME/rr-work}/board-statistics.json" \
  "https://chocfin.atlassian.net/rest/api/3/issue/<TICKET-KEY>/attachments"
```

### CPT Update (non-blocking)

After successful ticket creation, update CPT via Bash:
```bash
~/.claude/skills/rr/bin/_update_cpt.sh board_paper_published "Board Risk Oversight Paper: <Q> <YYYY> published as <TICKET-KEY>" || true
```

## Phase 5: Report

Report to user:

```
Board Risk Oversight Paper published.

Ticket:     MATTER-NNN (https://chocfin.atlassian.net/browse/MATTER-NNN)
Due date:   YYYY-MM-DD (14 days for Board voting)
Paper:      ~/rr-work/board-paper-Q1-2026.md
Statistics: ~/rr-work/board-statistics.json

Key metrics:
  Total risks assessed: N
  Critical (residual):  N
  High (residual):      N
  Controls:             N (X% Uncertain)
  Recommendations:      N
  Appetite breaches:    N of 8

Next: Directors will vote on the four resolutions in Jira.
```

## Error Handling

| Error | Recovery |
|-------|----------|
| No `--qtr` flag | Report usage error, stop |
| No assessment data | "Run `/rr all` first" |
| Aggregation fails | Show Python stderr, stop |
| MATTER project inaccessible | Report permission error |
| Paper too large for Jira | Put summary in description, attach full paper |
| Affiliates field format wrong | Try without affiliates, warn user to set manually |
| File attachment fails | Report error, provide manual instructions |
| User declines publication | Report local file path, stop |
