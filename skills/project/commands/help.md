---
name: project-help
description: Display full usage guide for the /project skill
allowed-tools:
  - Read
---

# project:help — Usage Guide

Read the installed skill version from `~/.claude/skills/project/SKILL.md` frontmatter, then display:

```
project vX.Y.Z — Project Repository Administration

USAGE
  /project                  Show status for current project (same as /project status)
  /project status           Show project config, worktrees, Jira, CI, docs
  /project new              Create a new project with full multi-session setup
  /project launch           Launch tmux sessions with Claude in each worktree
  /project launch --all     Launch all projects in TMUX_REPOS_DIR
  /project launch --dry-run Preview without launching
  /project audit            Audit against global standards, report gaps
  /project config           Change project config: worktrees, Jira, CI, loops
  /project update           Update to latest version
  /project help             Display this usage guide
  /project doctor           Check skill installation health
  /project version          Show installed version

PROJECT TYPES
  software         11 sessions, CI, branch protection, code scaffolding
  non-software     8 sessions (no chk1/chk2/playtester), no CI

STANDARD WORKTREE SESSIONS (per ~/.claude/MULTI_SESSION_ARCHITECTURE.md)
  master           Supervisor — alignment, cooperation, orderly updates
  planner          Feature request creation (after deep human discussion)
  implementer      Feature implementation (picks up Feature Request issues)
  fixer            Bug fixes (plan → triager approval → TDD)
  merger           Squash-merges approved branches to main
  chk1             Code quality auditor (runs /chk1:all on new commits)
  chk2             Security auditor (runs /chk2:all against servers)
  performance      Performance reviewer (pre-release assessment)
  playtester       End-to-end testing in sandboxed environment
  reviewer         Branch review (structured Jira comments, never merges)
  triager          Quality gate — releases issues to Ready for Coding

ISSUE TRACKING
  Jira project CPT (Claude Progress Tracking) — single source of truth.
  GitHub Issues are DISABLED. Each repo is a Jira epic, issues are tasks.
  Workflow: New → Needs Triage → Ready for Coding → In Progress → In Review → Done

REFERENCE FILES
  Architecture:  ~/.claude/MULTI_SESSION_ARCHITECTURE.md
  Standards:     ~/.claude/PROJECT_STANDARDS.md
  Global rules:  ~/.claude/CLAUDE.md
  User guide:    ~/.claude/skills/project/USER_GUIDE.md

LOCATION
  ~/.claude/skills/project/SKILL.md  (installed)
  Source:      see .source-repo marker
```

Stop after displaying.
