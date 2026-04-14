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
Launch tmux sessions with Claude Code running in each worktree session for a project. Creates one tmux session per project with named windows per role.
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
PROJECT_SLUG=$(echo "$PROJECT_NAME" | tr '.' '-' | tr ':' '-' | tr ' ' '-')
```

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

## Step 3: Read architecture and config

Read `~/.claude/MULTI_SESSION_ARCHITECTURE.md` for the role list.

Read `$REPO_ROOT/PROJECT_CONFIG.json` for:
- Project type (`project.type`)
- Role list (`sessions.roles`)
- Loop intervals and prompts (`sessions.loops.<role>.intervalMinutes` and `.prompt`)
- Env vars (`env.project` and `env.sessions.<role>`)

Detect project type from `PROJECT_CONFIG.json` or infer if absent:
- **Software** (11 roles): master, planner, implementer, fixer, merger, chk1, chk2, performance, playtester, reviewer, triager
- **Non-Software** (8 roles): master, planner, implementer, fixer, merger, performance, reviewer, triager

**Loop-capable roles** (8): master, triager, reviewer, merger, chk1, chk2, fixer, implementer. Other roles never loop — they are on-demand only (planner, performance, playtester).

**Project path env var:**
```bash
PROJECT_ENV_NAME="$(basename "$REPO_ROOT" | tr '[:lower:]' '[:upper:]')_PATH"
# e.g., choc-skills → CHOC-SKILLS_PATH
```
This is auto-exported into every launched session so loop prompts and env-dependent scripts can reference the project root portably.

Build the actual role list by checking which `.worktrees/<role>` directories exist:
```bash
ROLES=()
for wt in "$REPO_ROOT"/.worktrees/*/; do
  [ -d "$wt" ] && ROLES+=("$(basename "$wt")")
done
```

## Step 4: Check for existing tmux session

```bash
tmux has-session -t "=$PROJECT_SLUG" 2>/dev/null
```

If session exists:
- Show current state: `tmux list-windows -t "$PROJECT_SLUG" -F '#W #{window_active}'`
- Ask: "tmux session '$PROJECT_SLUG' already exists with N windows. Resume it, kill and recreate, or cancel?"

## Step 5: Present options checklist

Use AskUserQuestion with multiSelect to present launch options:

**Question:** "Select launch options for $PROJECT_NAME ($N worktree sessions):"

Options (multiSelect: true):
1. **Prompt pipe** (description: "Feed .claude/sessions/<role>.md as startup prompt to each Claude instance") — recommend checked by default
2. **--dangerously-skip-permissions** (description: "Skip permission prompts for autonomous operation") — recommend checked by default
3. **Resume existing sessions** (description: "Attach to existing tmux sessions instead of creating new") — recommend checked by default
4. **--model override** (description: "Use a specific model for all sessions — will ask which model")
5. **--max-turns limit** (description: "Set maximum autonomous turns per session — will ask for number")
6. **Skip idle roles** (description: "Only launch roles with pending Jira tasks or uncommitted git changes")
7. **Verbose logging** (description: "Enable --verbose on Claude for debugging")
8. **Dry run** (description: "Show what would be launched without actually launching anything")

If `--model` is selected, follow up: "Which model? (e.g., opus, sonnet, haiku)"
If `--max-turns` is selected, follow up: "Maximum turns per session? (e.g., 10, 50, unlimited)"

## Step 6: Create tmux session and windows

If `--dry-run` selected, skip execution and show the plan instead (jump to Step 8 reporting).

### Create session with first window

```bash
tmux new-session -d -s "$PROJECT_SLUG" -n "master" -c "$REPO_ROOT/.worktrees/master"
```

### Create remaining windows

For each role (excluding master, already created):
```bash
tmux new-window -t "$PROJECT_SLUG" -n "$ROLE" -c "$REPO_ROOT/.worktrees/$ROLE"
```

## Step 7: Launch Claude in each window

For each role/window:

### 7a. Export env vars

Before launching Claude, export env vars into the tmux window. Always set the project path var. Then apply `env.project` (project-level) followed by `env.sessions.<role>` (role-specific, wins on conflict):

```bash
tmux send-keys -t "$PROJECT_SLUG:$ROLE" "export ${PROJECT_ENV_NAME}='${REPO_ROOT}'" Enter
# For each key/value in env.project:
tmux send-keys -t "$PROJECT_SLUG:$ROLE" "export <KEY>='<VALUE>'" Enter
# For each key/value in env.sessions.<role>:
tmux send-keys -t "$PROJECT_SLUG:$ROLE" "export <KEY>='<VALUE>'" Enter
```

Do NOT inject secrets via this path — env section should contain only non-sensitive config. A future BWS/AWS Secrets Manager integration will handle secrets separately.

### 7b. Build and send the Claude command

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

Send the assembled command to the tmux window:
```bash
tmux send-keys -t "$PROJECT_SLUG:$ROLE" "$CMD" Enter
```

### 7c. Dispatch loop prompt (if configured)

If the role is one of the 8 loop-capable roles AND has a `sessions.loops.<role>` entry in PROJECT_CONFIG.json with `intervalMinutes > 0`:

1. Resolve the loop prompt path: `${sessions.loops.<role>.prompt}` (defaults to `loops/loop.md` if unset). Relative to the worktree root (which is cwd for this tmux window).
2. Verify the file exists at `$REPO_ROOT/.worktrees/$ROLE/$PROMPT_PATH`. If not, log a warning and skip loop dispatch for this role.
3. Wait for Claude to initialize. The tmux window was created with `-c "$REPO_ROOT/.worktrees/$ROLE"` so relative paths resolve correctly.
4. Send the loop command as a user prompt. Because Claude is reading stdin after the piped session prompt finished, we send via tmux keys after a short delay:
   ```bash
   # After Claude has initialized (wait for prompt readiness — use a sleep buffer)
   sleep 3
   tmux send-keys -t "$PROJECT_SLUG:$ROLE" "/loop ${INTERVAL_MINUTES}m $PROMPT_PATH" Enter
   ```
5. If `intervalMinutes == 0` or the role is not in `sessions.loops`, skip loop dispatch entirely.

**Never dispatch loops to:** planner, performance, playtester (on-demand roles).

### Skip idle roles (if selected)

Before launching Claude in a role, check for activity:
```bash
BRANCH="session/$ROLE"
# Check for uncommitted changes
DIRTY=$(git -C "$REPO_ROOT/.worktrees/$ROLE" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
# Check for commits ahead of main
AHEAD=$(git rev-list --count main.."$BRANCH" 2>/dev/null || echo 0)
```
If `DIRTY == 0` and `AHEAD == 0` and no Jira tasks assigned to this role: skip launching Claude in this window (but still create the window for manual use later).

## Step 8: Select master and report

```bash
tmux select-window -t "$PROJECT_SLUG:master"
```

Display launch report:

```
project launch — $PROJECT_NAME

  Session: $PROJECT_SLUG
  Windows: $N_LAUNCHED / $N_TOTAL
  Claude:  $N_WITH_CLAUDE running

  | # | Role        | Status  | Claude | Prompt | Loop  |
  |---|-------------|---------|--------|--------|-------|
  | a | master      | created | ●      | ✓      | 5m    |
  | b | planner     | created | ●      | ✓      | —     |
  | c | implementer | created | ○ idle | —      | 10m   |
  | d | fixer       | created | ○ idle | —      | 10m   |
  | e | merger      | created | ●      | ✓      | 10m   |
  | f | chk1        | created | ●      | ✓      | 15m   |
  | g | chk2        | created | ●      | ✓      | 15m   |
  | h | performance | created | ○ idle | —      | —     |
  | i | playtester  | created | ○ idle | —      | —     |
  | j | reviewer    | created | ●      | ✓      | 10m   |
  | k | triager     | created | ●      | ✓      | 10m   |

  To attach: tmux attach -t $PROJECT_SLUG
  To navigate: Prefix+P for project picker, or tmux select-window -t $PROJECT_SLUG:<role>
  To pick remotely: project-picker.sh
```

## `--all` mode

For each project found in `$REPOS_DIR` with `.worktrees/`:
1. Run Steps 2-8 for each project
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
- [ ] tmux session created with correct name
- [ ] All worktree roles have named windows
- [ ] Claude launched in each non-idle window with correct flags
- [ ] Session prompts piped when available
- [ ] Env vars exported (<PROJECT>_PATH + env.project + env.sessions.<role>)
- [ ] Loop prompts dispatched for loop-capable roles with intervalMinutes > 0
- [ ] On-demand roles (planner/performance/playtester) never get /loop
- [ ] Existing sessions handled gracefully (resume/recreate)
- [ ] Dry run shows plan without side effects
- [ ] --all mode launches all projects in TMUX_REPOS_DIR
- [ ] Report shows accurate status table with loop intervals
</success_criteria>
