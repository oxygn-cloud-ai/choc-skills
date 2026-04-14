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

**Project path env var (MUST be sanitized to a valid shell identifier):**
```bash
# Uppercase, then replace any non-[A-Z0-9_] char with underscore. Prepend '_'
# if the name would start with a digit. Append _PATH.
SAFE=$(basename "$REPO_ROOT" | LC_ALL=C tr '[:lower:]' '[:upper:]' | LC_ALL=C sed 's/[^A-Z0-9_]/_/g')
[[ "$SAFE" =~ ^[0-9] ]] && SAFE="_$SAFE"
PROJECT_ENV_NAME="${SAFE}_PATH"
# Examples:
#   choc-skills  → CHOC_SKILLS_PATH
#   my.thing     → MY_THING_PATH
#   42repo       → _42REPO_PATH
```
Hyphens, dots, and other characters invalid in bash identifiers are replaced with underscore; bare `basename | tr upper` would produce invalid names like `CHOC-SKILLS_PATH` and `export` would fail with "not a valid identifier". This variable is auto-exported into every launched session so loop prompts and env-dependent scripts can reference the project root portably.

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

For each role/window, run the following sub-steps in order. Between each tmux
operation that produces visible pane output and the next step that depends on
Claude being ready, use `_wait_pane_stable` (defined below) — do NOT use blind
`sleep` values. Claude + MCP startup is not bounded by a small fixed delay.

### Helper functions (define once per script)

```bash
# Wait until the tmux pane's visible output has not changed for `stable`
# consecutive samples (1s each), or `timeout` seconds total. Returns 0 if
# stabilized, 1 if timed out. Use this before and after sending a prompt
# so we don't race Claude's startup or message-processing phases.
_wait_pane_stable() {
  local target="$1" stable="${2:-3}" timeout="${3:-60}"
  local t=0 same=0 prev="" cur
  while [ "$t" -lt "$timeout" ]; do
    cur=$(tmux capture-pane -p -t "$target" 2>/dev/null | tail -40)
    if [ "$cur" = "$prev" ] && [ -n "$cur" ]; then
      same=$((same + 1))
      [ "$same" -ge "$stable" ] && return 0
    else
      same=0
    fi
    prev="$cur"
    sleep 1
    t=$((t + 1))
  done
  return 1
}

# Paste a file's contents into the pane as a single bracketed-paste block,
# then press Enter to submit. Used to inject the identity prompt into an
# already-running interactive Claude (not via stdin pipe — Claude's stdin
# must be the TTY so it stays interactive and reads subsequent send-keys).
_paste_file_and_submit() {
  local target="$1" file="$2"
  local buf="promptbuf_${RANDOM}_$$"
  tmux load-buffer -b "$buf" "$file"
  tmux paste-buffer -b "$buf" -t "$target" -p   # -p = bracketed paste
  tmux send-keys -t "$target" Enter
  tmux delete-buffer -b "$buf" 2>/dev/null || true
}

# Build a `/loop <N>m <prompt text>` command with the prompt text INLINED
# from the file (the /loop skill takes "a prompt or a slash command", not a
# file path — passing the path would schedule the literal string). Paste
# it as a single bracketed-paste block and submit.
_send_loop_command() {
  local target="$1" interval="$2" prompt_file="$3"
  local buf="loopbuf_${RANDOM}_$$"
  local tmpfile
  tmpfile=$(mktemp)
  {
    printf '/loop %sm ' "$interval"
    cat "$prompt_file"
  } > "$tmpfile"
  tmux load-buffer -b "$buf" "$tmpfile"
  tmux paste-buffer -b "$buf" -t "$target" -p
  tmux send-keys -t "$target" Enter
  tmux delete-buffer -b "$buf" 2>/dev/null || true
  rm -f "$tmpfile"
}

# Validate an env var name is a legal shell identifier, and quote its value
# with printf %q so embedded quotes / dollar signs / spaces are safe.
_export_via_tmux() {
  local target="$1" key="$2" value="$3"
  if ! [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "  [WARN] skipping env var with invalid identifier: $key" >&2
    return 1
  fi
  local q
  q=$(printf '%q' "$value")
  tmux send-keys -t "$target" "export $key=$q" Enter
}
```

