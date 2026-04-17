# Changelog — rr

All notable changes to the rr skill will be documented in this file.

## [5.3.24] - 2026-04-18

### Fixed
- **`/rr remove` and `/rr board` auth lines no longer tool-denied under CPT-32 enforcement** (CPT-146). CPT-102 correctly swapped `echo -n "$JIRA_EMAIL:$JIRA_API_KEY" | base64` for `printf '%s' ...` in four call sites across `commands/remove.md` (three — lines 49, 96, 164) and `commands/board.md` (one — line 168) to close the ps-aux credential leak. The security fix is correct, but neither file's `allowed-tools` frontmatter was extended: `printf` / `tr` / `wc` (remove.md) and `printf` / `base64` / `tr` / `cat` (board.md) were denied. Under per-command enforcement the auth line fails at first probe and every mode of `/rr remove` plus the `JIRA_EMAIL`/`JIRA_API_KEY` fallback path of `/rr board` got tool-denied — same fix-introduces-new-silent-failure pattern as CPT-101 → CPT-136 → this. Added the missing `Bash(<tool> *)` patterns to both frontmatters. Regression guards in `tests/rr-command-shell-tool-coverage.bats` (new file, 7 tests): per-file sentinels for each missing tool, plus a generic cross-check that any `rr/commands/*.md` using `printf` in its body must whitelist `Bash(printf *)` (or carry the wider `Bash(bash *)` catch-all).

**Note on version renumbering**: This entry originally targeted 5.3.23 on `fix/CPT-146-rr-printf-base64-tr-allowed-tools`, but CPT-143 landed on `main` first and claimed 5.3.23. Renumbered to 5.3.24 as part of the merge sequence; no code semantics changed from the original branch.

## [5.3.23] - 2026-04-18

### Fixed
- **Agent Orchestrator Mode now carries the CPT-133 per-phase compaction re-check** (CPT-143). CPT-133 added per-phase compaction re-checks to `skills/rr/commands/all.md` but only inside the Sequential Mode section. The default `/rr all` path — Agent Orchestrator Mode, activated whenever `~/.claude/skills/rr/bin/rr-prepare.sh` is executable and `JIRA_EMAIL` + `JIRA_API_KEY` are set (the entire documented batch-mode prerequisite) — is driven by `skills/rr/bin/sub-agent-prompt.md`, which CPT-133 never touched. The re-check instructions did not reach the actual execution path; the CPT-91 compaction degradation pattern continued unabated for every user with the standard setup. Mirrored the full six-phase per-phase re-check protocol into `sub-agent-prompt.md`: before each step-file-backed phase, recall a known heading from `step-1-extract.md` / `step-2-adversarial.md` / `step-3-rectify.md` / `step-5-finalise.md` / `step-6-publish.md`; re-read on miss; emit `pre-load recovered by re-read: <step-name>` to the log so per-phase drift is observable. Step 4 has no pre-loaded file (batch-mode-only logic) and has no re-check. Step 6 is retained for parity with Sequential Mode even though sub-agents don't publish directly (Phase 6 runs in the orchestrator via `rr-finalize.sh` + `_publish_one.sh`). Two bats regressions in `tests/rr-all-per-phase-recheck.bats` now enforce the same invariants on `sub-agent-prompt.md` as on `commands/all.md`: all 5 step files referenced in a verify/re-check/recall context, and the log line is step-annotated.

**Note on version renumbering**: This entry originally targeted 5.3.22 on `fix/CPT-143-sub-agent-prompt-per-phase-recheck`, but CPT-140 landed on `main` first and claimed 5.3.22. Renumbered to 5.3.23 as part of the merge sequence; no code semantics changed from the original branch.

## [5.3.22] - 2026-04-18

