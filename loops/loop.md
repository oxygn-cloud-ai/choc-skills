Run your review cycle.

**JQL:** epic scoping uses `parent = CPT-3` (next-gen project; `"Epic Link" = CPT-3` returns 0). No recency filter — review the full In Review backlog every iteration, FIFO.

**AUTHORITY OVERRIDE:** For CPT-3 the reviewer IS the verdict-and-transition gate. "Never approves, never merges" in MULTI_SESSION_ARCHITECTURE.md §11 and your session prompt is SUPERSEDED here: you deliver one verdict per ticket per cycle, and you transition the ticket to match. The merger then does the git squash-merge.

## Protocol

1. Query: `parent = CPT-3 AND status = "In Review" ORDER BY priority ASC, updated ASC` (highest priority first, then oldest update — FIFO within priority).

2. For each ticket, in order:
   - **Find the branch.** Read ticket description / comments / search: `git for-each-ref --format='%(refname:short)' refs/remotes/origin/ | grep -E '(fix|feature)/<KEY>'`.
   - **Read the diff safely.** `mkdir -p /tmp/review-<KEY> && git archive <branch> | tar -xC /tmp/review-<KEY>/`. Then inspect with Read/Grep against `/tmp/review-<KEY>/`. **NEVER** `git checkout` in this worktree — mutation caught 2026-04-17 (see MEMORY.md `feedback_reviewer_read_only_technique`).
   - **Capture the full SHA.** `git rev-parse origin/<branch>` → 40 chars verbatim. NEVER hallucinate a suffix (MEMORY.md `feedback_full_sha_verify`).
   - **Re-read the ticket's Acceptance Criteria.** Cite `file:line` against `/tmp/review-<KEY>/` for each AC that passes.
   - **Run tests where feasible.** `bats tests/` from the extracted tree, language-specific suites, or the diff's own tests. Record pass/fail counts.
   - **Check branch CI.** `gh run list --repo oxygn-cloud-ai/choc-skills --branch <branch> --limit 1`.

3. Deliver ONE verdict per ticket per cycle. No "partial review" outcomes.

   **APPROVE** — ALL of: every AC has a file:line citation showing it's met, tests pass (or N/A for docs-only), CI green on the branch, no blocking concerns.
   → Post the comment below, then call `mcp__claude_ai_Atlassian__transitionJiraIssue` with `transition: "41"` (Done). The merger picks up the squash-merge.

   **CHANGES REQUESTED** — ANY of: one or more ACs unmet, tests red, CI red, correctness/security/perf concern that must be addressed before shipping.
   → Post the comment below listing every specific change needed with `file:line`, then `transitionJiraIssue` with `transition: "44"` (Changes Requested). The fixer/implementer reworks.

   **HOLD** — ambiguous case requiring human input (scope question, philosophy conflict, unclear requirement).
   → Post the comment below explaining the ambiguity. Leave status as `In Review`. If a ticket is HOLD for two consecutive cycles, flag to master in your progress notes.

4. Comment format (always, before any transition):

   ```
   reviewed-sha: <full 40-char SHA>
   Recommendation: {APPROVE | CHANGES REQUESTED | HOLD} — <one-line reason>

   ## ACs
   - [✓] AC1 — <file:line>
   - [✗] AC2 — <why unmet, what's needed>

   ## Tests + CI
   - bats tests/: <N> passed / <M> failed
   - CI (<branch>): <green|red|pending>

   ## Concerns (if any)
   - <file:line>: <issue> — <proposed fix>
   ```

5. **Valid transitions from In Review**: `41` = Done (APPROVE path), `44` = Changes Requested (CHANGES REQUESTED path). Do not use other IDs. If `transitionJiraIssue` errors, read the error text, do NOT retry blindly.

6. **Concurrency & idempotency**: if a ticket has your `reviewed-sha:` comment matching the current branch HEAD, you already verdicted — skip it. If the branch HEAD has moved since your last comment, re-review.

7. **After a verdict, move to the next ticket.** Do not linger commenting on tickets you've already verdicted.

## End-of-cycle

When every In-Review ticket has a current-SHA verdict, report idle: comment summary on any one new progress ticket (Phase 3 pending — until then, master reads your commit log + Jira timeline).
