---
name: chk1:all
description: Full adversarial audit (all 8 sections) of recent changes
allowed-tools: Read, Grep, Glob, Bash(git *), AskUserQuestion
---

# chk1:all — Full Adversarial Audit

Run all 8 audit sections against the detected or specified scope. This is the default behavior when running `/chk1` with no arguments.

## Instructions

The main skill file (`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/chk1/SKILL.md`) is already in context — it was loaded to route to this command. Do not re-read it.

1. Execute the full audit as defined in SKILL.md (all 8 sections)
2. Follow the scope detection, pre-flight checks, and output format exactly as specified

## After

After producing the audit report, ask the user:

> **Do you want help fixing the issues found?** If yes, I'll walk through each bug, risk, and deviation with specific code fixes.

If the user says yes, invoke `/chk1:fix`.
