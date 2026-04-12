# rr:status — Batch Progress Check

Context from user: $ARGUMENTS

## Check Both Progress Sources

Check for progress from both parallel bin mode and sequential mode. Report whichever is found (or both if both exist).

### Parallel Orchestrator Progress

Check if `${RR_WORK_DIR:-~/rr-work}/progress.md` exists.

If yes:
1. Read and display the progress summary
2. Tail the last 30 lines of `${RR_WORK_DIR:-~/rr-work}/batch.log` for recent activity:
   ```bash
   tail -30 ${RR_WORK_DIR:-~/rr-work}/batch.log 2>/dev/null || echo "No batch log found"
   ```
3. Count files in each results directory:
   ```bash
   echo "Results:     $(ls ${RR_WORK_DIR:-~/rr-work}/results/ 2>/dev/null | wc -l | tr -d ' ') completed"
   echo "Errors:      $(ls ${RR_WORK_DIR:-~/rr-work}/errors/ 2>/dev/null | wc -l | tr -d ' ') failed"
   echo "Jira OK:     $(ls ${RR_WORK_DIR:-~/rr-work}/jira-results/ 2>/dev/null | wc -l | tr -d ' ') published"
   echo "Jira Errors: $(ls ${RR_WORK_DIR:-~/rr-work}/jira-errors/ 2>/dev/null | wc -l | tr -d ' ') failed to publish"
   ```

### Sequential Progress

Check if `${RR_OUTPUT_DIR:-~/rr-output}/rr-progress.md` exists.

If yes:
1. Read and display the full progress table
2. Calculate counts:
   - Total risks
   - Completed (done)
   - In progress (current)
   - Pending
   - Failed
   - Skipped

## Output

Present a structured summary. If parallel bin progress is found:

```
rr status — Batch Progress (Parallel Orchestrator)

  Assessments:   N completed, M failed, P total
  Jira publish:  J published, K failed
  Batch log:     [last 5 lines of activity]

  Next steps:
    /rr fix     Re-run N failed assessments
    /rr all     (batch still running / batch complete)
```

If sequential progress is found:

```
rr status — Batch Progress (Sequential)

  Total:      N risks
  Completed:  X (Y%)
  Pending:    Z
  Failed:     F
  Skipped:    S

  Last completed: RR-NNN (date)
  Next up:        RR-NNN

  Next steps:
    /rr all     Resume from RR-NNN
    /rr fix     Re-run F failed assessments
```

If no progress files found:

```
rr status — No batch in progress.

  Start a batch review with: /rr all
```
