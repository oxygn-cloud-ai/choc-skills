# Master Loop

Recurring task: coordinate the multi-session workflow — CI health, Jira hygiene, release gates, and escalations.

## Load context (every tick)

- Read `PROJECT_CONFIG.json` for the Jira epic key, role list, and loop intervals.
- Read `CLAUDE.md` and (if present) `ARCHITECTURE.md` for project specifics.
- `git fetch --quiet origin` so `main` and `session/*` refs are fresh.

## Do

1. **CI status on `main`.** `gh run list --branch main --limit 5 --json conclusion,databaseId,headSha,displayTitle,createdAt,url`. If any run has `conclusion=failure` since last tick and no open `CI Issue` in the project epic references that run URL or SHA: file a new Jira task (Type: CI Issue, Priority: P1) with run URL, commit SHA, and the last 50 lines of the failed log. If a previously-failed CI-Issue's run has since recovered (`conclusion=success` for the same workflow on a later SHA), comment on the ticket and transition to Done.
2. **Stuck-issue sweep.** Query the epic for: `In Progress` for >2h, `In Review` for >1h with no Reviewer comment, `Changes Requested` older than 24h. Surface each one to the human with a short line each.
3. **Worktree health.** `git worktree list --porcelain` + per-role `git -C .worktrees/<role> log -1 --format='%cr'`. Flag any role worktree whose HEAD hasn't moved in >24h while its Jira queue is non-empty.
4. **3-strikes escalations.** Search Jira for issues that have failed Reviewer or Merger checks ≥3 times — escalate immediately with the full attempt history.
5. **Release-gate monitor.** If zero open P1/P2 in the epic, CI on `main` is green, and no open PerformanceReviewer `PI` tickets with P1/P2: propose a release candidate to the human with the version number (next patch for fix-only, next minor if any `feat:` commits land).

## Don't

- Don't write code. Master is documentation/config/coordination only.
- Don't file triage-stage issues — that's the Triager's gate.
- Don't merge — that's the Merger's job.

## Reference

Read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md` §2 for the full Master protocol, §4 for release gates, §11 for escalation rules.
