---
name: project-config
description: Change project configuration — type, worktrees, labels, Jira, CI, protection
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

<objective>
Interactively modify the current project's configuration. Changes are persisted to PROJECT_CONFIG.json and applied to GitHub/git.
</objective>

<process>

## Step 1: Pre-checks

```bash
git rev-parse --show-toplevel 2>/dev/null
```
If not in a git repo: "Not in a git repository."

Verify dependencies exist before reading:
- `test -f ~/.claude/MULTI_SESSION_ARCHITECTURE.md` — if missing: **STOP** with error: "~/.claude/MULTI_SESSION_ARCHITECTURE.md not found. Required for project configuration."
- `test -f ~/.claude/PROJECT_STANDARDS.md` — if missing: **STOP** with error: "~/.claude/PROJECT_STANDARDS.md not found. Required for project configuration."

Read the project's `PROJECT_CONFIG.json` for current configuration.
Read `~/.claude/MULTI_SESSION_ARCHITECTURE.md` for role definitions.

## Step 2: Show current config and ask what to change

Display a summary of current config, then ask via AskUserQuestion:

"What would you like to change?"

Options:
- **Change project type** — switch between Software and Non-Software (re-applies appropriate config subset)
- **Add worktree session** — create a new session worktree (asks: role name, purpose)
- **Remove worktree session** — remove a session worktree and optionally delete its branch
- **List worktrees** — show all active worktrees with branch, path, and status
- **Add/remove labels** — manage GitHub labels
- **Enable/disable branch protection** — toggle branch protection on main
- **Enable/disable CI workflow** — add or remove .github/workflows/test.yml
- **Set Jira epic key** — update the Jira epic reference in CLAUDE.md and PROJECT_CONFIG.json
- **Update deviations** — document a deviation from global standards in PROJECT_CONFIG.json
- **Done — no changes**

## Step 3: Execute the chosen action

### Change project type
1. Ask: "Switch to Software or Non-Software?"
2. If switching to Software: add missing worktrees (chk1, chk2, playtester), create CI, set protection, add full label set
3. If switching to Non-Software: warn about removing CI/protection, remove extra worktrees if user confirms
4. Update PROJECT_CONFIG.json

### Add worktree session
1. Ask: "Role name?" (slug, e.g., `designer`)
2. Ask: "One-line purpose?"
3. Create worktree:
   ```bash
   git worktree add ".worktrees/<role>" -b "session/<role>" main
   git push -u origin "session/<role>"
   ```
4. Create session prompt at `.claude/sessions/<role>.md`
5. Update PROJECT_CONFIG.json with the new role

### Remove worktree session
1. Show list of current worktrees
2. Ask which to remove. **Enforce: `master` cannot be removed.** If the user selects `master`, say: "The master session cannot be removed — it's the coordination layer for all other sessions."
3. Check for work-in-progress before removing (ALL three checks required):
   ```bash
   BRANCH="session/<role>"
   # Check 1: Uncommitted changes in the worktree
   DIRTY=$(git -C ".worktrees/<role>" status --porcelain 2>/dev/null | head -5)
   # Check 2: Unmerged commits (ahead of main)
   AHEAD=$(git rev-list --count main.."$BRANCH" 2>/dev/null || echo 0)
   # Check 3: Unpushed commits (ahead of remote)
   UNPUSHED=$(git log --oneline "origin/$BRANCH..$BRANCH" 2>/dev/null | wc -l | tr -d ' ')
   ```
   If ANY check finds work, warn the user explicitly with specifics:
   - Uncommitted: "session/<role> has uncommitted changes:\n<first 5 lines of status>"
   - Unmerged: "session/<role> has N commits not merged to main"
   - Unpushed: "session/<role> has N commits not pushed to origin"
   Then: "Removing this worktree will **permanently destroy** this work. Are you absolutely sure?" Require explicit "yes" confirmation via AskUserQuestion before proceeding.
4. Remove (only after all safety checks pass or user explicitly confirms destruction):
   ```bash
   git worktree remove ".worktrees/<role>"
   git branch -D "session/<role>"  # -D (force) since user confirmed after safety warnings
   git push origin --delete "session/<role>" 2>/dev/null
   ```
5. Remove `.claude/sessions/<role>.md`
6. Update PROJECT_CONFIG.json

### List worktrees
```bash
git worktree list
# For each, show: branch, path, commits ahead of main, last commit date
for wt in $(git worktree list --porcelain | grep '^worktree ' | sed 's/worktree //'); do
  branch=$(git -C "$wt" branch --show-current 2>/dev/null)
  ahead=$(git rev-list --count main.."$branch" 2>/dev/null || echo 0)
  last=$(git -C "$wt" log -1 --format='%cr' 2>/dev/null || echo 'no commits')
  echo "$branch  $wt  ($ahead ahead, $last)"
done
```

### Add/remove labels
- Show current labels
- Ask which to add or remove
- Execute `gh label create` or `gh label delete`

### Enable/disable branch protection
- Toggle via `gh api repos/{owner}/{repo}/branches/main/protection`
- Update PROJECT_CONFIG.json

### Enable/disable CI
- Create or remove `.github/workflows/test.yml`
- Read template from `~/.claude/PROJECT_STANDARDS.md` section 3

### Set Jira epic key
- Ask for the key (e.g., CPT-42)
- Update CLAUDE.md and PROJECT_CONFIG.json

### Update deviations
- Ask: "What deviation are you documenting?"
- Append to PROJECT_CONFIG.json deviations array with justification

## Step 4: Confirm

After any change, show the updated config and ask if there's anything else to change. Loop back to step 2 until user selects "Done."

</process>
