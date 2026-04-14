# /project User Guide

A comprehensive guide to the `/project` skill — project repository administration for multi-session Claude Code workflows.

**Skill version:** 2.0.2

---

## Table of Contents

1. [What /project Does](#what-project-does)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [The Big Picture](#the-big-picture)
5. [Commands Reference](#commands-reference)
   - [/project status](#project-status)
   - [/project new](#project-new)
   - [/project launch](#project-launch)
   - [/project audit](#project-audit)
   - [/project config](#project-config)
   - [/project update](#project-update)
   - [/project help](#project-help)
   - [/project doctor](#project-doctor)
   - [/project version](#project-version)
6. [Key Concepts](#key-concepts)
   - [Project Types](#project-types)
   - [Session Roles](#session-roles)
   - [Worktrees](#worktrees)
   - [Session Prompts](#session-prompts)
   - [Loop Prompts](#loop-prompts)
   - [PROJECT_CONFIG.json](#project_configjson)
7. [Day-to-Day Workflow](#day-to-day-workflow)
8. [Configuration Files](#configuration-files)
9. [Troubleshooting](#troubleshooting)

---

## What /project Does

`/project` administers project repositories that follow the Oxygn multi-session workflow. It handles:

- **Creating** new projects with full scaffolding (GitHub repo, docs, worktrees, session prompts, CI, Jira integration)
- **Launching** all session roles simultaneously in tmux with Claude Code running in each
- **Auditing** projects against global standards (docs, worktrees, CI, branch protection, loops)
- **Configuring** projects (add/remove worktrees, branch protection, Jira epic, loop intervals)
- **Reporting** project status (config, worktrees, CI state, docs completeness)
- **Updating** the skill itself from its source repo

## Prerequisites

Before using `/project`, you need:

| Requirement | Check | Install |
|-------------|-------|---------|
| Claude Code CLI | `claude --version` | [docs.anthropic.com/en/docs/claude-code](https://docs.anthropic.com/en/docs/claude-code) |
| git | `git --version` | `brew install git` |
| gh (GitHub CLI) | `gh --version` | `brew install gh` |
| gh authenticated | `gh auth status` | `gh auth login` |
| tmux (for launch) | `tmux -V` | `brew install tmux` |
| python3 | `python3 --version` | `brew install python3` |
| jsonschema (for config validation) | `python3 -c "import jsonschema"` | `pip3 install jsonschema` |
| `~/.claude/MULTI_SESSION_ARCHITECTURE.md` | `test -f ~/.claude/MULTI_SESSION_ARCHITECTURE.md` | Manual setup |
| `~/.claude/PROJECT_STANDARDS.md` | `test -f ~/.claude/PROJECT_STANDARDS.md` | Manual setup |

Run `/project doctor` to check all prerequisites at once.

## Installation

### From the choc-skills repo (recommended)

```bash
git clone https://github.com/oxygn-cloud-ai/choc-skills.git
cd choc-skills/skills/project
./install.sh --force
```

### What gets installed

```
~/.claude/skills/project/
  SKILL.md                        # Main skill definition
  PROJECT_CONFIG.schema.json      # Schema for new projects
  .source-repo                    # Path back to source repo (for updates)

~/.claude/commands/
  project.md                      # Router (dispatches subcommands)
  project/
    new.md                        # /project:new
    status.md                     # /project:status
    launch.md                     # /project:launch
    audit.md                      # /project:audit
    config.md                     # /project:config
    update.md                     # /project:update
    doctor.md                     # /project:doctor
    help.md                       # /project:help
    version.md                    # /project:version

~/.local/bin/
  project-picker.sh               # Standalone tmux session picker
```

### Verify installation

```bash
./install.sh --check
```

Or in Claude Code:

```
/project doctor
```

## The Big Picture

A project managed by `/project` looks like this:

```
my-project/
├── .claude/
│   └── sessions/               # Session identity prompts
│       ├── master.md
│       ├── fixer.md
│       ├── implementer.md
│       └── ... (11 total for software)
├── .worktrees/                 # Git worktrees (one per session role)
│   ├── master/
│   ├── fixer/
│   ├── implementer/
│   └── ... (11 total for software)
├── PROJECT_CONFIG.json          # This project's config
├── PROJECT_CONFIG.schema.json   # JSON Schema for validation
├── CLAUDE.md                    # Project-specific Claude instructions
├── README.md
├── ARCHITECTURE.md
├── PHILOSOPHY.md
└── .github/workflows/
    └── test.yml                 # CI with notify-failure/recovery
```

Each worktree is a full checkout of the repo on its own branch (`session/<role>`). All 11 session roles can work simultaneously without stepping on each other.

### How sessions interact

```
                    ┌─────────┐
                    │  Human  │
                    └────┬────┘
                         │ talks to
                    ┌────▼────┐
                    │ Master  │ supervises all
                    └────┬────┘
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐    ┌─────▼─────┐   ┌─────▼─────┐
    │ Planner │    │  Triager  │   │  Reviewer  │
    │(features)│   │(gate)     │   │(reviews)   │
    └────┬────┘    └─────┬─────┘   └─────┬─────┘
         │               │               │
         │          ┌────▼────┐          │
         └─────────>│  Fixer  │<─────────┘
                    │Implementer│
                    └────┬────┘
                         │ pushes branch
                    ┌────▼────┐
                    │ Merger  │ squash-merges to main
                    └─────────┘
```

Auditor sessions (chk1, chk2, Performance, Playtester) file issues to Jira. They don't interact with other sessions directly.

### The issue lifecycle

```
Someone files issue → Needs Triage
    ↓
Triager reviews → Ready for Coding
    ↓
Fixer/Implementer claims → In Progress
    ↓
Branch pushed → In Review
    ↓
Reviewer reviews
    ├── APPROVE → Merger squash-merges → Done
    └── CHANGES REQUESTED → back to Fixer/Implementer → rework → In Review
```

All tracking happens in **Jira** (not GitHub Issues, not GitHub PRs). Reviewer posts structured review comments as Jira comments. Merger merges locally via `git merge --squash`.

## Commands Reference

### /project status

**What it does:** Shows comprehensive status of the current project.

**Usage:**
```
/project                    # shorthand
/project status             # explicit
```

**Output includes:**
- Project name, type, path, GitHub remote, Jira epic, version
- Documentation completeness (which required docs exist/missing)
- CI workflow status and last run result
- Branch protection status
- All worktrees with branch, commits ahead of main, last activity
- Test framework detection
- Open Jira issues by priority (via Atlassian MCP)

**Pre-flight checks:**
- Must be inside a git repo
- Warns if `~/.claude/MULTI_SESSION_ARCHITECTURE.md` missing (reduced output)
- Warns if `~/.claude/PROJECT_STANDARDS.md` missing (skips standard comparison)

### /project new

**What it does:** Creates a brand-new project repository with full multi-session scaffolding.

**Usage:**
```
/project new
```

**Interactive — asks you:**
1. Project name, description, and type (Software / Non-Software)
2. Language/framework (Software only): Python, Node/TypeScript, Rust, Go, Other
3. GitHub visibility: Public or Private
4. Where to create it (default: `~/Repos/<name>`)
5. PHILOSOPHY.md interview: vision, non-negotiables, out-of-scope
6. Jira epic key (create one in Jira first, or provide existing)

**What it creates:**

| Step | What |
|------|------|
| GitHub repo | `gh repo create` with visibility |
| Docs | README.md, ARCHITECTURE.md, PHILOSOPHY.md, CLAUDE.md |
| Config | PROJECT_CONFIG.json + PROJECT_CONFIG.schema.json |
| Language scaffolding | pyproject.toml / package.json / Cargo.toml / go.mod (Software) |
| Labels | None — all default GitHub labels deleted, `gh repo edit --enable-issues=false` |
| Worktrees | 11 (Software) or 8 (Non-Software) in `.worktrees/` |
| Session prompts | `.claude/sessions/<role>.md` for each role |
| CI | `.github/workflows/test.yml` with notify-failure/recovery (Software) |
| Branch protection | Required status checks, no force push (Software) |
| Memory | `~/.claude/projects/<encoded-path>/memory/` initialized |

**Safety checks:**
- Refuses to run inside an existing git repo
- Checks target directory doesn't already exist with content
- Verifies GitHub repo name isn't taken

### /project launch

**What it does:** Creates a tmux session with one window per worktree role, launches Claude Code in each.

**Usage:**
```
/project launch                 # Launch current project
/project launch --all           # Launch all projects in TMUX_REPOS_DIR
/project launch --dry-run       # Preview without launching
```

**Interactive options checklist:**
1. **Prompt pipe** (recommended) — feeds `.claude/sessions/<role>.md` to each Claude instance
2. **--dangerously-skip-permissions** — skip permission prompts for autonomous operation
3. **Resume existing sessions** — attach to existing tmux sessions
4. **--model override** — use a specific model for all sessions
5. **--max-turns limit** — cap autonomous turns per session
6. **Skip idle roles** — only launch roles with pending work (dirty git state or commits ahead)
7. **Verbose logging** — enable --verbose
8. **Dry run** — show plan without executing

**How it works:**
1. Detects project from `git rev-parse --show-toplevel`
2. Reads project type from `PROJECT_CONFIG.json` (or infers)
3. Scans `.worktrees/` for existing role directories
4. Creates tmux session: `tmux new-session -d -s <project> -n master`
5. Creates windows: `tmux new-window -t <project> -n <role>` for each role
6. Builds Claude command with selected flags
7. If prompt pipe selected: `cat .claude/sessions/<role>.md | claude [flags]`
8. Selects master window and reports status table

**Navigating launched sessions:**
```bash
tmux attach -t <project>                    # Attach to project session
tmux select-window -t <project>:<role>      # Switch to a role's window
project-picker.sh                           # TUI picker for all projects/roles
# Or bind to tmux key:
# bind-key P display-popup -E -w 60 -h 20 "~/.local/bin/project-picker.sh"
```

**`--all` mode:**
Scans `${TMUX_REPOS_DIR:-~/Repos}` for all directories with `.worktrees/`, launches each as a separate tmux session.

### /project audit

**What it does:** Audits the current project against global standards. Reports per-check verdicts.

**Usage:**
```
/project audit
```

**Checks (13 total):**

| # | Check | Verdict |
|---|-------|---------|
| 1 | GitHub repo exists | PASS/FAIL |
| 2 | Jira epic configured | PASS/FAIL |
| 3 | Required docs present | PASS/FAIL (lists missing) |
| 4 | Session worktrees present | PASS/FAIL (counts, lists missing) |
| 5 | Session startup prompts | PASS/FAIL (lists missing) |
| 6 | Branch protection on main | PASS/FAIL/SKIP |
| 7 | CI workflow exists | PASS/FAIL/SKIP (Non-Software) |
| 8 | notify-failure job in CI | PASS/FAIL/SKIP |
| 9 | notify-recovery job in CI | PASS/FAIL/SKIP |
| 10 | GitHub Issues disabled | PASS/FAIL |
| 11 | No GitHub labels present | PASS/FAIL |
| 12 | No stale worktree branches | PASS/WARN |
| 13 | Coverage thresholds | PASS/FAIL/SKIP |

**Pre-flight checks:**
- Must be inside a git repo
- Requires both `~/.claude/MULTI_SESSION_ARCHITECTURE.md` and `~/.claude/PROJECT_STANDARDS.md`
- Reads `PROJECT_CONFIG.json` for project type and documented deviations

### /project config

**What it does:** Interactively modify project configuration.

**Usage:**
```
/project config
```

**Available actions:**
- **Change project type** — switch between Software and Non-Software (adds/removes worktrees, CI)
- **Add worktree session** — create a new session worktree with branch and prompt
- **Remove worktree session** — remove with safety checks (uncommitted changes, unpushed commits, unmerged work). Master cannot be removed.
- **List worktrees** — show all with branch, path, commits ahead, last activity
- **Enable/disable branch protection** — toggle on main
- **Enable/disable CI** — add or remove test workflow
- **Set Jira epic key** — update in CLAUDE.md and PROJECT_CONFIG.json
- **Update deviations** — document a deviation from PROJECT_STANDARDS.md in PROJECT_CONFIG.json's deviations array

All changes are persisted to `PROJECT_CONFIG.json` and applied to GitHub/git. The config command loops — after each change, it asks if there's anything else.

**Safety: removing worktrees**

Before removing a worktree, `/project:config` checks three things:
1. Uncommitted changes in the worktree
2. Commits not merged to main
3. Commits not pushed to remote

If ANY check finds work, it warns with specifics and requires explicit "yes" confirmation before the destructive `git branch -D`.

### /project update

**What it does:** Updates the skill to the latest version from its source repo.

**Usage:**
```
/project update
/project --update
/project upgrade
```

**How it works:**
1. Reads `~/.claude/skills/project/.source-repo` (written during install)
2. Runs `git pull` in the choc-skills repo
3. Re-runs `install.sh --force` to update all files
4. Reports the new installed version

If `.source-repo` is missing, shows manual install instructions.

### /project help

**Usage:**
```
/project help
/project --help
/project -h
```

Shows the full usage guide with all subcommands, session roles, project types, and reference file locations.

### /project doctor

**Usage:**
```
/project doctor
/project --doctor
/project check
```

Runs 9 health checks:

1. Skill installed at `~/.claude/skills/project/SKILL.md`
2. Source repo marker exists and is reachable (catches unmounted drives)
3. Router at `~/.claude/commands/project.md`
4. 9 subcommand files in `~/.claude/commands/project/`
5. Global architecture doc (`~/.claude/MULTI_SESSION_ARCHITECTURE.md`)
6. Global project standards (`~/.claude/PROJECT_STANDARDS.md`)
7. git installed
8. gh installed
9. gh authenticated

### /project version

**Usage:**
```
/project version
/project --version
/project -v
```

Outputs: `project v2.0.2`

## Key Concepts

### Project Types

| Type | Sessions | CI | Branch Protection | Labels |
|------|----------|----|-------------------|--------|
| **Software** | 11 (all roles) | Yes | Yes | None (GitHub Issues disabled, all default labels deleted) |
| **Non-Software** | 8 (no chk1, chk2, playtester) | No | No | None (GitHub Issues disabled, all default labels deleted) |

### Session Roles

| # | Role | Writes Code? | Purpose |
|---|------|-------------|---------|
| 1 | **Master** | Yes | Supervises all sessions, coordinates releases, human's primary session |
| 2 | **Planner** | No | Creates feature requests after deep human discussion |
| 3 | **Implementer** | Yes | Implements features (picks up Feature Request issues) |
| 4 | **Fixer** | Yes | Fixes bugs (picks up Bug, Security, Performance Issue, CI Issue, Code Quality, UX issues) |
| 5 | **Merger** | Merges only | Squash-merges approved branches to main |
| 6 | **chk1** | No | Code quality auditor (runs /chk1:all on new commits) |
| 7 | **chk2** | No | Security auditor (runs /chk2:all against servers) |
| 8 | **Performance** | No | Performance reviewer (pre-release assessment) |
| 9 | **Playtester** | No | End-to-end testing in sandboxed environment |
| 10 | **Reviewer** | No | Reviews branches, posts structured Jira comments |
| 11 | **Triager** | No | Quality gate — no issue moves to coding until triager releases it |

**Work allocation:**
- **Implementer** picks up `Feature Request` issues only
- **Fixer** picks up everything else (Bug, Security, Performance Issue, CI Issue, Code Quality, UX)
- Both check for `Changes Requested` issues first — rework takes priority over new work

### Worktrees

Git worktrees let multiple branches be checked out simultaneously in separate directories. All worktrees share the same `.git` database — they are the same repo, just different working directories.

```
.worktrees/
  master/        ← session/master branch
  fixer/         ← session/fixer branch
  implementer/   ← session/implementer branch
  ...
```

When a worktree commits, it's a commit in the same repo. When that branch gets merged to main, every worktree sees the changes after pulling.

**Creating worktrees manually:**
```bash
git worktree add .worktrees/<role> -b session/<role> main
```

**Listing worktrees:**
```bash
git worktree list
```

### Session Prompts

Session prompts live in the repo at `.claude/sessions/<role>.md`. They are thin identity files — they tell Claude which role it is, which project it's working on, and where to find the full protocol:

```markdown
# Fixer Session — my-project

You are the **Fixer** for my-project.

## Protocol
Read ~/.claude/MULTI_SESSION_ARCHITECTURE.md section 4 for your full protocol.

## Project
- Jira epic: CPT-42
- Repo: oxygn-cloud-ai/my-project
- Read CLAUDE.md and ARCHITECTURE.md for project context.

## Quick Reference
- Rework first: check Changes Requested before new work
- Pick highest-priority bug in Ready for Coding
- ...
```

When `/project:launch` starts a session with "Prompt pipe" enabled, it feeds this file to Claude:
```bash
cat .claude/sessions/fixer.md | claude --dangerously-skip-permissions
```

### Loop Prompts

Loop prompts are recurring task instructions — separate from session identity prompts. They tell a session what to do on each polling cycle (e.g., "check Jira for new issues", "scan for branches to review").

**Location:** Each role's loop prompt lives in its own worktree at `.worktrees/<role>/loops/loop.md`. Because each worktree is on its own `session/<role>` branch, each role owns its loop prompt on its branch.

**Loop-capable roles (8):** master, triager, reviewer, merger, chk1, chk2, fixer, implementer. The on-demand roles (planner, performance, playtester) never loop.

**Configuration** in `PROJECT_CONFIG.json`:
```json
"sessions": {
  "loops": {
    "master":  { "intervalMinutes": 5,  "prompt": "loops/loop.md" },
    "triager": { "intervalMinutes": 10, "prompt": "loops/loop.md" }
  }
}
```
- `intervalMinutes: 0` = loop disabled for this role
- `prompt` path is relative to the worktree root (default: `loops/loop.md`)

**Dispatch:** `/project:launch` reads each role's `loops/loop.md`, inlines the contents into the `/loop` command, and pastes it as a single bracketed-paste block after Claude reaches a stable state (polled, no blind `sleep`). The `/loop` skill takes "a prompt or a slash command" — a file path would be treated as literal text, so the text is inlined rather than passed as a path.

### Environment Variables

Every launched session gets env vars exported automatically:

**Auto-set:** `<DIRNAME_SANITIZED>_PATH` — e.g., `CHOC_SKILLS_PATH=/path/to/repo`. Directory name uppercased with any non-`[A-Z0-9_]` characters replaced by underscore, `_PATH` suffix. (Bash identifiers can't contain hyphens, so `choc-skills` becomes `CHOC_SKILLS_PATH`, not `CHOC-SKILLS_PATH`.) Used by loop prompts and scripts to reference the project root portably.

**From `PROJECT_CONFIG.json` `env` section:**
```json
"env": {
  "project": { "JIRA_PROJECT": "CPT" },
  "sessions": {
    "chk2": { "CHK2_TARGET": "staging.example.com" }
  }
}
```
- `env.project` — exported into every session
- `env.sessions.<role>` — exported into that role only (overrides project-level)

**Never put secrets here.** Future BWS/AWS Secrets Manager integration will handle those separately. Use `/project:config` → Manage env vars to edit.

### PROJECT_CONFIG.json

Every project has a `PROJECT_CONFIG.json` at the repo root. It's the machine-readable configuration for the project:

```json
{
  "schemaVersion": 1,
  "project": {
    "name": "my-project",
    "type": "software",
    "description": "What this project does"
  },
  "jira": {
    "projectKey": "CPT",
    "cloudId": "...",
    "epicKey": "CPT-42"
  },
  "github": {
    "owner": "oxygn-cloud-ai",
    "repo": "my-project",
    "defaultBranch": "main",
    "issuesEnabled": false,
    "branchProtection": {
      "requiredStatusChecks": ["test", "lint"],
      "strict": true,
      "enforceAdmins": false,
      "allowForcePushes": false,
      "allowDeletions": false
    }
  },
  "sessions": {
    "roles": ["master", "planner", "implementer", "fixer", ...],
    "loops": {
      "master": { "intervalMinutes": 5 },
      "triager": { "intervalMinutes": 10 },
      ...
    }
  },
  "coverage": { "tool": "pytest-cov", "thresholds": { "line": 80 } },
  "sandbox": { "type": "docker" },
  "deviations": []
}
```

**Validation:**
```bash
./scripts/validate-config.sh
```

This validates against `PROJECT_CONFIG.schema.json` (schema checks) and runs semantic checks (epic key matches project key, loop roles exist in roles list, etc.).

## Day-to-Day Workflow

### Starting your day

1. **Launch all sessions:**
   ```
   /project launch
   ```
   Select options (prompt pipe + skip-permissions recommended). This creates a tmux session with all roles running.

2. **Check status:**
   ```
   /project status
   ```
   See what's happening — docs, CI, worktrees, open issues.

3. **Navigate between sessions:**
   ```bash
   # From terminal:
   tmux attach -t my-project
   # Switch windows: Ctrl-B then window number, or:
   tmux select-window -t my-project:fixer
   # Or use the picker:
   project-picker.sh
   ```

### The human's role

You primarily interact with the **Master** session. Master is your coordination layer:
- Check on other sessions' progress
- Make architecture decisions
- Approve feature plans from Planner
- Cut releases when gates are met
- Handle escalations (3-strikes rule, P1 issues)

### When things go wrong

- **Session stalled?** Check its worktree for uncommitted changes or failed tests
- **CI broken?** Master files a Jira issue automatically (CI Issue type, P1)
- **Issue stuck in workflow?** Master monitors Jira for stuck issues
- **Merge conflict?** Merger detects and either resolves or escalates to Master
- **Same bug fails 3 times?** Escalated to human via Master with full context

### Releasing

Master monitors release gates:
1. Zero open P1/P2 issues
2. Performance reviewer has run against current main
3. Playtester regression pass
4. CI green on main
5. No in-progress issues

When all gates pass, Master notifies you:
> Release candidate: v1.2.0 — 5 merges since last release, 0 P1/P2 open, CI green. Cut release?

## Configuration Files

| File | Location | Purpose |
|------|----------|---------|
| `MULTI_SESSION_ARCHITECTURE.md` | `~/.claude/` | Global: 11 role definitions, workflow rules, Jira integration, release model |
| `PROJECT_STANDARDS.md` | `~/.claude/` | Global: branch protection, CI monitoring, push discipline, coverage, docs requirements |
| `PROJECT_CONFIG.json` | Repo root | Per-project: Jira epic, GitHub settings, session roles, loop intervals, deviations |
| `PROJECT_CONFIG.schema.json` | Repo root | Per-project: JSON Schema for config validation |
| `.claude/sessions/<role>.md` | Repo | Per-project: session identity prompts (thin — point to architecture doc) |
| `sessions.loops` in PROJECT_CONFIG.json | Repo root | Per-project: loop intervals per role (planned — CPT-41) |
| `CLAUDE.md` | Repo root | Per-project: Claude Code instructions |
| `PHILOSOPHY.md` | Repo root | Per-project: vision, principles, non-negotiables |

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `/project:new` fails with "gh not authenticated" | gh CLI not logged in | Run `gh auth login` |
| `/project:audit` reports all FAIL | Running in wrong directory | `cd` into a project repo first |
| `~/.claude/MULTI_SESSION_ARCHITECTURE.md missing` | File deleted or never created | Restore from backup or recreate |
| `~/.claude/PROJECT_STANDARDS.md missing` | Old setup (had GITHUB_CONFIG.md) | Create PROJECT_STANDARDS.md per v1.3.0 |
| Skill not appearing in Claude Code | Not installed | `./install.sh --force` from skills/project/ |
| Skill is outdated | Source repo not pulled | `/project update` |
| `doctor` reports `.source-repo` unreachable | External drive unmounted | Mount drive and re-run |
| tmux session already exists | Previous launch didn't clean up | Choose "kill and recreate" when prompted |
| `project-picker.sh` not found | bin/ not installed | `cd skills/project && ./install.sh --force` |
| `validate-config.sh` fails | Missing python3 jsonschema | `pip3 install jsonschema` |
| Worktree in detached HEAD | Branch was deleted | `git worktree remove` then recreate |

---

*This guide covers /project v2.0.2. Run `/project version` to check your installed version.*
