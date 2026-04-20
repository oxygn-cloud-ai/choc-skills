# chk1:all — Full Adversarial Audit

Run all 8 audit sections against the detected or specified scope. This is the default behavior when running `/chk1` with no arguments.

## Instructions

1. Read the main skill file at `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/chk1/SKILL.md`
2. Execute the full audit as defined there (all 8 sections)
3. Follow the scope detection, pre-flight checks, and output format exactly as specified

## After

After producing the audit report, ask the user:

> **Do you want help fixing the issues found?** If yes, I'll walk through each bug, risk, and deviation with specific code fixes.

If the user says yes, invoke `/chk1:fix`.
