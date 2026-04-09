# Changelog — rr

All notable changes to the rr skill will be documented in this file.

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
