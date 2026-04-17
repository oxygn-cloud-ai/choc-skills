# Changelog — ra

All notable changes to the ra skill will be documented in this file.

## [1.0.5] - 2026-04-17

### Fixed
- **Exit-code contract**: `install.sh --check` now exits non-zero when issues are reported (was unconditional `exit 0`). Aligns with root `install.sh --check` behavior (CPT-77).

### Note on version renumbering
- CPT-77 source branch targeted 1.0.4; CPT-76 took 1.0.4 at merge time, so renumbered to 1.0.5.

## [1.0.4] - 2026-04-17

### Fixed
- **Argument parsing**: `install.sh` now uses an order-independent while-loop parser instead of positional `$1` checks. `-f --uninstall` (and other flag combinations) now uninstalls instead of silently re-installing. Unknown flags now exit non-zero (CPT-76).

## [1.0.3] - 2026-04-17

### Changed
- **Performance**: `install.sh` removes redundant post-`cmp -s` shasum block and replaces `$(cat .source-repo)` with bash builtin `$(< .source-repo)` — eliminates ~2 forks per install (CPT-20).

### Note on version renumbering
- CPT-20's source branch bumped 1.0.0 → 1.0.1 in isolation. By merge time, 1.0.1 (CPT-27) and 1.0.2 (CPT-19) had both shipped, so the Merger renumbered CPT-20 to 1.0.3. No code semantics changed.

## [1.0.2] - 2026-04-17

### Changed
- **Performance**: `assess.md` marks reference files as already-in-context for downstream step files, avoiding redundant reads (CPT-19).

### Note on version renumbering
- CPT-19's source branch bumped 1.0.0 → 1.0.1 in isolation. By merge time, 1.0.1 (CPT-27) had already shipped, so the Merger renumbered CPT-19 to 1.0.2. No code semantics changed.

## [1.0.1] - 2026-04-14

### Fixed
- **Security**: Replaced hardcoded Jira Cloud ID and Assignee Account ID with `$JIRA_CLOUD_ID` and `$RR_ASSIGNEE_ID` environment variable references across SKILL.md, reference docs, and command files
- Doctor check now verifies `JIRA_CLOUD_ID` is set and warns if `RR_ASSIGNEE_ID` is unset

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