### Fixed
- **`_publish_one.sh` EXIT trap no longer clobbers lock cleanup** (CPT-140, regression 1). CPT-118 added `trap 'rm -f "$attempt_headers"' EXIT` for the headers tempfile without realizing each `trap ... EXIT` call REPLACES the previous handler under bash semantics. The lock-cleanup trap installed near the top of the script was silently overridden — every batch publish from `rr-finalize.sh` (which exports `LOCK_DIR`) leaked `$LOCK_DIR/${risk_key}.lock`, and subsequent runs hit the `ALREADY_PUBLISHING` early-return for every already-attempted risk until someone manually removed the lock directory. Replaced both traps with a single unified `_cleanup` function that removes both resources, registered once with `trap _cleanup EXIT`. The `attempt_headers` variable is declared empty up-front so the guard is correct even if the script exits before the mktemp runs.
- **`_publish_one.sh` Retry-After grep pipeline no longer aborts under `set -e pipefail` when the header is absent** (CPT-140, regression 2). The CPT-118 pipeline `grep -iE '^Retry-After:' | tail -1 | sed ...` was unguarded. When the response had no Retry-After header (common for 503/529, many 429), grep exited 1, pipefail propagated it as the pipeline's exit code, command substitution returned 1, and `set -e` aborted the worker before the `.retryAfter` body fallback or exponential-backoff path could run. Added `|| true` at the end of the pipeline so the missing-header case leaves `retry_after_header` empty and the fallback chain runs as designed. Three bats regressions in `tests/rr-publish-retry-after.bats` enforce: single EXIT trap (at most one `trap ... EXIT` in the script), unified `_cleanup` function references both `LOCK_DIR` and `attempt_headers`, and the `retry_after_header=$(...)` assignment contains `|| true`.

## [5.3.21] - 2026-04-18

### Fixed
- **`_update_cpt.sh` and `rr-finalize.sh` direct-path invocations now whitelisted in per-command frontmatter** (CPT-128). CPT-97 (v5.3.6) extended `rr:all` allowed-tools with the direct-path patterns for `rr-prepare.sh` and `rr-finalize.sh` but missed `_update_cpt.sh`, even though `rr:all` invokes it from three code paths (Agent-orchestrator `dispatch_progress`, sequential `started`, sequential `complete`). All three invocations end with `|| true`, so failures don't crash the main flow — they silently suppress CPT-1 progress tracking. Verified the same class of defect in `rr:board` (calls `_update_cpt.sh` after board-paper publish) and `rr:fix` (calls `rr-finalize.sh` after retry loop). Added the missing `Bash(~/.claude/skills/rr/bin/<script>.sh *)` patterns to all three. `doctor.md`'s references are `ls <path>` existence checks, already covered by `Bash(ls *)` — no change needed. Added a generic bats cross-check (`tests/router-allowed-tools.bats`): for every `rr/commands/*.md`, grep the body for `~/.claude/skills/rr/bin/<script>.sh` invocations (excluding `ls <path>` existence checks) and assert each one has a matching `Bash(<path> *)` entry in the frontmatter allowed-tools line. Pre-fix flagged `all.md:_update_cpt.sh`, `board.md:_update_cpt.sh`, `fix.md:rr-finalize.sh`; post-fix clean.

## [5.3.20] - 2026-04-18

### Fixed
- **`rr:update` `Bash(bash install.sh *)` pattern widened for consistency** (CPT-119). The rr:update body instructs direct execution (`<repo-path>/install.sh --force`) rather than `bash <path>/install.sh`, so the narrow pattern was not a live defect on rr. Widened to `Bash(bash *install.sh *)` to keep all three per-skill update commands on the same pattern and future-proof against an edit that re-introduces `bash <abs-path>/install.sh` invocation. Same fix applied across chk1:update, chk2:update, rr:update.

**Note on version renumbering**: This entry originally targeted 5.3.19 on `fix/CPT-119-bash-install-sh-pattern`, but CPT-103 (MCP call-spec preamble) landed on `main` and claimed 5.3.19 first. Renumbered to 5.3.20 as part of the merge sequence; no code semantics changed from the original branch.

## [5.3.19] - 2026-04-18

