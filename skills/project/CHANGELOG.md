# Changelog — project

All notable changes to the project skill will be documented in this file.

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
