#!/bin/bash
# _update_cpt.sh — Non-blocking CPT (Claude Progress Tracker) event helper
#
# Posts a comment to CPT-1 in Jira and appends to local audit log.
# ALWAYS exits 0 — never blocks the calling workflow.
#
# Kill switch: export RR_CPT_DISABLED=true to skip all CPT activity.
#
# Usage:
#   _update_cpt.sh <event> <message>
#
# Events:
#   started | prepared | no_work | dispatch_progress |
#   complete | complete_with_errors | fatal | board_paper_published
#
# Required env:
#   JIRA_EMAIL, JIRA_API_KEY (for Jira API)
#   WORK_DIR or RR_WORK_DIR (for local audit log and run metadata)
#
# Revert instructions:
#   1. Remove all lines containing '_update_cpt.sh' from rr-prepare.sh and rr-finalize.sh
#   2. Delete this file
#   That's it. No other files depend on this script.

set -uo pipefail

# ─── KILL SWITCH ─────────────────────────────────────────────────────────────
if [ "${RR_CPT_DISABLED:-false}" = "true" ]; then
    exit 0
fi

# ─── CONFIGURATION ───────────────────────────────────────────────────────────

WORK_DIR="${WORK_DIR:-${RR_WORK_DIR:-${HOME}/rr-work}}"
CPT_TICKET="${CPT_TICKET:-CPT-1}"
JIRA_BASE_URL="https://chocfin.atlassian.net"
LOG_FILE="${WORK_DIR}/batch.log"
AUDIT_FILE="${WORK_DIR}/cpt-events.jsonl"
METADATA_FILE="${WORK_DIR}/run-metadata.json"

EVENT="${1:-unknown}"
MESSAGE="${2:-}"

# ─── HELPERS ─────────────────────────────────────────────────────────────────

timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

warn() {
    local msg
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] WARN [CPT] $*"
    echo "$msg" >&2
    [ -d "$WORK_DIR" ] && echo "$msg" >> "$LOG_FILE" 2>/dev/null
}

audit() {
    local jira_status="$1"
    local jira_error="${2:-}"
    local run_id
    run_id=$(jq -r '.run_id // "unknown"' "$METADATA_FILE" 2>/dev/null || echo "unknown")

    local entry
    entry=$(jq -nc \
        --arg ts "$(timestamp)" \
        --arg rid "$run_id" \
        --arg ev "$EVENT" \
        --arg msg "$MESSAGE" \
        --arg js "$jira_status" \
        --arg je "$jira_error" \
        '{timestamp:$ts, run_id:$rid, event:$ev, message:$msg, jira_status:$js, jira_error:$je}')

    mkdir -p "$WORK_DIR" 2>/dev/null
    echo "$entry" >> "$AUDIT_FILE" 2>/dev/null
}

# ─── BUILD COMMENT BODY ─────────────────────────────────────────────────────

build_comment() {
    local run_id quarter force_mode
    run_id=$(jq -r '.run_id // "unknown"' "$METADATA_FILE" 2>/dev/null || echo "unknown")
    quarter=$(jq -r '.quarter // "?"' "$METADATA_FILE" 2>/dev/null || echo "?")
    force_mode=$(jq -r '.force // false' "$METADATA_FILE" 2>/dev/null || echo "false")

    cat <<EOF
[RR Batch] ${EVENT} | Run: ${run_id} | $(timestamp)

${MESSAGE}

Quarter: ${quarter} | Force: ${force_mode}
EOF
}

# ─── POST COMMENT TO JIRA ───────────────────────────────────────────────────

post_comment() {
    # Compute auth internally — does NOT depend on caller exporting JIRA_AUTH
    if [ -z "${JIRA_EMAIL:-}" ] || [ -z "${JIRA_API_KEY:-}" ]; then
        warn "JIRA_EMAIL or JIRA_API_KEY not set — skipping CPT update"
        audit "skipped" "missing credentials"
        return 0
    fi

    local auth
    auth=$(echo -n "${JIRA_EMAIL}:${JIRA_API_KEY}" | base64 | tr -d '\n')

    local comment_body
    comment_body=$(build_comment)

    local payload
    payload=$(jq -n --arg body "$comment_body" '{body: {type: "doc", version: 1, content: [{type: "paragraph", content: [{type: "text", text: $body}]}]}}')

    local http_code
    local attempt=0
    local max_attempts=2

    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))

        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST "${JIRA_BASE_URL}/rest/api/3/issue/${CPT_TICKET}/comment" \
            -H "Authorization: Basic $auth" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            --max-time 15 2>/dev/null)

        case "$http_code" in
            2[0-9][0-9])
                audit "sent" ""
                return 0
                ;;
            429|503|529)
                if [ $attempt -lt $max_attempts ]; then
                    sleep 2
                    continue
                fi
                warn "CPT comment failed after retry: HTTP $http_code"
                audit "failed" "HTTP $http_code after $max_attempts attempts"
                return 0
                ;;
            *)
                warn "CPT comment failed: HTTP $http_code"
                audit "failed" "HTTP $http_code"
                return 0
                ;;
        esac
    done
}

# ─── MAIN ────────────────────────────────────────────────────────────────────

# Always exit 0 — wrap everything in a trap
trap 'exit 0' ERR EXIT

post_comment
exit 0
