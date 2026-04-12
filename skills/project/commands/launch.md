---
name: project-launch
description: Launch multi-session terminal environment for project worktrees
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - AskUserQuestion
---

<objective>
Launch tmux sessions with Claude Code running in each worktree session for a project. Creates one tmux session per role, with iTerm2 tabs per role inside a project-named window.
</objective>

<process>

## Step 0: Pre-checks

Verify dependencies exist:
- `test -f ~/.claude/MULTI_SESSION_ARCHITECTURE.md` — if missing: **STOP** with error.
- `command -v tmux` — if missing: **STOP** with error: "tmux is required. Install with: brew install tmux"
- `command -v claude` — if missing: **STOP** with error: "Claude Code CLI is required."

## Step 1: Detect project

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
```
If not in a git repo: "Not in a git repository. Navigate to a project and try again."

Parse `$ARGUMENTS` for flags:
- `--all` → scan `${TMUX_REPOS_DIR:-~/Repos}` for all projects with `.worktrees/`
- `--dry-run` → show what would be launched without launching
- No flags → launch current project only

## Step 2: Determine scope

### Single project mode (default)

```bash
PROJECT_NAME=$(basename "$REPO_ROOT")
PROJECT_SLUG=$(echo "$PROJECT_NAME" | tr '.:=+ ' '-----')
```

Note: the sanitize characters (`.`, `:`, `=`, `+`, ` ` → `-`) match the `sanitize_name()` function in the iterm2-tmux scripts.

Verify `.worktrees/` exists:
```bash
test -d "$REPO_ROOT/.worktrees"
```
If missing: "No worktrees found at $REPO_ROOT/.worktrees/. Run /project:new to create a project with worktrees, or /project:config to add them."

### All projects mode (`--all`)

```bash
REPOS_DIR="${TMUX_REPOS_DIR:-$HOME/Repos}"
for dir in "$REPOS_DIR"/*/; do
  if [ -d "$dir/.worktrees" ]; then
    # Add to project list
  fi
done
```

## Step 3: Read architecture

Read `~/.claude/MULTI_SESSION_ARCHITECTURE.md` for the role list.

Detect project type from `GITHUB_CONFIG.md` or infer:
- **Software** (11 roles): master, planner, implementer, fixer, merger, chk1, chk2, performance, playtester, reviewer, triager
- **Non-Software** (8 roles): master, planner, implementer, fixer, merger, performance, reviewer, triager

Build the actual role list by checking which `.worktrees/<role>` directories exist:
```bash
ROLES=()
for wt in "$REPO_ROOT"/.worktrees/*/; do
  [ -d "$wt" ] && ROLES+=("$(basename "$wt")")
done
```

## Step 4: Check for existing role sessions

Check each role for an existing tmux session:

```bash
EXISTING=()
MISSING=()
for role in "${ROLES[@]}"; do
  if tmux has-session -t "=${PROJECT_SLUG}-${role}" 2>/dev/null; then
    EXISTING+=("$role")
  else
    MISSING+=("$role")
  fi
done
```

If some sessions exist:
- Show which roles have sessions and which don't
- Ask: "N of M role sessions already exist (master, planner, ...). Create missing ones only, kill all and recreate, or cancel?"

If all sessions exist:
- Ask: "All N role sessions already exist. Kill all and recreate, or cancel?"

## Step 5: Present options checklist

Use AskUserQuestion with multiSelect to present launch options:

**Question:** "Select launch options for $PROJECT_NAME ($N worktree sessions):"

Options (multiSelect: true):
1. **Prompt pipe** (description: "Feed .claude/sessions/<role>.md as startup prompt to each Claude instance") — recommend checked by default
2. **--dangerously-skip-permissions** (description: "Skip permission prompts for autonomous operation") — recommend checked by default
3. **--model override** (description: "Use a specific model for all sessions — will ask which model")
4. **--max-turns limit** (description: "Set maximum autonomous turns per session — will ask for number")
5. **Skip idle roles** (description: "Only launch roles with pending Jira tasks or uncommitted git changes")
6. **Verbose logging** (description: "Enable --verbose on Claude for debugging")
7. **Dry run** (description: "Show what would be launched without actually launching anything")

If `--model` is selected, follow up: "Which model? (e.g., opus, sonnet, haiku)"
If `--max-turns` is selected, follow up: "Maximum turns per session? (e.g., 10, 50, unlimited)"

## Step 6: Create tmux sessions (one per role)

If `--dry-run` selected, skip execution and show the plan instead (jump to Step 8 reporting).

For each role, create a dedicated tmux session with environment metadata:

```bash
idx=0
for role in "${ROLES[@]}"; do
  SESSION_NAME="${PROJECT_SLUG}-${role}"

  # Create session with working directory in the role's worktree
  tmux new-session -d -s "$SESSION_NAME" -c "$REPO_ROOT/.worktrees/$role"

  # Set environment variables for picker grouping and tab identification
  tmux set-environment -t "$SESSION_NAME" PROJECT "$PROJECT_SLUG"
  tmux set-environment -t "$SESSION_NAME" ROLE "$role"
  tmux set-environment -t "$SESSION_NAME" ROLE_INDEX "$idx"

  idx=$((idx + 1))
