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
- `command -v jq` — if missing: **STOP** with error: "jq is required for PROJECT_CONFIG.json reading."
- `command -v bash` — if missing: **STOP** (the per-role launch script requires bash). macOS and Linux always have bash; this check guards against exotic environments.
- `command -v ~/.local/bin/project-launch-session.sh` — if missing: **STOP** with error: "project-launch-session.sh not installed. Re-run `~/.claude/skills/project/install.sh --force`."

## Step 1: Detect project (worktree-aware)

```bash
# Use git-common-dir so we resolve to the MAIN repo path even when /project:launch
# is invoked from inside a .worktrees/<role>/ subdirectory (common case: master
# session running /project:launch from within its own worktree).
COMMON=$(git rev-parse --git-common-dir 2>/dev/null) || {
  echo "Not in a git repository. Navigate to a project and try again."
  exit 1
}
REPO_ROOT=$(cd "$COMMON/.." && pwd)
```
`REPO_ROOT` is always the main repo path — the directory that contains `.worktrees/`.
Verify `$REPO_ROOT/.worktrees/` exists; if not, STOP (no worktrees to launch into).

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

## Step 7: Launch Claude in each window (delegates to project-launch-session.sh)

**All per-role logic lives in `~/.local/bin/project-launch-session.sh`** (installed
by the `project` skill). This is a real bash script — NOT pseudocode inside
`launch.md` — so its helper functions survive across the Bash tool
invocations that Claude Code makes. It also gives us something we can unit-test
and run in `--dry-run` mode before the real launch.

The script's responsibilities per role:

1. **Validate env var keys** against `^[A-Za-z_][A-Za-z0-9_]*$`; skip any invalid.
2. **Generate a setup script** at `/tmp/project-launch-<slug>-<role>.sh` that:
   - Exports the sanitized `<SANITIZED_DIRNAME>_PATH` (e.g., `CHOC_SKILLS_PATH`).
   - Exports `ENABLE_PROMPT_CACHING_1H=1` (CPT-74 Phase 1, Claude Code v2.1.108+) so the 5-minute prompt-cache TTL default is bumped to 1 hour — large win for polling roles whose system prompt + CLAUDE.md context is identical across every iteration.
   - Exports `env.project` and `env.sessions.<role>` entries using `jq @sh`
     (POSIX-compatible single-quoted, lossless for tabs, newlines, single
     quotes, dollar signs — no `printf %q` portability traps).
   - `cd`'s into the worktree.
   - `exec`s Claude — `exec claude --continue $CLAUDE_FLAGS 2>/dev/null || exec claude $CLAUDE_FLAGS` (CPT-74 Phase 1, Claude Code v2.1.110+). Tries `--continue` first to resurrect the most recent conversation in the worktree (including any unexpired scheduled `/loop` tasks); falls through to a plain launch when no prior session exists or `--continue` errors. `exec` only replaces the process on success — on error the parent shell continues to the `||` branch. Stdin = pane TTY, NOT a pipe.
3. **Source that script** in the pane via `tmux send-keys "source … ; rm -f …" Enter`.
4. **Wait for Claude readiness** by polling `tmux capture-pane` for output
   stability (N consecutive 1s samples unchanged). No blind `sleep`.
5. **Paste the identity prompt** (if `--prompt-pipe` requested and
   `.claude/sessions/<role>.md` exists) as a single bracketed-paste block via
   `tmux load-buffer`/`paste-buffer -p`. Then wait for stability again before
   dispatching `/loop`. On timeout: SKIP /loop dispatch (no fire-and-forget).
6. **Dispatch `/loop`** as a **single line**:
   `/loop <N>m Read the file loops/loop.md in this worktree and execute the recurring task described there.`
   We do NOT inline multi-line prompt text into `/loop` because the slash-command
   parser's behavior on multi-line bracketed pastes is undocumented and a line
   starting with `/` in the pasted content could flip into slash-command mode.
   The session reads the file fresh each cycle, so edits take effect on next tick.

### Invocation per role

