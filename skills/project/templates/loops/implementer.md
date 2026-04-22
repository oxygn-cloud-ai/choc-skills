# Implementer Loop

Recurring task: work through feature requests one at a time. Rework first, then new. Red-green TDD only.

## Load context (every tick)

- Read `PROJECT_CONFIG.json` for the Jira epic key.
- `git fetch --quiet origin`.
- Current worktree branch: `git -C .worktrees/implementer branch --show-current`.

## Do

1. **Rework pass first.** Scan Jira for `Feature Request` issues in `Changes Requested` state whose linked branch `feature/<KEY>-<n>-<slug>` is one you own. If any: check out that branch, read the Reviewer's comments, rework, push, transition back to `In Review`. Stop this tick — rework takes priority.
2. **If no rework:** pick the highest-priority `Feature Request` in `Ready for Coding`, ordered P1 > P2 > P3 > P4 then oldest-first within a priority.
3. **Claim the issue.** Transition to `In Progress`. Create branch `feature/<KEY>-<n>-<slug>` from `main` inside THIS worktree (never a new worktree — §7.1): `git checkout main && git pull && git checkout -b feature/<KEY>-<n>-<slug>`.
4. **Red-green TDD.** For each acceptance criterion in the issue:
   - Write a failing test first.
   - Write the minimum code to pass.
   - Refactor with tests green.
5. **Atomic commits** referencing the Jira issue key in the subject.
6. Full test suite must pass before push.
7. **Update docs** in the same branch if the change affects documented features, endpoints, config, or architecture — `README.md` and `ARCHITECTURE.md` only. Never `PHILOSOPHY.md`.
8. `git push -u origin feature/<KEY>-<n>-<slug>`, transition Jira to `In Review`, return worktree to `session/implementer`.

## Sub-agents

Use them when independent components can be implemented in parallel. Not by default.

## Don't

- Don't pick up issues that aren't `Ready for Coding`.
- Don't skip the failing test. "Trivial feature, no test needed" produces regressions the moment the feature interacts with anything else.
- Don't merge. Your exit state is `In Review`, not `Done`.

## Reference

Read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md` §5 for the full Implementer protocol, §10 for quality standards.
