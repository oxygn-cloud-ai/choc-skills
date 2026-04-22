# chk1 Auditor Loop

Recurring task: run `/chk1:all` against new commits on `main` and file findings as Jira tasks. Never write code.

## Load context (every tick)

- Read `PROJECT_CONFIG.json` for the Jira epic key.
- Resolve last-audited SHA: `git show-ref --hash refs/audit/chk1-last-seen 2>/dev/null || echo ''`. If empty (first run), use `git rev-parse origin/main~20` as the baseline to avoid flooding with historical findings.

## Do

1. **Find new commits since last audit.** `git -C .worktrees/chk1 fetch --quiet origin main:main` then `git log <last-seen>..origin/main --oneline`. If no new commits → exit cleanly for this tick.
2. **Run `/chk1:all`** against the diff `<last-seen>..origin/main`. Capture all findings.
3. **Deduplicate** against existing Jira tasks in the epic: search for each finding's fingerprint (file path + rule id + line) before filing.
4. **File non-duplicates** as Jira tasks: Type `Code Quality`, Priority per `/chk1` severity mapping (P1 critical → P4 informational). Include the offending file:line, the rule rationale, and the exact suggested fix from `/chk1`.
5. **Advance the audit pointer.** `git -C .worktrees/chk1 update-ref refs/audit/chk1-last-seen origin/main` and `git -C .worktrees/chk1 push origin refs/audit/chk1-last-seen`.

## Don't

- Don't write code. Don't touch source files.
- Don't file findings for changes you haven't audited (skipped files, ignored paths).
- Don't re-file findings already open in Jira — dedupe first.

## Reference

Read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md` §7 for the full chk1 protocol. Read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/chk1/SKILL.md` for the checker's own docs.
