# Progress registry (CPT-74 Phase 3)

Jira-native per-role progress tracker. Replaces the ad-hoc `MEMORY.md` / `CHANGELOG.md` file-based pattern with a structured, queryable, multi-machine-friendly surface that every role writes to at the end of each `/loop` cycle.

**Phase 3.0 (this version)** ships the helper library + schema + docs only. No Jira tickets are created. Phase 3.1 (follow-up) adds the bootstrap script that creates the real tickets and the rollover machinery. Phase 3.2 wires `/project:audit` and per-role `loops/loop.md` so every cycle reads and writes via MCP.

## Topology

```
CPT-3 (Epic: choc-skills)
 ├── Session Progress Registry   (pinned task; description = JSON registry doc)
 ├── Progress: master #1          (child task; holds master's cycle comments)
 ├── Progress: master #2          (created on rollover from #1)
 ├── Progress: planner #1
 ├── Progress: implementer #1
 └── ... one per loop-capable role; rolled when thresholds exceeded
```

The **registry ticket's description** contains a fenced `json` code block with the canonical registry document. Roles read this on every cycle to discover their active progress ticket; roles write to it on rollover.

## Registry document shape

See `skills/project/schemas/progress-registry.schema.json` for the authoritative JSON Schema. Canonical example:

```json
{
  "version": 1,
  "lastUpdated": "2026-04-17T02:30:00Z",
  "roles": {
    "master":      { "currentProgressTicket": "CPT-90", "archivedTickets": [],           "cycleCount": 12, "lastCycleAt": "2026-04-17T02:28:00Z" },
    "planner":     { "currentProgressTicket": "CPT-91", "archivedTickets": [],           "cycleCount": 0,  "lastCycleAt": null },
    "implementer": { "currentProgressTicket": "CPT-92", "archivedTickets": [],           "cycleCount": 3,  "lastCycleAt": "2026-04-17T02:20:00Z" },
    "fixer":       { "currentProgressTicket": "CPT-93", "archivedTickets": [],           "cycleCount": 0,  "lastCycleAt": null },
    "merger":      { "currentProgressTicket": "CPT-94", "archivedTickets": [],           "cycleCount": 1,  "lastCycleAt": "2026-04-17T02:10:00Z" },
    "chk1":        { "currentProgressTicket": "CPT-95", "archivedTickets": [],           "cycleCount": 0,  "lastCycleAt": null },
    "chk2":        { "currentProgressTicket": "CPT-96", "archivedTickets": [],           "cycleCount": 0,  "lastCycleAt": null },
    "performance": { "currentProgressTicket": "CPT-97", "archivedTickets": [],           "cycleCount": 0,  "lastCycleAt": null },
    "playtester":  { "currentProgressTicket": "CPT-98", "archivedTickets": [],           "cycleCount": 0,  "lastCycleAt": null },
    "reviewer":    { "currentProgressTicket": "CPT-99", "archivedTickets": [],           "cycleCount": 2,  "lastCycleAt": "2026-04-17T02:15:00Z" },
    "triager":     { "currentProgressTicket": "CPT-100","archivedTickets": [],           "cycleCount": 4,  "lastCycleAt": "2026-04-17T02:25:00Z" }
  }
}
```

## Read pattern (Step 0 of each loop cycle)

At the start of every `/loop` tick a role:

1. Calls `getJiraIssue` (Atlassian MCP) on the pinned registry ticket. Passes the description through `registry_extract_json` to recover the JSON.
2. Calls `registry_validate_json` — hard-fails if the shape has drifted (guards against someone hand-editing the registry with bad JSON).
3. Calls `registry_get_role_ticket "$json" "<my-role>"` to look up the active progress ticket.
4. Calls `getJiraIssue` on that progress ticket and reads the latest 1–3 comments (ordered by `created` desc). The most recent comment is "the state I ended my last cycle in".
5. Proceeds with the cycle's work.

## Write pattern (end of each loop cycle)

Before sleeping to the next tick, the role:

