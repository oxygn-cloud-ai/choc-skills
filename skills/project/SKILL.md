---
name: project
version: 1.2.11
description: Project repository administration — create new, audit, configure, status check. Multi-session workflow scaffolding per $CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md and $CLAUDE_DIR/PROJECT_STANDARDS.md (where $CLAUDE_DIR = ${CLAUDE_CONFIG_DIR:-$HOME/.claude}).
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(gh *), Bash(git *), Bash(mkdir *), Bash(cp *), Bash(mv *), Bash(sed *), Bash(cat *), Bash(chmod *), Bash(touch *), Bash(ls *), Bash(test *), Bash(basename *), Bash(dirname *), Bash(stat *), Bash(date *), Bash(python3 *), Bash(npm *), Bash(find *), Write, Edit, AskUserQuestion
argument-hint: [status | new | launch | audit | config | update | help | doctor | version]
---

# project — Project Repository Administration

Throughout this file, `$CLAUDE_DIR` means the Claude config directory —
`$CLAUDE_CONFIG_DIR` if set and non-empty, otherwise `$HOME/.claude` (CPT-174).
Resolve it in every bash invocation with `CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"`
before using any `$CLAUDE_DIR/...` path.

## Subcommands

Check `$ARGUMENTS` before proceeding. If it matches one of the following subcommands, execute that subcommand and stop. Do not proceed to the main skill.

The router at `$CLAUDE_DIR/commands/project.md` intercepts sub-command arguments and dispatches to `/project:new`, `/project:status`, `/project:audit`, and `/project:config` directly. This `SKILL.md` is only reached for `help`, `doctor`, `version` (and aliases), or when Claude self-invokes the skill without a matching argument.

### help

If `$ARGUMENTS` equals `help`, `--help`, or `-h`, display the following usage guide and stop.

```
project v1.2.11 — Project Repository Administration

USAGE
  /project                  Show status for current project (same as /project status)
  /project status           Show project config, worktrees, Jira, CI, docs
  /project new              Create a new project with full multi-session setup
  /project launch           Launch tmux sessions with Claude in each worktree
  /project launch --all     Launch all projects in TMUX_REPOS_DIR
  /project launch --dry-run Preview without launching
  /project audit            Audit against global standards, report gaps
  /project config           Change project config: worktrees, labels, Jira, CI
  /project update           Update to latest version
  /project help             Display this usage guide
  /project doctor           Check skill installation health
  /project version          Show installed version

PROJECT TYPES
  software         11 sessions, CI, branch protection, full labels, code scaffolding
  non-software     8 sessions (no chk1/chk2/playtester), no CI, reduced labels

STANDARD WORKTREE SESSIONS (per $CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md)
  master           Supervisor — alignment, cooperation, orderly updates
  planner          Feature request creation (after deep human discussion)
  implementer      Feature implementation (picks up Ready for Coding issues)
  fixer            Bug fixes (plan → triager approval → TDD)
  merger           Squash-merges approved branches to main
  chk1             Code quality auditor (runs /chk1:all on new commits)
  chk2             Security auditor (runs /chk2:all against servers)
  performance      Performance reviewer (pre-release assessment)
  playtester       End-to-end testing in sandboxed environment
  reviewer         PR review (structured comments, never merges)
  triager          Quality gate — releases issues to Ready for Coding

ISSUE TRACKING
  Jira project CPT (Claude Progress Tracking)
  Each repo is an epic. Issues are tasks under that epic.
  Workflow: New → Needs Triage → Ready for Coding → In Progress → In Review → Done

REFERENCE FILES
  Architecture:  $CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md
  Standards:     $CLAUDE_DIR/PROJECT_STANDARDS.md
  Global rules:  $CLAUDE_DIR/CLAUDE.md

LOCATION
  $CLAUDE_DIR/skills/project/SKILL.md  (installed)
  Source:      see .source-repo marker
```

