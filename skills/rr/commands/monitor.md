# rr:monitor — Batch Progress Dashboard

Context from user: $ARGUMENTS

## Configuration

- Work directory: `${RR_WORK_DIR:-~/rr-work}`

## Check for Active Batch

Run this check first:

```bash
WORK_DIR="${RR_WORK_DIR:-$HOME/rr-work}"
if [ ! -d "$WORK_DIR" ]; then
  echo "No batch work directory found at $WORK_DIR"
  echo "Start a batch first: /rr all"
  exit 1
fi
```

If no work directory exists, tell user to run `/rr all` first. Stop here.

## Display Dashboard

Run the following bash script. It takes a single snapshot and returns immediately.

```bash
WORK_DIR="${RR_WORK_DIR:-$HOME/rr-work}"

# Get baseline totals
total_risks=0
to_process=0
total_batches=0
if [ -f "$WORK_DIR/filter-result.json" ]; then
  to_process=$(jq -r '.to_process // 0' "$WORK_DIR/filter-result.json")
fi
if [ -f "$WORK_DIR/discovery.json" ]; then
  total_risks=$(jq -r '.total // 0' "$WORK_DIR/discovery.json")
fi
total_batches=$(ls -1 "$WORK_DIR/extracts/" 2>/dev/null | wc -l | tr -d ' ')

# Count files in each phase directory
extracts=$(ls -1 "$WORK_DIR/extracts/" 2>/dev/null | wc -l | tr -d ' ')
payloads=$(ls -1 "$WORK_DIR/payloads/" 2>/dev/null | wc -l | tr -d ' ')
results=$(ls -1 "$WORK_DIR/results/" 2>/dev/null | wc -l | tr -d ' ')
errors=$(ls -1 "$WORK_DIR/errors/" 2>/dev/null | wc -l | tr -d ' ')
assessments=$(ls -1 "$WORK_DIR/individual/" 2>/dev/null | wc -l | tr -d ' ')
jira_ok=$(ls -1 "$WORK_DIR/jira-results/" 2>/dev/null | wc -l | tr -d ' ')
jira_err=$(ls -1 "$WORK_DIR/jira-errors/" 2>/dev/null | wc -l | tr -d ' ')

# Detect current phase from batch.log
phase="unknown"
if [ -f "$WORK_DIR/batch.log" ]; then
  phase=$(grep -o 'PHASE [0-9]' "$WORK_DIR/batch.log" | tail -1 | sed 's/PHASE //')
fi
phase_name=""
case "$phase" in
  1) phase_name="Discovery" ;;
  2) phase_name="Quarterly Filter" ;;
  3) phase_name="Extraction" ;;
  4) phase_name="Sub-Agent Dispatch" ;;
  5) phase_name="Collection" ;;
  6) phase_name="Publication" ;;
  7) phase_name="Completion" ;;
  *) phase_name="Starting..." ;;
esac

# Check if complete
complete=false
if [ -f "$WORK_DIR/progress.md" ] && grep -q 'BATCH COMPLETE' "$WORK_DIR/batch.log" 2>/dev/null; then
  complete=true
fi

# Calculate progress percentage
if [ "$to_process" -gt 0 ]; then
  pct=$((jira_ok * 100 / to_process))
else
  pct=0
fi

# Build progress bar (40 chars wide)
filled=$((pct * 40 / 100))
empty=$((40 - filled))
bar=$(printf '%0.s#' $(seq 1 $filled 2>/dev/null) || true)
space=$(printf '%0.s-' $(seq 1 $empty 2>/dev/null) || true)

# Last 5 log entries
last_logs=""
if [ -f "$WORK_DIR/batch.log" ]; then
  last_logs=$(tail -5 "$WORK_DIR/batch.log")
fi

# Display dashboard
echo "==============================================="
echo "  RR BATCH MONITOR"
echo "==============================================="
echo ""
echo "  Phase:    $phase — $phase_name"
echo "  Progress: [$bar$space] $pct%"
echo ""
echo "  +-----------------------+-------+-------+"
echo "  | Stage                 | Done  | Total |"
echo "  +-----------------------+-------+-------+"
printf "  | %-21s | %5s | %5s |\n" "Risks discovered" "$total_risks" "$total_risks"
printf "  | %-21s | %5s | %5s |\n" "Filtered to process" "$to_process" "$total_risks"
printf "  | %-21s | %5s | %5s |\n" "Batches created" "$extracts" "$extracts"
printf "  | %-21s | %5s | %5s |\n" "Sub-agent results" "$results" "$total_batches"
printf "  | %-21s | %5s | %5s |\n" "Sub-agent errors" "$errors" ""
printf "  | %-21s | %5s | %5s |\n" "Assessments extracted" "$assessments" "$to_process"
printf "  | %-21s | %5s | %5s |\n" "Published to Jira" "$jira_ok" "$to_process"
printf "  | %-21s | %5s | %5s |\n" "Jira errors" "$jira_err" ""
echo "  +-----------------------+-------+-------+"
echo ""
echo "  Recent log:"
echo "$last_logs" | sed 's/^/    /'
echo ""

if [ "$complete" = true ]; then
  echo "  === BATCH COMPLETE ==="
else
  echo "  Batch still running."
fi
```

## After Dashboard

If the batch is complete: also display the full `progress.md` content.

If the batch is still running: use the `/loop` skill to auto-refresh. Invoke:

```
/loop 10s /rr monitor
```

This will re-run the monitor every 10 seconds, giving the user a live-updating view. The `/loop` skill handles the repetition — the monitor itself just takes a single snapshot each time.

Tell the user: "Monitoring every 10 seconds. Press Escape to stop."
