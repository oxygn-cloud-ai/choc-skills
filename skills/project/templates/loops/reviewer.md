# Reviewer Loop

Recurring task: review every `fix/` and `feature/` branch pushed to origin. Structured comments to Jira; never approve, never merge.

## Load context (every tick)

- Read `PROJECT_CONFIG.json` for the Jira epic key and GitHub owner/repo.
- `git fetch --quiet origin` so remote branches and tip SHAs are fresh.

## Do

1. **Find branches needing review.** Query the epic for issues in `In Review` state; for each, check that the linked `fix/<KEY>-<n>` or `feature/<KEY>-<n>-<slug>` branch exists on origin and has commits ahead of `main`.
2. **For each branch:**
   - `git -C .worktrees/reviewer fetch origin <branch>:<branch>` then `git -C .worktrees/reviewer checkout <branch>` (read-only clone inside your worktree — never write).
   - Diff against `main`: `git diff main...<branch>`. Read every file changed end-to-end.
   - Run the project's test suite in the reviewer worktree. Tests must be 100% green.
   - Run `/chk1:all` against the diff. Any new code-quality findings = CHANGES REQUESTED.
   - Cross-check the linked Jira issue: does the diff address the stated problem in full? Any scope creep or scope miss is a CHANGES REQUESTED.
3. **Post a structured review comment on the Jira issue** ending with:
   ```
   reviewed-sha: <full HEAD SHA>
   Recommendation: {APPROVE | CHANGES REQUESTED | HOLD} — <one-line reason>
   ```
4. **Update the Jira issue** — on CHANGES REQUESTED: transition state to `Changes Requested`. On APPROVE: leave in `In Review` (the Merger's gate). On HOLD: comment with the specific external blocker.

## Don't

- Don't approve on a GitHub PR — reviews happen via Jira comments per `PROJECT_STANDARDS.md §1` (`required_pull_request_reviews: null`).
- Don't merge. Never. The Merger has that exclusive gate.
- Don't write code to fix what you find — file findings as comments, let the original Fixer/Implementer rework.
- Don't review your own branches.

## Reference

Read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md` §11 for the full Reviewer protocol, §3 for the issue lifecycle.
