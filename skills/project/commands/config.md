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
Interactively modify the current project's configuration. Changes are persisted to GITHUB_CONFIG.md and applied to GitHub/git.
</objective>

<process>

## Step 1: Pre-checks

```bash
git rev-parse --show-toplevel 2>/dev/null
```
If not in a git repo: "Not in a git repository."

Read the project's `GITHUB_CONFIG.md` for current configuration.
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
- **Set Jira epic key** — update the Jira epic reference in CLAUDE.md and GITHUB_CONFIG.md
- **Update deviations** — document a deviation from global standards in GITHUB_CONFIG.md
- **Done — no changes**

## Step 3: Execute the chosen action

### Change project type
1. Ask: "Switch to Software or Non-Software?"
2. If switching to Software: add missing worktrees (chk1, chk2, playtester), create CI, set protection, add full label set
3. If switching to Non-Software: warn about removing CI/protection, remove extra worktrees if user confirms
4. Update GITHUB_CONFIG.md

### Add worktree session
1. Ask: "Role name?" (slug, e.g., `designer`)
2. Ask: "One-line purpose?"
3. Create worktree:
   ```bash
   git worktree add ".worktrees/<role>" -b "session/<role>" main
   git push -u origin "session/<role>"
   ```
4. Create session prompt at `.claude/sessions/<role>.md`
5. Update GITHUB_CONFIG.md with the new role

### Remove worktree session
1. Show list of current worktrees
2. Ask which to remove. **Enforce: `master` cannot be removed.** If the user selects `master`, say: "The master session cannot be removed — it's the coordination layer for all other sessions."
3. Check for unmerged work before removing:
   ```bash
   BRANCH="session/<role>"
   AHEAD=$(git rev-list --count main.."$BRANCH" 2>/dev/null || echo 0)
   if [ "$AHEAD" -gt 0 ]; then
     # WARN: this branch has unmerged commits
   fi
   ```
   If unmerged: warn the user explicitly ("session/<role> has N unmerged commits — removing will lose that work") and ask for confirmation before proceeding.
4. Remove:
   ```bash
   git worktree remove ".worktrees/<role>"
   git branch -D "session/<role>"  # -D (force) since user confirmed
   git push origin --delete "session/<role>" 2>/dev/null
   ```
5. Remove `.claude/sessions/<role>.md`
6. Update GITHUB_CONFIG.md

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
- Update GITHUB_CONFIG.md

### Enable/disable CI
- Create or remove `.github/workflows/test.yml`
- Read template from `~/.claude/GITHUB_CONFIG.md` section 3

### Set Jira epic key
- Ask for the key (e.g., CPT-42)
- Update CLAUDE.md and GITHUB_CONFIG.md

### Update deviations
- Ask: "What deviation are you documenting?"
- Append to GITHUB_CONFIG.md deviations section with justification

## Step 4: Confirm

After any change, show the updated config and ask if there's anything else to change. Loop back to step 2 until user selects "Done."

</process>
