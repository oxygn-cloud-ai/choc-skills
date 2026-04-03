# rr:fix — Re-run Failed Assessments

Context from user: $ARGUMENTS

## Identify Failures

Check both parallel orchestrator and sequential mode for failed assessments.

### Sub-agent Failures (Agent Orchestrator)

List files in the errors directory:
```bash
ls ${RR_WORK_DIR:-~/rr-work}/errors/ 2>/dev/null
```

For each error file found:
1. Read the error JSON
2. Extract `batch_id`, `risk_key`, error type, and error message
3. Collect into a failures list

Also check for batches that have extracts but no results and no errors:
```bash
for f in ${RR_WORK_DIR:-~/rr-work}/extracts/batch_*.json; do
  id=$(basename "$f" | sed 's/batch_//;s/\.json//')
  [ ! -f "${RR_WORK_DIR:-~/rr-work}/results/result_${id}.json" ] && \
  [ ! -f "${RR_WORK_DIR:-~/rr-work}/errors/error_${id}.json" ] && \
  echo "Batch $id: no result or error (agent may have crashed)"
done
```

### Jira Publication Failures (Agent Orchestrator)

List files in the jira-errors directory:
```bash
ls ${RR_WORK_DIR:-~/rr-work}/jira-errors/ 2>/dev/null
```

For each jira-error file found:
1. Read the error JSON
2. Extract `risk_key`, HTTP status code, and error body
3. Collect into a jira failures list

### Sequential Mode Failures

Check `${RR_OUTPUT_DIR:-~/rr-output}/rr-progress.md` for any rows with `failed` status.

## Present Summary

Display a structured summary of all failures:

```
rr fix — Failed Assessment Summary

Sub-agent failures: N
| # | Batch | Risk Keys | Error Type | Message |
|---|-------|-----------|------------|---------|
| 1 | 3     | RR-220... | timeout    | Agent did not complete |
| 2 | 7     | RR-225... | api_error  | Reference file not found |

Jira publication failures: M
| # | Risk Key | HTTP Code | Error |
|---|----------|-----------|-------|
| 1 | RR-221   | 403       | Forbidden — check permissions |
| 2 | RR-230   | 500       | Internal server error |

Sequential failures: P
| # | Risk Key | Category | Summary |
|---|----------|----------|---------|
| 1 | RR-240   | T        | Technology risk description... |
```

If no failures found in any source:
```
rr fix — No failures found.

All assessments completed successfully.
Check status with: /rr status
```
Stop here.

## Offer Retry Options

### For Sub-agent Failures

If sub-agent failures exist:
1. Ask user: "Re-run N failed batches via Agent dispatch? (y/n)"
2. If yes:
   a. Read the sub-agent prompt template from `~/.claude/skills/rr/orchestrator/sub-agent-prompt.md`
   b. For each failed batch:
      - Determine the batch_id from the error file or missing result
      - Verify the extract file exists: `${RR_WORK_DIR:-~/rr-work}/extracts/batch_<batch_id>.json`
      - Delete the old error file if it exists
      - Construct the Agent prompt: prepend batch-specific values (batch_id, batch file path, work directory) to the sub-agent prompt contents, replacing `BATCH_ID`, `BATCH_FILE`, `WORK_DIR`, and `SKILLS_DIR` with actual values
      - Spawn Agent tool (model: "opus") with the constructed prompt
      - After agent completes, check if result file was created:
        ```bash
        test -f ${RR_WORK_DIR:-~/rr-work}/results/result_<batch_id>.json && echo "SUCCESS" || echo "FAILED"
        ```
      - Report success or persistent failure
   c. After all retries, run finalization for any newly completed assessments:
      ```bash
      ~/.claude/skills/rr/orchestrator/rr-finalize.sh [--qtr:Q1|Q2|Q3|Q4 if applicable]
      ```
3. Report retry results

### For Jira Publication Failures

If Jira publication failures exist:
1. Ask user: "Re-publish M failed assessments to Jira via MCP tools? (y/n)"
2. If yes, for each failed risk_key:
   a. Read the completed assessment from `${RR_WORK_DIR:-~/rr-work}/individual/<risk_key>.json`
   b. Verify the assessment file exists and is valid JSON
   c. Render to markdown for Jira description
   d. Attempt to create the Review child ticket via `mcp__claude_ai_Atlassian__createJiraIssue`
   e. If successful: move error file from `jira-errors/` to `jira-results/`
   f. If failed again: report the new error
3. Report results: N succeeded, M still failing

### For Sequential Failures

If sequential mode failures exist:
1. Ask user: "Re-run P failed assessments interactively? (y/n)"
2. If yes, for each failed risk:
   a. Update progress file status from `failed` to `current`
   b. Execute the full 6-step workflow (same as `/rr:review`)
   c. Update progress file on completion
3. Check context capacity after each risk

## After

Report retry results summary:
- How many retries were attempted
- How many succeeded
- How many still failing

Suggest: `/rr status` to verify current state.
