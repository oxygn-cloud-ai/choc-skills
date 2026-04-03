#!/bin/bash
# rr-prepare.sh — Batch preparation: discovery, filtering, extraction (macOS-adapted)
#
# Phases 1-3 of the batch review workflow. No LLM required.
# After completion, the Claude Code session orchestrates Phase 4 (Agent dispatch).
#
# Usage: ./rr-prepare.sh [--force] [--reset] [--qtr:Q1|Q2|Q3|Q4]
#
# Required environment variables:
#   JIRA_EMAIL           — Jira account email
#   JIRA_API_KEY         — Jira API token
#
# Optional:
#   RR_CATEGORY_FILTER   — Filter by category (T, C, F, etc.)
#   RR_WORK_DIR          — Working directory (default: $HOME/rr-work)
#   SLACK_WEBHOOK_URL    — Slack incoming webhook (optional)
#
# Output (stdout last line): number of batches created

set -uo pipefail

#=============================================================================
# CONFIGURATION
#=============================================================================

WORK_DIR="${RR_WORK_DIR:-${HOME}/rr-work}"
LOG_FILE="$WORK_DIR/batch.log"

JIRA_BASE_URL="https://chocfin.atlassian.net"
PROJECT_KEY="RR"

RISKS_PER_SUBAGENT=10

FORCE_MODE=false
CATEGORY_FILTER="${RR_CATEGORY_FILTER:-}"
QUARTER_OVERRIDE=""

# Parse arguments
for arg in "$@"; do
    case $arg in
        --force) FORCE_MODE=true ;;
        --reset) rm -rf "$WORK_DIR"; echo "Work directory reset"; exit 0 ;;
        --qtr:Q[1-4]) QUARTER_OVERRIDE="${arg#--qtr:}" ;;
    esac
done

#=============================================================================
# SETUP
#=============================================================================

mkdir -p "$WORK_DIR"/{extracts,payloads,results,errors,assessments,individual,jira-payloads,jira-results,jira-errors,progress,logs}
: > "$LOG_FILE"

