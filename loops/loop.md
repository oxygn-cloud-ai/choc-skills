Run your recurring implementer cycle for choc-skills:

**JQL note:** epic scoping uses `parent = CPT-3` (this is a next-gen Jira project; `"Epic Link" = CPT-3` returns 0).

**JQL must NOT include freshness filters.** Do not add `updated >= <timestamp>`, `created >= <timestamp>`, or any other recency clause to your JQL. Every cycle must see the full backlog. A self-imposed recency filter caused implementer to report "idle" while 9+ Feature Requests sat in Ready-for-Coding for >1 hour (observed 2026-04-17). The idempotency safeguard is: skip a ticket if (a) a branch matching `feature/CPT-<n>-*` already exists on origin (another session owns it), or (b) its `reviewed-sha:` comment matches the branch HEAD (already verdicted). Never use `updated` as a filter.

1. **Rework first**: check Jira CPT-3 for any Feature Request in "Changes Requested" state assigned to you. If found, read Reviewer's Jira comments and rework before picking up new work.
2. If no rework, query CPT-3 for highest-priority Feature Request in "Ready for Coding" status. JQL: `parent = CPT-3 AND status = "Ready for Coding" AND issuetype = "Feature Request" ORDER BY priority ASC, created ASC`. No freshness filter.
3. Transition to "In Progress", write a plan under the issue (per Implementer protocol), get triager approval if plan diverges from issue scope.
4. TDD implementation on this worktree's branch (session/implementer).
5. Push branch, transition to "In Review", Reviewer will pick up on its next loop.
6. After Reviewer approves and Merger squash-merges, run bashcov (once wired) and report coverage delta.

Read ~/.claude/MULTI_SESSION_ARCHITECTURE.md section 5 for full implementer protocol.
