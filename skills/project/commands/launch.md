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

## Prompting fallback (v2.4.0+)

This process uses `AskUserQuestion` — a Claude Code built-in tool — for the Step 5 multi-select options checklist and for the Step 2.5 confirmation. **If `AskUserQuestion` is not available in the current session** (an older Claude Code build, or a custom harness that does not expose it), fall back to a numbered-list plain-text prompt and wait for the user's numeric (or `y/n`) reply. Alongside the fallback, emit this one-line install hint:

> Note: `AskUserQuestion` is a Claude Code built-in. Update Claude Code to the latest release, or enable the tool in your harness configuration, to get structured prompts.

Every subsequent "AskUserQuestion" reference in this file is subject to this fallback — do not re-state it inline.

## Step 0: Pre-checks

Verify dependencies exist:
- `test -f ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md` — if missing: **STOP** with error.
- `command -v tmux` — if missing: **STOP** with error: "tmux is required. Install with: brew install tmux"
- `command -v claude` — if missing: **STOP** with error: "Claude Code CLI is required."
- `command -v jq` — if missing: **STOP** with error: "jq is required for PROJECT_CONFIG.json reading."
- `command -v bash` — if missing: **STOP** (the per-role launch script requires bash). macOS and Linux always have bash; this check guards against exotic environments.
- `command -v ~/.local/bin/project-launch-session.sh` — if missing: **STOP** with error: "project-launch-session.sh not installed. Re-run `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/project/install.sh --force`."

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
`REPO_ROOT` is always the main repo path — the directory that contains (or will contain) `.worktrees/`.

**Do NOT STOP here if `.worktrees/` is missing.** In single-project mode, Step 2.5 below auto-materialises missing role worktrees with user confirmation. In `--all` mode, Step 2's loop already skips repos without `.worktrees/`.

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

**Missing `.worktrees/` is handled by Step 2.5 — do not STOP here.** The user explicitly invoked `/project:launch` on this project, so absent worktrees are a configuration gap to fix (with confirmation), not a reason to abort.

### All projects mode (`--all`)

```bash
REPOS_DIR="${TMUX_REPOS_DIR:-$HOME/Repos}"
for dir in "$REPOS_DIR"/*/; do
  if [ -d "$dir/.worktrees" ]; then
    # Add to project list
  fi
done
```

**Missing-worktree policy in `--all`:** repos without `.worktrees/` are silently skipped. Step 2.5 is NOT run for them. Rationale: in bulk mode the lack of `.worktrees/` is the intentional signal that a repo isn't set up for multi-session work — auto-materialising across an entire `$REPOS_DIR` would quietly promote unrelated projects into multi-session configuration. If a listed repo IS supposed to be multi-session but is missing some role worktrees, launch it individually with `/project:launch` so Step 2.5's confirmation runs on it.

## Step 2.5: Materialise missing role worktrees (single-project mode only)

**Scope:** single-project mode. Skipped entirely in `--all` mode per the policy note above.

Invoke the helper to build a plan:

```bash
~/.local/bin/project-materialise-worktrees.sh --list --repo "$REPO_ROOT"
```

The helper reads `PROJECT_CONFIG.json` `.sessions.roles[]`, checks each role's worktree presence via `git worktree list --porcelain` (not `-d` — a stray plain directory doesn't count as present), and prints a plan. Per role the action is one of:

- `REUSE` — local `session/<role>` branch exists and is free → attach worktree to it (no `-b`).
- `TRACK` — only `origin/session/<role>` exists → create local tracking branch (`--track -b session/<role> … origin/session/<role>`).
- `CREATE` — neither exists → new `session/<role>` branch from the detected default branch (`PROJECT_CONFIG.json` `.github.defaultBranch` → `git symbolic-ref refs/remotes/origin/HEAD` → error).
- `CONFLICT` — `session/<role>` is already checked out at another worktree; the script **will not** try to move it. Operator must resolve before retrying.
- `STRAY` — `.worktrees/<role>/` exists as a plain directory (not a registered worktree); operator must remove or inspect before retrying.

### If the plan is empty

If the helper prints `0 missing worktrees — nothing to do`, continue to Step 3 immediately.

### If the plan is non-empty

Show the plan verbatim to the user and ask for confirmation:

> Create N worktree(s)? [y/N]

- **y / yes** → run the helper with `--execute`:
  ```bash
  ~/.local/bin/project-materialise-worktrees.sh --execute --repo "$REPO_ROOT"
  ```
  - Exit 0 → continue to Step 3.
  - Exit 4 (partial failure) → show the helper's stderr to the user and **abort the launch**. The user resolves the underlying conflict (free the branch, remove the stray dir) and re-runs `/project:launch`.
  - Any other non-zero → abort and report.

- **n / no / anything else** → abort with "Launch cancelled — role worktrees are required before /project:launch can proceed."

### Interaction with `--dry-run`

If the CLI flag `--dry-run` was passed (parsed in Step 2), Step 2.5 runs `--list` only, prints the plan, and **continues** to Step 3 so the rest of the launch proceeds under its own dry-run semantics. No `--execute`, no prompt, no creation.

### Policy note — GIT_WORKTREE_OVERRIDE

The helper inlines `GIT_WORKTREE_OVERRIDE=1` on every `git worktree add` to bypass the `block-worktree-add.sh` PreToolUse hook. This is the sanctioned setup-automation bypass per `MULTI_SESSION_ARCHITECTURE.md §7.1`; `/project:launch` and `/project:new` are the two authorised boundaries. No other command or agent may silently bypass.

## Step 3: Read architecture and config

