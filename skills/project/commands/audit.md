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
Audit the current project against ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md and ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/PROJECT_STANDARDS.md. Report compliance gaps with PASS/FAIL/WARN/SKIP verdicts.
</objective>

<process>

## Step 1: Pre-checks

```bash
git rev-parse --show-toplevel 2>/dev/null
```
If not in a git repo: "Not in a git repository. Navigate to a project and try again."

## Step 2: Verify dependencies and read standards

Before reading, verify the dependency files exist:
- `test -f ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md` — if missing: **STOP** with error: "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md not found. This file is required for project auditing. Restore it or check your ~/.claude configuration."
- `test -f ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/PROJECT_STANDARDS.md` — if missing: **STOP** with error: "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/PROJECT_STANDARDS.md not found. This file is required for project auditing."

Read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md` for the full role list and requirements.
Read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/PROJECT_STANDARDS.md` for branch protection, CI, and documentation requirements.
Read the project's `PROJECT_CONFIG.json` to understand project type and documented deviations.

## Step 3: Determine project type

If `PROJECT_CONFIG.json` exists and specifies a type, use it.
Otherwise infer: if `.github/workflows/` exists or `pyproject.toml`/`package.json` exists → Software. Else → Non-Software.

## Step 4: Run audit checklist

For each check, report PASS, FAIL, WARN, or SKIP with details.

### Checks (run all, adapt expectations to project type):

1. **GitHub repo exists**: `git remote get-url origin` succeeds
2. **Jira epic configured**: CLAUDE.md or PROJECT_CONFIG.json contains a CPT-<N> or Jira epic reference
3. **Required docs present**: README.md, CLAUDE.md, PROJECT_CONFIG.json (always). ARCHITECTURE.md, PHILOSOPHY.md (Software or if present).
4. **Session worktrees present**: Per architecture doc — 11 for Software, 8 for Non-Software. Check `git worktree list`.
5. **Session startup prompts**: `.claude/sessions/<role>.md` exists for each expected role
6. **Branch protection on main**: Derive `OWNER_REPO` from `git remote get-url origin | sed 's|.*github.com[:/]||; s|\.git$||'`, then `gh api "repos/$OWNER_REPO/branches/main/protection"` succeeds. SKIP for Non-Software if documented deviation.
7. **CI workflow exists** (Software only): `.github/workflows/test.yml` or similar. SKIP for Non-Software.
8. **CI failure tracking** (Software only): auto-detect the mode. Grep workflow files for `notify-failure`. If present → **PASS** (workflow-jobs mode — CI files to Jira directly via GitHub Actions secrets). If absent → **SKIP** (Master-session mode — the default per `PROJECT_STANDARDS.md §3` / `MULTI_SESSION_ARCHITECTURE.md §5`; Master polls `gh run list` and files Jira tasks on failure). Either mode is compliant; no deviation entry needed.
9. **CI recovery tracking** (Software only): same auto-detect logic — grep for `notify-recovery`. Present → PASS; absent → SKIP (Master comments on the Jira CI task and transitions it to Done on recovery).
10. **GitHub Issues disabled**: `gh repo view --json hasIssuesEnabled --jq .hasIssuesEnabled` returns `false` (Jira is source of truth).
11. **No GitHub-default labels**: `gh label list --json name --jq '.[].name'` must not contain any of the 9 GitHub-default names: `bug`, `documentation`, `duplicate`, `enhancement`, `good first issue`, `help wanted`, `invalid`, `question`, `wontfix`. Project-specific labels declared in `.github/labels.yml` (e.g., `ci`, `dependencies`, `skill:*`, `category:*`) are allowed — they are the repo's intentional PR-labelling taxonomy. FAIL lists which default labels remain.
12. **Loop configuration**: for every role in `sessions.roles` that is loop-capable (master, triager, reviewer, merger, chk1, chk2, fixer, implementer), `sessions.loops.<role>` exists in PROJECT_CONFIG.json with a non-negative `intervalMinutes`. On-demand roles (planner, performance, playtester) must NOT have loop entries.
13. **Loop prompt files**: for every role with `intervalMinutes > 0`, the prompt file exists at `.worktrees/<role>/<prompt-path>` (default `loops/loop.md`).
14. **No stale worktree branches**: any `session/*` branch with no commits in >7 days → WARN
15. **Coverage thresholds** (Software only): if coverage job exists, thresholds match actuals. SKIP if no coverage.
16. **No unauthorised worktrees**: per MULTI_SESSION_ARCHITECTURE.md §7.1, the only worktrees permitted are the role worktrees named in `sessions.roles` (plus the main repo). Iterate `git worktree list --porcelain` and for each `.worktrees/<name>/`, assert `<name>` is in `sessions.roles` — FAIL on any `<name>` not in the role list. For each role worktree's HEAD branch, apply a **role-aware** rule (per `MULTI_SESSION_ARCHITECTURE.md §1` — only fixer and implementer write code; all other roles are read-only on source): **fixer** may be `session/fixer` OR match `^fix/<KEY>-[0-9]+` (PASS with note naming the active ticket); **implementer** may be `session/implementer` OR match `^feature/<KEY>-[0-9]+` (PASS with note); **all other role worktrees** (master, planner, merger, chk1, chk2, performance, playtester, reviewer, triager) must be on `session/<role>` — any other branch value FAILs (a read-only role on a feature/fix branch indicates a re-pointed worktree, forbidden). `<KEY>` is `jira.projectKey` from PROJECT_CONFIG.json.

## Step 5: Display report

```
project audit — Compliance Audit for <name>
Type: <Software|Non-Software>

  [PASS] 1.  GitHub repo exists: <remote URL>
  [FAIL] 2.  Jira epic not configured in CLAUDE.md
  [PASS] 3.  Required docs: 5/5 present
  [FAIL] 4.  Session worktrees: 7/11 present (missing: chk2, performance, playtester, triager)
  [WARN] 5.  Session prompts: .claude/sessions/playtester.md missing
  [PASS] 6.  Branch protection on main
  [PASS] 7.  CI workflow: .github/workflows/test.yml
  [SKIP] 8.  CI failure tracking: Master-session mode (no notify-failure jobs in CI)
  [SKIP] 9.  CI recovery tracking: Master-session mode (no notify-recovery jobs in CI)
  [PASS] 10. GitHub Issues disabled
  [PASS] 11. No GitHub-default labels present (30 project labels declared in .github/labels.yml)
  [PASS] 12. Loop configuration: 8/8 roles configured
  [FAIL] 13. Loop prompt missing: .worktrees/chk2/loops/loop.md
  [WARN] 14. Stale worktree: session/playtester (no commits in 5 days)
  [SKIP] 15. Coverage thresholds (not configured)
  [PASS] 16. Worktree HEADs: 11/11 authorised; all role-aware rules satisfied

  Result: 9 passed, 2 warnings, 3 failed, 2 skipped

  To fix gaps, run /project:config or address manually.
```

</process>
