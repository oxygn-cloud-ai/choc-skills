#!/bin/bash
# _publish_one.sh — Standalone wrapper for publishing a single review to Jira
#
# Replaces the export -f publish_review pattern for macOS compatibility.
# Called by rr-batch.sh via xargs -P.
#
# Features:
#   - Idempotency: checks for existing same-day Review before creating
#   - Retry with exponential backoff on 429/503/529
#
# Usage: _publish_one.sh <risk_key>
#
# Required environment variables:
#   WORK_DIR         — Working directory
#   JIRA_BASE_URL    — Jira instance URL
#   JIRA_AUTH        — Base64-encoded Jira auth (email:token)
#   PROJECT_KEY      — Jira project key (e.g. RR)

set -uo pipefail

risk_key="${1:?Usage: _publish_one.sh <risk_key>}"

# Source config from env vars
WORK_DIR="${WORK_DIR:?WORK_DIR must be set}"
JIRA_BASE_URL="${JIRA_BASE_URL:?JIRA_BASE_URL must be set}"
JIRA_AUTH="${JIRA_AUTH:?JIRA_AUTH must be set}"
PROJECT_KEY="${PROJECT_KEY:?PROJECT_KEY must be set}"

MAX_PUBLISH_RETRIES=3

# File paths
assessment_file="$WORK_DIR/individual/${risk_key}.json"
result_file="$WORK_DIR/jira-results/${risk_key}.json"
error_file="$WORK_DIR/jira-errors/${risk_key}.json"
log_file="$WORK_DIR/logs/publish_${risk_key}.log"

# Ensure directories exist
mkdir -p "$WORK_DIR/jira-results" "$WORK_DIR/jira-errors" "$WORK_DIR/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$log_file"
}

# Check assessment exists
if [ ! -f "$assessment_file" ]; then
    log "${risk_key}:SKIP:NO_ASSESSMENT"
    echo "${risk_key}:SKIP:NO_ASSESSMENT"
    exit 1
fi

log "${risk_key}:PUBLISHING"

#=============================================================================
# IDEMPOTENCY CHECK — skip if same-day Review already exists
#=============================================================================

today=$(date +%Y-%m-%d)
check_jql="project = $PROJECT_KEY AND parent = $risk_key AND issuetype = Review AND summary ~ \"$today\""
check_payload=$(jq -n --arg jql "$check_jql" '{jql: $jql, maxResults: 1, fields: ["summary"]}')

existing_response=$(curl -s -X POST "$JIRA_BASE_URL/rest/api/3/search/jql" \
    -H "Authorization: Basic $JIRA_AUTH" \
    -H "Content-Type: application/json" \
    -d "$check_payload" \
    --max-time 15 2>/dev/null)

existing_count=$(echo "$existing_response" | jq '.issues | length' 2>/dev/null || echo 0)

if [ "$existing_count" -gt 0 ]; then
    existing_key=$(echo "$existing_response" | jq -r '.issues[0].key')
    log "${risk_key}:SKIP:ALREADY_REVIEWED:${existing_key}"
    echo "${risk_key}:SKIP:ALREADY_REVIEWED:${existing_key}"
    # Save to results (not errors) — this is a successful outcome
    echo "$existing_response" > "$result_file"
    exit 0
fi

#=============================================================================
# BUILD JIRA PAYLOAD
#=============================================================================

# Extract Jira description from assessment
jira_desc=$(jq -r '.jira_description // .assessment.sections.context.narrative // "Assessment completed"' "$assessment_file")
summary="Risk Review -- $today"

# Create ADF description
adf_desc=$(jq -n --arg text "$jira_desc" '{
    type: "doc",
    version: 1,
    content: [{
        type: "paragraph",
        content: [{type: "text", text: $text}]
    }]
}')

# Build Jira payload
payload=$(jq -n \
    --arg project "$PROJECT_KEY" \
    --arg parent "$risk_key" \
    --arg summary "$summary" \
    --argjson desc "$adf_desc" \
    '{
        fields: {
            project: {key: $project},
            issuetype: {name: "Review"},
            parent: {key: $parent},
            summary: $summary,
            description: $desc
        }
    }')

#=============================================================================
# CREATE JIRA ISSUE — with retry and backoff
#=============================================================================

attempt=0
while [ $attempt -lt $MAX_PUBLISH_RETRIES ]; do
    attempt=$((attempt + 1))

    response=$(curl -s -w "\n%{http_code}" -X POST "$JIRA_BASE_URL/rest/api/3/issue" \
        -H "Authorization: Basic $JIRA_AUTH" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --max-time 30 2>&1)

    http_code=$(echo "$response" | tail -n1 | tr -d '\r')
    http_body=$(echo "$response" | sed '$d')

    case "$http_code" in
        201)
            echo "$http_body" > "$result_file"
            new_key=$(echo "$http_body" | jq -r '.key')
            log "${risk_key}:SUCCESS:${new_key}"
            echo "${risk_key}:SUCCESS:${new_key}"
            exit 0
            ;;
        429|503|529)
            # Rate limited or overloaded — backoff and retry
            sleep_time=$((attempt * 10))
            log "${risk_key}:HTTP_${http_code}:RETRY_${attempt}:SLEEPING_${sleep_time}s"
            sleep "$sleep_time"
            continue
            ;;
        *)
            # Permanent failure — don't retry
            jq -n --arg code "http_$http_code" --arg body "$http_body" '{error: $code, response: $body}' > "$error_file" 2>/dev/null || \
                echo "{\"error\": \"http_$http_code\", \"response\": \"parse_error\"}" > "$error_file"
            log "${risk_key}:FAILED:HTTP_$http_code"
            echo "${risk_key}:FAILED:HTTP_$http_code"
            exit 1
            ;;
    esac
done

# Exhausted retries
jq -n --arg code "max_retries" --argjson attempts "$MAX_PUBLISH_RETRIES" '{error: $code, attempts: $attempts}' > "$error_file"
log "${risk_key}:FAILED:MAX_RETRIES"
echo "${risk_key}:FAILED:MAX_RETRIES"
exit 1
