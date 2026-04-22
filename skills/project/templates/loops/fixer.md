# Fixer Loop

Recurring task: work through bug issues one at a time. Rework first, then new issues. Plan before code. Red-green TDD only.

## Load context (every tick)

- Read `PROJECT_CONFIG.json` for the Jira epic key.
- `git fetch --quiet origin`.
- Current worktree branch: `git -C .worktrees/fixer branch --show-current`.

## Do

1. **Rework pass first.** Scan Jira for issues in `Changes Requested` state whose linked branch `fix/<KEY>-<n>` matches the one you're on (or one you own). If any: check out that branch, read the Reviewer's comments on the issue, rework, push, transition back to `In Review`. Stop this tick — rework takes priority.
2. **If no rework:** pick the highest-priority `Bug` in `Ready for Coding`, ordered P1 > P2 > P3 > P4 then oldest-first within a priority.
3. **Claim the issue.** Transition to `In Progress`. Create branch `fix/<KEY>-<n>` from `main` inside THIS worktree (never create a new worktree — §7.1): `git checkout main && git pull && git checkout -b fix/<KEY>-<n>`.
4. **Write a plan** (mandatory for every bug, every priority):
   - Root cause analysis — trace every caller and side effect.
   - Test specification — exact file, describe block, test name, assertion.
   - Implementation approach — HOW, not "fix it".
   - Files to modify — exhaustive list.
   - Risk assessment — what could break.
5. **Check the plan recursively for correctness.** Send to Codex for a second opinion. Improve based on feedback.
6. **Attach the plan to the Jira issue as a comment.** Wait for the Triager to review and transition to `Plan Approved` before coding.
7. **RED:** write the failing regression test first.
8. **GREEN:** minimum fix to pass.
9. Full test suite 100% green before push.
10. **Update docs** in the same branch if the fix changes documented behavior — `README.md` and `ARCHITECTURE.md` only. Never `PHILOSOPHY.md`.
11. `git push -u origin fix/<KEY>-<n>`, transition Jira to `In Review`, return worktree to `session/fixer`.

## 3-strikes rule

If the same issue fails Reviewer or Merger checks 3 times across separate fix attempts, escalate to the human via Master with full context of all 3 attempts. Do not retry silently.

## Don't

- Don't pick up issues that aren't `Ready for Coding` — the Triager's gate is non-negotiable.
- Don't code before the plan is approved.
- Don't skip RED — "the bug is obvious, I'll just fix it" is how regressions ship.
- Don't merge. Your exit state is `In Review`, not `Done`.

## Reference

Read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md` §4 for the full Fixer protocol, §9 for plan-before-code discipline, §10 for quality standards.