### Fixed
- **MCP call-spec `$JIRA_CLOUD_ID` now reliably substituted**: CPT-27 (v5.2.7) replaced hardcoded Atlassian Cloud IDs with `$JIRA_CLOUD_ID` across rr references — correct in shell contexts but broken in MCP call specs embedded in markdown (the MCP layer does not expand shell variables, so Claude could pass the literal `"$JIRA_CLOUD_ID"` as the `cloudId` parameter and Atlassian would reject it as an invalid UUID). Added an "IMPORTANT: MCP call-spec variable substitution" preamble to every rr file using the pattern (`references/jira-config.md`, `references/matter-jira-config.md`, `references/workflow/step-1-extract.md`, `references/workflow/step-6-publish.md`, `commands/board.md`) explicitly directing Claude to substitute the env var value before calling the MCP tool. Shell contexts untouched — `$JIRA_CLOUD_ID` continues to expand as before in bin scripts and doctor output (CPT-103).

**Note on version renumbering**: This entry originally targeted 5.3.17 on `fix/CPT-103-mcp-cloudid-preamble`, but CPT-102 (credential-leak) and CPT-137 (nested first-run) landed on `main` and claimed 5.3.17 / 5.3.18 first. Renumbered to 5.3.19 as part of the merge sequence; no code semantics changed from the original branch.

## [5.3.18] - 2026-04-18

### Fixed
- **Nested first-run `RR_WORK_DIR` now works** (`rr-prepare.sh`, `rr-finalize.sh`): CPT-100 canonicalized only the immediate parent of `WORK_DIR`, which handled the default `$HOME/rr-work` case but not nested paths like `$HOME/new/subdir/rr-work` where intermediate segments are also missing on first run. In that case `dirname` returned a non-existent directory, the `[ -d ]` gate skipped the realpath step, and the script FATALed with the same path-allowlist message CPT-100 was written to fix. Replaced the single-level `dirname` with a walk-up loop (`_rr_resolve_work_dir_with_missing_tail` helper) that probes upward until an existing ancestor is found, canonicalizes that, and recombines the missing tail. Applied identically in both scripts; handles any depth of missing segments (CPT-137).

**Note on version renumbering**: This entry originally targeted 5.3.17 on `fix/CPT-137-rr-nested-first-run`, but CPT-102 (credential-leak completion) landed on `main` and claimed 5.3.17 first. Renumbered to 5.3.18 as part of the merge sequence; no code semantics changed from the original branch.

## [5.3.17] - 2026-04-18

### Security
- **Credential-leak fix completed across `/rr` user surfaces** (`commands/remove.md`, `commands/board.md`): CPT-28 (v5.2.8) replaced `echo -n "$JIRA_EMAIL:$JIRA_API_KEY" | base64` with `printf '%s'` in `rr-prepare.sh`, `rr-finalize.sh`, and `_update_cpt.sh` to keep Basic-auth credentials off `ps aux`. Four call sites in `commands/*.md` were missed (3 in `remove.md`, 1 in `board.md`) — the exact same exploit class in different files, reachable via `/rr remove` and `/rr board` subcommands. Replaced all four with `printf '%s'`. Extended the regression test (`tests/rr-commands-no-credential-echo.bats`) to scan `commands/*.md` in addition to `bin/*.sh`, so future additions of the same shell base64-auth pattern are caught on both surfaces. Also added an `ra/` audit-scope test for the same pattern (CPT-102).

## [5.3.16] - 2026-04-18

### Fixed
- **Per-phase compaction re-check in `rr:all` batch mode**: CPT-91 added a compaction-aware re-check to the per-risk loop but it verified only `step-1-extract.md` at the start of each risk, then used all five pre-loaded step files. Compaction can evict step-2/3/5/6 while leaving step-1 retrievable (single-file heuristic passes, later phases execute with missing instructions) and can happen mid-workflow between Step 2 and Step 5 (check-at-start misses it). Moved the re-check inside each of the five step-file-backed phases: before each phase, recall a known heading from that phase's step file and re-read on miss. Log entry is now annotated — `pre-load recovered by re-read: <step-name>` — so per-phase degradation is observable. Step 4 (Discussion) has no pre-loaded file in batch mode, so no re-check there (CPT-133, concerns 1+2).
- **Duplicate `3.` in Process Each Risk numbered list**: inserting the compaction re-check step in CPT-91 didn't renumber subsequent items, leaving two `3.` items (execute workflow, update progress file). Markdown auto-renumbers on render but raw text carried the bug. Renumbered correctly as part of the per-phase restructure above (CPT-133, concern 3).

