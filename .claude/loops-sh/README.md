# `.claude/loops-sh/` — shell-loop drivers for polling roles

## What this is

Per-role shell wrappers that drive the 8 polling roles (master, triager, reviewer, merger, chk1, chk2, fixer, implementer) via `claude -p` (headless) instead of an in-session `/loop`. Each iteration is a **fresh process** so context exhaustion is structurally impossible.

Tracked by **CPT-42** (epic CPT-3). Superseded CPT-41's in-session loop for polling roles — CPT-41 still drives planner/performance/playtester and any role explicitly configured `driver: "session"`.

## Shell vs session driver

| driver  | When to pick                                                  | What happens                                                                    |
|---------|---------------------------------------------------------------|----------------------------------------------------------------------------------|
| `shell` | Polling role with long-running unattended operation.          | `<project>-<role>-loop` tmux session runs `.claude/loops-sh/<role>.sh`.          |
| `session` | Role needs interactive TUI (human drop-in) or subagent-heavy flows that benefit from warm context within a run. | Legacy CPT-41 path: iTerm2 tab with `claude` interactive + `/loop N m <prompt>`. |
| `none`  | Role exists on disk but is not currently polling.             | `/project:launch` skips it. Equivalent to `intervalMinutes: 0`.                  |

The `shell` driver is the recommended default for all 8 polling roles. It is the only option that cannot corrupt itself on a long horizon.

### Why the shell driver matters

In-session `/loop`s accumulate context every iteration. At ~95% they auto-compact (lossy) or overflow (fails). See upstream issues anthropics/claude-code#19877, #20267, #16659 — all open. Shell-loop driver sidesteps this entirely: every iteration starts cold, reads state from `.claude/state/<role>.md`, does its work, writes state back, exits. No context window to exhaust.

## Files

```
.claude/loops-sh/
  _lib.sh        # Shared helpers: acquire_lock, release_lock, log, render_prompt, heartbeat
  master.sh      # Role wrappers — one per polling role
  triager.sh
  reviewer.sh
  merger.sh
  chk1.sh
  chk2.sh
  fixer.sh
  implementer.sh
  README.md      # This file
```

Runtime artefacts (created on first run, not checked in):

```
.claude/locks/<role>.lock         # flock file — prevents double-start
.claude/locks/<role>.lock.pid     # current holder's PID
.claude/logs/<role>.log            # structured per-iteration log
.claude/state/<role>.md            # state handoff — the only durable memory
.claude/state/<role>.heartbeat.json # {role,lastIteration,lastExitCode,pid} for /project:status
```

## State-handoff contract

`.claude/state/<role>.md` is the single source of handoff between iterations. Each loop prompt **must** instruct the model to read it on entry and overwrite it before exit.

```markdown
---
role: triager
lastIteration: 2026-04-17T02:15:00Z
iterationCount: 147
lastSeenJiraUpdate: 2026-04-17T02:12:03Z
lastSeenGitSha: 7386b42
---

## Open work
- CPT-123: waiting on detail from implementer (asked 2026-04-13)
- CPT-124: approved, moved to Ready for Coding

## Running notes
<free-form role-specific context the next iteration needs>
```

The loop prompt at `.claude/loops/<role>.md` gets the state-file path via the `{{STATE_FILE}}` placeholder, substituted by `render_prompt` in `_lib.sh`.

## Running a wrapper manually

```bash
./.claude/loops-sh/triager.sh        # runs in foreground; ^C to stop
```

The wrapper:

1. Reads `intervalMinutes` from `.loops.<role>.intervalMinutes` in `PROJECT_CONFIG.json`. If `0`, exits cleanly.
2. Acquires `flock` on `.claude/locks/<role>.lock`. If held by another process, logs and exits with code 1 (AC #2).
3. Traps EXIT to release the lock.
4. Enters `while true` — each iteration:
   - `claude --dangerously-skip-permissions --append-system-prompt <.claude/sessions/<role>.md> -p <rendered prompt>`.
   - Writes heartbeat JSON regardless of exit code.
   - Logs success or failure; `|| continue` never drops out of the outer loop (AC #13).
5. Sleeps `intervalMinutes * 60` seconds between iterations.

`/project:launch` does this automatically under tmux; manual invocation is for debugging.

## Debugging a stuck loop

```bash
# What's currently running?
cat .claude/locks/triager.lock.pid
ps -p "$(cat .claude/locks/triager.lock.pid)" -o pid,etime,command

# Recent iteration activity
tail -n 100 .claude/logs/triager.log

# Current heartbeat
cat .claude/state/triager.heartbeat.json | jq .

# Inspect tmux session (if launched via /project:launch)
tmux attach -t "$(basename "$(git rev-parse --show-toplevel)")-triager-loop"
```

**Staleness detection:** `/project:status` flags a role as stale if its heartbeat is older than `3 × intervalMinutes`. That's usually the first signal that a loop has deadlocked on something network-side or gone into a tight-retry spiral.

**Common root causes:**

- `claude` CLI update changed a flag — check `claude --help` and the command the wrapper builds.
- `--append-system-prompt` file missing — fallback emits a minimal role string so the loop continues, but iterations won't have role identity.
- `jq` missing from `PATH` — install via `brew install jq` / `apt install jq`.
- Another holder of the flock — another tmux session, a crashed process that leaked the pidfile, or two `/project:launch` invocations racing. `rm .claude/locks/<role>.lock*` after verifying no live PID.

## Permissions & tool scoping

`--dangerously-skip-permissions` is in use because the wrapper **is** the trust boundary. Per-role tool allowlisting must be enforced via `--allowed-tools` sourced from `.sessions.<role>.allowedTools` in `PROJECT_CONFIG.json` (AC #8). The `claude` invocation in each wrapper reads that list at launch time.

## Rollout status

- **Phase 1** (this change): wrapper scaffolding, `_lib.sh`, config schema extended, validator updated, `/project:config|launch|status` wired. **Default driver: `session`** — no behaviour change yet.
- **Phase 2** (pilot): triager flipped to `driver: "shell"` in this change as AC #12 pilot. 7 days of green heartbeats required before widening.
- **Phase 3**: reviewer, merger, fixer, implementer flipped.
- **Phase 4**: chk1, chk2 flipped.
- **Phase 5**: master flipped last. Drop-in query access restored via follow-up `master-repl.sh` if the handoff proves lossy.

## Related

- Spec: CPT-42 (this ticket).
- Config foundations: CPT-40 (ship schema), CPT-41 (launch integration).
- Open upstream issues on in-session context exhaustion: anthropics/claude-code#19877, #20267, #16659, #12665, #31220, #45627, #47861.
