# Changelog — project

All notable changes to the project skill will be documented in this file.

## [1.2.6] - 2026-04-18

### Fixed
- **`install.sh --check` no longer fails on valid modern installs**: CPT-77 made the per-skill installer's `--check` exit non-zero when issues are reported. `skills/project/install.sh --check` still required the retired `~/.claude/GITHUB_CONFIG.md` file — superseded in the multi-session architecture by `~/.claude/PROJECT_STANDARDS.md` (narrative) and per-project `PROJECT_CONFIG.json` (machine-readable). After CPT-77 shipped, every modern install reported unhealthy and exited 1, breaking CI/automation that relied on the exit code. Migration applied across `install.sh`, `SKILL.md`, `README.md`, `commands/new.md`: all live runtime-reference uses of `GITHUB_CONFIG.md` replaced with `PROJECT_STANDARDS.md` (or `PROJECT_CONFIG.json` where per-project machine-readable config is appropriate). A migration-nudge warning in `--check` flags a stale `GITHUB_CONFIG.md` as safe to remove without incrementing the issues counter (CPT-124).

## [1.2.5] - 2026-04-17

### Fixed
- **`/project:status` role-list tautology**: CPT-19 replaced reading `MULTI_SESSION_ARCHITECTURE.md` with deriving ROLES from `.worktrees/*/` directly. That made the subsequent missing/stray comparison tautological — the observed set was the expected set, so missing roles silently vanished and stray worktrees were implicitly accepted (a fresh repo with three configured worktrees would report "all roles present" instead of "8 missing"). Restored the authoritative source: `skills/project/commands/status.md` now extracts `session/<role>` tokens from `~/.claude/MULTI_SESSION_ARCHITECTURE.md`'s role table (~20 lines parsed, not the full file), derives the observed worktrees separately, computes set-differences, and surfaces `[missing role]` / `[unexpected worktree]` markers in the Step 4 display output (CPT-114).

## [1.2.4] - 2026-04-17

### Fixed
- **Exit-code contract**: `install.sh --check` now exits non-zero when issues are reported (was unconditional `exit 0`). Aligns with root `install.sh --check` behavior (CPT-77).

### Note on version renumbering
- CPT-77 source branch targeted 1.2.3; CPT-76 took 1.2.3 at merge time, so renumbered to 1.2.4.

## [1.2.3] - 2026-04-17

### Fixed
- **Argument parsing**: `install.sh` now uses an order-independent while-loop parser instead of positional `$1` checks. `-f --uninstall` (and other flag combinations) now uninstalls instead of silently re-installing. Unknown flags now exit non-zero (CPT-76).

## [1.2.2] - 2026-04-17

### Changed
- **Performance**: `status.md` derives role list from `.worktrees/` directories instead of reading full `MULTI_SESSION_ARCHITECTURE.md` each invocation (CPT-19).
- **Performance**: `new.md` Steps 6 and 11 reference Step 1 context instead of re-reading scaffolded config files (CPT-19).

### Note on version renumbering
- CPT-19's source branch bumped 1.2.0 → 1.2.1 in isolation. By merge time, 1.2.1 (CPT-17) had already shipped, so the Merger renumbered CPT-19 to 1.2.2. No code semantics changed.

## [1.2.1] - 2026-04-14

### Changed
- **Performance**: `project-picker.sh` draw_box_top/bottom use `printf -v` instead of `$(seq)` fork (was 2 forks per render)
- **Performance**: `project-picker.sh` draw_row uses bash parameter expansion instead of `echo|sed` for ANSI stripping (was 2 forks per row per render)
- **Performance**: `project-picker.sh` show_roles uses `read -r` instead of `echo|awk` for field extraction (was 2 forks per window per render)
- **Performance**: `project-picker.sh` merged get_window_count + get_active_count into single `get_window_stats` (was 2 tmux calls per session, now 1)
- **Performance**: `tmux-iterm-tabs.sh` lookup_label inlines sanitize_name logic (avoids subshell fork per directory iteration)

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