Read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md` for the role list.

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

**Note**: `--effort max` is always applied (every session starts in maximum thinking-effort mode for deep reasoning on complex coordination tasks). This is a hardcoded default, not a checkbox.

Options (multiSelect: true):
1. **Prompt pipe** (description: "Feed .claude/sessions/<role>.md as startup prompt to each Claude instance") — recommend checked by default
2. **--dangerously-skip-permissions** (description: "Skip permission prompts for autonomous operation") — recommend checked by default
3. **Resume existing sessions** (description: "Attach to existing tmux sessions instead of creating new") — recommend checked by default
4. **--model override** (description: "Use a specific model for all sessions — will ask which model")
5. **Skip idle roles** (description: "Only launch roles with pending Jira tasks or uncommitted git changes")
6. **Verbose logging** (description: "Enable --verbose on Claude for debugging")
7. **Dry run** (description: "Show what would be launched without actually launching anything")

If `--model` is selected, follow up: "Which model? (e.g., opus, sonnet, haiku)"

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
   - Exports `env.project` and `env.sessions.<role>` entries using `jq @sh`
     (POSIX-compatible single-quoted, lossless for tabs, newlines, single
     quotes, dollar signs — no `printf %q` portability traps).
   - `cd`'s into the worktree.
   - `exec`s Claude with the requested flags (stdin = pane TTY, NOT a pipe).
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
# Seed with --effort max so every session starts in maximum thinking-effort mode.
# This is hardcoded, not conditional — see the Step 5 note above.
CLAUDE_FLAGS="--effort max"
[ "$SKIP_PERMS" = "true" ] && CLAUDE_FLAGS="$CLAUDE_FLAGS --dangerously-skip-permissions"
[ "$VERBOSE"    = "true" ] && CLAUDE_FLAGS="$CLAUDE_FLAGS --verbose"
[ -n "${MODEL:-}" ]        && CLAUDE_FLAGS="$CLAUDE_FLAGS --model $MODEL"
```

`--max-turns` is NOT built here. The flag was removed from the `claude` CLI; leaving it in would have produced an "unknown option" error at launch. Model and verbose remain configurable via Step 5 answers.

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

### Step 8a: Open iTerm2 tabs (macOS + iTerm2 + not dry-run, single-project mode only)

```bash
ITERM_STATUS="skipped"
if [ "$DRY_RUN" != "true" ] \
   && [ "$(uname -s)" = "Darwin" ] \
   && pgrep -qf "iTerm" \
   && [ -x ~/.local/bin/tmux-iterm-tabs.sh ]; then
  if ~/.local/bin/tmux-iterm-tabs.sh --session "$PROJECT_SLUG" 2>&1; then
    ITERM_STATUS="opened"
  else
    ITERM_STATUS="failed — tmux session still running; attach manually with: tmux attach -t $PROJECT_SLUG"
  fi
fi
```

- **Scope**: only invoked in single-project mode and only on macOS with iTerm2 running. Skipped entirely in `--all` mode (would spam one iTerm2 window per project) and in dry-run.
- **Architecture contract**: `tmux-iterm-tabs.sh --session <slug>` iterates `tmux list-windows -t <slug>` (the windows created in Step 6) and opens one iTerm2 tab per window, each tab exec-ing `tmux attach -t <slug>:<role>`. It does NOT enumerate global tmux sessions, so other projects' sessions are not tabbed.
- **Failure mode**: if iTerm2 is not running or AppleScript fails, the tmux session is left running and the report tells the user how to attach manually. Launch does not abort.

Display launch report:

```
project launch — $PROJECT_NAME

  Session: $PROJECT_SLUG
  Windows: $N_LAUNCHED / $N_TOTAL
  Claude:  $N_WITH_CLAUDE running
  iTerm2:  $ITERM_STATUS

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
- [ ] Step 8a invokes `~/.local/bin/tmux-iterm-tabs.sh --session "$PROJECT_SLUG"` in single-project mode on macOS when iTerm2 is running. Skipped for --dry-run, --all, non-macOS, or iTerm2 not running. Failure does not abort the launch.
- [ ] `tmux-iterm-tabs.sh --session` iterates `tmux list-windows -t <slug>` (NOT global `tmux ls`), so tabs are scoped to the current project's windows only — no leakage from other projects' tmux sessions.
- [ ] Step 2.5 invokes `~/.local/bin/project-materialise-worktrees.sh --list` and displays the missing-worktree plan to the user before any creation. User confirmation required before `--execute`; on "n" the launch aborts cleanly. Helper exit 4 surfaces stderr and aborts.
- [ ] Presence check for `.worktrees/<role>/` uses `git worktree list --porcelain`, not `-d` — stray plain directories are flagged as STRAY, not treated as registered.
- [ ] Branch precedence: local `session/<role>` (REUSE) → remote `origin/session/<role>` (TRACK with --track) → default branch (CREATE). Branch already checked out elsewhere = CONFLICT, fails loudly.
- [ ] Default-branch detection: `PROJECT_CONFIG.json .github.defaultBranch` → `git symbolic-ref --short refs/remotes/origin/HEAD` → error. Never hardcoded `main`.
- [ ] `--dry-run` CLI flag: Step 2.5 runs `--list` only, never `--execute`. No prompt.
- [ ] `--all` mode SKIPS Step 2.5. Repos without `.worktrees/` stay skipped. Rationale documented in Step 2.
- [ ] Helper uses `GIT_WORKTREE_OVERRIDE=1` inline on every `git worktree add`. Policy exception documented in launch.md and `hooks/block-worktree-add.sh`.
</success_criteria>
