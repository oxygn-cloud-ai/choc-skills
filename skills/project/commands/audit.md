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
Audit the current project against `$CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md` (role/worktree/Jira definitions) and `$CLAUDE_DIR/PROJECT_STANDARDS.md` (narrative label/CI/branch-protection spec), with machine-readable per-project config from the repo's `PROJECT_CONFIG.json`. Report compliance gaps with PASS/FAIL/WARN/SKIP verdicts. (CPT-124/141 migration: the retired `GITHUB_CONFIG.md` is no longer consulted.)

Throughout this document, `$CLAUDE_DIR` means the Claude config directory —
`$CLAUDE_CONFIG_DIR` if set and non-empty, otherwise `$HOME/.claude` (CPT-174).
Resolve it in every bash invocation with `CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"`
before using any `$CLAUDE_DIR/...` path.
</objective>

<process>

## Step 1: Pre-checks

```bash
git rev-parse --show-toplevel 2>/dev/null
```
If not in a git repo: "Not in a git repository. Navigate to a project and try again."

## Step 2: Verify dependencies and read standards

Before reading, verify the dependency files exist:
- `test -f $CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md` — if missing: **STOP** with error: "$CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md not found. This file is required for project auditing. Restore it or check your ~/.claude configuration."
- `test -f $CLAUDE_DIR/PROJECT_STANDARDS.md` — if missing: **STOP** with error: "$CLAUDE_DIR/PROJECT_STANDARDS.md not found. This file defines the narrative label/CI/branch-protection standards (replaces retired GITHUB_CONFIG.md). Restore it or check your ~/.claude configuration."

Read `$CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md` for the full role list and requirements.
Read `$CLAUDE_DIR/PROJECT_STANDARDS.md` for label, CI, branch protection, and doc requirements.
Read the project's `PROJECT_CONFIG.json` (if present) to understand project type, Jira epic, and documented deviations. If missing, fall back to inference in Step 3.

Migration note (CPT-141): the retired per-project `GITHUB_CONFIG.md` is no longer consulted — its narrative content is now in `$CLAUDE_DIR/PROJECT_STANDARDS.md` and per-project machine-readable config is in each repo's `PROJECT_CONFIG.json`. If a repo still has a stale `GITHUB_CONFIG.md`, flag it as migration-pending in the audit output (informational only — do not STOP).

## Step 3: Determine project type

If `PROJECT_CONFIG.json` exists and has `.project.type` (or `.project_type` / `.projectType`), use it.
Otherwise infer: if `.github/workflows/` exists or `pyproject.toml`/`package.json` exists → Software. Else → Non-Software.

## Step 4: Run audit checklist

For each check, report PASS, FAIL, WARN, or SKIP with details.

### Checks (run all, adapt expectations to project type):

1. **GitHub repo exists**: `git remote get-url origin` succeeds
2. **Jira epic configured**: `PROJECT_CONFIG.json` has `.jira.epicKey` (preferred) OR `CLAUDE.md` contains a `CPT-<N>` reference.
3. **Required docs present**: README.md, CLAUDE.md, PROJECT_CONFIG.json (always). ARCHITECTURE.md, PHILOSOPHY.md (Software or if present). A stale `GITHUB_CONFIG.md` is informational only — flag as migration-pending but do not fail.
4. **Session worktrees present**: Per architecture doc — 11 for Software, 8 for Non-Software. Check `git worktree list`.
5. **Session startup prompts**: `.claude/sessions/<role>.md` exists for each expected role
6. **Branch protection on main**: Derive `OWNER_REPO` from `git remote get-url origin | sed 's|.*github.com[:/]||; s|\.git$||'`, then `gh api "repos/$OWNER_REPO/branches/main/protection"` succeeds. SKIP for Non-Software if documented deviation.
7. **CI workflow exists** (Software only): `.github/workflows/test.yml` or similar. SKIP for Non-Software.
8. **notify-failure job** (Software only): grep for `notify-failure` in workflow files.
9. **notify-recovery job** (Software only): grep for `notify-recovery` in workflow files.
10. **P1-P4 labels exist**: `gh label list` includes P1, P2, P3, P4
11. **Category labels exist**: check for expected labels per project type
12. **No deprecated labels**: no `P1-blocking`, `P2-important`, `severity-*`, etc.
13. **Every open issue has priority**: check `gh issue list` for issues missing P-labels
14. **No stale worktree branches**: any `session/*` branch with no commits in >7 days → WARN
15. **Coverage thresholds** (Software only): if coverage job exists, thresholds match actuals. SKIP if no coverage.

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
  [FAIL] notify-failure job missing from CI workflow
  [PASS] notify-recovery job present
  [PASS] P1-P4 labels exist
  [WARN] Deprecated labels found: severity-high, severity-low
  [PASS] All open issues have priority labels
  [WARN] Stale worktree: session/playtester (no commits in 5 days)
  [SKIP] Coverage thresholds (not configured)

  Result: 8 passed, 3 warnings, 3 failed, 1 skipped

  To fix gaps, run /project:config or address manually.
```

</process>