```bash
# $PROJECT_SLUG is the tmux session name from Step 2.
# $ROLE is the current role in the iteration.
# $CLAUDE_FLAGS is the space-separated flag string built from Step 5 answers.
# $PROMPT_PIPE / $SKIP_IDLE are "true" / "false" strings from Step 5.
# $DRY_RUN is "true" if Step 5 dry-run option was selected.

for ROLE in "${ROLES[@]}"; do
  target="$PROJECT_SLUG:$ROLE"
  args=(
    --target "$target"
    --role "$ROLE"
    --repo "$REPO_ROOT"
    --claude-flags "$CLAUDE_FLAGS"
  )
  [ "$PROMPT_PIPE" = "true" ] && args+=(--prompt-pipe)
  [ "$SKIP_IDLE"   = "true" ] && args+=(--skip-idle)
  [ "$DRY_RUN"     = "true" ] && args+=(--dry-run)

  # The script returns non-zero on readiness timeout (exit 4) but we continue
  # to the next role — the window is left in a recoverable state and the
  # summary table will flag it.
  ~/.local/bin/project-launch-session.sh "${args[@]}" || true
done
```

### Building `$CLAUDE_FLAGS` from Step 5 answers

```bash
CLAUDE_FLAGS=""
[ "$SKIP_PERMS" = "true" ] && CLAUDE_FLAGS="$CLAUDE_FLAGS --dangerously-skip-permissions"
[ "$VERBOSE"    = "true" ] && CLAUDE_FLAGS="$CLAUDE_FLAGS --verbose"
[ -n "${MAX_TURNS:-}" ]    && CLAUDE_FLAGS="$CLAUDE_FLAGS --max-turns $MAX_TURNS"
[ -n "${MODEL:-}" ]        && CLAUDE_FLAGS="$CLAUDE_FLAGS --model $MODEL"
CLAUDE_FLAGS="${CLAUDE_FLAGS# }"   # trim leading space
```

Tune timeouts (optional) via env vars:
- `PROJECT_LAUNCH_READY_TIMEOUT` (default 60s) — max wait for initial Claude readiness
- `PROJECT_LAUNCH_PROCESS_TIMEOUT` (default 120s) — max wait after identity prompt
- `PROJECT_LAUNCH_STABLE_SAMPLES` (default 3) — consecutive quiet samples required

**Dispatch order is important**: launch all roles serially, because bracketed
paste is targeted at a specific tmux window and parallel paste can interleave
if the shared global tmux buffer is ever under contention. With 11 roles and
typical init times, expect 10-20 minutes of serial launch — acceptable for a
session restart that happens once per day.

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
- [ ] Per-role logic runs in `~/.local/bin/project-launch-session.sh` — no helper functions defined inline in this prompt
- [ ] `REPO_ROOT` resolved via `git rev-parse --git-common-dir` + parent (works from main repo AND from inside a worktree)
- [ ] Claude launched via `source /tmp/project-launch-*.sh` → `exec claude` (no stdin pipe, attached to pane TTY)
- [ ] Env vars: sanitized `<PROJECT>_PATH` + env.project + env.sessions.<role>, written through `jq @sh` (lossless for tabs/newlines/quotes). Invalid identifier keys are filtered with a WARN.
- [ ] Identity prompt (if selected) pasted as bracketed-paste block via `tmux load-buffer`/`paste-buffer -p`
- [ ] Pane stability polled before and after identity-prompt paste; no blind sleep. On readiness/processing timeout, `/loop` is SKIPPED (exit 4) — never fired blind.
- [ ] `/loop` dispatched as a SINGLE LINE: `/loop <N>m Read the file loops/loop.md in this worktree and execute the recurring task described there.`
- [ ] On-demand roles (planner/performance/playtester) never get /loop
- [ ] Existing sessions handled gracefully (resume/recreate)
- [ ] Dry run passes `--dry-run` to `project-launch-session.sh` and prints the full setup-script contents without executing
- [ ] --all mode launches all projects in TMUX_REPOS_DIR
- [ ] Report shows accurate status table with loop intervals and readiness-timeout markers
</success_criteria>
