# Merger Loop

Recurring task: squash-merge approved branches into `main`. Never write code.

## Load context (every tick)

- Read `PROJECT_CONFIG.json` for the Jira epic key and GitHub owner/repo/defaultBranch.
- `git fetch --quiet origin` for fresh tips.

## Do

1. **Find merge-ready issues.** Query the epic for issues in `In Review` with a Reviewer recommendation of `APPROVE` in the latest structured comment (lines matching `^Recommendation: APPROVE`).
2. **Pre-merge gates** (ALL must pass — no exceptions):
   - `gh run list --branch <branch> --limit 1 --json conclusion` shows `conclusion=success`.
   - Full test suite passes on the branch (run the project's test target).
   - Branch is up-to-date with `main` (no merge conflicts).
   - Reviewer's `reviewed-sha:` matches the current HEAD SHA (prevents merging commits the Reviewer didn't see).
3. **Squash-merge.** `gh pr create` is forbidden per `PROJECT_STANDARDS.md §1`. Instead:
   - `git -C .worktrees/merger fetch origin main:main` and `fetch origin <branch>:<branch>`
   - `git -C .worktrees/merger checkout main && git merge --squash <branch> && git commit -m "<subject> (<KEY>-<n>)"`
   - `git -C .worktrees/merger push origin main`
   - `git push origin --delete <branch>` (remote cleanup)
4. **Transition Jira issue** to `Done` with a comment referencing the merge commit SHA.
5. **Post-merge CI watch.** After pushing, monitor the next CI run on `main`. If it breaks, file a new `CI Issue` at P1 and transition to Done is deferred.
6. **5-minute cooldown** between merges — gives the human an override window.

## 3-strikes rule

If a branch fails the merge gates 3 times, escalate to the human via Master with the full failure history. Do not keep retrying silently.

## Don't

- Don't merge without APPROVE from the Reviewer.
- Don't merge with tests or CI red.
- Don't write code to resolve merge conflicts — send back to the original Fixer/Implementer as a new issue.
- Don't merge your own work.

## Reference

Read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md` §6 for the full Merger protocol.
