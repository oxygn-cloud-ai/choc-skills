#!/bin/bash
# rr-batch.sh — Fully autonomous risk register batch review (macOS-adapted)
#
# Executes entire workflow without returning to orchestrator:
# 1. Query Jira for all risks
# 2. Filter by quarterly review
# 3. Extract risk data
# 4. Dispatch sub-agents (parallel)
# 5. Collect and validate results
# 6. Publish to Jira (parallel)
# 7. Notify via Slack
#
# Usage: ./rr-batch.sh [--force]
#
# Required environment variables:
#   ANTHROPIC_API_KEY    — For sub-agent API calls
#   JIRA_EMAIL           — Jira account email
#   JIRA_API_KEY       — Jira API token
#   SLACK_WEBHOOK_URL    — Slack incoming webhook (optional)
#
# Optional:
#   RR_CATEGORY_FILTER   — Filter by category (T, C, F, etc.)
#   RR_MODEL             — Claude model for sub-agents (default: claude-sonnet-4-20250514)
#   ANTHROPIC_API_VERSION — API version (default: 2023-06-01)
#   RR_WORK_DIR          — Working directory (default: $HOME/rr-work)

set -uo pipefail

#=============================================================================
# CONFIGURATION
#=============================================================================

WORK_DIR="${RR_WORK_DIR:-${HOME}/rr-work}"
LOG_FILE="$WORK_DIR/batch.log"

# Resolve the directory this script lives in (follows symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

JIRA_BASE_URL="https://chocfin.atlassian.net"
JIRA_CLOUD_ID="81a55da4-28c8-4a49-8a47-03a98a73f152"
PROJECT_KEY="RR"

MAX_PARALLEL_SUBAGENTS=20
MAX_PARALLEL_JIRA=50
RISKS_PER_SUBAGENT=10
SUBAGENT_TIMEOUT=300
SUBAGENT_MAX_RETRIES=3

FORCE_MODE=false
CATEGORY_FILTER="${RR_CATEGORY_FILTER:-}"

# Configurable model and API version
MODEL="${RR_MODEL:-claude-sonnet-4-20250514}"
API_VERSION="${ANTHROPIC_API_VERSION:-2023-06-01}"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --force) FORCE_MODE=true ;;
        --reset) rm -rf "$WORK_DIR"; echo "Work directory reset"; exit 0 ;;
    esac
done

#=============================================================================
# SETUP
#=============================================================================

mkdir -p "$WORK_DIR"/{extracts,payloads,results,errors,assessments,individual,jira-payloads,jira-results,jira-errors,logs}
: > "$LOG_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

die() {
    log "FATAL: $*"
    notify_slack "RR batch review failed: $*"
    exit 1
}

