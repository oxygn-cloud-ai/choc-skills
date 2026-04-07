#!/bin/bash
# rr-finalize.sh — Batch finalization: collection, publication, completion (macOS-adapted)
#
# Phases 5-7 of the batch review workflow. No LLM required.
# Called after Agent dispatch (Phase 4) completes.
#
# Usage: ./rr-finalize.sh [--qtr:Q1|Q2|Q3|Q4]
#
# Required environment variables:
#   JIRA_EMAIL           — Jira account email
#   JIRA_API_KEY         — Jira API token
#
# Optional:
#   RR_WORK_DIR          — Working directory (default: $HOME/rr-work)
#   SLACK_WEBHOOK_URL    — Slack incoming webhook (optional)

set -uo pipefail

#=============================================================================
# CONFIGURATION
#=============================================================================

WORK_DIR="${RR_WORK_DIR:-${HOME}/rr-work}"
LOG_FILE="$WORK_DIR/batch.log"

# Resolve the directory this script lives in (follows symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

JIRA_BASE_URL="https://chocfin.atlassian.net"
PROJECT_KEY="RR"

MAX_PARALLEL_JIRA=10

QUARTER_OVERRIDE=""

# Parse arguments
for arg in "$@"; do
    case $arg in
        --qtr:Q[1-4]) QUARTER_OVERRIDE="${arg#--qtr:}" ;;
    esac
done

#=============================================================================
# SETUP
#=============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE" >&2
}

die() {
    log "FATAL: $*"
    notify_slack "RR batch finalization failed: $*"
    exit 1
}

# Verify required environment variables
check_env() {
    local missing=()
    [ -z "${JIRA_EMAIL:-}" ] && missing+=("JIRA_EMAIL")
    [ -z "${JIRA_API_KEY:-}" ] && missing+=("JIRA_API_KEY")

    if [ ${#missing[@]} -gt 0 ]; then
        die "Missing required environment variables: ${missing[*]}"
    fi
}

#=============================================================================
# SLACK NOTIFICATION
#=============================================================================

notify_slack() {
    local message="$1"
    if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
        local payload
        payload=$(jq -n --arg msg "$message" '{text: $msg}')
        curl -s -X POST "$SLACK_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            --max-time 10 >/dev/null 2>&1 || true
    fi
}

#=============================================================================
# PHASE 5: COLLECTION
#=============================================================================

phase_collection() {
    log "PHASE 5: COLLECTION"

    local total=0
    local valid=0

    for result_file in "$WORK_DIR/results"/result_*.json; do
        [ -f "$result_file" ] || continue

        local batch_id
        batch_id=$(basename "$result_file" | sed 's/result_//;s/\.json//')

        # Result files are raw JSON (no Anthropic response wrapper)
        local content
        content=$(cat "$result_file" 2>/dev/null)

        if [ -z "$content" ] || ! echo "$content" | jq -e '.assessments' >/dev/null 2>&1; then
            log "Batch $batch_id: invalid response"
            continue
        fi

        echo "$content" > "$WORK_DIR/assessments/batch_${batch_id}.json"

        # Extract individual assessments from batch result
        local count
        count=$(echo "$content" | jq '.assessments | length')
        for ((i=0; i<count; i++)); do
            local assessment risk_key status
            assessment=$(echo "$content" | jq ".assessments[$i]")
            risk_key=$(echo "$assessment" | jq -r '.risk_key')
            status=$(echo "$assessment" | jq -r '.status')

            total=$((total + 1))

            if [ "$status" = "success" ] || [ "$status" = "complete" ] || [ "$status" = "completed" ] || [ "$status" = "final" ]; then
                echo "$assessment" > "$WORK_DIR/individual/${risk_key}.json"
                valid=$((valid + 1))
            fi
        done
    done

    log "Collection complete: $valid valid of $total total"
    echo "$valid"
}

#=============================================================================
# PHASE 6: PUBLICATION
#=============================================================================

phase_publication() {
    log "PHASE 6: PUBLICATION"

    local risk_keys total
    risk_keys=$(ls "$WORK_DIR/individual" | sed 's/\.json//')
    total=$(echo "$risk_keys" | wc -w | tr -d ' ')

    log "Publishing $total reviews to Jira..."

    # Dispatch in parallel using standalone wrapper script
    echo "$risk_keys" | xargs -P "$MAX_PARALLEL_JIRA" -I {} "$SCRIPT_DIR/_publish_one.sh" {}

    # Merge per-process logs into main log
    cat "$WORK_DIR/logs"/publish_*.log >> "$LOG_FILE" 2>/dev/null

    local succeeded failed
    succeeded=$(ls "$WORK_DIR/jira-results" 2>/dev/null | wc -l | tr -d ' ')
    failed=$((total - succeeded))

    log "Publication complete: $succeeded succeeded, $failed failed"
    echo "$succeeded"
}

#=============================================================================
# PHASE 7: COMPLETION
#=============================================================================

phase_completion() {
    log "PHASE 7: COMPLETION"

    local total_risks filtered published failed
    total_risks=$(jq '.total' "$WORK_DIR/discovery.json")
    filtered=$(jq '.to_process // .total' "$WORK_DIR/filter-result.json")
    published=$(ls "$WORK_DIR/jira-results" 2>/dev/null | wc -l | tr -d ' ')
    failed=$(ls "$WORK_DIR/jira-errors" 2>/dev/null | wc -l | tr -d ' ')

    # Pre-compute failed risks list
    local failed_list=""
    if [ "$failed" -gt 0 ]; then
        failed_list=$(for f in "$WORK_DIR/jira-errors"/*.json; do
            [ -f "$f" ] || continue
            key=$(basename "$f" .json)
            error=$(jq -r '.error // "unknown"' "$f" 2>/dev/null)
            echo "- $key: $error"
        done)
    fi

    # Generate progress report
    cat > "$WORK_DIR/progress.md" << EOF
# RR Batch Review Complete

**Completed:** $(date '+%Y-%m-%d %H:%M:%S')

## Summary

| Metric | Count |
|--------|-------|
| Total risks in register | $total_risks |
| Quarterly-reviewed (skipped) | $((total_risks - filtered)) |
| Processed this run | $filtered |
| Successfully published | $published |
| Failed | $failed |

## Failed Risks

$failed_list

EOF

    log "Progress report written to $WORK_DIR/progress.md"

    # Slack notification
    notify_slack "RR batch review complete. Total: $total_risks risks, Processed: $filtered, Published: $published, Failed: $failed"

    log "BATCH COMPLETE: $published/$filtered published"
}

#=============================================================================
# MAIN
#=============================================================================

main() {
    log "=========================================="
    log "RR BATCH REVIEW — FINALIZATION"
    log "=========================================="

    check_env
    # Compute and export JIRA_AUTH for _publish_one.sh
    JIRA_AUTH=$(echo -n "${JIRA_EMAIL}:${JIRA_API_KEY}" | base64 | tr -d '\n')
    export WORK_DIR JIRA_BASE_URL JIRA_AUTH PROJECT_KEY RR_QUARTER_OVERRIDE="$QUARTER_OVERRIDE"

    # phase_collection and phase_publication echo counts to stdout which we
    # don't consume here — phase_completion re-reads the authoritative counts
    # from $WORK_DIR. Redirect to /dev/null to keep stdout clean.
    phase_collection >/dev/null
    phase_publication >/dev/null

    phase_completion

    log "=========================================="
    log "RR BATCH REVIEW COMPLETE"
    log "=========================================="
}

main "$@"
