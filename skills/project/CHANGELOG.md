# Changelog — project

All notable changes to the project skill will be documented in this file.

## [1.3.0] - 2026-04-14

### Changed
- **Breaking**: Replaced `GITHUB_CONFIG.md` (both global and per-project) with `PROJECT_CONFIG.json` (structured, schema-validated) and `~/.claude/PROJECT_STANDARDS.md` (narrative standards)
- All commands (new, config, status, audit, launch) updated to read `PROJECT_CONFIG.json` for project config and `PROJECT_STANDARDS.md` for standards
- `install.sh` health check now looks for `PROJECT_STANDARDS.md` instead of `GITHUB_CONFIG.md`
- SKILL.md doctor check updated accordingly

### Added
- `PROJECT_CONFIG.schema.json` — JSON Schema for validating PROJECT_CONFIG.json
- `scripts/validate-config.sh` — validates PROJECT_CONFIG.json against schema with semantic checks
- `tests/validate-config.bats` — 16 BATS tests for config validation

## [1.2.0] - 2026-04-12

### Added
- `/project:launch` subcommand — creates tmux session per project with named windows per worktree role, launches Claude Code in each with configurable options
- `--all` mode scans TMUX_REPOS_DIR for all projects with `.worktrees/`
- `--dry-run` mode previews launch without side effects
- Interactive options checklist: prompt pipe, --dangerously-skip-permissions, model override, max-turns, resume, skip idle, verbose, dry run
- `project-picker.sh` — standalone two-level TUI for navigating project sessions from any terminal (Blink, Moshi, Prompt 3 over Mosh)
- Keyboard navigation: single-keypress selection (a-z) at both project and role levels, Esc to go back
- tmux binding: `bind-key P display-popup -E -w 60 -h 20 "~/.local/bin/project-picker.sh"` opens the picker from anywhere

## [1.1.0] - 2026-04-12

### Added
- `/project:update` subcommand — reads `.source-repo`, pulls latest, re-runs install.sh
- Dependency pre-flight checks in all command files — clear errors if `MULTI_SESSION_ARCHITECTURE.md` or `GITHUB_CONFIG.md` are missing
- Router now includes `update`, `--update`, `upgrade` routes and help/doctor/version aliases (`--help`, `-h`, `--doctor`, `check`, `--version`, `-v`)

### Fixed
- **P1**: `config.md` worktree removal now checks uncommitted changes, unpushed commits, and stashed work before `git branch -D` — was only checking unmerged commits vs main
- `new.md` Step 8: replaced `git add -A` (risks staging sensitive files) with explicit file list per scaffolded files
- `new.md` Co-Authored-By format aligned to global CLAUDE.md standard
- `status.md` Python version detection: `tomllib` fallback for Python <3.11 via `tomli` or regex
- `status.md` cross-platform `stat` for file dates (macOS + Linux)
- `status.md` jq issue grouping handles unlabeled issues without crashing

## [1.0.0] - 2026-04-12

### Added
- Initial release in choc-skills. Migrated from loose files in `~/.claude/commands/project/`.
- `SKILL.md` with inline `help`, `doctor`, `version` subcommands (matches chk1/chk2/ra/rr convention).
- Per-skill `install.sh` following the standard choc-skills installer pattern.
- Router at install time writes `~/.claude/commands/project.md`; four subcommands copied to `~/.claude/commands/project/` (`new.md`, `status.md`, `audit.md`, `config.md`).
- `.source-repo` marker written on install for future `/project update` support.
- Narrow `allowed-tools` frontmatter (enumerated `Bash(gh *), Bash(git *), Bash(mkdir *), ...` — never `Bash(*)`) per CONTRIBUTING.md least-privilege rule.

### Changed
- Renamed `/project:doctor` (project-compliance audit) to `/project:audit`. The `doctor` name is now reserved for skill-install health checks, which are handled inline in `SKILL.md` per choc-skills convention. Any existing muscle memory for `/project doctor` as "audit a project against standards" now needs to use `/project audit` instead.
- Merged former `/project:help` (standalone subcommand file) into the inline `help` handler in `SKILL.md`. The help content is no longer a separate file under `commands/`.
- Internal references to `/project:doctor` in `commands/new.md` rewritten to `/project:audit`.
