---
name: rr:all
description: "Batch risk register review — orchestrate parallel/sequential assessments"
allowed-tools: Read, Grep, Glob, Bash(ls *), Bash(rm *), Bash(date *), Bash(echo *), Bash(sed *), Bash(bash *), Bash(test *), Bash(~/.claude/skills/rr/bin/rr-prepare.sh *), Bash(~/.claude/skills/rr/bin/rr-finalize.sh *), Write, Agent, AskUserQuestion
---

# rr:all — Batch Risk Register Review

Context from user: $ARGUMENTS

## Parse Arguments

Parse any flags or filters from $ARGUMENTS (everything after the `all` keyword):

- `--force` — Set FORCE flag: skip quarterly review date filtering, review all risks regardless of last review date
- `--reset` — Delete all progress and work files, start fresh (confirm with user first before deleting)
- `--qtr:Q1` (or Q2, Q3, Q4) — Override the quarter for Review ticket summaries and labels (e.g., `--qtr:Q1` sets summary to "Review: 2026: Q1" and label to "Q1-Risk-Review")
- Single category letter (T, C, F, A, B, D, ER, I, L, O, OO, P) — Set RR_CATEGORY_FILTER to that value
- Default: no force, no category filter, quarter auto-detected from current date

## Mode Selection

Check if the batch scripts are available by running these checks via Bash:

```bash
test -x ~/.claude/skills/rr/bin/rr-prepare.sh && echo "bin_available"
test -n "${JIRA_EMAIL:-}" && test -n "${JIRA_API_KEY:-}" && echo "jira_creds_set"
```

If BOTH checks pass: use **Agent Orchestrator Mode**.
Otherwise: use **Sequential Mode** (fallback).

Note: ANTHROPIC_API_KEY is NOT required. Sub-agents run via Claude Code Agent tool.

---

## Agent Orchestrator Mode

### Pre-flight

Verify environment variables are set (do not display values):
- `JIRA_EMAIL` — required for Jira REST API authentication
- `JIRA_API_KEY` — required for Jira REST API authentication

### Handle --reset

If `--reset` flag is set:
1. Ask user to confirm: "This will delete the entire batch work directory at ${RR_WORK_DIR:-~/rr-work}. Continue? (y/n)"
2. If confirmed, delegate to the bin script which has symlink validation (CPT-26) and marker-file safety checks:
   ```bash
   ~/.claude/skills/rr/bin/rr-prepare.sh --reset
   ```
3. Report cleared and continue to launch

### Notify User

Tell the user:
```
Batch review starting (runs in this session, ~30-45 min for full register).
Open a second Claude Code session for other work if needed.
Monitor progress: /rr monitor (in separate terminal)
```

### Phase 1-3: Preparation

Build the command with applicable flags and run via Bash tool:

```bash
RR_CATEGORY_FILTER="${category_filter}" ~/.claude/skills/rr/bin/rr-prepare.sh [--force] [--qtr:Q1|Q2|Q3|Q4]
```

Capture the batch count from the last line of stdout. If 0, report "No risks to process" and stop.

### Phase 4: Agent Dispatch

#### Setup

1. Write a phase marker to the batch log:
   ```bash
   echo "[$(date '+%Y-%m-%d %H:%M:%S')] PHASE 4: SUB-AGENT DISPATCH" >> ${RR_WORK_DIR:-~/rr-work}/batch.log
   ```

2. Read the sub-agent prompt template:
   ```
   ~/.claude/skills/rr/bin/sub-agent-prompt.md
   ```

3. List all batch files:
   ```bash
   ls ${RR_WORK_DIR:-~/rr-work}/extracts/batch_*.json | sort -V
   ```

#### Dispatch in Waves

Process batches in waves of up to 5 concurrent agents.

For each wave of batches:

1. For EACH batch in this wave, write a dispatch marker via Bash:
   ```bash
   echo '{"dispatched":true,"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > ${RR_WORK_DIR:-~/rr-work}/payloads/payload_<batch_id>.json
   ```

