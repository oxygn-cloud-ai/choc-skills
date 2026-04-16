# Changelog — chk1

All notable changes to the chk1 skill will be documented in this file.

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
