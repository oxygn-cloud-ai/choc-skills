# Changelog — project

All notable changes to the project skill will be documented in this file.

## [1.4.0] - 2026-04-14

### Added
- `/project:launch` Step 7: Export environment variables from `PROJECT_CONFIG.json` to tmux windows before Claude launches — supports `env.project` (all sessions) and `env.sessions.<role>` (per-session overrides)
- `/project:launch` Step 9: Send `/loop <interval>m <prompt-file>` to polling sessions after Claude initializes — reads `loops.<role>.intervalMinutes` from config, references `.worktrees/<role>/loops/<role>.md` prompt files
- `/project:config` "Configure environment variables" menu option — add/edit/remove project-level and per-session env vars with jq-based persistence
- `/project:new` Step 10b: Scaffold `.worktrees/<role>/loops/` directories with role-appropriate loop prompt files for all polling roles
- `/project:new` `env` section in PROJECT_CONFIG.json scaffold — auto-populates `<PROJECT>_PATH` and empty per-session objects
- `/project:status` now shows env vars (project-level and session overrides) and loop state (interval + prompt file presence)
- 8 loop prompt files in `.worktrees/<role>/loops/` for polling roles: master, triager, reviewer, merger, chk1, chk2, fixer, implementer
- `env` section in PROJECT_CONFIG.json with `env.project` (project-level vars) and `env.sessions` (per-role overrides)
- `scripts/validate-config.sh` validates env section (project object with string values, sessions with valid role keys)

### Changed
- `/project:launch` step numbering updated: env export (Step 7), Claude launch (Step 8), loop invocation (Step 9), report (Step 10)

## [1.3.0] - 2026-04-14

### Added
- `PROJECT_CONFIG.json` at repo root — structured JSON config replacing `GITHUB_CONFIG.md` with sections: `schemaVersion`, `project`, `jira`, `github`, `sessions`, `loops`, `coverage`, `deviations`
- `scripts/validate-config.sh` — jq-based validation of PROJECT_CONFIG.json (required fields, types, valid role names, polling role subset, non-negative intervalMinutes)
- Loop interval configuration: `loops` section with per-role `intervalMinutes` for 8 polling sessions (master, triager, reviewer, merger, chk1, chk2, fixer, implementer)
- `/project:config` "Configure loop intervals" menu option — view and edit per-role loop intervals with validation

### Changed
- All command files (config, audit, new, status, launch) now read/write `PROJECT_CONFIG.json` instead of `GITHUB_CONFIG.md`
- SKILL.md, install.sh, README.md: all references updated from `GITHUB_CONFIG.md` to `PROJECT_CONFIG.json`
- `/project:launch` report now shows loop interval per role
- `/project:audit` runs `validate-config.sh` when `PROJECT_CONFIG.json` exists
- `/project:new` scaffolds `PROJECT_CONFIG.json` from template with schema validation

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
