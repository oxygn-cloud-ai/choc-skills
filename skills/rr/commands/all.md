# rr:all — Batch Risk Register Review

Context from user: $ARGUMENTS

## Parse Arguments

Parse any flags or filters from $ARGUMENTS (everything after the `all` keyword):

- `--force` — Set FORCE flag: skip quarterly review date filtering, review all risks regardless of last review date
- `--reset` — Delete all progress and work files, start fresh (confirm with user first before deleting)
- Single category letter (T, C, F, A, B, D, ER, I, L, O, OO, P) — Set RR_CATEGORY_FILTER to that value
- Default: no force, no category filter

## Mode Selection

Check if the parallel orchestrator is available by running these checks via Bash:

```bash
test -x ~/.claude/skills/rr/orchestrator/rr-batch.sh && echo "orchestrator_available"
test -n "${ANTHROPIC_API_KEY:-}" && echo "api_key_set"
test -n "${JIRA_EMAIL:-}" && test -n "${JIRA_API_KEY:-}" && echo "jira_creds_set"
```

If ALL three checks pass: use **Parallel Orchestrator Mode**.
Otherwise: use **Sequential Mode** (fallback).

---

## Parallel Orchestrator Mode

### Pre-flight

Verify all three environment variables are set (do not display values):
- `ANTHROPIC_API_KEY` — required for sub-agent API calls
- `JIRA_EMAIL` — required for Jira REST API authentication
- `JIRA_API_KEY` — required for Jira REST API authentication

### Handle --reset

If `--reset` flag is set:
1. Ask user to confirm: "This will delete the entire batch work directory at ${RR_WORK_DIR:-~/rr-work}. Continue? (y/n)"
2. If confirmed:
   ```bash
   rm -rf "${RR_WORK_DIR:-$HOME/rr-work}"
   ```
   This removes everything: results, errors, payloads, extracts, assessments, logs, and all other intermediate files. A clean slate.
3. Report cleared and continue to launch

### Launch

Build the command with applicable flags and run via Bash tool in background:

```bash
~/.claude/skills/rr/orchestrator/rr-batch.sh [--force] [--category X]
```

### Report to User

```
Batch review launched.

Running in background (~30 minutes for 200 risks).
Slack notification on completion (if SLACK_WEBHOOK_URL set).

Monitor progress:  /rr status
Re-run failures:   /rr fix
```

---

## Sequential Mode (Fallback)

Report to user why parallel mode is not available, then proceed sequentially.

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

### Process Each Risk

For each pending risk in the progress file:

1. Update status to `current` in progress file
2. Read all workflow step files and execute the full 6-step workflow inline:
   - Step 1: Extract and draft (read `~/.claude/skills/rr/references/workflow/step-1-extract.md`)
   - Step 2: Adversarial review (read `~/.claude/skills/rr/references/workflow/step-2-adversarial.md`)
   - Step 3: Rectified assessment (read `~/.claude/skills/rr/references/workflow/step-3-rectify.md`)
   - Step 4: Discussion — **in batch mode, skip interactive discussion** and auto-resolve based on adversarial findings
   - Step 5: Final assessment (read `~/.claude/skills/rr/references/workflow/step-5-finalise.md`)
   - Step 6: Publish to Jira (read `~/.claude/skills/rr/references/workflow/step-6-publish.md`)
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

## After

Tell user:
- `/rr status` to check progress at any time
- `/rr fix` to retry any failed assessments
- `/rr all --reset` to start a fresh batch
