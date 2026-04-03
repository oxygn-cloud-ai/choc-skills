#!/bin/bash
# _publish_one.sh — Publish a single risk assessment as a Jira Review ticket
#
# Reads the full assessment from individual/<risk_key>.json, renders all 8
# sections to markdown, and creates a Review child ticket with proper labels,
# dates, assignee, and summary format per step-6-publish.md spec.
#
# Features:
#   - Full assessment rendering (all 8 sections, not just context)
#   - Idempotency: checks for existing same-day Review before creating
#   - Retry with exponential backoff on 429/503/529
#   - Proper Jira fields: labels, dates, assignee, contentFormat: markdown
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
ASSIGNEE_ID="712020:fd08a63d-8c2c-4412-8761-834339d9475c"

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
# DATE AND LABEL COMPUTATION
#=============================================================================

today=$(date +%Y-%m-%d)
month=$(date +%m)
year=$(date +%Y)
month_name=$(date +%b)
day=$(date +%d)

# Summary format: "Review: 2026, Apr 03"
summary="Review: ${year}, ${month_name} ${day}"

# Quarterly label
case $month in
    01|02|03) quarterly_label="Q1-Risk-Review" ;;
    04|05|06) quarterly_label="Q2-Risk-Review" ;;
    07|08|09) quarterly_label="Q3-Risk-Review" ;;
    10|11|12) quarterly_label="Q4-Risk-Review" ;;
esac

#=============================================================================
# IDEMPOTENCY CHECK — skip if same-day Review already exists
#=============================================================================

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
    echo "$existing_response" > "$result_file"
    exit 0
fi

#=============================================================================
# RENDER FULL ASSESSMENT TO MARKDOWN
#=============================================================================

