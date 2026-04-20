# rr:review — Single Risk Assessment

Context from user: $ARGUMENTS

## Extract Risk Key

Parse $ARGUMENTS for an RR-NNN pattern (case-insensitive). Normalise to uppercase (e.g. rr-220 becomes RR-220).

If no valid key found, report an error and stop:
> **rr error**: Could not extract a valid risk key from "$ARGUMENTS". Expected format: RR-NNN (e.g. RR-220).

## Configuration

- Output directory: `${RR_OUTPUT_DIR:-~/rr-output}`
- Reference files: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/rr/references/`
- Date stamp: current date in `yyyy-mm-dd` format
- File prefix: lowercase key with hyphen (e.g. `rr-220`)

## Before Starting

Read these reference files:

1. `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/rr/references/schemas/enums.schema.json` — Strict enum values for all fields
2. `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/rr/references/business-context.md` — Chocolate Finance facts and operating context
3. `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/rr/references/jira-config.md` — Jira connection details, field mappings, Cloud ID

Create the output directory if it does not exist:
```bash
mkdir -p ${RR_OUTPUT_DIR:-~/rr-output}
```

## Workflow

Execute each step by reading the step file and following its instructions exactly. All output files are written to the output directory using the file naming convention: `<key>_<date>_<type>.json`.

### Step 1 — Extract and Draft

Read: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/rr/references/workflow/step-1-extract.md`

Execute step 1 instructions:
1. Retrieve the target risk from Jira via MCP tools
2. Fetch all child tickets (Reviews, Mitigations)
3. Export to JSON (`<key>_export.json`)
4. Draft initial assessment (`<key>_<date>_assessment_1.json`)
5. Present summary to user

### Step 2 — Adversarial Review

Read: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/rr/references/workflow/step-2-adversarial.md`

Execute step 2 instructions:
1. Challenge Assessment 1 against 8 adversarial criteria
2. Verify all regulatory citations via web search
3. Produce adversarial review (`<key>_<date>_adversarial_review.json`)
4. Present challenges to user

Proceed immediately to Step 3 — do not wait for user input.

### Step 3 — Rectified Assessment

Read: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/rr/references/workflow/step-3-rectify.md`

Execute step 3 instructions:
1. Address every challenge from Step 2
2. Correct ratings or justify retention with evidence
3. Track all changes in `changes_from_previous` field
4. Produce Assessment 2 (`<key>_<date>_assessment_2.json`)

Proceed immediately to Step 4 — do not wait for user input.

### Step 4 — Discussion

Read: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/rr/references/workflow/step-4-discussion.md`

Initiate discussion with user. Do NOT wait passively — ask the first question immediately:
1. Identify unresolved points from Step 2/3
2. Ask about each uncertainty one at a time
3. Handle user challenges and counter-arguments
4. Update discussion log (`<key>_<date>_discussion.json`)
5. Continue until all points resolved or user requests progression

### Step 5 — Final Assessment

Read: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/rr/references/workflow/step-5-finalise.md`

Produce final assessment:
1. Incorporate all discussion outcomes from Step 4
2. Produce final assessment (`<key>_<date>_assessment_final.json`)
3. Present final ratings and recommendations to user
4. **WAIT for explicit user confirmation before proceeding to Step 6**

If the user requests changes, update the assessment and re-present. Do not proceed until the user confirms.

### Step 6 — Publish to Jira

Read: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/rr/references/workflow/step-6-publish.md`

Publish to Jira:
1. Check for existing same-day Review child ticket
2. Render final assessment to markdown for Jira description
3. Create or update Review ticket in Jira via MCP tools
4. Attach all workflow JSON files to the Review ticket
5. Confirm completion with ticket link

## Completion

Report to user:
- Review ticket key and link
- Inherent risk rating (likelihood x impact = rating)
- Residual risk rating (likelihood x impact = rating)
- Number of recommendations
- List of files created in output directory
