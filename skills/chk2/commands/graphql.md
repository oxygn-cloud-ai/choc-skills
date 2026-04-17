---
name: chk2:graphql
description: "Test GraphQL security: introspection, depth, batching"
allowed-tools: Read, Bash(curl *), Bash(echo *), Write
---

# chk2:graphql — GraphQL Security

Test for GraphQL-related vulnerabilities on https://myzr.io. Append results to `SECURITY_CHECK.md`.

## Tests

```bash
# GQ1: Introspection — check common GraphQL endpoints
for path in /graphql /graphql/ /api/graphql /gql /query /v1/graphql; do
  status=$(curl -s -o /dev/null -w "%{http_code}" "https://myzr.io$path" -X POST \
    -H "Content-Type: application/json" \
    -H "User-Agent: Mozilla/5.0" \
    -d '{"query":"{__schema{types{name}}}"}')
  echo "$path: $status"
done

# Also try GET-based introspection
for path in /graphql /api/graphql; do
  status=$(curl -s -o /dev/null -w "%{http_code}" "https://myzr.io${path}?query=%7B__schema%7Btypes%7Bname%7D%7D%7D" \
    -H "User-Agent: Mozilla/5.0")
  echo "$path (GET): $status"
done
```

```bash
# GQ2: Query depth — send deeply nested query (20 levels)
DEEP_QUERY='{"query":"{ a1: __typename '
for i in $(seq 1 20); do
  DEEP_QUERY+="... on Query { a${i}: __typename "
done
for i in $(seq 1 20); do
  DEEP_QUERY+="} "
done
DEEP_QUERY+='}"}'

for path in /graphql /api/graphql; do
  result=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "https://myzr.io$path" -X POST \
    -H "Content-Type: application/json" \
    -H "User-Agent: Mozilla/5.0" \
    -d "$DEEP_QUERY")
  echo "$path depth test: $result"
done
```

```bash
# GQ3: Batch query — send array of 50 queries
BATCH='['
for i in $(seq 1 50); do
  if [ $i -gt 1 ]; then BATCH+=','; fi
  BATCH+="{\"query\":\"{__typename}\"}"
done
BATCH+=']'

for path in /graphql /api/graphql; do
  result=$(curl -s -o /dev/null -w "%{http_code}" "https://myzr.io$path" -X POST \
    -H "Content-Type: application/json" \
    -H "User-Agent: Mozilla/5.0" \
    -d "$BATCH")
  echo "$path batch test: $result"
done
```

```bash
# GQ4: Field suggestion — send query with typo to trigger "Did you mean" suggestions
for path in /graphql /api/graphql; do
  result=$(curl -s "https://myzr.io$path" -X POST \
    -H "Content-Type: application/json" \
    -H "User-Agent: Mozilla/5.0" \
    -d '{"query":"{usr}"}')
  echo "$path suggestion test: $result"
done
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| GQ1 | Introspection disabled | All GraphQL endpoints return 404 or introspection query returns error/empty (PASS if 404 or introspection disabled) |
| GQ2 | Query depth limit | Deeply nested query (20 levels) returns depth limit error or 404 (PASS if limited or no GraphQL endpoint) |
| GQ3 | Batch query limit | Array of 50 queries is rejected or limited, or endpoint returns 404 (PASS if batching limited or no endpoint) |
| GQ4 | Field suggestions suppressed | Query with typo does NOT return "Did you mean" suggestions, or endpoint returns 404 (PASS if no suggestions or no endpoint) |

## Output

Write to `SECURITY_CHECK.parts/graphql.md`:

```markdown
### GraphQL

| # | Test | Result | Evidence |
|---|------|--------|----------|
| GQ1 | Introspection disabled | {PASS/FAIL} | {HTTP status per path, whether schema returned} |
| GQ2 | Query depth limit | {PASS/FAIL} | {response or HTTP status} |
| GQ3 | Batch query limit | {PASS/FAIL} | {response or HTTP status} |
| GQ4 | Field suggestions suppressed | {PASS/FAIL} | {whether "Did you mean" appeared} |
```

## After

Ask the user: **Do you want help fixing the GraphQL issues found?** If yes, invoke `/chk2:fix` with context about which GraphQL tests failed.

## Status signal

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
