# Changelog — ra

All notable changes to the ra skill will be documented in this file.

## [1.0.9] - 2026-04-18

### Fixed
- **ra command allowed-tools now permit reading the env vars referenced by the CPT-103 MCP-substitution preamble** (CPT-149, companion fix to the rr v5.3.25 entry — rr renumbered from 5.3.24 to 5.3.25 as part of the merge sequence because CPT-146 claimed 5.3.24 on `main` first). Added `Bash(echo *)` to `skills/ra/commands/publish.md` (preamble in the command body) and `skills/ra/commands/assess.md` (loads `references/workflow/step-2-ingest.md`, which carries the preamble). Without it, the CPT-103 preamble's instruction to substitute `$JIRA_CLOUD_ID` via `echo "$JIRA_CLOUD_ID"` was denied by CPT-32 per-command enforcement. Covered by `tests/mcp-substitution-env-read-tool.bats`.

## [1.0.8] - 2026-04-18

### Fixed
- **MCP call-spec `$JIRA_CLOUD_ID` now reliably substituted**: same class as the companion rr fix (CPT-103). Added an "IMPORTANT: MCP call-spec variable substitution" preamble to every ra file using the pattern (`references/jira-config.md`, `references/workflow/step-2-ingest.md`, `commands/publish.md`) so Claude substitutes the env var value before passing `cloudId` to MCP rather than sending the literal string.

**Note on version renumbering**: This entry originally targeted 1.0.7 on `fix/CPT-103-mcp-cloudid-preamble`, but CPT-134 (validator drift + ra README normalisation) landed on `main` and claimed 1.0.7 first. Renumbered to 1.0.8 as part of the merge sequence; no code semantics changed from the original branch.

## [1.0.7] - 2026-04-18

### Fixed
- **Stale `Current` version in `skills/ra/README.md`**: the README displayed `1.0.0` long after the frontmatter moved on (reached 1.0.5 via CPT-77). CPT-92's version-sync validator checked only the `Current: **X.Y.Z**` form that chk1/chk2/project/rr use, but ra's README used a bare `## Version\n\nX.Y.Z` form, so the drift passed silently. Normalised ra's README to the canonical `Current: **X.Y.Z**` form and updated to the now-current value. Extended `scripts/validate-skills.sh` to check per-skill READMEs (both forms) and the root README skills-table row; `tests/version-sync.bats` now discovers skills dynamically from `skills/*/SKILL.md` rather than a hardcoded array, so any newly added skill is automatically covered (CPT-134).

**Note on version renumbering**: This entry originally targeted 1.0.6 on `fix/CPT-134-validator-drift-ra-stale`, but CPT-123 (conflicting-flag detection) landed on `main` and claimed 1.0.6 first. Renumbered to 1.0.7 as part of the merge sequence; no code semantics changed from the original branch.

## [1.0.6] - 2026-04-17

### Fixed
- **Conflicting action flags in `install.sh` now die at parse time** (CPT-123): see the chk1 v2.4.7 entry for the full write-up. Same fix, applied identically to ra's per-skill installer.

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