2. For EACH batch in this wave, spawn an Agent tool call with these settings:
   - **model**: `"opus"`
   - **prompt**: Construct the prompt by combining:
     - A preamble with batch-specific values:
       ```
       Process batch <batch_id>.
       Batch file: <absolute path to extracts/batch_<batch_id>.json>
       Work directory: <absolute path to ${RR_WORK_DIR:-~/rr-work}>
       ```
     - The FULL contents of `sub-agent-prompt.md` read above, with these literal replacements applied:
       - Replace every occurrence of `{{BATCH_ID}}` with the actual batch number
       - Replace every occurrence of `{{BATCH_FILE}}` with the actual absolute path to the batch extract file
       - Replace every occurrence of `{{WORK_DIR}}` with the actual absolute path to the work directory
       - Replace every occurrence of `{{SKILLS_DIR}}` with `~/.claude/skills/rr`

   Launch ALL agents in this wave in a single message (parallel Agent tool calls).

3. After the wave completes, log results for each batch via Bash:
   ```bash
   for id in <batch_ids_in_wave>; do
     if [ -f "${RR_WORK_DIR:-~/rr-work}/results/result_${id}.json" ]; then
       echo "[$(date '+%Y-%m-%d %H:%M:%S')] BATCH_${id}:SUCCESS" >> ${RR_WORK_DIR:-~/rr-work}/batch.log
     else
       echo "[$(date '+%Y-%m-%d %H:%M:%S')] BATCH_${id}:FAILED" >> ${RR_WORK_DIR:-~/rr-work}/batch.log
     fi
   done
   ```

4. Update CPT with wave progress (non-blocking) via Bash:
   ```bash
   ~/.claude/skills/rr/bin/_update_cpt.sh dispatch_progress "Wave N of M complete: X succeeded, Y failed" || true
   ```

5. Proceed to the next wave.

#### Retry Failures

After all waves complete, check for failed batches:
```bash
ls ${RR_WORK_DIR:-~/rr-work}/extracts/batch_*.json | while read f; do
  id=$(basename "$f" | sed 's/batch_//;s/\.json//')
  [ ! -f "${RR_WORK_DIR:-~/rr-work}/results/result_${id}.json" ] && echo "$id"
done
```

For any failed batches (up to 3), retry once by re-spawning an Agent with the same prompt. Log retry outcomes.

#### Dispatch Summary

Log the dispatch summary:
```bash
succeeded=$(ls ${RR_WORK_DIR:-~/rr-work}/results/ 2>/dev/null | wc -l | tr -d ' ')
total=$(ls ${RR_WORK_DIR:-~/rr-work}/extracts/ 2>/dev/null | wc -l | tr -d ' ')
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dispatch complete: ${succeeded}/${total} batches succeeded" >> ${RR_WORK_DIR:-~/rr-work}/batch.log
```

### Phase 5-7: Finalization

Run via Bash tool:

```bash
~/.claude/skills/rr/bin/rr-finalize.sh [--qtr:Q1|Q2|Q3|Q4]
```

### Report to User

```
Batch review complete.

Published: N reviews to Jira
Failed:    M assessments, K publications
Assessed:  P of Q risks

Full report:  ~/rr-work/progress.md
Re-run fails: /rr fix
```

---

## Sequential Mode (Fallback)

Report to user why batch script mode is not available, then proceed sequentially.

### CPT — Sequential Mode Start

At the start of sequential processing, update CPT via Bash (non-blocking):
```bash
~/.claude/skills/rr/bin/_update_cpt.sh started "Sequential mode: processing N risks" || true
```
Do NOT update CPT per-risk (avoids spam). Only update at completion.

### Check for Existing Progress

Check if `${RR_OUTPUT_DIR:-~/rr-output}/rr-progress.md` exists.

**If it exists:**
1. Read the progress file
2. Parse it to find the first `pending` or `current` risk
3. Calculate completion percentage
4. Ask user:
   ```
   Found existing batch review in progress.

   Progress: N/M completed (X%)
   Last completed: RR-NNN (date)
   Next up: RR-NNN

   Continue from RR-NNN? (y/n)
   ```
5. If user says no, offer to reset (delete progress file and start fresh)

**If it does not exist:**
1. Query all Risk items from Jira:
   ```jql
   project = RR AND issuetype = Risk ORDER BY key ASC
   ```
2. If RR_CATEGORY_FILTER is set, add to JQL: `AND "Risk Category" = "X"`
3. Create progress file at `${RR_OUTPUT_DIR:-~/rr-output}/rr-progress.md`:

