# Loop step-0 context-management preamble

**Read this file at the START of every `/loop` cycle, BEFORE executing your role's loop task.** The harness's `/loop` dispatch is constructed so that each tick begins by reading this preamble, then reads your role's `loops/loop.md`, then executes the task. This preamble's purpose is to keep your session context healthy across long-running operation.

## Three-tier context strategy

Apply these rules in priority order at the start of each cycle. Use `/status` to estimate your current context utilisation:

### Tier 1 — Compact at >60%

If current context usage is greater than 60%:

1. **Write a summary comment** on your pinned progress ticket (Phase 3 registry — see §"Where state lives" below) capturing: what you've done this cycle and last, any open work you're tracking, last-seen Jira or git SHA, and anything the next-cycle-you must know.
2. Run `/compact`. Compaction is lossy — your summary comment is your safety net.

### Tier 2 — Clear at >85% or after a discrete unit

If current context usage is greater than 85%, OR if you have just finished a discrete unit of work (e.g., one Jira issue transitioned In Review; one branch pushed; one commit verified green by CI):

1. Post the same summary comment as Tier 1.
2. Run `/clear`. Context resets to zero. On the next cycle you'll re-read your identity, `MEMORY.md`, and the progress registry to rebuild working state.

### Tier 3 — Daily `--continue` relaunch

Once per day (local 04:00, orchestrated by the master session), every polling role is relaunched via `claude --continue`. Scheduled `/loop` tasks survive per Claude Code v2.1.110 — `--continue` resurrects unexpired cron tasks with the conversation. You don't need to do anything for this tier; it just happens.

## Role-specific tuning

The thresholds above apply equally, but the BALANCE between `/compact` and `/clear` differs by role type:

### Monitor roles — mostly `/compact`, `/clear` rare

- **master** — orchestrator; loss of context damages mental model of the fleet
- **triager** — release-gate role; context history informs triage judgements
- **reviewer** — batched reviews; keep the thread warm
- **merger** — merge decisions benefit from the history
- **chk1** — adversarial audits; context helps spot patterns
- **chk2** — same

For these roles: `/compact` liberally (above 60%), `/clear` only when 85% is hit or after an explicit operator signal.

### Code-writing roles — `/clear` between Jira issues

- **fixer** — each bug fix is a discrete unit; state lives in git + Jira
- **implementer** — each feature ticket is a discrete unit; state lives in git + Jira

For these roles: `/clear` AT the boundary between Jira issues (one ticket closed → `/clear`). Between issues the session carries no useful state that isn't already in the Jira ticket or the feature branch. Between `/clear`s, `/compact` at 60% remains the same.

## Where state lives after `/compact` / `/clear`

Your durable state is NOT in the conversation. Re-establish working state at each cycle's start from these sources, in order:

1. **MEMORY.md** (cross-session durable facts: user identity, feedback rules, project context, shipped tickets). Loaded automatically into your context.
2. **Your pinned progress ticket** (Phase 3 Jira-backed registry — CPT-83). Lookup via the registry JSON pointer map; read latest 1–3 comments for tactical per-cycle state.
3. **Git state**: `git log --oneline -10`, `git status`, `git branch --show-current` for work-in-progress.
4. **Jira state**: rework queue (Changes Requested for you), Ready-for-Coding queue, your In-Progress tickets.

Compact and clear are safe as long as your summary comment at Tier 1/Tier 2 captures what the next-cycle-you needs beyond what MEMORY.md and the registry already hold.

## Notes

- **Phase 3 (CPT-83)** is the progress-registry mechanism referenced above. Until Phase 3 lands, the "pinned progress ticket" is aspirational — you record cycle state in MEMORY.md updates + Jira ticket comments instead. Once Phase 3 is live, registry lookups replace ad-hoc memory updates.
- **Discrete unit definition** for fixer/implementer is "one Jira issue transitioned In Review" (matches CPT-74 parent ticket). Branch-push alone is not the boundary — the Jira transition IS.
- **Context measurement** is advisory — Claude Code exposes `/status` but no env var for in-line percentage. Eyeball the `/status` output; err on the side of `/compact` rather than running hot.
- **Override**: if an active multi-step operation is in flight and clearing would lose ground, skip this cycle's context action and pick it up at the next cycle's start. The thresholds are guides, not hard gates.
