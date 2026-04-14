Run your recurring implementer cycle for choc-skills:

1. **Rework first**: check Jira CPT-3 for any Feature Request in "Changes Requested" state assigned to you. If found, read Reviewer's Jira comments and rework before picking up new work.
2. If no rework, query CPT-3 for highest-priority Feature Request in "Ready for Coding" status.
3. Transition to "In Progress", write a plan under the issue (per Implementer protocol), get triager approval if plan diverges from issue scope.
4. TDD implementation on this worktree's branch (session/implementer).
5. Push branch, transition to "In Review", Reviewer will pick up on its next loop.
6. After Reviewer approves and Merger squash-merges, run bashcov (once wired) and report coverage delta.

Read ~/.claude/MULTI_SESSION_ARCHITECTURE.md section 5 for full implementer protocol.
