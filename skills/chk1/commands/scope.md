---
name: chk1:scope
description: Scope compliance + omissions + unintended changes audit
allowed-tools: Read, Grep, Glob, Bash(git *)
---

# chk1:scope — Scope Compliance Audit

Check that changes stay within the approved scope. Detects unintended modifications, out-of-scope features, unauthorized dependency changes, and missing plan items.

## Instructions

1. Determine scope using the same logic as the full audit
2. Run pre-flight checks
3. Read the implementation plan if one exists (PLAN.md, or similar in working directory or .planning/)
4. Run `git diff <base>..<head> --stat` and `git diff <base>..<head>` for full changes
5. Execute these sections from the full audit:
   - **Section 4: Scope Compliance Verification**
   - **Section 5: Unintended Changes Detection**
   - **Section 7: Omissions Analysis**
   - **Section 8: Completeness Verification**

6. Output format:

```markdown
### Scope Audit

**Scope**: <base>..<head> (N commits, N files)
**Plan**: <plan file path or "None detected">

### Scope Compliance

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| 1 | All changes within plan scope | PASS/FAIL | {details} |
| 2 | No unintended deletions | PASS/FAIL | {details} |
| 3 | No unauthorized dependency changes | PASS/FAIL | {details} |
| 4 | No unexpected config changes | PASS/FAIL | {details} |

### Unintended Changes

| # | File | Line | Description | Risk |
|---|------|------|-------------|------|
| 1 | path/file | :42 | Refactored unrelated function | Low |

Or: "None detected after comparing against plan scope."

### Omissions

| # | Plan Item | Status | Notes |
|---|-----------|--------|-------|
| 1 | "Add input validation to /api/users" | Missing | Not implemented |

Or: "All plan items verified as complete."

### Verdict

VERDICT: BLOCKED | PERMITTED | PERMITTED WITH WARNINGS
Unintended changes: N | Omissions: N
```

## After

Ask the user: **Do you want help fixing the scope issues found?** If yes, invoke `/chk1:fix`.