**Note on version renumbering**: This entry originally targeted 5.3.15 on `fix/CPT-133-rr-per-phase-compaction-recheck`, but CPT-123 (conflicting-flag detection) landed on `main` and claimed 5.3.15 first. Renumbered to 5.3.16 as part of the merge sequence; no code semantics changed from the original branch.

## [5.3.15] - 2026-04-18

### Fixed
- **Conflicting action flags in `install.sh` now die at parse time** (CPT-123): see the chk1 entry for the full write-up. Same fix, applied identically to rr's per-skill installer.

**Note on version renumbering**: This entry originally targeted 5.3.14 on `fix/CPT-123-installer-conflict-detection`, but CPT-118 (Retry-After header) landed on `main` and claimed 5.3.14 first. Renumbered to 5.3.15 as part of the merge sequence; no code semantics changed from the original branch.

## [5.3.14] - 2026-04-17

### Fixed
- **Retry-After header actually honoured now** (`skills/rr/bin/_publish_one.sh`): CPT-33 (v5.3.4) claimed to honour the `Retry-After` header on 429/503/529 retries but only read a `.retryAfter` JSON body field via jq. Jira sends rate-limit hints in the HTTP response header (RFC 7231 §7.1.3), so the body lookup returned empty and the code silently fell back to 2/4/8s exponential backoff — under parallel `xargs -P` workers against a throttled Jira endpoint, the ignored server-mandated delay caused premature `MAX_PUBLISH_RETRIES` exhaustion. Fixed: the curl POST now writes headers to a tempfile via `-D`, the 429/503/529 arm parses `Retry-After:` case-insensitively (last-occurrence wins per RFC §4), accepts bare-integer seconds, falls back to body `.retryAfter` (kept as secondary for API variants that return it there), then to exp backoff. The CPT-33 CHANGELOG wording ("Honours `Retry-After` header when present") is now accurate rather than aspirational (CPT-118).

## [5.3.13] - 2026-04-17

### Fixed
- **`/rr status` progress totals missing** (`skills/rr/commands/status.md`): CPT-32's per-command frontmatter declared only `Read, Bash(ls *), Bash(tail *)` but the command body uses `echo`, `wc`, and `tr` in four `echo "Results: $(ls … | wc -l | tr -d ' ')"` counter lines. Under enforcement those three commands were denied, so users saw the recent log tail but lost the most-useful published/failed/results section. Added `Bash(echo *), Bash(wc *), Bash(tr *)` to `allowed-tools` (CPT-111).
- **`/rr update` security-scope consistency** (`skills/rr/commands/update.md`): frontmatter carried the wide `Bash(bash *)` pattern while the sibling `/chk2 update` uses scoped `Bash(bash install.sh *)`. Narrowed rr:update to match chk2:update, preserving CPT-25's "no unscoped bash" intent. No behavioural change to the update flow (the body already uses `bash install.sh --force` and direct `install.sh` paths, both of which are still covered) (CPT-111).

**Note on version renumbering**: This entry originally targeted 5.3.12 on `fix/CPT-111-rr-status-update-allowed-tools`, but CPT-100 (rr symlink-first-run fix) landed on `main` and claimed 5.3.12 first. Renumbered to 5.3.13 as part of the merge sequence; no code semantics changed from the original branch.

## [5.3.12] - 2026-04-17

### Fixed
- **First-run on symlinked `$HOME` no longer FATALs** (`rr-prepare.sh`, `rr-finalize.sh`): CPT-26's path allowlist canonicalized `$HOME` eagerly but gated `WORK_DIR` canonicalization on `[ -e "$WORK_DIR" ]`. On hosts where `$HOME` has a distinct canonical form (macOS `/var/folders/...` → `/private/var/folders/...`, autofs mounts, firmlinked network homes), a first-time user's `$HOME/rr-work` stayed unresolved while `RESOLVED_HOME` was canonical, so the case guard never matched and the script aborted with `FATAL: RR_WORK_DIR must be under $HOME or /tmp`. Both scripts now canonicalize the **parent directory** of `WORK_DIR` when `WORK_DIR` itself doesn't exist yet, preserving CPT-26's symlink-traversal protection while letting first-run users through (CPT-100).

