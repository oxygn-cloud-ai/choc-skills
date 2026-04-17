---
name: rr:remove
description: "Delete review tickets from Jira (testing only)"
allowed-tools: Bash(curl *), Bash(jq *), Bash(base64 *), Bash(echo *), Bash(printf *), Bash(tr *), Bash(wc *), Bash(sleep *)
---

# rr:remove — Delete Review Tickets from Jira (TESTING ONLY)

**WARNING: This is a destructive, hidden testing command. It deletes Jira tickets.**

Context from user: $ARGUMENTS

## Parse Arguments

Determine the mode from $ARGUMENTS:

| Input | Mode | Action |
|-------|------|--------|
| `remove` (no args) | All Reviews | Delete every Review ticket in project RR |
| `remove RR-220` | Parent Reviews | Delete all Review children of RR-220 |
| `remove RR-220 RR-221 RR-222` | Parent Reviews | Delete all Review children of each listed parent |
| `remove RR-840` (where RR-840 is a Review) | Single Review | Delete that one Review ticket only |
| `remove RR-840 RR-841` (where both are Reviews) | Single Reviews | Delete those specific Review tickets |

To distinguish: if a ticket key is given, query its `issuetype`. If it's a Risk, find its Review children. If it's a Review, delete it directly.

---

## Mode 1: Delete ALL Review Tickets

### Safety Confirmation

```
WARNING: This will DELETE ALL Review tickets in the RR project.

- ONLY Review tickets (issue type ID 12686) will be deleted
- Risk items (parent tickets) will NOT be touched
- Mitigation items will NOT be touched
- This cannot be undone

Type "DELETE ALL REVIEWS" to confirm:
```

Wait for the user to type exactly `DELETE ALL REVIEWS`. Any other response: abort.

### Query

```bash
JIRA_AUTH=$(printf '%s' "${JIRA_EMAIL}:${JIRA_API_KEY}" | base64 | tr -d '\n')
JIRA_BASE_URL="https://chocfin.atlassian.net"

all_keys=""
next_page_token=""
page_count=0
MAX_PAGES=100
while true; do
  page_count=$((page_count + 1))
  if [ "$page_count" -gt "$MAX_PAGES" ]; then
    echo "WARNING: Pagination limit reached ($MAX_PAGES pages). Results may be incomplete."
    break
  fi

  payload='{"jql": "project = RR AND issuetype = Review ORDER BY key ASC", "maxResults": 100, "fields": ["summary", "issuetype"]'
  if [ -n "$next_page_token" ]; then
    payload="$payload, \"nextPageToken\": \"$next_page_token\""
  fi
  payload="$payload}"

  resp=$(curl -s -X POST "$JIRA_BASE_URL/rest/api/3/search/jql" \
    -H "Authorization: Basic $JIRA_AUTH" \
    -H "Content-Type: application/json" \
    -d "$payload" --max-time 30)

  batch_keys=$(echo "$resp" | jq -r '.issues[] | select(.fields.issuetype.id == "12686" or .fields.issuetype.name == "Review") | .key')
  all_keys="$all_keys $batch_keys"

  next_page_token=$(echo "$resp" | jq -r '.nextPageToken // empty')
  [ -z "$next_page_token" ] && break
done

count=$(echo "$all_keys" | wc -w | tr -d ' ')
echo "Found $count Review tickets to delete"
```

Show count, first 10 keys, ask "Proceed? (yes/no)". Then delete (see Deletion section below).

---

## Mode 2: Delete Review Children of Specific Risk(s)

For each ticket key provided in $ARGUMENTS:

### Step 1 — Verify it's a Risk (not a Review or Mitigation)

```bash
JIRA_AUTH=$(printf '%s' "${JIRA_EMAIL}:${JIRA_API_KEY}" | base64 | tr -d '\n')
JIRA_BASE_URL="https://chocfin.atlassian.net"

resp=$(curl -s "$JIRA_BASE_URL/rest/api/3/issue/RR-220?fields=issuetype,summary" \
  -H "Authorization: Basic $JIRA_AUTH" --max-time 15)

issue_type=$(echo "$resp" | jq -r '.fields.issuetype.name')
echo "$issue_type"
```

- If `Risk`: proceed to find its Review children
- If `Review`: switch to Mode 3 (delete this single Review directly)
- If `Mitigation` or anything else: **refuse to delete**, tell user this is not a Risk or Review

### Step 2 — Find all Review children of the Risk

```bash
jql="project = RR AND issuetype = Review AND parent = RR-220 ORDER BY key ASC"
```

Use the same paginated search as Mode 1 but with the parent filter.

### Step 3 — Confirm with user

```
Found N Review tickets under RR-220:
  RR-840: Review: 2026, Apr 03
  RR-841: Review: 2026, Apr 03
  ...

Delete these N Review tickets? (yes/no)
```

Then delete (see Deletion section below).

---

## Mode 3: Delete Specific Review Ticket(s)

For each ticket key provided:

### Step 1 — Verify it's a Review

Query the ticket and check `issuetype.name == "Review"` or `issuetype.id == "12686"`.

- If Review: add to deletion list
- If Risk: ask user "RR-220 is a Risk, not a Review. Delete all its Review children instead? (yes/no)"
- If Mitigation or other: **refuse**. Say "RR-XXX is a Mitigation, not a Review. Skipping."

### Step 2 — Confirm

```
Will delete N Review ticket(s):
  RR-840: Review: 2026, Apr 03
  RR-841: Review: 2026, Apr 03

Proceed? (yes/no)
```

Then delete (see Deletion section below).

---

## Deletion (shared by all modes)

Delete one at a time with rate limiting:

```bash
JIRA_AUTH=$(printf '%s' "${JIRA_EMAIL}:${JIRA_API_KEY}" | base64 | tr -d '\n')
JIRA_BASE_URL="https://chocfin.atlassian.net"

deleted=0
failed=0
for key in $ALL_KEYS; do
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE "$JIRA_BASE_URL/rest/api/3/issue/$key" \
    -H "Authorization: Basic $JIRA_AUTH" \
    --max-time 15)

  if [ "$http_code" = "204" ]; then
    deleted=$((deleted + 1))
    echo "Deleted $key ($deleted done)"
  elif [ "$http_code" = "429" ]; then
    echo "Rate limited at $key — sleeping 30s"
    sleep 30
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
      -X DELETE "$JIRA_BASE_URL/rest/api/3/issue/$key" \
      -H "Authorization: Basic $JIRA_AUTH" \
      --max-time 15)
    if [ "$http_code" = "204" ]; then
      deleted=$((deleted + 1))
      echo "Deleted $key on retry ($deleted done)"
    else
      failed=$((failed + 1))
      echo "FAILED to delete $key: HTTP $http_code"
    fi
  else
    failed=$((failed + 1))
    echo "FAILED to delete $key: HTTP $http_code"
  fi

  sleep 1
done

echo ""
echo "Complete: $deleted deleted, $failed failed"
```

## Report

```
Review ticket cleanup complete.
Deleted: N
Failed: M
Risk items: untouched
Mitigation items: untouched
```

## Critical Safety Rules

1. **NEVER delete tickets where issuetype is NOT "Review" (ID 12686)**
2. **NEVER delete tickets outside project RR**
3. **Always verify issuetype before deleting — via JQL filter AND per-ticket check**
4. **Always require explicit user confirmation before any deletion**
5. **Rate limit: maximum 1 delete per second to avoid 429s**
6. **If a ticket is a Mitigation: REFUSE. Do not offer alternatives.**
7. **If a ticket is a Risk: offer to delete its Review children, never the Risk itself**
