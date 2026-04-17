---
name: chk1:github
description: Log audit findings as GitHub Issues with P1-P4 priority labels
allowed-tools: Read, Grep, Glob, Bash(gh *), Bash(git *), AskUserQuestion
---

# chk1:github — Log Audit Findings to GitHub Issues

Read the most recent audit output and create a GitHub Issue for every finding, assigning P1-P4 priority labels. Skip findings that already have an open issue (comment instead).

## Pre-flight Checks

Before doing anything, silently verify:

1. **`gh` is installed**: Run `gh --version`. If not found:
   > **chk1:github error**: GitHub CLI (`gh`) is not installed. Install it from https://cli.github.com/ and try again.

2. **`gh` is authenticated**: Run `gh auth status`. If not authenticated:
   > **chk1:github error**: `gh` is not authenticated. Run `gh auth login` and try again.

3. **Inside a GitHub repo**: Run `gh repo view --json nameWithOwner` to confirm the current directory is a GitHub-tracked repo. If not:
   > **chk1:github error**: Not inside a GitHub repository. Navigate to a repo with a GitHub remote and try again.

## Instructions

### 1. Locate the most recent audit output

Check in order:
- The current conversation (if a `/chk1` audit was just run)
- `AUDIT.md` in the repo root
- The most recent `/chk1` output in conversation history

If no audit is available:
> **chk1:github error**: No recent audit found. Run `/chk1` first, then `/chk1 github`.

### 2. Parse all findings into a structured list

Extract every finding from these audit sections:
- Bugs Found
- Critical Risks
- Unintended Changes
- Omissions
- Architectural Deviations

For each finding, capture:
- **ID** (e.g., BUG-1, RISK-2 — assign sequentially if the audit didn't number them)
- **Concise title** (one line, ≤70 chars)
- **Severity** (Critical / High / Medium / Low / Info)
- **Category** (bug / security / risk / unintended / omission / architecture)
- **File** and **line** reference (if applicable)
- **Description** (full text from audit)
- **Current code snippet** (if cited in audit)
- **Proposed fix** (if audit suggested one)

### 3. Map severity to P1-P4 labels

Use this priority mapping:

| Audit Severity | Label | Criteria |
|---|---|---|
| Critical | `P1-blocking` | Game-breaking, security allowing arbitrary execution, core loop unplayable |
| High | `P2-important` | Wrong data, broken metrics, state leaks, missing validation, TDD violations |
| Medium | `P3-minor` | Display formatting, non-critical UI polish, rare edge cases |
| Low / Info | `P4-infra` | Performance, code dedup, test coverage gaps, documentation drift |

**Tiebreakers (apply after initial mapping):**
- Security finding → bump up one level (P3 → P2, P2 → P1)
- TDD violation (missing test for new behavior) → at least P2
- User-facing impact (visible in UI/CLI output) → at least P3
- Docs-only change → P4 (no upward bumps)

### 4. Determine category labels

Map the finding category to a GitHub label:
- bug / Bugs Found → `bug`
- security risk → `security`
- performance risk → `enhancement`
- unintended change → `bug`
- omission → `enhancement`
- architectural deviation → `enhancement`

Also add these labels when applicable:
- `tdd-target` — fix needs a failing test written first
- `regression-locked` — a regression test already exists for this finding

### 5. Check for duplicates before creating issues

Run once:
```bash
gh issue list --limit 100 --state open --json number,title,labels,body
```

For each finding, scan the result for a likely match:
- Title contains the same file path AND a similar phrase (≥3 keywords overlap), OR
- Body contains the same file:line reference

If a match is found:
- Add a comment to the existing issue with the new audit context (`gh issue comment <num> --body "..."`)
- Track this as a "comment added" rather than a new issue
- Do not create a new issue

### 6. Create GitHub Issues

For each non-duplicate finding, run:

```bash
gh issue create \
  --title "chk1: <concise description>" \
  --label "<category>,<priority>" \
  --milestone "<milestone>" \
  --body "$(cat <<'EOF'
**Source:** chk1 audit <YYYY-MM-DD>, finding <ID>

**File:** `<path>:<line>`

**Severity:** <Critical|High|Medium|Low>
**Priority:** <P1-blocking|P2-important|P3-minor|P4-infra>

## Description

<full description from audit>

## Current code

```<lang>
<snippet from audit, if available>
```

## Proposed fix

<brief description of the fix from audit, if available>

---
*Logged automatically by `/chk1:github`. Run `/chk1 fix` to implement.*
EOF
)"
```

**Milestone selection:**
- P1 / P2 → current milestone (use `gh api repos/:owner/:repo/milestones --jq '.[] | select(.state=="open") | .title' | head -1` to get current)
- P3 → next milestone (second result of the same query)
- P4 → no milestone (omit `--milestone` flag)

If milestone resolution fails (no milestones exist), skip the `--milestone` flag for all issues and note this in the summary.

**Label creation:** If `gh issue create` fails because a label doesn't exist, create it first:
```bash
gh label create "P1-blocking"  --color "b60205" --description "Game-breaking, security RCE, core loop unplayable" --force
gh label create "P2-important" --color "d93f0b" --description "Wrong data, state leaks, missing validation, TDD violations" --force
gh label create "P3-minor"     --color "fbca04" --description "Display formatting, UI polish, rare edge cases" --force
gh label create "P4-infra"     --color "0e8a16" --description "Performance, code dedup, test coverage, documentation" --force
gh label create "tdd-target"        --color "5319e7" --description "Fix requires a failing test written first" --force
gh label create "regression-locked" --color "0075ca" --description "Regression test already exists for this fix" --force
```
Then retry the failed `gh issue create` command.

### 7. Output a summary table

After all issues are processed, print:

```
Audit findings logged to GitHub Issues

| #   | Issue | Title                                    | Priority    | Labels             |
|-----|-------|------------------------------------------|-------------|--------------------|
| 1   | #42   | chk1: validate-skills.sh grep prefix bug | P2-important| bug, P2-important  |
| 2   | #43   | chk1: install.sh exit code on zero fail  | P1-blocking | bug, P1-blocking   |
| 3   | comment#39 | (added context to existing issue)   | -           | -                  |
| ... | ...   | ...                                      | ...         | ...                |

Totals
  New issues created:  N
  Comments added:      M
  By priority:
    P1-blocking:  X
    P2-important: X
    P3-minor:     X
    P4-infra:     X
```

### 8. Final message

End with exactly:

> All audit findings logged to GitHub Issues. Run `/chk1:fix` to implement fixes.

## Failure modes

- **`gh` rate-limited**: Stop, report how many issues were created so far, and tell the user to retry in N minutes (parse the rate limit reset from `gh api rate_limit`).
- **Network failure mid-batch**: Print the partial summary table and the IDs of findings not yet logged. The user can re-run `/chk1:github` — duplicate detection will skip the ones already created.
- **No findings in audit**: Print "No findings to log — the audit reported a clean run." and exit without creating issues.