## [5.3.11] - 2026-04-17

### Fixed
- **Honest scoping for pre-load optimization**: CPT-9's pre-load optimization claimed to eliminate 6×(N-1) redundant reads but assumed pre-loaded content stayed in context across all N risks. Under Claude Code auto-compaction the content can be summarised or dropped silently, causing per-risk steps to execute against a stale/empty view. `commands/all.md` now (1) documents the auto-compaction limitation in the pre-load section, (2) adds a per-risk re-check step that verifies a known heading is still retrievable and re-reads on miss, logging "pre-load recovered by re-read" for observability, (3) scopes the savings claim to per-session rather than per-register (CPT-91).

## [5.3.10] - 2026-04-17

### Fixed
- **P1 regression**: `/rr update` and `/rr all --reset` direct script invocations (`./install.sh --force`, `~/.claude/skills/rr/bin/rr-prepare.sh --reset`, `~/.claude/skills/rr/bin/rr-finalize.sh ...`) previously required `Bash(bash *)` coverage but CPT-25 removed that in favour of direct invocation — without adding matching path patterns. Added `Bash(*/install.sh *)` and `Bash(./install.sh *)` to `commands/update.md`, and `Bash(~/.claude/skills/rr/bin/rr-prepare.sh *)` + `Bash(~/.claude/skills/rr/bin/rr-finalize.sh *)` to `commands/all.md`. Least-privilege per-sub-command; no change to SKILL.md router. (CPT-97)

## [5.3.9] - 2026-04-17

### Fixed
- **Exit-code contract**: `install.sh --check` now exits non-zero when issues are reported (was unconditional `exit 0`). Aligns with root `install.sh --check` behavior (CPT-77).

### Note on version renumbering
- CPT-77 source branch targeted 5.3.7; both 5.3.7 (CPT-117) and 5.3.8 (CPT-76) shipped earlier this cycle. Renumbered to 5.3.9.

## [5.3.8] - 2026-04-17

### Fixed
- **Argument parsing**: `install.sh` now uses an order-independent while-loop parser instead of positional `$1` checks. `-f --uninstall` (and other flag combinations) now uninstalls instead of silently re-installing. Unknown flags now exit non-zero (CPT-76).

### Note on version renumbering
- CPT-76's source branch bumped 5.3.6 → 5.3.7 in isolation. By merge time, 5.3.7 (CPT-117) had already shipped, so the Merger renumbered CPT-76 to 5.3.8. No code semantics changed.

## [5.3.7] - 2026-04-17

### Fixed
- **P1 regression**: `rr-prepare.sh` `phase_filter` referenced undefined `$reviews_tmpfile` (typo of `$tmp_reviews`) introduced by CPT-35. Under `set -euo pipefail` every `/rr all` invocation aborted at phase 2. Root cause was a dead-code block that computed an unused `all_reviews` aggregate; the block has been removed entirely. The subsequent `$tmp_reviews` consumer (lines 300-304) was always the only real consumer. Also clears two CI-breaking ShellCheck warnings (SC2154, SC2034) introduced by the same block (CPT-117).

## [5.3.6] - 2026-04-17

### Changed
- **Performance**: Shell fork waste eliminated across `install.sh`, `bin/_publish_one.sh`, and `bin/rr-finalize.sh` — redundant `shasum` after `cmp -s`, `$(cat file)` → `$(< file)`, `ls | wc | tr` → glob-array `${#arr[@]}`. Net ~10 forks saved per batch invocation (CPT-20).

### Note on version renumbering
- CPT-20's source branch bumped 5.2.1 → 5.2.2 in isolation. By merge time, 5.2.2–5.3.5 had all shipped, so the Merger renumbered CPT-20 to 5.3.6. No code semantics changed.

## [5.3.5] - 2026-04-17

