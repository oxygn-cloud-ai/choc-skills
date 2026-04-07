# chk2:github — Log Security Findings to GitHub Issues

Read the most recent `SECURITY_CHECK.md` and create a GitHub Issue for every FAIL and WARN finding, assigning P1-P4 priority labels and category labels. Skip findings that already have an open issue (comment instead).

## Pre-flight Checks

Before doing anything, silently verify:

1. **`gh` is installed**: Run `gh --version`. If not found:
   > **chk2:github error**: GitHub CLI (`gh`) is not installed. Install it from https://cli.github.com/ and try again.

2. **`gh` is authenticated**: Run `gh auth status`. If not authenticated:
   > **chk2:github error**: `gh` is not authenticated. Run `gh auth login` and try again.

3. **Inside a GitHub repo**: Run `gh repo view --json nameWithOwner` to confirm the current directory is a GitHub-tracked repo. If not:
   > **chk2:github error**: Not inside a GitHub repository. Navigate to a repo with a GitHub remote and try again.

4. **`SECURITY_CHECK.md` exists**: Verify the file exists in the repo root. If not:
   > **chk2:github error**: No `SECURITY_CHECK.md` found in the repo root. Run `/chk2` first, then `/chk2 github`.

## Instructions

### 1. Read SECURITY_CHECK.md

Read the entire file and extract:
- The audit date (from the `**Date**:` header line)
- The target URL (from the `**Target**:` header line)
- Every category section with its results table

### 2. Parse all FAIL and WARN findings

For each category section, parse the results table. Skip rows where Result is `PASS`. For every FAIL and WARN row, capture:

- **Category** (e.g., `tls`, `headers`, `cors`, `api`)
- **Test ID** (the `#` column value)
- **Test name** (the `Test` column value)
- **Status** (`FAIL` or `WARN`)
- **Evidence** (the `Evidence` column value)
- **Recommendation** — look up the matching item in the `## Recommendations` section at the bottom of the file (if present)

### 3. Map status + category to P1-P4 priority

Use this base mapping:

| Status | Category bucket | Default Priority |
|---|---|---|
| FAIL | auth, jwt, api, brute, smuggling, infra, ws, cors, tls (cert/cipher) | P1-blocking |
| FAIL | headers, dns, waf, scale, disclosure, cookies, redirect | P2-important |
| FAIL | cache, fingerprint, hardening, transport, negotiation, proxy, business, backend, timing, compression, sse, ipv6 | P3-minor |
| FAIL | reporting, graphql (informational) | P3-minor |
| WARN | any category | P4-infra |

**Tiebreakers (apply after base mapping):**
- Active exploit possible (e.g., SQL injection, RCE, XSS confirmed) → P1-blocking
- Authentication or authorization bypass confirmed → P1-blocking
- User data exposure (PII, credentials, session tokens visible) → at least P2-important
- Compliance/reporting only (security.txt, NEL, Report-To, CT) → P4-infra
- WARN status never goes above P3-minor (warnings are not blockers)

### 4. Determine labels

Every issue gets:
- `security` (always)
- One priority label: `P1-blocking`, `P2-important`, `P3-minor`, or `P4-infra`
- One category label: `category:<cat>` (e.g., `category:tls`, `category:headers`)

### 5. Check for duplicates before creating issues

Run once:
```bash
gh issue list --limit 100 --state open --label security --json number,title,labels,body
```

For each finding, scan the result for a likely match:
- Title contains the same category AND same test ID, OR
- Body contains the same `category: <cat>, test: <id>` reference

If a match is found:
- Add a comment to the existing issue: `gh issue comment <num> --body "Re-detected by chk2 audit on <date>. Evidence: <new evidence>"`
- Track this as a "comment added"
- Do not create a new issue

### 6. Create GitHub Issues

For each non-duplicate finding, run:

```bash
gh issue create \
  --title "chk2: <category>:<id> <test name>" \
  --label "security,category:<cat>,<priority>" \
  --milestone "<milestone>" \
  --body "$(cat <<'EOF'
**Source:** chk2 audit <YYYY-MM-DD>, category `<cat>`, test `<id>: <name>`

**Status:** <FAIL|WARN>
**Priority:** <P1-blocking|P2-important|P3-minor|P4-infra>
**Target:** <target URL from SECURITY_CHECK.md>

## Evidence

<evidence column text from SECURITY_CHECK.md>

## Recommendation

<recommendation from Recommendations section, if available — otherwise: "See `/chk2 fix` for resolution guidance.">

---
*Logged automatically by `/chk2:github`. Run `/chk2:fix` for resolution guidance.*
EOF
)"
```