done
```

## Step 7: Launch Claude in each session

For each role/session, build and send the Claude command:

Build the claude command string based on which options the user selected in Step 5:

1. Start with base: `claude`
2. If "dangerously-skip-permissions" selected: append `--dangerously-skip-permissions`
3. If "verbose" selected: append `--verbose`
4. If "max-turns" selected: append `--max-turns <N>` (using the number from the follow-up question)
5. If "model override" selected: append `--model <model>` (using the model from the follow-up question)

Then, if "Prompt pipe" was selected and `.claude/sessions/<role>.md` exists in the project:
- Read the prompt file content
- Pipe it to Claude via stdin: `cat "$PROMPT_FILE" | claude [flags]`
- If no prompt file exists for this role, launch Claude without a prompt

Send the assembled command to the role's tmux session:
```bash
tmux send-keys -t "${PROJECT_SLUG}-${ROLE}" "$CMD" Enter
```

### Skip idle roles (if selected)

Before launching Claude in a role, check for activity:
```bash
BRANCH="session/$ROLE"
# Check for uncommitted changes
DIRTY=$(git -C "$REPO_ROOT/.worktrees/$ROLE" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
# Check for commits ahead of main
AHEAD=$(git rev-list --count main.."$BRANCH" 2>/dev/null || echo 0)
```
If `DIRTY == 0` and `AHEAD == 0` and no Jira tasks assigned to this role: skip launching Claude in this session (but still create the session for manual use later).

## Step 8: Report and iTerm2 integration

Display launch report:

```
project launch — $PROJECT_NAME

  Project:  $PROJECT_SLUG
  Sessions: $N_LAUNCHED / $N_TOTAL
  Claude:   $N_WITH_CLAUDE running

  | Role        | Session             | Claude | Prompt |
  |-------------|---------------------|--------|--------|
  | master      | choc-skills-master  | ●      | ✓      |
  | planner     | choc-skills-planner | ●      | ✓      |
  | implementer | choc-skills-impl    | ○ idle | —      |
  | fixer       | choc-skills-fixer   | ○ idle | —      |
  | merger      | choc-skills-merger  | ●      | ✓      |
  | chk1        | choc-skills-chk1    | ●      | ✓      |
  | chk2        | choc-skills-chk2    | ●      | ✓      |
  | performance | choc-skills-perf    | ○ idle | —      |
  | playtester  | choc-skills-play    | ○ idle | —      |
  | reviewer    | choc-skills-rev     | ●      | ✓      |
  | triager     | choc-skills-triager | ●      | ✓      |

  Navigate: Prefix+P for project picker
  Attach to a role: tmux attach -t choc-skills-master
```

### iTerm2 tab integration

If running on macOS and iTerm2 is active, create iTerm2 tabs using the `--session` flag:

```bash
if [ "$(uname -s)" = "Darwin" ] && pgrep -qf "iTerm"; then
  TABS_SCRIPT=""
  if command -v tmux-iterm-tabs.sh &>/dev/null; then
    TABS_SCRIPT="tmux-iterm-tabs.sh"
  elif [ -x "$HOME/.local/bin/tmux-iterm-tabs.sh" ]; then
    TABS_SCRIPT="$HOME/.local/bin/tmux-iterm-tabs.sh"
  fi
  if [ -n "$TABS_SCRIPT" ]; then
    "$TABS_SCRIPT" --session "$PROJECT_SLUG" 2>/dev/null || true
  fi
fi
```

This creates:
- One iTerm2 **window** named after the project (e.g., "choc-skills")
- One iTerm2 **tab** per role, labeled with the role name (e.g., "merger")
- Each tab has a background image with the role name watermark
- Each tab is attached to the role's tmux session

If `tmux-iterm-tabs.sh` is not installed, warn: "iTerm2 detected but tmux-iterm-tabs.sh not found. Install with: `cd skills/iterm2-tmux && ./install.sh`"

Note: Auto-attach is not performed because `/project:launch` runs inside Claude Code which is not a TTY. The iTerm2 tabs handle attachment automatically.

## `--all` mode

For each project found in `$REPOS_DIR` with `.worktrees/`:
1. Run Steps 2-8 for each project (each project gets its own iTerm2 window)
2. Present a combined summary at the end:

```
project launch --all — $N projects launched

  | Project      | Sessions | Claude instances |
  |--------------|----------|-----------------|
  | choc-skills  | 11       | 7 active        |
  | bgb          | 8        | 3 active        |
  | website-xyz  | 8        | 1 active        |

  Total: $TOTAL sessions, $ACTIVE Claude instances
  Picker: project-picker.sh or Prefix+P
```

</process>

<success_criteria>
- [ ] Per-role tmux sessions created with correct names (<project>-<role>)
- [ ] Tmux env vars set: PROJECT, ROLE, ROLE_INDEX on each session
- [ ] Claude launched in each non-idle session with correct flags
- [ ] Session prompts piped when available
- [ ] Existing sessions handled gracefully (create missing, recreate all, or cancel)
- [ ] Dry run shows plan without side effects
- [ ] --all mode launches all projects in TMUX_REPOS_DIR
- [ ] Report shows accurate status table with session names
- [ ] iTerm2 window created with project name, tabs per role (via tmux-iterm-tabs.sh --session)
- [ ] Background images generated per role with role name watermark
</success_criteria>