### Changed
- **Performance**: `rr-prepare.sh` pagination loops in `phase_discovery` and `phase_filter` no longer re-parse accumulated JSON on each page. Each page appends its `.issues[]` to a temp file, then a single `jq -s 'add'` combines them. Reduces work from O(p×n) to O(n) on multi-page Jira responses (CPT-35).

### Fixed
- `phase_filter` temp file now cleaned up via `trap 'rm -f … ' RETURN` (was relying on explicit `rm -f` after the loop, which could leak the file on early exit) (CPT-35).

### Note on version renumbering
- CPT-35's source branch bumped 5.2.1 → 5.2.2 in isolation. By merge time, 5.2.2–5.3.4 had all shipped, so the Merger renumbered CPT-35 to 5.3.5. No code semantics changed.

## [5.3.4] - 2026-04-17

### Changed
- **Performance**: `_publish_one.sh` and `_update_cpt.sh` now use exponential backoff with random jitter on HTTP 429/503/529 retries instead of linear `attempt * 10` sleeps. Prevents thundering-herd retries under `xargs -P 10` parallel Jira publishing. Honours `Retry-After` header when present (CPT-33).

### Note on version renumbering
- CPT-33's source branch bumped 5.2.1 → 5.2.2 in isolation. By merge time, 5.2.2–5.3.3 had all shipped, so the Merger renumbered CPT-33 to 5.3.4. No code semantics changed.

## [5.3.3] - 2026-04-17

### Changed
- **Performance**: `monitor.py` and `monitor_server.py` read `batch.log` once per refresh cycle and cache directory listings instead of re-reading for each helper. Reduces I/O from ~120 reads/minute to ~30 on `monitor.py`, and from 4+ reads per HTTP request to 1 on `monitor_server.py` (CPT-31).

### Note on version renumbering
- CPT-31's source branch bumped 5.2.1 → 5.2.2 in isolation. By merge time, 5.2.2–5.3.2 had all shipped, so the Merger renumbered CPT-31 to 5.3.3. No code semantics changed.

## [5.3.2] - 2026-04-17

### Changed
- **Performance**: `review.md` marks reference files as already-in-context for downstream step files, avoiding redundant reads (CPT-19).

### Note on version renumbering
- CPT-19's source branch bumped 5.2.1 → 5.2.2 in isolation. By merge time, 5.2.2–5.3.1 had all shipped, so the Merger renumbered CPT-19 to 5.3.2. No code semantics changed.

## [5.3.1] - 2026-04-17

### Fixed
- `log()` in `rr-prepare.sh` and `rr-finalize.sh` no longer produces `tee` errors when `WORK_DIR` doesn't exist; gracefully falls back to stderr-only logging (CPT-38).

### Note on version renumbering
- CPT-38's source branch bumped 5.2.1 → 5.2.2 in isolation. By merge time, 5.2.2–5.3.0 had all shipped, so the Merger renumbered CPT-38 to 5.3.1. No code semantics changed.

## [5.3.0] - 2026-04-17

### Changed
- **Performance/Security**: Reduced SKILL.md router `allowed-tools` from 33 entries to 5 (`Read, Grep, Glob, Bash(ls *), AskUserQuestion`) (CPT-32).
- Added YAML frontmatter with per-command `allowed-tools` to all 11 sub-command files.
- Each sub-command now declares only the tools it actually needs (e.g., `review.md` gets WebSearch+Write+Agent, `help.md` gets only Read).

Note: MINOR bump (5.2.8 → 5.3.0) is the source branch's intended version and lands as-is — no renumber required.

## [5.2.8] - 2026-04-17

### Security
- Replaced `echo -n` with `printf '%s'` for credential encoding in `rr-prepare.sh`, `rr-finalize.sh`, and `_update_cpt.sh` to prevent credentials appearing in process list via `ps aux` (CPT-28).

### Note on version renumbering
- CPT-28's source branch bumped 5.2.1 → 5.2.2 in isolation. By merge time, 5.2.2–5.2.7 had all shipped, so the Merger renumbered CPT-28 to 5.2.8. No code semantics changed.