### 7a. Export env vars

Before launching Claude, export env vars into the tmux window's shell. Always
set the sanitized project path var first. Then apply `env.project`
(project-level) followed by `env.sessions.<role>` (role-specific, wins on
conflict). All keys are validated as legal shell identifiers; all values are
shell-quoted with `printf '%q'` so single quotes, dollar signs, spaces, and
newlines are preserved safely.

```bash
target="$PROJECT_SLUG:$ROLE"

# 1. Sanitized project-path var (computed in Step 3)
_export_via_tmux "$target" "$PROJECT_ENV_NAME" "$REPO_ROOT"

# 2. env.project (apply to every role)
while IFS=$'\t' read -r k v; do
  [ -z "$k" ] && continue
  _export_via_tmux "$target" "$k" "$v"
done < <(jq -r '.env.project // {} | to_entries[] | "\(.key)\t\(.value)"' "$REPO_ROOT/PROJECT_CONFIG.json")

# 3. env.sessions.<role> (overrides project-level for this role)
while IFS=$'\t' read -r k v; do
  [ -z "$k" ] && continue
  _export_via_tmux "$target" "$k" "$v"
done < <(jq -r --arg r "$ROLE" '.env.sessions[$r] // {} | to_entries[] | "\(.key)\t\(.value)"' "$REPO_ROOT/PROJECT_CONFIG.json")
```

Do NOT inject secrets via this path — the `env` section should contain only
non-sensitive config. A future BWS/AWS Secrets Manager integration will handle
secrets separately at launch time.

### 7b. Launch Claude attached to the pane TTY (NEVER pipe stdin)

Claude must be started with its stdin pointing at the tmux pane TTY, not a
closed pipe. Previous versions used `cat prompt.md | claude …` which closed
stdin after the prompt; subsequent `tmux send-keys "/loop …"` then either hit
the shell (Claude having exited) or landed on a non-interactive process.

Build the Claude command with selected flags, but DO NOT include a stdin pipe:

```bash
CLAUDE_CMD="claude"
$SKIP_PERMS && CLAUDE_CMD="$CLAUDE_CMD --dangerously-skip-permissions"
$VERBOSE    && CLAUDE_CMD="$CLAUDE_CMD --verbose"
[ -n "$MAX_TURNS" ] && CLAUDE_CMD="$CLAUDE_CMD --max-turns $MAX_TURNS"
[ -n "$MODEL" ]     && CLAUDE_CMD="$CLAUDE_CMD --model $MODEL"

tmux send-keys -t "$target" "$CLAUDE_CMD" Enter
```

### 7c. Wait for Claude readiness

MCP server initialization commonly takes 8–15 seconds; new sessions with many
plugins can take longer. Poll the pane for output stability before sending any
further input.

```bash
_wait_pane_stable "$target" 3 60 || {
  echo "  [WARN] $ROLE: Claude did not become ready within 60s; skipping prompt/loop dispatch"
  continue
}
```

If this times out, do not attempt to send the identity prompt or loop command
for this role — note it in the report and move on (manual recovery is safer
than firing `/loop` into an unknown state).

### 7d. Paste identity prompt (if "Prompt pipe" selected)

If the user selected "Prompt pipe" in Step 5 AND
`$REPO_ROOT/.claude/sessions/$ROLE.md` exists, paste it into Claude as a
single bracketed-paste block (not as repeated send-keys) so multi-line content
becomes one message:

```bash
PROMPT_FILE="$REPO_ROOT/.claude/sessions/$ROLE.md"
if $PROMPT_PIPE && [ -f "$PROMPT_FILE" ]; then
  _paste_file_and_submit "$target" "$PROMPT_FILE"
  # Wait for Claude to finish processing the identity prompt before dispatching /loop
  _wait_pane_stable "$target" 3 120 || echo "  [WARN] $ROLE: identity-prompt processing did not settle within 120s"
fi
```