**Milestone selection:**
- P1 / P2 → current open milestone (`gh api repos/:owner/:repo/milestones --jq '.[] | select(.state=="open") | .title' | head -1`)
- P3 → next open milestone (second result of the same query)
- P4 → no milestone (omit `--milestone` flag)

If no milestones exist, omit `--milestone` for all issues and note this in the summary.

**Auto-create labels** (idempotent — safe to run every time):
```bash
gh label create "security"          --color "e4e669" --description "Security concern" --force
gh label create "P1-blocking"       --color "b60205" --description "Blocks release: RCE, auth bypass, data exposure" --force
gh label create "P2-important"      --color "d93f0b" --description "Wrong data, state leaks, missing validation" --force
gh label create "P3-minor"          --color "fbca04" --description "Display formatting, polish, rare edge cases" --force
gh label create "P4-infra"          --color "0e8a16" --description "Performance, code dedup, test gaps, docs" --force
gh label create "category:headers"  --color "1d76db" --description "HTTP security headers" --force
gh label create "category:tls"      --color "1d76db" --description "TLS/SSL configuration" --force
gh label create "category:dns"      --color "1d76db" --description "DNS, DNSSEC, SPF, DMARC" --force
gh label create "category:cors"     --color "1d76db" --description "CORS policy" --force
gh label create "category:api"      --color "1d76db" --description "API injection, fuzzing" --force
gh label create "category:ws"       --color "1d76db" --description "WebSocket security" --force
gh label create "category:waf"      --color "1d76db" --description "WAF rules, rate limiting" --force
gh label create "category:infra"    --color "1d76db" --description "Cloudflare/infrastructure config" --force
gh label create "category:brute"    --color "1d76db" --description "Brute force, session enumeration" --force
gh label create "category:scale"    --color "1d76db" --description "Scaling, payload limits, ReDoS" --force
gh label create "category:disclosure" --color "1d76db" --description "Information disclosure" --force
gh label create "category:auth"     --color "1d76db" --description "Auth, session, IDOR, privilege escalation" --force
gh label create "category:jwt"      --color "1d76db" --description "JWT/token security" --force
```

Run the label creation block ONCE before the issue creation loop. Additional category labels can be created on demand if a category appears that isn't pre-listed.

### 7. Output a summary table

After all findings are processed, print:

```
Security findings logged to GitHub Issues

| #   | Issue       | Category | Test                                  | Priority    |
|-----|-------------|----------|---------------------------------------|-------------|
| 1   | #45         | tls      | tls:3 weak cipher suite enabled       | P1-blocking |
| 2   | #46         | headers  | headers:7 missing CSP                 | P2-important|
| 3   | comment#39  | api      | api:12 (added context to existing)    | -           |
| ... | ...         | ...      | ...                                   | ...         |

Totals
  New issues created:  N
  Comments added:      M
  By priority:
    P1-blocking:  X
    P2-important: X
    P3-minor:     X
    P4-infra:     X
  By category:
    tls:        X
    headers:    X
    cors:       X
    ...
```

### 8. Final message

End with exactly:

> All security findings logged to GitHub Issues. Run `/chk2:fix` to implement fixes.

## Failure modes

- **`gh` rate-limited**: Stop, report how many issues were created so far, and tell the user to retry in N minutes (parse the rate limit reset from `gh api rate_limit`).
- **Network failure mid-batch**: Print the partial summary table and the IDs of findings not yet logged. The user can re-run `/chk2:github` — duplicate detection will skip the ones already created.
- **No FAIL or WARN findings**: Print "No findings to log — the audit reported all PASS." and exit without creating issues.
- **`SECURITY_CHECK.md` malformed**: If the file exists but no category sections can be parsed, report "Unable to parse SECURITY_CHECK.md — file may be incomplete or corrupted. Re-run `/chk2` to regenerate."