## [5.2.7] - 2026-04-17

### Security
- Replaced hardcoded Jira Cloud ID (27 occurrences) and Assignee Account ID (10 occurrences) across all rr files with `$JIRA_CLOUD_ID` and `$RR_ASSIGNEE_ID` environment variable references (CPT-27).
- `_publish_one.sh` now reads assignee from `$RR_ASSIGNEE_ID` env var and omits the assignee field if unset.
- `jira-ticket.schema.json` `const` constraints on `cloud_id` and `assignee_account_id` removed.
- Doctor check now verifies `JIRA_CLOUD_ID` is set and warns if `RR_ASSIGNEE_ID` is unset.

### Note on version renumbering
- CPT-27's source branch bumped 5.2.1 → 5.2.2 in isolation. By merge time, 5.2.2/5.2.3/5.2.4/5.2.5/5.2.6 had all shipped, so the Merger renumbered CPT-27 to 5.2.7. No code semantics changed.

## [5.2.6] - 2026-04-17

### Security
- Resolve symlinks before path validation in `rr-prepare.sh` and `rr-finalize.sh` to prevent symlink-traversal attacks on `rm -rf` (CPT-26). A symlink at `$HOME/rr-work` pointing outside allowed paths would previously pass the case check.
- Added the missing path validation (case guard) to `rr-finalize.sh` entirely.
- Updated `commands/all.md` `--reset` handler with the same symlink resolution and path validation.

### Note on version renumbering
- CPT-26's source branch bumped 5.2.1 → 5.2.2 in isolation. By merge time, 5.2.2/5.2.3/5.2.4/5.2.5 had already shipped, so the Merger renumbered CPT-26 to 5.2.6. No code semantics changed.

## [5.2.5] - 2026-04-17

### Security
- Removed 5 overly broad `allowed-tools` grants: `Bash(rm *)`, `Bash(bash *)`, `Bash(chmod *)`, `Bash(cp *)`, `Bash(xargs *)` (CPT-25).
- Updated `commands/all.md` `--reset` to delegate to `rr-prepare.sh --reset` (which has symlink validation) instead of raw `rm -rf`.
- Updated `commands/update.md` to use direct script execution instead of `bash` prefix.

### Note on version renumbering
- CPT-25's source branch bumped 5.2.1 → 5.2.2 in isolation. By merge time, 5.2.2/5.2.3/5.2.4 had already shipped, so the Merger renumbered CPT-25 to 5.2.5. No code semantics changed.

## [5.2.4] - 2026-04-17

### Fixed
- `/rr:remove` Mode 1 pagination loop now has a 100-page safety cap (10,000 tickets) to prevent infinite loops from malformed Jira `nextPageToken` responses. Warns if the cap is reached. (CPT-15)

### Note on version renumbering
- CPT-15's source branch bumped 5.2.1 → 5.2.2 in isolation. By merge time, 5.2.2 (CPT-9) and 5.2.3 (CPT-10) had already shipped to main with different changes, so the Merger renumbered CPT-15 to 5.2.4. No code semantics changed in renumbering.

## [5.2.3] - 2026-04-17

### Fixed
- **Performance**: Eliminated O(N×M) per-risk `grep` lookup in `phase_filter` — now uses a pure-bash space-delimited set + `case` pattern lookup (CPT-10).
- **Performance**: Consolidated repeated `jq` forks in `phase_discovery` and `phase_filter` pagination — streaming `jq -c '...' >> tmp` + final `jq -s` slurp instead of per-page re-parse (CPT-10).
- **macOS compatibility**: Bash 3.2-compatible string set replaces `declare -A` (bash 4+ only); restores the macOS-adapted contract advertised in the script header. Closes the regression flagged in Reviewer feedback during CPT-10 rework.
- Dropped the `| tr -d '"'` pipe from reviewed-parents extraction by switching `jq -s` to `jq -rs` (raw output) — eliminates one subprocess per invocation.

