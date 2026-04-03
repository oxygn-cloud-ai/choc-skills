# rr:remove — Delete All Review Tickets from Jira (TESTING ONLY)

**WARNING: This is a destructive, hidden testing command. It deletes Jira tickets.**

Context from user: $ARGUMENTS

## Safety Checks

Before doing ANYTHING, confirm with user:

```
WARNING: This will DELETE all Review tickets in the RR project.

- ONLY Review tickets (issue type ID 12686) will be deleted
- Risk items (parent tickets) will NOT be touched
- Mitigation items will NOT be touched
- This cannot be undone

Type "DELETE ALL REVIEWS" to confirm:
```

Wait for the user to type exactly `DELETE ALL REVIEWS`. Any other response: abort.

## Process

### Step 1 — Query all Review tickets

Use the Bash tool to query Jira for all Review tickets:

```bash
JIRA_AUTH=$(echo -n "${JIRA_EMAIL}:${JIRA_API_KEY}" | base64 | tr -d '\n')
JIRA_BASE_URL="https://chocfin.atlassian.net"

# Paginate through all Review tickets
all_keys=""
next_page_token=""
while true; do
  payload='{"jql": "project = RR AND issuetype = Review ORDER BY key ASC", "maxResults": 100, "fields": ["summary", "issuetype"]'
  if [ -n "$next_page_token" ]; then
    payload="$payload, \"nextPageToken\": \"$next_page_token\""
  fi
  payload="$payload}"

  resp=$(curl -s -X POST "$JIRA_BASE_URL/rest/api/3/search/jql" \
    -H "Authorization: Basic $JIRA_AUTH" \
    -H "Content-Type: application/json" \
    -d "$payload" --max-time 30)

  # Extract keys — DOUBLE CHECK each is issuetype Review (ID 12686)
  batch_keys=$(echo "$resp" | jq -r '.issues[] | select(.fields.issuetype.id == "12686" or .fields.issuetype.name == "Review") | .key')
  all_keys="$all_keys $batch_keys"

  next_page_token=$(echo "$resp" | jq -r '.nextPageToken // empty')
  [ -z "$next_page_token" ] && break
done

count=$(echo "$all_keys" | wc -w | tr -d ' ')
echo "Found $count Review tickets to delete"
echo "$all_keys"
```

### Step 2 — Show the user what will be deleted

Display the count and ask for final confirmation:

```
Found N Review tickets.

First 10: RR-840, RR-841, RR-842, ...

Proceed with deletion? (yes/no)
```

### Step 3 — Delete each Review ticket

Delete one at a time with rate limiting (1 second delay between calls):

```bash
JIRA_AUTH=$(echo -n "${JIRA_EMAIL}:${JIRA_API_KEY}" | base64 | tr -d '\n')
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
    # Retry once
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

  sleep 1  # Rate limit: 1 request per second
done

echo ""
echo "Complete: $deleted deleted, $failed failed"
```

### Step 4 — Report

Show final count:
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
3. **Always verify issuetype in the JQL AND in the jq filter (defense in depth)**
4. **Always require explicit user confirmation**
5. **Rate limit: maximum 1 delete per second to avoid 429s**
