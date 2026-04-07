# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **chk1 v2.2.0** — New `/chk1 github` subcommand that logs audit findings as GitHub Issues with P1-P4 priority labels, duplicate detection (comments instead of new issues), milestone assignment based on priority, and automatic label creation

## [1.3.0] - 2026-04-07

### Added
- **BATS test suite** — 21 tests covering install.sh and generate-checksums.sh (`tests/install.bats`, `tests/generate-checksums.bats`)
- **BATS CI job** — Runs BATS tests on macOS in GitHub Actions
- **macOS CI matrix** — Installer smoke test now runs on both Ubuntu and macOS
- **CLAUDE.md** — Project documentation for Claude Code (conventions, testing, CI, adding skills)
- **Issue templates** — Bug report, feature request, and security concern forms
- **PR template** — Checklist for skills, installer, and security changes
- **dependabot.yml** — Weekly GitHub Actions dependency updates (major bumps ignored)
- **labels.yml** — Canonical label definitions (18 labels)

### Fixed
- **validate-skills.sh** — Now accepts routing-style skills with separate command files (fixes `rr` validation)
- **install.sh** — Fixed `set -e` exit code bug when `[ "$failed" -gt 0 ] &&` short-circuits on zero failures

## [1.2.0] - 2026-04-01

### Added
- **chk2 skill** — Adversarial security audit for web services with 11 test categories (~100 checks): headers, TLS, DNS, CORS, API injection, WebSocket, WAF, infrastructure, brute force, scaling, and info disclosure
- **CI/CD pipeline** — GitHub Actions for ShellCheck, skill validation, installer smoke tests, and file permission checks
- **Release workflow** — Automated GitHub Releases with checksums on version tags
- **Skill validation script** (`scripts/validate-skills.sh`) — Automated SKILL.md frontmatter and structure validation
- **Checksum generation** (`scripts/generate-checksums.sh`) — SHA256 integrity verification for all SKILL.md files
- `CHECKSUMS.sha256` — Published checksums for installed skill verification
- `SECURITY.md` — Security policy, trust model, vulnerability reporting, and contributor checklist
- `CONTRIBUTING.md` — Contribution guide with skill requirements, PR process, and security review checklist
- `.shellcheckrc` — ShellCheck configuration for consistent linting

### Changed
- **install.sh** — Added `--dry-run` mode, SHA256 integrity verification, bash version check, `--changelog` command, and upgrade reporting during `--update`
- **README.md** — Added chk2 to skills table, manual install examples, and project structure

### Fixed
- **install.sh** — Fixed `local` keyword used outside function scope in `--uninstall --all` block
- **install.sh** — Removed accidental blank line at line 181

## [1.1.0] - 2026-03-31

### Added
- **chk1 skill** v1.1.0 — Adversarial implementation audit with 8 audit sections, auto-scope detection, structured output format
- Root installer with skill discovery, version checking, health verification
- Per-skill installer pattern (delegates to root, standalone fallback)
- Skill template (`_template/`) with SKILL.md and README.md skeletons
- Codebase architecture documentation (`.planning/codebase/`)

### Changed
- Installer hardened with path traversal prevention, copy verification, and non-interactive mode support

## [1.0.0] - 2026-03-30

### Added
- **iterm2-tmux tool** — iTerm2 + tmux tab orchestration with colored tabs, session management, and background watermarks
- Initial project structure with README, LICENSE (MIT), and .gitignore
