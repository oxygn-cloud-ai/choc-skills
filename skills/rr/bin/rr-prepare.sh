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

set -euo pipefail

#=============================================================================
# CONFIGURATION
#=============================================================================

WORK_DIR="${RR_WORK_DIR:-${HOME}/rr-work}"

# Resolve symlinks before validation to prevent symlink traversal attacks (CPT-26).
# A symlink at $HOME/rr-work -> /outside/path would pass the case guard without this.
# Also resolve HOME for consistent comparison (macOS: /var -> /private/var).
RESOLVED_HOME="$HOME"
if command -v realpath >/dev/null 2>&1; then
    RESOLVED_HOME="$(realpath "$HOME")"
    [ -e "$WORK_DIR" ] && WORK_DIR="$(realpath "$WORK_DIR")"
elif [ -d "$WORK_DIR" ]; then
    RESOLVED_HOME="$(cd "$HOME" && pwd -P)"
    WORK_DIR="$(cd "$WORK_DIR" && pwd -P)"
fi

# Validate WORK_DIR is under $HOME or /tmp to prevent accidental operations elsewhere
case "$WORK_DIR" in
    "$RESOLVED_HOME"/*|/tmp/*|/private/tmp/*) ;;
    *) echo "FATAL: RR_WORK_DIR must be under \$HOME or /tmp (after symlink resolution). Got: $WORK_DIR" >&2; exit 1 ;;
esac

LOG_FILE="$WORK_DIR/batch.log"

JIRA_BASE_URL="https://chocfin.atlassian.net"
PROJECT_KEY="RR"

RISKS_PER_SUBAGENT=10

FORCE_MODE=false
CATEGORY_FILTER="${RR_CATEGORY_FILTER:-}"

# Validate CATEGORY_FILTER against known enum values
if [ -n "$CATEGORY_FILTER" ]; then
    case "$CATEGORY_FILTER" in
        A|B|C|D|ER|F|I|L|O|OO|P|T) ;;
        *) echo "FATAL: Invalid CATEGORY_FILTER '$CATEGORY_FILTER'. Must be one of: A, B, C, D, ER, F, I, L, O, OO, P, T" >&2; exit 1 ;;
    esac
fi

# Parse arguments
# Note: --qtr:Q[1-4] is accepted by rr-finalize.sh (where the quarter override
# affects Jira publication) but is not consumed here. Unknown args are silently
# ignored by the case statement below, so wrapper scripts that pass --qtr: to
# both scripts continue to work.
for arg in "$@"; do
    case $arg in
        --force) FORCE_MODE=true ;;
        --reset)
            # Verify this is actually an rr-work directory before deleting
            if [ -d "$WORK_DIR" ] && { [ -f "$WORK_DIR/batch.log" ] || [ -f "$WORK_DIR/discovery.json" ]; }; then
                rm -rf "$WORK_DIR"
                echo "Work directory reset"
            elif [ -d "$WORK_DIR" ]; then
                echo "FATAL: $WORK_DIR does not look like an rr-work directory (missing batch.log and discovery.json). Refusing to delete." >&2
                exit 1
            else
                echo "Work directory does not exist, nothing to reset"
            fi
            exit 0
            ;;
    esac
done

#=============================================================================
# SETUP — define functions and check env BEFORE any destructive cleanup
#=============================================================================

# Resolve script directory for sibling script calls
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE" >&2
}

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

die() {
    log "FATAL: $*"
    notify_slack "RR batch review failed: $*"
    "$SCRIPT_DIR/_update_cpt.sh" fatal "$*" || true
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

# Check env BEFORE cleanup to avoid destroying state when credentials are missing
check_env

mkdir -p "$WORK_DIR"/{extracts,payloads,results,errors,assessments,individual,jira-payloads,jira-results,jira-errors,progress,logs}
: > "$LOG_FILE"

# Clean stale files from previous runs at startup
rm -f "$WORK_DIR/extracts"/*.json 2>/dev/null
rm -f "$WORK_DIR/payloads"/*.json 2>/dev/null
rm -f "$WORK_DIR/results"/*.json 2>/dev/null
rm -f "$WORK_DIR/errors"/*.json 2>/dev/null
rm -f "$WORK_DIR/individual"/*.json 2>/dev/null
rm -f "$WORK_DIR/assessments"/*.json 2>/dev/null
rm -f "$WORK_DIR/jira-results"/*.json 2>/dev/null
rm -f "$WORK_DIR/jira-errors"/*.json 2>/dev/null
rm -f "$WORK_DIR/progress"/*.json 2>/dev/null

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

    local next_page_token=""
    local page=0
    local tmp_risks
    tmp_risks=$(mktemp)

    while true; do
        page=$((page + 1))
        log "Fetching risks (page $page)..."
        local response
        response=$(jira_search "$jql" 100 "$next_page_token")

        if [ -z "$response" ] || ! echo "$response" | jq -e '.issues' >/dev/null 2>&1; then
            rm -f "$tmp_risks"
            die "Failed to query Jira"
        fi

        local batch_count
        batch_count=$(echo "$response" | jq '.issues | length')
        log "Page $page: $batch_count risks"

        # Append issues as individual JSON lines (avoids O(P*N) re-parse accumulation)
        echo "$response" | jq -c '.issues[]' >> "$tmp_risks"

        # Cursor-based pagination: nextPageToken is authoritative
        next_page_token=$(echo "$response" | jq -r '.nextPageToken // empty')
        if [ -z "$next_page_token" ]; then
            break
        fi
    done

    local all_risks
    if [ -s "$tmp_risks" ]; then
        all_risks=$(jq -s '.' "$tmp_risks")
    else
        all_risks="[]"
    fi
    rm -f "$tmp_risks"

    local risk_count
    risk_count=$(echo "$all_risks" | jq 'length')
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
    local month year quarter_start
    month=$(date +%m)
    year=$(date +%Y)

    case $month in
        01|02|03) quarter_start="$year-01-01" ;;
        04|05|06) quarter_start="$year-04-01" ;;
        07|08|09) quarter_start="$year-07-01" ;;
        10|11|12) quarter_start="$year-10-01" ;;
    esac

    log "Quarter start: $quarter_start"

    if [ "$FORCE_MODE" = true ]; then
        log "Force mode: skipping quarterly filter"
        local count
        count=$(jq '.risks | length' "$WORK_DIR/discovery.json")
        jq --argjson tp "$count" '. + {to_process: $tp}' "$WORK_DIR/discovery.json" > "$WORK_DIR/filter-result.json"
        echo "$count"
        return
    fi

    # Query for existing reviews this quarter (cursor-paginated)
    local jql="project = $PROJECT_KEY AND issuetype = Review AND created >= $quarter_start"
    local tmp_reviews
    tmp_reviews=$(mktemp)
    local next_page_token=""
    while true; do
        local reviews_response
        reviews_response=$(jira_search "$jql" 100 "$next_page_token")
        if [ -z "$reviews_response" ] || ! echo "$reviews_response" | jq -e '.issues' >/dev/null 2>&1; then
            break
        fi
        # Append issues as JSON lines (avoids O(P*N) re-parse accumulation)
        echo "$reviews_response" | jq -c '.issues[]' >> "$tmp_reviews"
        next_page_token=$(echo "$reviews_response" | jq -r '.nextPageToken // empty')
        [ -z "$next_page_token" ] && break
    done

    # Build space-delimited set of reviewed parent keys for O(|set|) lookup.
    # Bash 3.2-compatible alternative to `declare -A` (associative arrays are
    # bash 4+; macOS ships /bin/bash 3.2.57). At realistic register sizes
    # (≲ hundreds of reviewed parents) this is indistinguishable from O(1) in
    # wall-clock terms, and still eliminates the per-risk grep subprocess fork
    # that was the original CPT-10 hotspot.
    local reviewed_set=" "
    if [ -s "$tmp_reviews" ]; then
        while IFS= read -r parent_key; do
            [ -n "$parent_key" ] && reviewed_set="${reviewed_set}${parent_key} "
        done < <(jq -rs '[.[].fields.parent.key // empty] | unique | .[]' "$tmp_reviews")
    fi
    rm -f "$tmp_reviews"

    # Filter out already-reviewed risks using pure-bash case-pattern lookup.
    local reviewed_count=0
    local tmp_filter
    tmp_filter=$(mktemp)

    while read -r risk; do
        local key
        key=$(echo "$risk" | jq -r '.key')
        case "$reviewed_set" in
            *" $key "*) reviewed_count=$((reviewed_count + 1)) ;;
            *)          echo "$risk" >> "$tmp_filter" ;;
        esac
    done < <(jq -c '.risks[]' "$WORK_DIR/discovery.json")

    local to_process
    if [ -s "$tmp_filter" ]; then
        to_process=$(jq -s '.' "$tmp_filter")
    else
        to_process="[]"
    fi
    rm -f "$tmp_filter"

    local to_process_count
    to_process_count=$(echo "$to_process" | jq 'length')

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

    local risks
    risks=$(jq -c '.risks[]' "$WORK_DIR/filter-result.json" 2>/dev/null)

    # Guard: no risks to batch
    if [ -z "$risks" ]; then
        log "No risks to batch"
        echo 0
        return
    fi

    local risk_array=()

    while read -r risk; do
        risk_array+=("$risk")
    done <<< "$risks"

    local total=${#risk_array[@]}
    local batch_num=0

    for ((i=0; i<total; i+=RISKS_PER_SUBAGENT)); do
        batch_num=$((batch_num + 1))

        # Accumulate batch risks in temp file to avoid O(n^2) jq
        local tmp_batch
        tmp_batch=$(mktemp)
        for ((j=i; j<i+RISKS_PER_SUBAGENT && j<total; j++)); do
            echo "${risk_array[$j]}" >> "$tmp_batch"
        done

        local batch_risks
        batch_risks=$(jq -s '.' "$tmp_batch")
        rm -f "$tmp_batch"

        local batch_size
        batch_size=$(echo "$batch_risks" | jq 'length')
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

    # check_env already called at top level before cleanup
    JIRA_AUTH=$(echo -n "${JIRA_EMAIL}:${JIRA_API_KEY}" | base64 | tr -d '\n')

    # Generate run metadata with unique run_id for CPT tracking
    local run_id
    run_id=$(uuidgen 2>/dev/null || echo "run-$(date +%s)")
    jq -n \
        --arg rid "$run_id" \
        --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        --arg q "$QUARTER_OVERRIDE" \
        --argjson force "$FORCE_MODE" \
        --arg cat "${CATEGORY_FILTER:-}" \
        '{run_id:$rid, started_at:$ts, quarter:$q, force:$force, category_filter:$cat}' \
        > "$WORK_DIR/run-metadata.json"

    notify_slack "RR batch review starting (force=$FORCE_MODE)"

    local total_risks
    total_risks=$(phase_discovery)
    [ "$total_risks" -eq 0 ] && die "No risks found"

    local to_process
    to_process=$(phase_filter)
    if [ "$to_process" -eq 0 ]; then
        log "No risks to process"
        echo "0"
        exit 0
    fi

    local batches
    batches=$(phase_extraction)

    # Update run metadata with discovery/filter/batch counts
    jq --argjson disc "$total_risks" --argjson proc "$to_process" --argjson bat "$batches" \
        '. + {total_discovered:$disc, total_to_process:$proc, batch_count:$bat}' \
        "$WORK_DIR/run-metadata.json" > "$WORK_DIR/run-metadata.json.tmp" \
        && mv "$WORK_DIR/run-metadata.json.tmp" "$WORK_DIR/run-metadata.json"

    "$SCRIPT_DIR/_update_cpt.sh" prepared "$batches batches ready ($to_process risks, force=$FORCE_MODE)" || true

    log "=========================================="
    log "PREPARATION COMPLETE — $batches batches ready for dispatch"
    log "=========================================="

    # Output batch count as last line for caller to capture
    echo "$batches"
}

main "$@"