```markdown
# RR Batch Review Progress

**Started:** {current date and time}
**Filter:** {all | category letter}
**Force:** {yes | no}
**Total:** {count} risks

## Progress

| # | Key | Category | Summary | Status | Completed |
|---|-----|----------|---------|--------|-----------|
| 1 | RR-220 | T | Technology risk... | pending | |
| 2 | RR-221 | C | Compliance risk... | pending | |
...

## Session Log
```

4. Confirm with user before starting

### Pre-Load Workflow Steps

Before processing any risks, read all workflow step files once. These are static reference documents that do not change between risks — loading them once avoids 6×(N-1) redundant file reads **within a single uninterrupted session**.

Read these files now and keep them in context for the batch run:
- `~/.claude/skills/rr/references/workflow/step-1-extract.md`
- `~/.claude/skills/rr/references/workflow/step-2-adversarial.md`
- `~/.claude/skills/rr/references/workflow/step-3-rectify.md`
- `~/.claude/skills/rr/references/workflow/step-5-finalise.md`
- `~/.claude/skills/rr/references/workflow/step-6-publish.md`

**Known limitation — auto-compaction**: Claude Code auto-compacts context as it fills. Compaction can summarise or drop the pre-loaded step content silently. The per-risk loop below therefore includes a re-check step to detect this and re-read on miss. Realistic savings are per-session (until the first compaction or new chat), not per-register — the claim holds for the first ~N risks processed before compaction, then degrades.

### Process Each Risk

For each pending risk in the progress file:

1. Update status to `current` in progress file
2. Execute the full 6-step workflow with **per-phase compaction re-checks** (CPT-133). Before each phase, verify the corresponding pre-loaded step file is still retrievable — recall a known heading from the step file. If the content has been compacted away or is no longer retrievable, re-read that step file on demand and log `pre-load recovered by re-read: <step-name>` to the session log so per-phase degradation is observable (a single "start of risk" check can't catch mid-workflow compaction between, say, Step 2 and Step 5):
   - **Phase 1 — Step 1: Extract and draft.** Verify `step-1-extract.md` heading is still retrievable (re-read on miss), then extract the risk from Jira, fetch child tickets, export to JSON, and draft the initial assessment.
   - **Phase 2 — Step 2: Adversarial review.** Verify `step-2-adversarial.md` heading is still retrievable (re-read on miss), then challenge Assessment 1 against the 8 criteria.
   - **Phase 3 — Step 3: Rectified assessment.** Verify `step-3-rectify.md` heading is still retrievable (re-read on miss), then address every challenge from Step 2.
   - **Phase 4 — Step 4: Discussion.** In batch mode, skip interactive discussion and auto-resolve based on adversarial findings. (No step file is pre-loaded for Step 4 — this phase is batch-mode-only logic and has no re-check.)
   - **Phase 5 — Step 5: Final assessment.** Verify `step-5-finalise.md` heading is still retrievable (re-read on miss), then incorporate the adversarial-driven resolutions and produce the final assessment.
   - **Phase 6 — Step 6: Publish to Jira.** Verify `step-6-publish.md` heading is still retrievable (re-read on miss), then check for existing same-day Review, create or update the Review child ticket, and attach workflow files.
3. After completion: update progress file — set status to `done` with timestamp
4. Mark next risk as `current`
5. After each risk: check context capacity
6. If context approaching limit: save progress, add session log entry, tell user:
   ```
   Context limit approaching.

   Progress saved to rr-progress.md
   Completed this session: RR-220, RR-221, RR-222 (N risks)
   Remaining: M risks

   To continue: Start a new chat and say /rr all
   The review will automatically resume from RR-NNN.
   ```

### Progress File Status Values

| Status | Meaning |
|--------|---------|
| `pending` | Not yet started |
| `current` | In progress right now |
| `done` | Completed successfully |
| `failed` | Error during processing |
| `skipped` | Skipped (already reviewed this quarter, unless --force) |

### CPT — Sequential Mode Complete

After all risks are processed (or context limit reached), update CPT via Bash (non-blocking):
```bash
~/.claude/skills/rr/bin/_update_cpt.sh complete "Sequential mode: N/M risks processed" || true
```

## After

Tell user:
- `/rr status` to check progress at any time
- `/rr fix` to retry any failed assessments
- `/rr all --reset` to start a fresh batch
