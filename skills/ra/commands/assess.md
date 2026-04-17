---
name: ra:assess
description: "Interactive bespoke risk assessment — interview, ingest, assess, adversarial review, discuss, output"
allowed-tools: Read, Grep, Glob, Bash(mkdir *), Bash(date *), Bash(shasum *), Bash(ls *), Bash(echo *), Write, Edit, Agent, AskUserQuestion, WebSearch, WebFetch
---

# ra:assess — Interactive Risk Assessment

Context from user: $ARGUMENTS

## Configuration
- Output directory: `${RA_OUTPUT_DIR:-~/ra-output}`
- Reference files: `~/.claude/skills/ra/references/`
- Date stamp: current date in `yyyy-mm-dd` format

## Before Starting

Read these reference files:
1. `~/.claude/skills/ra/references/schemas/enums.schema.json`
2. `~/.claude/skills/ra/references/business-context.md`
3. `~/.claude/skills/ra/references/quality-standards.md`

## Workflow

The reference files loaded above are already in context for all step files below. Do not re-read them when step files reference the same schemas or business context.

Execute each step by reading the step file and following its instructions exactly.

### Step 1 — Interview
Read: `~/.claude/skills/ra/references/workflow/step-1-interview.md`

Execute: adaptive conversation, scope confirmation, material gathering.

Output: `01_interview.json`

### Step 2 — Ingest
Read: `~/.claude/skills/ra/references/workflow/step-2-ingest.md`

Execute: fetch, normalise, provenance, subject brief.

Output: `02_ingest.json`

### Step 3 — Assess
Read: `~/.claude/skills/ra/references/workflow/step-3-assess.md`

Execute: categorise, rate, epistemic classify, mitigations, projected residual.

Output: `03_assessment.json` (draft)

### Step 4 — Adversarial Review
Read: `~/.claude/skills/ra/references/workflow/step-4-adversarial.md`

Execute: challenge 11 criteria, verify regulatory, rectify.

Updates: `03_assessment.json` (rectified)

### Step 5 — Discuss
Read: `~/.claude/skills/ra/references/workflow/step-5-discuss.md`

Execute: present findings, walk through with user, handle deferred items.

Output: `04_discussion.json`

### Step 6 — Output
Read: `~/.claude/skills/ra/references/workflow/step-6-output.md`

Execute: finalise, write all files.

Output: `assessment_final.json`

Create output directory: `mkdir -p ${RA_OUTPUT_DIR:-~/ra-output}/<date>_<subject-slug>`

## Completion

Report: number of findings by severity, overall risk profile, files created, next step (/ra:publish).