End of help output. Do not continue.

### doctor

If `$ARGUMENTS` equals `doctor`, `--doctor`, or `check`, run skill-install health diagnostics and stop.

**Checks** (report each as `[PASS]`, `[WARN]`, or `[FAIL]`):

1. **Skill installed**: `test -f $CLAUDE_DIR/skills/project/SKILL.md`. If present, read the `version:` line and display it.
2. **Source repo marker**: `test -f $CLAUDE_DIR/skills/project/.source-repo`. If present, read the path and verify `test -d "$(cat $CLAUDE_DIR/skills/project/.source-repo)"` — catches unmounted external drives.
3. **Router present**: `test -f $CLAUDE_DIR/commands/project.md`.
4. **Subcommand files present**: `ls $CLAUDE_DIR/commands/project/*.md` — expect 6 files: `new.md`, `status.md`, `launch.md`, `audit.md`, `config.md`, `update.md`. No stale `doctor.md` or `help.md` (those were removed in the v1.0.0 migration).
5. **Global architecture doc**: `test -f $CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md` — the skill is useless without it (FAIL if missing).
6. **Global project standards**: `test -f $CLAUDE_DIR/PROJECT_STANDARDS.md` — FAIL if missing. (Replaces retired `GITHUB_CONFIG.md`; narrative label/CI/branch-protection spec now lives here, per-project machine-readable config lives in each repo's `PROJECT_CONFIG.json`.)
7. **git installed**: `command -v git` — FAIL if missing.
8. **gh installed**: `command -v gh` — FAIL if missing (required for repo creation, labels, branch protection).
9. **gh authenticated**: `gh auth status 2>&1 | grep -q "Logged in"` — WARN if not (some subcommands work without auth, but `/project:new` does not).

Format:
```
project doctor — Skill Installation Health Check

  [PASS] Skill installed at $CLAUDE_DIR/skills/project/SKILL.md (vX.Y.Z)
  [PASS] Source repo: /Volumes/.../choc-skills/skills/project (reachable)
  [PASS] Router: $CLAUDE_DIR/commands/project.md
  [PASS] Subcommands: 6 files (new, status, launch, audit, config, update)
  [PASS] $CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md
  [PASS] $CLAUDE_DIR/PROJECT_STANDARDS.md
  [PASS] git: /opt/homebrew/bin/git
  [PASS] gh: /opt/homebrew/bin/gh
  [PASS] gh authenticated

  Result: 9 passed, 0 warnings, 0 failed
```

End of doctor output. Do not continue.

### version

If `$ARGUMENTS` equals `version`, `--version`, or `-v`, output the version and stop.

```
project v1.2.11
```

End of version output. Do not continue.

---

## Pre-flight Checks

Before executing any main-skill logic, silently verify:

1. **Global architecture doc present**: `test -f $CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md`. If missing:
   > **project error**: `$CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md` not found. This skill is authoritative on the multi-session workflow and cannot operate without it. Restore the file or run `/project doctor` for diagnostics.

2. **Global project standards present**: `test -f $CLAUDE_DIR/PROJECT_STANDARDS.md`. If missing:
   > **project error**: `$CLAUDE_DIR/PROJECT_STANDARDS.md` not found. See `/project doctor` for diagnostics. (Replaces retired `GITHUB_CONFIG.md`.)

---

## Instructions

If execution reaches this section, `$ARGUMENTS` did not match any of `help`, `doctor`, `version` (or aliases). This happens when Claude self-invokes the skill without a matching subcommand — the router at `$CLAUDE_DIR/commands/project.md` would normally dispatch explicit subcommands directly to `/project:new`, `/project:status`, `/project:audit`, or `/project:config`.

In this fallback case, display the help block above and stop.

Do not attempt to infer intent or execute any destructive action. The project skill's main operations all live in subcommand files under `$CLAUDE_DIR/commands/project/` and are only run via explicit user invocation through the router.
