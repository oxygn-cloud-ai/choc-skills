# Changelog — ra

All notable changes to the ra skill will be documented in this file.

## [1.0.1] - 2026-04-13

### Changed
- **Performance**: `ra:publish` now creates finding tasks and mitigation sub-tasks in parallel MCP calls (3 sequential waves instead of 41+ sequential calls)

## [1.0.0] - 2026-04-11

### Added
- Initial release of bespoke risk assessment skill
- Interactive 6-step workflow: interview, ingest, assess, adversarial, discuss, output
- Adaptive interview phase with scope confirmation
- Multi-source ingestion with full provenance tracking (files, URLs, Jira, Confluence, Slack)
- Epistemic classification (fact, user_claim, assumption, unknown)
- 11-criteria adversarial self-review (rr's 8 + assumption_not_validated, scope_gap, stakeholder_not_consulted)
- Projected residual risk with confidence levels
- Jira RA project integration: Assessment (Epic), Finding (Task), Mitigation (Sub-task)
- Publish with --dry-run preview
- Per-skill installer with health check
- 7 JSON schemas for structured outputs
- 6 workflow step files
- Sub-commands: assess, publish, status, update, help, doctor, version
