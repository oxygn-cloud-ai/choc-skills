---
name: project
version: 1.3.0
description: Project repository administration — create new, audit, configure, status check. Multi-session workflow scaffolding per ~/.claude/MULTI_SESSION_ARCHITECTURE.md and ~/.claude/PROJECT_STANDARDS.md.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(gh *), Bash(git *), Bash(mkdir *), Bash(cp *), Bash(mv *), Bash(sed *), Bash(cat *), Bash(chmod *), Bash(touch *), Bash(ls *), Bash(test *), Bash(basename *), Bash(dirname *), Bash(stat *), Bash(date *), Bash(python3 *), Bash(npm *), Bash(find *), Write, Edit, AskUserQuestion
argument-hint: [status | new | launch | audit | config | update | help | doctor | version]
---

# project — Project Repository Administration

## Subcommands

Check `$ARGUMENTS` before proceeding. If it matches one of the following subcommands, execute that subcommand and stop. Do not proceed to the main skill.

The router at `~/.claude/commands/project.md` intercepts sub-command arguments and dispatches to `/project:new`, `/project:status`, `/project:audit`, and `/project:config` directly. This `SKILL.md` is only reached for `help`, `doctor`, `version` (and aliases), or when Claude self-invokes the skill without a matching argument.

### help

If `$ARGUMENTS` equals `help`, `--help`, or `-h`, display the following usage guide and stop.

```
project v1.3.0 — Project Repository Administration

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

STANDARD WORKTREE SESSIONS (per ~/.claude/MULTI_SESSION_ARCHITECTURE.md)
  master           Supervisor — alignment, cooperation, orderly updates
  planner          Feature request creation (after deep human discussion)
  implementer      Feature implementation (picks up Ready for Coding issues)
  fixer            Bug fixes (plan → triager approval → TDD)
  merger           Squash-merges approved branches to main
  chk1             Code quality auditor (runs /chk1:all on new commits)
  chk2             Security auditor (runs /chk2:all against servers)
  performance      Performance reviewer (pre-release assessment)
  playtester       End-to-end testing in sandboxed environment
  reviewer         Branch review (structured comments, never merges)
  triager          Quality gate — releases issues to Ready for Coding

ISSUE TRACKING
  Jira project CPT (Claude Progress Tracking)
  Each repo is an epic. Issues are tasks under that epic.
  Workflow: New → Needs Triage → Ready for Coding → In Progress → In Review → Done

REFERENCE FILES
  Architecture:  ~/.claude/MULTI_SESSION_ARCHITECTURE.md
  Standards:     ~/.claude/PROJECT_STANDARDS.md
  Global rules:  ~/.claude/CLAUDE.md

LOCATION
  ~/.claude/skills/project/SKILL.md  (installed)
  Source:      see .source-repo marker
```

End of help output. Do not continue.

### doctor

If `$ARGUMENTS` equals `doctor`, `--doctor`, or `check`, run skill-install health diagnostics and stop.

**Checks** (report each as `[PASS]`, `[WARN]`, or `[FAIL]`):

1. **Skill installed**: `test -f ~/.claude/skills/project/SKILL.md`. If present, read the `version:` line and display it.
2. **Source repo marker**: `test -f ~/.claude/skills/project/.source-repo`. If present, read the path and verify `test -d "$(cat ~/.claude/skills/project/.source-repo)"` — catches unmounted external drives.
3. **Router present**: `test -f ~/.claude/commands/project.md`.
4. **Subcommand files present**: `ls ~/.claude/commands/project/*.md` — expect 6 files: `new.md`, `status.md`, `launch.md`, `audit.md`, `config.md`, `update.md`. No stale `doctor.md` or `help.md` (those were removed in the v1.0.0 migration).
5. **Global architecture doc**: `test -f ~/.claude/MULTI_SESSION_ARCHITECTURE.md` — the skill is useless without it (FAIL if missing).
6. **Global project standards**: `test -f ~/.claude/PROJECT_STANDARDS.md` — FAIL if missing.
7. **git installed**: `command -v git` — FAIL if missing.
8. **gh installed**: `command -v gh` — FAIL if missing (required for repo creation, labels, branch protection).
9. **gh authenticated**: `gh auth status 2>&1 | grep -q "Logged in"` — WARN if not (some subcommands work without auth, but `/project:new` does not).

Format:
```
project doctor — Skill Installation Health Check

  [PASS] Skill installed at ~/.claude/skills/project/SKILL.md (v1.3.0)
  [PASS] Source repo: /Volumes/.../choc-skills/skills/project (reachable)
  [PASS] Router: ~/.claude/commands/project.md
  [PASS] Subcommands: 6 files (new, status, launch, audit, config, update)
  [PASS] ~/.claude/MULTI_SESSION_ARCHITECTURE.md
  [PASS] ~/.claude/PROJECT_STANDARDS.md
  [PASS] git: /opt/homebrew/bin/git
  [PASS] gh: /opt/homebrew/bin/gh
  [PASS] gh authenticated

  Result: 9 passed, 0 warnings, 0 failed
```

End of doctor output. Do not continue.

### version

If `$ARGUMENTS` equals `version`, `--version`, or `-v`, output the version and stop.

```
project v1.3.0
```

End of version output. Do not continue.

---

## Pre-flight Checks

Before executing any main-skill logic, silently verify:

1. **Global architecture doc present**: `test -f ~/.claude/MULTI_SESSION_ARCHITECTURE.md`. If missing:
   > **project error**: `~/.claude/MULTI_SESSION_ARCHITECTURE.md` not found. This skill is authoritative on the multi-session workflow and cannot operate without it. Restore the file or run `/project doctor` for diagnostics.

2. **Global project standards present**: `test -f ~/.claude/PROJECT_STANDARDS.md`. If missing:
   > **project error**: `~/.claude/PROJECT_STANDARDS.md` not found. See `/project doctor` for diagnostics.

---

## Instructions

If execution reaches this section, `$ARGUMENTS` did not match any of `help`, `doctor`, `version` (or aliases). This happens when Claude self-invokes the skill without a matching subcommand — the router at `~/.claude/commands/project.md` would normally dispatch explicit subcommands directly to `/project:new`, `/project:status`, `/project:audit`, or `/project:config`.

In this fallback case, display the help block above and stop.

Do not attempt to infer intent or execute any destructive action. The project skill's main operations all live in subcommand files under `~/.claude/commands/project/` and are only run via explicit user invocation through the router.