# Use jq to render all 8 sections into markdown matching step-6-publish.md template
rendered_md=$(jq -r '
    .assessment as $a |
    $a.sections as $s |

    "## Risk Assessment: \($s.header.risk_id) — \($s.header.risk_name)\n" +
    "\n**Risk Statement:** \($s.header.risk_statement // "N/A")\n" +
    "\n**Risk Category:** \($s.header.risk_category_name // $s.header.risk_category // "N/A")\n" +
    "\n**Assessment Date:** \($a.metadata.assessment_date // "N/A")\n" +
    "\n---\n" +

    "\n### Context\n\n" +
    "\($s.context.narrative // "N/A")\n\n" +
    "**Business Relevance:**\n" +
    ([$s.context.business_relevance[]? // empty] | map("- " + .) | join("\n")) +
    "\n\n**Materiality:** \($s.context.materiality_rationale // "N/A")\n" +
    "\n---\n" +

    "\n### Applicable Regulatory Framework\n\n" +
    ([$s.regulatory_framework[]? // empty] | to_entries | map(
        "\(.value | (.key + 1 | tostring) // (.key | tostring)). **\(.value.instrument_name // "Unknown")** (\(.value.version_date // "N/A"), \(.value.status // "N/A"))\n   \(.value.relevance // "N/A")"
    ) | join("\n")) +
    "\n\n---\n" +

    "\n### Inherent Risk Assessment\n\n" +
    "| Dimension | Rating | Rationale |\n" +
    "|-----------|--------|----------|\n" +
    "| Likelihood | \($s.inherent_risk.likelihood // "N/A") | \($s.inherent_risk.likelihood_rationale // "N/A") |\n" +
    "| Impact | \($s.inherent_risk.impact // "N/A") | \($s.inherent_risk.impact_rationale // "N/A") |\n" +
    "| **Rating** | **\($s.inherent_risk.rating // "N/A")** | |\n" +
    "\n---\n" +

    "\n### Existing Controls\n\n" +
    ([$s.existing_controls[]? // empty] | map(
        "**\(.id // "C?"): \(.description // "N/A")**\n" +
        "- Type: \(.control_type // "N/A")\n" +
        "- Effectiveness: \(.effectiveness // "N/A")\n" +
        (if .effectiveness_rationale then "- \(.effectiveness_rationale)\n" else "" end) +
        (if .gaps and (.gaps | length) > 0 then "- Gaps: " + (.gaps | join(", ")) + "\n" else "" end)
    ) | join("\n")) +
    "\n\n---\n" +

    "\n### Residual Risk Assessment\n\n" +
    "| Dimension | Rating | Rationale |\n" +
    "|-----------|--------|----------|\n" +
    "| Likelihood | \($s.residual_risk.likelihood // "N/A") | \($s.residual_risk.likelihood_rationale // "N/A") |\n" +
    "| Impact | \($s.residual_risk.impact // "N/A") | \($s.residual_risk.impact_rationale // "N/A") |\n" +
    "| **Rating** | **\($s.residual_risk.rating // "N/A")** | |\n\n" +
    "\($s.residual_risk.control_effect_summary // "")\n" +
    "\n---\n" +

    "\n### Recommendations\n\n" +
    ([$s.recommendations[]? // empty] | map(
        "**\(.id // "R?"): \(.action // "N/A")**\n" +
        "- Priority: \(.priority // "N/A")\n" +
        "- Regulatory Basis: \(.regulatory_basis // "N/A")\n" +
        (if .suggested_owner then "- Suggested Owner: \(.suggested_owner)\n" else "" end)
    ) | join("\n")) +
    "\n\n---\n" +

    "\n### Evidences\n\n" +
    "**Sources Used:**\n" +
    ([$s.evidences.sources_used[]? // empty] | map("- \(.description // "N/A")") | join("\n")) +
    "\n\n**Sources Unavailable:**\n" +
    ([$s.evidences.sources_unavailable[]? // empty] | map("- " + .) | join("\n")) +
    "\n\n**Caveats:**\n" +
    ([$s.evidences.caveats[]? // empty] | map("- " + .) | join("\n"))
' "$assessment_file" 2>/dev/null)

if [ -z "$rendered_md" ]; then
    log "${risk_key}:ERROR:RENDER_FAILED"
    # Fallback to context narrative
    rendered_md=$(jq -r '.assessment.sections.context.narrative // "Assessment render failed"' "$assessment_file")
fi

#=============================================================================
# BUILD JIRA PAYLOAD — with all required fields
#=============================================================================

# Build ADF description from rendered markdown
# Jira REST API v3 requires Atlassian Document Format, not raw strings.
# Split markdown into paragraphs and render each as an ADF node.
adf_desc=$(echo "$rendered_md" | python3 -c '
import sys, json

lines = sys.stdin.read().split("\n")
nodes = []
i = 0
while i < len(lines):
    line = lines[i]

    # Skip empty lines
    if not line.strip():
        i += 1
        continue

    # Horizontal rule
    if line.strip() == "---":
        nodes.append({"type": "rule"})
        i += 1
        continue

    # Headings
    if line.startswith("### "):
        nodes.append({"type": "heading", "attrs": {"level": 3},
            "content": [{"type": "text", "text": line[4:]}]})
        i += 1
        continue
    if line.startswith("## "):
        nodes.append({"type": "heading", "attrs": {"level": 2},
            "content": [{"type": "text", "text": line[3:]}]})
        i += 1
        continue

    # Table (collect all | lines)
    if line.startswith("|"):
        rows = []
        while i < len(lines) and lines[i].startswith("|"):
            cells = [c.strip() for c in lines[i].split("|")[1:-1]]
            # Skip separator rows (|---|---|)
            if cells and all(set(c) <= set("-: ") for c in cells):
                i += 1
                continue
            rows.append(cells)
            i += 1
        if rows:
            header = rows[0] if rows else []
            body = rows[1:] if len(rows) > 1 else []
            table_rows = []
            # Header row
            if header:
                table_rows.append({"type": "tableRow", "content": [
                    {"type": "tableHeader", "content": [
                        {"type": "paragraph", "content": [{"type": "text", "text": c}]}
                    ]} for c in header
                ]})
            for row in body:
                table_rows.append({"type": "tableRow", "content": [
                    {"type": "tableCell", "content": [
                        {"type": "paragraph", "content": [{"type": "text", "text": c}]}
                    ]} for c in row
                ]})
            nodes.append({"type": "table", "content": table_rows})
        continue

    # Bold paragraph (starts with **)
    # Bullet list (starts with -)
    if line.startswith("- "):
        items = []
        while i < len(lines) and lines[i].startswith("- "):
            text = lines[i][2:]
            items.append({"type": "listItem", "content": [
                {"type": "paragraph", "content": [{"type": "text", "text": text}]}
            ]})
            i += 1
        nodes.append({"type": "bulletList", "content": items})
        continue

    # Regular paragraph (collect consecutive non-empty non-special lines)
    para_lines = []
    while i < len(lines) and lines[i].strip() and not lines[i].startswith("#") and not lines[i].startswith("|") and not lines[i].startswith("- ") and lines[i].strip() != "---":
        para_lines.append(lines[i])
        i += 1
    if para_lines:
        text = " ".join(para_lines)
        # Handle bold markers
        content = []
        parts = text.split("**")
        for j, part in enumerate(parts):
            if not part:
                continue
            if j % 2 == 1:  # odd = bold
                content.append({"type": "text", "text": part, "marks": [{"type": "strong"}]})
            else:
                content.append({"type": "text", "text": part})
        if content:
            nodes.append({"type": "paragraph", "content": content})

doc = {"type": "doc", "version": 1, "content": nodes if nodes else [
    {"type": "paragraph", "content": [{"type": "text", "text": "Assessment rendered but ADF conversion produced no nodes."}]}
]}
print(json.dumps(doc))
' 2>/dev/null)

# Fallback if Python ADF conversion fails
if [ -z "$adf_desc" ] || ! echo "$adf_desc" | jq -e '.type' >/dev/null 2>&1; then
    log "${risk_key}:WARN:ADF_FALLBACK"
    adf_desc=$(jq -n --arg text "$rendered_md" '{
        type: "doc", version: 1,
        content: [{
            type: "codeBlock",
            attrs: {language: "markdown"},
            content: [{type: "text", text: $text}]
        }]
    }')
fi

payload=$(jq -n \
    --arg project "$PROJECT_KEY" \
    --arg parent "$risk_key" \
    --arg summary "$summary" \
    --argjson desc "$adf_desc" \
    --arg assignee "$ASSIGNEE_ID" \
    --arg duedate "$today" \
    --arg startdate "$today" \
    --arg label "$quarterly_label" \
    '{
        fields: {
            project: {key: $project},
            issuetype: {name: "Review"},
            parent: {key: $parent},
            summary: $summary,
            description: $desc,
            assignee: {accountId: $assignee},
            duedate: $duedate,
            customfield_10015: $startdate,
            labels: [$label]
        },
        update: {}
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
            sleep_time=$((attempt * 10))
            log "${risk_key}:HTTP_${http_code}:RETRY_${attempt}:SLEEPING_${sleep_time}s"
            sleep "$sleep_time"
            continue
            ;;
        *)
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
