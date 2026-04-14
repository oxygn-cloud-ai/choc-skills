# Changelog — rr

All notable changes to the rr skill will be documented in this file.

## [5.2.2] - 2026-04-13

### Fixed
- Added MAX_TOTAL_AGENTS (50) hard cap on total agent dispatches in Agent Orchestrator Mode
- Added cumulative agent count tracking with wave abort when cap is reached
- Added MAX_TOTAL_RETRIES (10) global retry budget across all failed batches
- Added finalization gating: finalization runs exactly once after all retries complete, preventing duplicate Jira publications

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
