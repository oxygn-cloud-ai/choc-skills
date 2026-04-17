# Changelog — rr

All notable changes to the rr skill will be documented in this file.

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

## [5.2.2] - 2026-04-14

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