### Notes
- Pure-bash O(|set|) lookup replaces the associative-array O(1) lookup. At realistic register sizes (≲ hundreds of reviewed parents) wall-clock cost is indistinguishable; still eliminates the per-risk `grep` subprocess fork that was the original CPT-10 hotspot.
- `tests/rr-prepare-perf.bats` now pins bash-3.2 compatibility via anti-assertions on `declare -A`, `readarray`, and `mapfile`, plus a `/bin/bash -n` syntax-parse test.

## [5.2.2] - 2026-04-17

### Fixed
- Sequential mode: workflow step files (step-1 through step-6) are now pre-loaded once before the per-risk loop instead of re-read for every risk. Eliminates 6×(N-1) redundant file reads for a register of N risks. (CPT-9)

## [5.2.1] - 2026-04-12

### Fixed
- Cleaned up semantic text after orchestrator→bin rename: variable `ORCHESTRATOR_SOURCE` → `BIN_SOURCE`, health check messages, command file prose

## [5.2.0] - 2026-04-12

### Changed
- Renamed `orchestrator/` directory to `bin/` for consistency with repo-wide convention. All install paths, health checks, and references updated. No functional changes to scripts.

## [5.1.0] - 2026-04-09

### Changed
- **Security**: Restricted `Bash(*)` to 28 explicit command patterns
- **Security**: JIRA_AUTH no longer exported in environment — uses temp file with chmod 600
- **Security**: monitor_server.py bound to 127.0.0.1 (was 0.0.0.0), CORS restricted to localhost
- **Security**: board.md reads auth from `.jira-auth` file instead of `source ~/.zshenv`
- **Performance**: Replaced O(n²) jq-in-loop in phase_filter and phase_extraction with temp file + `jq -s`
- **Reliability**: Per-risk lockfile prevents duplicate Jira tickets during parallel publishing
- Credential validation now runs before work directory cleanup
- `--reset` validates directory contains batch.log before deleting
- CATEGORY_FILTER validated against known enum values
- RR_WORK_DIR validated to be under $HOME or /tmp
- `set -euo pipefail` in all orchestrator scripts (was `set -uo pipefail`)
- Added `board` route to SKILL.md routing table and install.sh router

### Fixed
- `eval curl` for attachments replaced with array-based approach
- monitor.py batch risk_count now handles dict format correctly
- `ls` without `2>/dev/null` in phase_publication
- Empty-risks guard added to phase_extraction
- Regulatory framework numbering uses correct array index
- Doctor checks all 9 orchestrator files (was 4)
- Help text file counts aligned with actual directory contents
- `_update_cpt.sh` now uses `set -uo pipefail`

## [5.0.0] - 2026-04-07

### Added
- Board paper generation: `/rr board` command for Board Risk Oversight Papers
- Board aggregation script (rr-board-aggregate.py) in orchestrator
- CPT-1 ticket update script (_update_cpt.sh) in orchestrator
- Web-based monitoring dashboard (monitor_server.py, monitor_dashboard.html)

### Changed
- Restricted Bash allowed-tools from wildcard to explicit command list
- Updated routing table to include `board` command
- Aligned version references across all files

### Fixed
- Doctor command now checks all orchestrator files including _publish_one.sh, _update_cpt.sh, rr-board-aggregate.py, monitor_server.py, monitor_dashboard.html

## [4.0.0] - 2026-04-03

### Added
- Complete rewrite: removed Anthropic API dependency, uses Claude Code agents exclusively
- Sub-command architecture: `/rr all`, `/rr review`, `/rr status`, `/rr monitor`, `/rr fix`, `/rr update`, `/rr help`, `/rr doctor`, `/rr version`
- Batch orchestration via shell scripts (rr-prepare.sh, rr-finalize.sh, _publish_one.sh)
- Real-time monitoring dashboard (monitor.py, monitor_server.py, monitor_dashboard.html)
- Parallel sub-agent dispatch for batch reviews
- Jira integration: discovery, quarterly filtering, parallel publication
- Per-skill installer with orchestrator, references, schemas, and workflow docs
- 6-step workflow: extract → adversarial review → rectify → discussion → finalise → publish

### Changed
- Moved from direct Anthropic API calls to Claude Code Agent tool for all LLM interactions