# Clean stale results/errors/progress from previous runs at startup
rm -f "$WORK_DIR/jira-results"/*.json 2>/dev/null
rm -f "$WORK_DIR/jira-errors"/*.json 2>/dev/null
rm -f "$WORK_DIR/progress"/*.json 2>/dev/null

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE" >&2
}

die() {
    log "FATAL: $*"
    notify_slack "RR batch review failed: $*"
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

JIRA_AUTH=""  # Computed after check_env validates credentials

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
# JIRA API FUNCTIONS
#=============================================================================

jira_search() {
    local jql="$1"
    local max_results="${2:-100}"
    local next_page_token="${3:-}"
    local payload
    payload=$(jq -n \
        --arg jql "$jql" \
        --argjson max "$max_results" \
        '{jql: $jql, maxResults: $max, fields: ["summary", "description", "issuetype", "status", "parent", "created"]}')

    # Add cursor pagination token if provided
    if [ -n "$next_page_token" ]; then
        payload=$(echo "$payload" | jq --arg token "$next_page_token" '. + {nextPageToken: $token}')
    fi

    curl -s -X POST "$JIRA_BASE_URL/rest/api/3/search/jql" \
        -H "Authorization: Basic $JIRA_AUTH" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --max-time 60
}

#=============================================================================
# PHASE 1: DISCOVERY
#=============================================================================

phase_discovery() {
    log "PHASE 1: DISCOVERY"

    local jql="project = $PROJECT_KEY AND issuetype = Risk ORDER BY key ASC"
    [ -n "$CATEGORY_FILTER" ] && jql="project = $PROJECT_KEY AND issuetype = Risk AND summary ~ \"[$CATEGORY_FILTER]\" ORDER BY key ASC"

    local all_risks="[]"
    local next_page_token=""
    local page=0

    while true; do
        page=$((page + 1))
        log "Fetching risks (page $page)..."
        local response=$(jira_search "$jql" 100 "$next_page_token")

        if [ -z "$response" ] || ! echo "$response" | jq -e '.issues' >/dev/null 2>&1; then
            die "Failed to query Jira"
        fi

        local batch_count=$(echo "$response" | jq '.issues | length')
        log "Page $page: $batch_count risks"

        all_risks=$(echo "$all_risks" "$response" | jq -s '.[0] + .[1].issues')

        # Cursor-based pagination: nextPageToken is authoritative
        next_page_token=$(echo "$response" | jq -r '.nextPageToken // empty')
        if [ -z "$next_page_token" ]; then
            break
        fi
    done

    local risk_count=$(echo "$all_risks" | jq 'length')
    log "Discovered $risk_count risks"

    echo "$all_risks" | jq '{
        timestamp: now | todate,
        total: length,
        risks: [.[] | {
            key: .key,
            summary: .fields.summary,
            description: (.fields.description // null),
            status: .fields.status.name,
            created: .fields.created
        }]
    }' > "$WORK_DIR/discovery.json"

    echo "$risk_count"
}

#=============================================================================
# PHASE 2: QUARTERLY FILTER
#=============================================================================

phase_filter() {
    log "PHASE 2: QUARTERLY FILTER"

    # Calculate quarter start
    local month=$(date +%m)
    local year=$(date +%Y)
    local quarter_start

    case $month in
        01|02|03) quarter_start="$year-01-01" ;;
        04|05|06) quarter_start="$year-04-01" ;;
        07|08|09) quarter_start="$year-07-01" ;;
        10|11|12) quarter_start="$year-10-01" ;;
    esac

    log "Quarter start: $quarter_start"

    if [ "$FORCE_MODE" = true ]; then
        log "Force mode: skipping quarterly filter"
        local count=$(jq '.risks | length' "$WORK_DIR/discovery.json")
        jq --argjson tp "$count" '. + {to_process: $tp}' "$WORK_DIR/discovery.json" > "$WORK_DIR/filter-result.json"
        echo "$count"
        return
    fi

    # Query for existing reviews this quarter (cursor-paginated)
    local jql="project = $PROJECT_KEY AND issuetype = Review AND created >= $quarter_start"
    local all_reviews="[]"
    local next_page_token=""
    while true; do
        local reviews_response=$(jira_search "$jql" 100 "$next_page_token")
        if [ -z "$reviews_response" ] || ! echo "$reviews_response" | jq -e '.issues' >/dev/null 2>&1; then
            break
        fi
        all_reviews=$(echo "$all_reviews" "$reviews_response" | jq -s '.[0] + .[1].issues')
        next_page_token=$(echo "$reviews_response" | jq -r '.nextPageToken // empty')
        [ -z "$next_page_token" ] && break
    done

    # Extract parent keys of existing reviews
    local reviewed_parents=$(echo "$all_reviews" | jq -r '[.[].fields.parent.key // empty] | unique | .[]')

    # Filter out already-reviewed risks
    local reviewed_count=0
    local to_process="[]"

    while read -r risk; do
        local key=$(echo "$risk" | jq -r '.key')
        if echo "$reviewed_parents" | grep -q "^${key}$"; then
            reviewed_count=$((reviewed_count + 1))
        else
            to_process=$(echo "$to_process" | jq --argjson r "$risk" '. + [$r]')
        fi
    done < <(jq -c '.risks[]' "$WORK_DIR/discovery.json")

    local to_process_count=$(echo "$to_process" | jq 'length')

    log "Quarterly reviewed (skipped): $reviewed_count"
    log "To process: $to_process_count"

    echo "{
        \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\",
        \"quarter_start\": \"$quarter_start\",
        \"force_mode\": $FORCE_MODE,
        \"total_risks\": $(jq '.total' "$WORK_DIR/discovery.json"),
        \"quarterly_reviewed\": $reviewed_count,
        \"to_process\": $to_process_count,
        \"risks\": $to_process
    }" | jq '.' > "$WORK_DIR/filter-result.json"

    echo "$to_process_count"
}

#=============================================================================
# PHASE 3: EXTRACTION
#=============================================================================

phase_extraction() {
    log "PHASE 3: EXTRACTION"

    local risks=$(jq -c '.risks[]' "$WORK_DIR/filter-result.json")
    local risk_array=()

    while read -r risk; do
        risk_array+=("$risk")
    done <<< "$risks"

    local total=${#risk_array[@]}
    local batch_num=0

    for ((i=0; i<total; i+=RISKS_PER_SUBAGENT)); do
        batch_num=$((batch_num + 1))
        local batch_risks="[]"

        for ((j=i; j<i+RISKS_PER_SUBAGENT && j<total; j++)); do
            batch_risks=$(echo "$batch_risks" | jq --argjson r "${risk_array[$j]}" '. + [$r]')
        done

        local batch_size=$(echo "$batch_risks" | jq 'length')
        log "Batch $batch_num: $batch_size risks"

        echo "{\"batch_id\": $batch_num, \"risks\": $batch_risks}" > "$WORK_DIR/extracts/batch_${batch_num}.json"
    done

    log "Created $batch_num batches"
    echo "$batch_num"
}

#=============================================================================
# MAIN
#=============================================================================

main() {
    log "=========================================="
    log "RR BATCH REVIEW — PREPARATION"
    log "Force mode: $FORCE_MODE"
    log "Category filter: ${CATEGORY_FILTER:-none}"
    log "=========================================="

    check_env
    JIRA_AUTH=$(echo -n "${JIRA_EMAIL}:${JIRA_API_KEY}" | base64 | tr -d '\n')

    notify_slack "RR batch review starting (force=$FORCE_MODE)"

    local total_risks=$(phase_discovery)
    [ "$total_risks" -eq 0 ] && die "No risks found"

    local to_process=$(phase_filter)
    if [ "$to_process" -eq 0 ]; then
        log "No risks to process"
        echo "0"
        exit 0
    fi

    local batches=$(phase_extraction)

    log "=========================================="
    log "PREPARATION COMPLETE — $batches batches ready for dispatch"
    log "=========================================="

    # Output batch count as last line for caller to capture
    echo "$batches"
}

main "$@"
