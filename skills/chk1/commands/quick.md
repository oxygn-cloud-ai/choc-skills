---
name: chk1:quick
description: Quick bug + risk audit (sections 2 and 3 only)
allowed-tools: Read, Grep, Glob, Bash(git *)
---

# chk1:quick — Quick Bug and Risk Check

Run only the bug detection and critical risk sections. Skips scope compliance, architecture review, and omissions analysis. Faster for quick sanity checks before committing.

## Instructions

1. Determine scope using the same logic as the full audit (auto-detect or from $ARGUMENTS)
2. Run pre-flight checks (git available, inside repo, has commits, valid diff)
3. Run `git diff <base>..<head>` and read all changed files
4. Execute ONLY these sections:
   - **Section 2: Bug Detection** — syntax, types, race conditions, resource leaks, hardcoded values, missing checks
   - **Section 3: Critical Risk Assessment** — security vulnerabilities, data integrity, performance, breaking changes

5. Output format:

```markdown
### Quick Audit

**Scope**: <base>..<head> (N commits, N files)

### Bugs Found

| # | File | Line | Severity | Description |
|---|------|------|----------|-------------|
| 1 | path/to/file | :42 | High | Description |

### Critical Risks

| # | File | Category | Severity | Description | Remediation |
|---|------|----------|----------|-------------|-------------|
| 1 | path/to/file | Security | Critical | Description | Fix guidance |

### Quick Verdict

VERDICT: BLOCKED | PERMITTED | PERMITTED WITH WARNINGS
Issues: N bugs, N risks
```

## After

Ask the user: **Do you want help fixing the issues found?** If yes, invoke `/chk1:fix`.