If no prompt file exists, skip this sub-step.

### 7e. Dispatch loop prompt (if configured)

If the role is one of the 8 loop-capable roles AND has a
`sessions.loops.<role>` entry with `intervalMinutes > 0`:

1. Resolve the prompt path: `jq -r --arg r "$ROLE" '.sessions.loops[$r].prompt // "loops/loop.md"' PROJECT_CONFIG.json`. Relative to the worktree root.
2. Resolve intervalMinutes: `jq -r --arg r "$ROLE" '.sessions.loops[$r].intervalMinutes // 0' PROJECT_CONFIG.json`.
3. Verify the file exists at `$REPO_ROOT/.worktrees/$ROLE/$PROMPT_PATH`. If not, log a warning and skip loop dispatch for this role.
4. INLINE the prompt text into the `/loop` command — the `/loop` skill
   accepts "a prompt or a slash command", not a filesystem path argument.
   Passing `/loop 5m loops/loop.md` would schedule the literal string
   "loops/loop.md". Instead, build `/loop <N>m <prompt text>` and paste it
   as a single bracketed-paste block:

   ```bash
   INTERVAL=$(jq -r --arg r "$ROLE" '.sessions.loops[$r].intervalMinutes // 0' "$REPO_ROOT/PROJECT_CONFIG.json")
   PROMPT_REL=$(jq -r --arg r "$ROLE" '.sessions.loops[$r].prompt // "loops/loop.md"' "$REPO_ROOT/PROJECT_CONFIG.json")
   PROMPT_ABS="$REPO_ROOT/.worktrees/$ROLE/$PROMPT_REL"

   if [ "$INTERVAL" -gt 0 ] 2>/dev/null && [ -f "$PROMPT_ABS" ]; then
     _send_loop_command "$target" "$INTERVAL" "$PROMPT_ABS"
   elif [ "$INTERVAL" -gt 0 ] 2>/dev/null; then
     echo "  [WARN] $ROLE: loop prompt missing at $PROMPT_ABS — skipping /loop"
   fi
   ```

5. If `intervalMinutes == 0` or the role is not in `sessions.loops`, skip loop dispatch entirely.

**Never dispatch loops to:** planner, performance, playtester (on-demand roles
— the schema's patternProperties already rejects them from `sessions.loops`,
but the launcher must also refuse as a defense-in-depth check).

### Skip idle roles (if selected, applies before Step 7b)

If "Skip idle roles" was selected, evaluate activity BEFORE launching Claude:

```bash
BRANCH="session/$ROLE"
DIRTY=$(git -C "$REPO_ROOT/.worktrees/$ROLE" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
AHEAD=$(git rev-list --count main.."$BRANCH" 2>/dev/null || echo 0)
```
If `DIRTY == 0` and `AHEAD == 0` and no Jira tasks assigned to this role: skip
7b–7e (create the window for manual use later, do not start Claude). Env vars
from 7a are still exported.

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
- [ ] Claude launched in each non-idle window attached to the pane TTY (no stdin pipe)
- [ ] Identity prompt (if selected) pasted as bracketed-paste block — single message
- [ ] Env vars exported (sanitized `<PROJECT>_PATH` + env.project + env.sessions.<role>) with keys validated and values `printf %q`-escaped
- [ ] Pane stability polled before and after identity-prompt paste; no blind sleep
- [ ] Loop prompts dispatched with `/loop <N>m <prompt text>` (text inlined from the file, NOT a file path)
- [ ] On-demand roles (planner/performance/playtester) never get /loop
- [ ] Existing sessions handled gracefully (resume/recreate)
- [ ] Dry run shows plan without side effects
- [ ] --all mode launches all projects in TMUX_REPOS_DIR
- [ ] Report shows accurate status table with loop intervals
</success_criteria>