1. Measures the current progress ticket's size (description bytes + sum of comment bodies + comment count). These come from `getJiraIssue` + a `search`/comment-count call.
2. Calls `registry_needs_rollover "$bytes" "$comments"`. If true → **rollover** (Phase 3.1 adds this):
   - `createJiraIssue` with summary from `registry_new_ticket_summary` and parent = CPT-3.
   - Atomic registry update: swap `currentProgressTicket` to the new key and append the old key to `archivedTickets`. Uses Jira's version field for optimistic locking; retries up to N=3 on version mismatch.
3. Writes the cycle comment via `registry_format_cycle_comment` + `addCommentToJiraIssue`.
4. Bumps `roles.<self>.cycleCount` and updates `roles.<self>.lastCycleAt` in the registry description.

## Rollover thresholds

Initial values baked into `_progress-registry.sh` (overridable via env):

| Variable                         | Default | Meaning |
|----------------------------------|---------|---------|
| `REGISTRY_ROLLOVER_MAX_BYTES`    | 512000  | Rollover when combined description + comment bytes exceed 500 KB. |
| `REGISTRY_ROLLOVER_MAX_COMMENTS` | 300     | Rollover when comment count exceeds 300. |

Semantics: **strict-greater-than** (boundary values do NOT trigger). This matches CPT-74 §3.3 ("Roll when EITHER cap is hit" — "hit" here means "exceeded"). Phase 3.1 will measure Jira UI/API latency at 100 / 300 / 500 / 1000 comments and tune the defaults empirically.

## Relationship to MEMORY.md

Both coexist:

- **MEMORY.md** is for **cross-session durable facts**: user identity, feedback rules, project context, shipped-ticket index. Changes rarely; loaded automatically into every role's context.
- **Progress registry** is for **tactical per-cycle state**: what the role just did, what's in flight, when the next cycle is scheduled. Changes on every tick; read via MCP at cycle start.

Rule of thumb: if a fact matters to a future session or role that isn't you, it goes in MEMORY.md. If it only matters to your next-cycle-self, it goes in your progress comment.

## Using the helpers from a loop cycle

In Phase 3.2 the per-role `loops/loop.md` will instruct the model to source `_progress-registry.sh` (installed at `~/.local/bin/_progress-registry.sh`) and compose Bash calls around MCP reads/writes. Until Phase 3.2 lands, the helpers are callable but unused at runtime — they serve Phase 3.1's bootstrap script and Phase 3.2's wiring layer.

## Helpers summary

| Function                             | Side-effect-free? | Purpose |
|--------------------------------------|-------------------|---------|
| `registry_extract_json <desc>`       | Yes               | Pull the JSON block out of a Jira description. |
| `registry_validate_json <json>`      | Yes (needs python3+jsonschema) | Validate registry shape against the schema. |
| `registry_get_role_ticket <json> <r>`| Yes (needs jq)    | Return active progress ticket for role `r`. |
| `registry_format_cycle_comment …`    | Yes               | Format the structured cycle-comment body. |
| `registry_needs_rollover <b> <c>`    | Yes               | Should we rollover? Strict-greater thresholds. |
| `registry_new_ticket_summary <r> <n>`| Yes               | Format new rolled ticket summary. |

## Out of Phase 3.0 scope

- **Bootstrap script** (`scripts/init-progress-registry.sh`) that actually creates the 12 Jira tickets. Phase 3.1.
- **Rollover execution** — the helpers compute "should roll?" locally; actual createJiraIssue + registry-update round-trip is Phase 3.1.
- **Optimistic-locking retry** on concurrent registry writes. Phase 3.1.
- **Per-role `loops/loop.md` wiring** that makes every cycle read/write via MCP. Phase 3.2.
- **`/project:audit` check #17** — verifies the registry + all 11 progress tickets exist and are reachable. Phase 3.2.
- **Rate-limit mitigation** — cache registry JSON with a 60 s TTL, batch where possible. Phase 3.1 / 3.2 empirical.
- **Local-file fallback** when Jira is unreachable. Phase 3.2.
- **Archival status for rolled tickets** — "Done" label vs new status vs pure-array tracking. Deferred to Phase 3.1 based on Jira admin input.
