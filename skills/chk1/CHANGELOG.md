# Changelog — chk1

All notable changes to the chk1 skill will be documented in this file.

## [2.4.5] - 2026-04-17

### Fixed
- **Exit-code contract**: `install.sh --check` now exits non-zero when issues are reported (was unconditional `exit 0`). Aligns with root `install.sh --check` behavior so CI/automation can detect unhealthy installations by exit code (CPT-77).

### Note on version renumbering
- CPT-77's source branch bumped 2.4.3 → 2.4.4 in isolation. By merge time, 2.4.4 (CPT-76) had already shipped, so the Merger renumbered CPT-77 to 2.4.5. No code semantics changed.

## [2.4.4] - 2026-04-17

### Fixed
- **Argument parsing**: `install.sh` now uses an order-independent while-loop parser instead of positional `$1` checks. `-f --uninstall` (and other flag combinations) now uninstalls instead of silently re-installing. Unknown flags now exit non-zero (CPT-76).

## [2.4.3] - 2026-04-17

### Added
- **Security**: YAML frontmatter with scoped `allowed-tools` added to all 8 chk1 sub-command files. Tool allocations follow least-privilege (CPT-39):
  - `all`, `architecture`, `quick`, `scope`, `security`: `Read, Grep, Glob, Bash(git *)`
  - `fix`: adds `Edit, Write, AskUserQuestion`
  - `github`: adds `Bash(gh *), AskUserQuestion`
  - `update`: scoped `Bash` (`git`, `bash install.sh`, `curl`, `mkdir`, `grep`, `sed`) — no catch-all

### Note on version renumbering
- CPT-39's source branch bumped 2.4.0 → 2.4.1 in isolation. By merge time, 2.4.1 (CPT-13) and 2.4.2 (CPT-19) had both shipped, so the Merger renumbered CPT-39 to 2.4.3. No code semantics changed.

## [2.4.2] - 2026-04-17

### Changed
- **Performance**: `all.md` no longer re-reads SKILL.md (already loaded by router). `SKILL.md` scope detection references pre-flight `git diff --stat` instead of re-running (CPT-19).
- **Performance**: `update.md` parallelises curl downloads with `xargs -P 4` (was sequential `for` loop) (CPT-19).

### Note on version renumbering
- CPT-19's source branch bumped 2.4.0 → 2.4.1 in isolation. By merge time, 2.4.1 (CPT-13) had already shipped, so the Merger renumbered CPT-19 to 2.4.2. No code semantics changed.

## [2.4.1] - 2026-04-14

### Fixed
- `/chk1:fix` now has a maximum of 2 fix→audit rounds. After the cap, remaining findings are presented as a summary instead of continuing to loop. (CPT-13)

## [2.4.0] - 2026-04-09

### Changed
- **Security**: Restricted `Bash(*)` to explicit command patterns (`Bash(git *)`, `Bash(gh *)`, `Bash(curl *)`)
- Per-skill installer now cleans stale command files before installing new version
- Per-skill installer now creates `.source-repo` marker for `/chk1 update`

### Fixed
- Stale sub-command files no longer persist after upgrade

## [2.3.0] - 2026-04-07

### Added
- New `/chk1 github` subcommand logs audit findings as GitHub Issues with P1-P4 priority labels, duplicate detection, milestone assignment, and automatic label creation
- New `/chk1 update` subcommand pulls latest chk1 from the GitHub repo (uses `.source-repo` marker if present, falls back to curl)
- Added `Bash(gh *)` and `Bash(curl *)` to allowed-tools

## [2.1.0] - 2026-04-03

### Added
- 8 adversarial audit checks added to the full audit mode

## [2.0.0] - 2026-04-03

### Added
- Sub-command architecture: `/chk1 quick`, `/chk1 security`, `/chk1 scope`, `/chk1 architecture`, `/chk1 fix`
- Per-skill installer with router and command file installation

## [1.1.0] - 2026-03-31

### Added
- Initial release: adversarial implementation audit with 8 audit sections
- Auto-scope detection (commit range, branch, SHA, or auto-detect recent changes)
- Structured output format with audit metadata, per-file analysis, and remediation plan
