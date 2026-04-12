---
name: project-audit
description: Audit current project against global standards, report gaps
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

<objective>
Audit the current project against ~/.claude/MULTI_SESSION_ARCHITECTURE.md and ~/.claude/GITHUB_CONFIG.md. Report compliance gaps with PASS/FAIL/WARN/SKIP verdicts.
</objective>

<process>

## Step 1: Pre-checks

```bash
git rev-parse --show-toplevel 2>/dev/null
```
If not in a git repo: "Not in a git repository. Navigate to a project and try again."

## Step 2: Verify dependencies and read standards

Before reading, verify the dependency files exist:
- `test -f ~/.claude/MULTI_SESSION_ARCHITECTURE.md` — if missing: **STOP** with error: "~/.claude/MULTI_SESSION_ARCHITECTURE.md not found. This file is required for project auditing. Restore it or check your ~/.claude configuration."
- `test -f ~/.claude/GITHUB_CONFIG.md` — if missing: **STOP** with error: "~/.claude/GITHUB_CONFIG.md not found. This file is required for project auditing."

Read `~/.claude/MULTI_SESSION_ARCHITECTURE.md` for the full role list and requirements.
Read `~/.claude/GITHUB_CONFIG.md` for label, CI, branch protection, and doc requirements.
Read the project's `GITHUB_CONFIG.md` to understand project type and documented deviations.

## Step 3: Determine project type

If `GITHUB_CONFIG.md` exists and specifies a type, use it.
Otherwise infer: if `.github/workflows/` exists or `pyproject.toml`/`package.json` exists → Software. Else → Non-Software.

## Step 4: Run audit checklist

For each check, report PASS, FAIL, WARN, or SKIP with details.

### Checks (run all, adapt expectations to project type):

1. **GitHub repo exists**: `git remote get-url origin` succeeds
2. **Jira epic configured**: CLAUDE.md or GITHUB_CONFIG.md contains a CPT-<N> reference
3. **Required docs present**: README.md, CLAUDE.md, GITHUB_CONFIG.md (always). ARCHITECTURE.md, PHILOSOPHY.md (Software or if present).
4. **Session worktrees present**: Per architecture doc — 11 for Software, 8 for Non-Software. Check `git worktree list`.
5. **Session startup prompts**: `.claude/sessions/<role>.md` exists for each expected role
6. **Branch protection on main**: Derive `OWNER_REPO` from `git remote get-url origin | sed 's|.*github.com[:/]||; s|\.git$||'`, then `gh api "repos/$OWNER_REPO/branches/main/protection"` succeeds. SKIP for Non-Software if documented deviation.
7. **CI workflow exists** (Software only): `.github/workflows/test.yml` or similar. SKIP for Non-Software.
8. **GitHub Issues disabled**: `gh repo view --json hasIssuesEnabled --jq .hasIssuesEnabled` returns `false`. WARN if still enabled.
9. **No GitHub labels**: `gh label list` returns empty. WARN if labels exist (Jira is sole tracker).
10. **No stale worktree branches**: any `session/*` branch with no commits in >7 days → WARN
11. **Coverage thresholds** (Software only): if coverage job exists, thresholds match actuals. SKIP if no coverage.

## Step 5: Display report

```
project audit — Compliance Audit for <name>
Type: <Software|Non-Software>

  [PASS] GitHub repo exists: <remote URL>
  [FAIL] Jira epic not configured in CLAUDE.md
  [PASS] Required docs: 5/5 present
  [FAIL] Session worktrees: 7/11 present (missing: chk2, performance, playtester, triager)
  [WARN] Session prompts: .claude/sessions/playtester.md missing
  [PASS] Branch protection on main
  [PASS] CI workflow: .github/workflows/test.yml
  [PASS] GitHub Issues disabled
  [PASS] No GitHub labels present
  [WARN] Stale worktree: session/playtester (no commits in 5 days)
  [SKIP] Coverage thresholds (not configured)

  Result: 7 passed, 2 warnings, 2 failed, 1 skipped

  To fix gaps, run /project:config or address manually.
```

</process>
