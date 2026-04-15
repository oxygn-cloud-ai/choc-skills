---
name: project-doctor
description: Check skill installation health
allowed-tools:
  - Bash
  - Read
---

# project:doctor — Skill Installation Health Check

Run the following checks and report each as `[PASS]`, `[WARN]`, or `[FAIL]`:

1. **Skill installed**: `test -f ~/.claude/skills/project/SKILL.md`. If present, read the `version:` line and display it.
2. **Source repo marker**: `test -f ~/.claude/skills/project/.source-repo`. If present, read the path and verify `test -d "$(cat ~/.claude/skills/project/.source-repo)"` — catches unmounted external drives.
3. **Router present**: `test -f ~/.claude/commands/project.md`.
4. **Subcommand files present**: `ls ~/.claude/commands/project/*.md` — expect 9 files: `new.md`, `status.md`, `launch.md`, `audit.md`, `config.md`, `update.md`, `doctor.md`, `help.md`, `version.md`.
5. **Global architecture doc**: `test -f ~/.claude/MULTI_SESSION_ARCHITECTURE.md` — FAIL if missing (the skill is useless without it).
6. **Global project standards**: `test -f ~/.claude/PROJECT_STANDARDS.md` — FAIL if missing.
7. **git installed**: `command -v git` — FAIL if missing.
8. **gh installed**: `command -v gh` — FAIL if missing (required for repo creation and branch protection).
9. **gh authenticated**: `gh auth status 2>&1 | grep -q "Logged in"` — WARN if not (some subcommands work without auth, but `/project:new` does not).

Format the output as:

```
project doctor — Skill Installation Health Check

  [PASS] Skill installed at ~/.claude/skills/project/SKILL.md (vX.Y.Z)
  [PASS] Source repo: /path/to/source (reachable)
  [PASS] Router: ~/.claude/commands/project.md
  [PASS] Subcommands: 9 files
  [PASS] ~/.claude/MULTI_SESSION_ARCHITECTURE.md
  [PASS] ~/.claude/PROJECT_STANDARDS.md
  [PASS] git: /opt/homebrew/bin/git
  [PASS] gh: /opt/homebrew/bin/gh
  [PASS] gh authenticated

  Result: 9 passed, 0 warnings, 0 failed
```

Stop after displaying the report.
