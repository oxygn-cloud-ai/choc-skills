---
name: project
version: 2.2.1
description: Project repository administration — create new, audit, configure, status check. Multi-session workflow scaffolding per ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md and ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/PROJECT_STANDARDS.md.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(gh *), Bash(git *), Bash(mkdir *), Bash(cp *), Bash(mv *), Bash(sed *), Bash(cat *), Bash(chmod *), Bash(touch *), Bash(ls *), Bash(test *), Bash(basename *), Bash(dirname *), Bash(stat *), Bash(date *), Bash(python3 *), Bash(npm *), Bash(find *), Write, Edit, AskUserQuestion
argument-hint: [status | new | launch | audit | config | update | help | doctor | version]
---

# project — Project Repository Administration

All subcommands are dispatched by the router at `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/project.md`. The router maps the user's argument (including aliases) to a colon-command file under `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/project/`. See `commands/help.md` for the full argument list.

## Pre-flight Checks

Before invoking any subcommand, silently verify:

1. **Global architecture doc present**: `test -f ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md`. If missing:
   > **project error**: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md` not found. This skill is authoritative on the multi-session workflow and cannot operate without it. Restore the file or run `/project:doctor` for diagnostics.

2. **Global project standards present**: `test -f ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/PROJECT_STANDARDS.md`. If missing:
   > **project error**: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/PROJECT_STANDARDS.md` not found. See `/project:doctor` for diagnostics.

## Fallback Behaviour

This file is only reached when Claude self-invokes the skill without a matching subcommand argument. In that case, invoke `/project:help` via the Skill tool and stop.

Do not attempt to infer intent or execute any destructive action. All operational subcommands live as explicit command files under `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/project/` and are routed by `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/project.md`.