# Verify required environment variables
check_env() {
    local missing=()
    [ -z "${ANTHROPIC_API_KEY:-}" ] && missing+=("ANTHROPIC_API_KEY")
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

jira_create_issue() {
    local payload="$1"

    curl -s -w "\n%{http_code}" -X POST "$JIRA_BASE_URL/rest/api/3/issue" \
        -H "Authorization: Basic $JIRA_AUTH" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --max-time 30
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
        # NOTE: Jira /search/jql may return isLast:true even when more pages exist.
        # Always check for nextPageToken presence — continue if token exists.
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
        cp "$WORK_DIR/discovery.json" "$WORK_DIR/filter-result.json"
        jq '.risks | length' "$WORK_DIR/filter-result.json"
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
        # NOTE: Jira /search/jql may return isLast:true with a valid nextPageToken.
        # Always check token presence — continue if token exists.
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
# PHASE 4: SUB-AGENT DISPATCH
#=============================================================================

# Load sub-agent system prompt from external file
SUBAGENT_PROMPT=""
if [ -f "$SCRIPT_DIR/sub-agent-system-prompt.txt" ]; then
    SUBAGENT_PROMPT=$(cat "$SCRIPT_DIR/sub-agent-system-prompt.txt")
else
    die "Missing sub-agent system prompt file: $SCRIPT_DIR/sub-agent-system-prompt.txt"
fi

create_payload() {
    local batch_file="$1"
    local batch_id=$(jq '.batch_id' "$batch_file")
    local risks=$(jq -c '.risks' "$batch_file")

    local payload=$(jq -n \
        --arg model "$MODEL" \
        --argjson max_tokens 20000 \
        --arg system "$SUBAGENT_PROMPT" \
        --arg user "Assess these risks and return JSON only: $risks" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            system: $system,
            messages: [{role: "user", content: $user}]
        }')

    echo "$payload" > "$WORK_DIR/payloads/payload_${batch_id}.json"
}

phase_dispatch() {
    log "PHASE 4: SUB-AGENT DISPATCH"

    # Create payloads
    for batch_file in "$WORK_DIR/extracts"/batch_*.json; do
        create_payload "$batch_file"
    done

    local payload_count=$(ls "$WORK_DIR/payloads" | wc -l | tr -d ' ')
    log "Created $payload_count payloads"

    # Export env vars needed by _dispatch_one.sh
    export WORK_DIR ANTHROPIC_API_KEY SUBAGENT_TIMEOUT SUBAGENT_MAX_RETRIES
    export MODEL API_VERSION

    # Dispatch in parallel using standalone wrapper script
    local batch_ids=$(ls "$WORK_DIR/payloads" | sed 's/payload_//;s/\.json//' | sort -n)
    echo "$batch_ids" | xargs -P "$MAX_PARALLEL_SUBAGENTS" -I {} "$SCRIPT_DIR/_dispatch_one.sh" {}

    # Merge per-process logs into main log
    cat "$WORK_DIR/logs"/dispatch_*.log >> "$LOG_FILE" 2>/dev/null

    local succeeded=$(ls "$WORK_DIR/results" 2>/dev/null | wc -l | tr -d ' ')
    local failed=$((payload_count - succeeded))

    log "Dispatch complete: $succeeded succeeded, $failed failed"
    echo "$succeeded"
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

        local batch_id=$(basename "$result_file" | sed 's/result_//;s/\.json//')
        local content=$(jq -r '.content[0].text // empty' "$result_file" 2>/dev/null \
            | sed 's/^```json[[:space:]]*//' | sed 's/^```[[:space:]]*//' | sed 's/[[:space:]]*```$//')

        if [ -z "$content" ] || ! echo "$content" | jq -e '.assessments' >/dev/null 2>&1; then
            log "Batch $batch_id: invalid response"
            continue
        fi

        echo "$content" > "$WORK_DIR/assessments/batch_${batch_id}.json"

        # Extract individual assessments
        local count=$(echo "$content" | jq '.assessments | length')
        for ((i=0; i<count; i++)); do
            local assessment=$(echo "$content" | jq ".assessments[$i]")
            local risk_key=$(echo "$assessment" | jq -r '.risk_key')
            local status=$(echo "$assessment" | jq -r '.status')

            total=$((total + 1))

            if [ "$status" = "success" ]; then
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

    # Export env vars needed by _publish_one.sh
    export WORK_DIR JIRA_BASE_URL JIRA_AUTH PROJECT_KEY

    local risk_keys=$(ls "$WORK_DIR/individual" | sed 's/\.json//')
    local total=$(echo "$risk_keys" | wc -w | tr -d ' ')

    log "Publishing $total reviews to Jira..."

    # Dispatch in parallel using standalone wrapper script
    echo "$risk_keys" | xargs -P "$MAX_PARALLEL_JIRA" -I {} "$SCRIPT_DIR/_publish_one.sh" {}

    # Merge per-process logs into main log
    cat "$WORK_DIR/logs"/publish_*.log >> "$LOG_FILE" 2>/dev/null

    local succeeded=$(ls "$WORK_DIR/jira-results" 2>/dev/null | wc -l | tr -d ' ')
    local failed=$((total - succeeded))

    log "Publication complete: $succeeded succeeded, $failed failed"
    echo "$succeeded"
}

#=============================================================================
# PHASE 7: COMPLETION
#=============================================================================

phase_completion() {
    log "PHASE 7: COMPLETION"

    local total_risks=$(jq '.total' "$WORK_DIR/discovery.json")
    local filtered=$(jq '.to_process' "$WORK_DIR/filter-result.json")
    local assessed=$(ls "$WORK_DIR/individual" 2>/dev/null | wc -l | tr -d ' ')
    local published=$(ls "$WORK_DIR/jira-results" 2>/dev/null | wc -l | tr -d ' ')
    local failed=$((filtered - published))

    # Generate progress report
    cat > "$WORK_DIR/progress.md" << EOF
# RR Batch Review Complete

**Completed:** $(date '+%Y-%m-%d %H:%M:%S')
**Mode:** $([ "$FORCE_MODE" = true ] && echo "--force" || echo "default")

## Summary

| Metric | Count |
|--------|-------|
| Total risks in register | $total_risks |
| Quarterly-reviewed (skipped) | $((total_risks - filtered)) |
| Processed this run | $filtered |
| Successfully published | $published |
| Failed | $failed |

## Failed Risks

$(ls "$WORK_DIR/jira-errors" 2>/dev/null | sed 's/\.json//' | while read key; do
    error=$(jq -r '.error // "unknown"' "$WORK_DIR/jira-errors/${key}.json" 2>/dev/null)
    echo "- $key: $error"
done)

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
    log "RR BATCH REVIEW STARTING"
    log "Force mode: $FORCE_MODE"
    log "Category filter: ${CATEGORY_FILTER:-none}"
    log "Model: $MODEL"
    log "API version: $API_VERSION"
    log "=========================================="

    check_env
    JIRA_AUTH=$(echo -n "${JIRA_EMAIL}:${JIRA_API_KEY}" | base64 | tr -d '\n')

    notify_slack "RR batch review starting (force=$FORCE_MODE)"

    local total_risks=$(phase_discovery)
    [ "$total_risks" -eq 0 ] && die "No risks found"

    local to_process=$(phase_filter)
    [ "$to_process" -eq 0 ] && { log "No risks to process"; exit 0; }

    local batches=$(phase_extraction)

    local dispatched=$(phase_dispatch)

    local collected=$(phase_collection)

    local published=$(phase_publication)

    phase_completion

    log "=========================================="
    log "RR BATCH REVIEW COMPLETE"
    log "=========================================="
}

main "$@"
