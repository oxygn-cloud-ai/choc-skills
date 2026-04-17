# Changelog — project

All notable changes to the project skill will be documented in this file.

## [1.2.10] - 2026-04-18

### Fixed
- **`/project:status` role-detection block now distinguishes `sessions.roles=[]` from "key absent", and no longer uses `local` at top level** (CPT-156). CPT-139 added a three-layer precedence for the expected-role set but carried two defects: (1) `jq -r '.sessions.roles[]? // empty'` emits zero lines for both `{"roles":[]}` and `{}`-no-key, so a project explicitly declaring "no expected roles" silently fell through to the full MSA catalog; (2) Layer 2/3 declared `local project_type=""` at the top level of the bash snippet — `local` is function-only and bash rejects it outside a function (`bash: line 0: local: can only be used in a function`, exit 1), aborting the whole role-detection under `set -e`. Added a `SESSIONS_ROLES_DECLARED` sentinel gated on `jq -e '.sessions | has("roles")'` so present-but-empty is honoured; replaced `local project_type=""` with a plain assignment. Seven bats regressions in `tests/project-status-role-detection.bats`: runtime tests exercise the extracted bash block against `{"roles":[]}` → empty ROLES, `{}` → MSA fallback, `{"roles":["master","fixer"]}` → verbatim, plus static checks asserting the sentinel pattern and no-`local` invariants.

**Note on version renumbering**: CPT-141 is on an open branch targeting 1.2.10. Taking 1.2.10 here because CPT-141 hasn't landed yet — if the merger resolves differently, this entry renumbers. No code semantics changed.

## [1.2.9] - 2026-04-18

### Fixed
- **Finished the CPT-124 `GITHUB_CONFIG.md` → `PROJECT_STANDARDS.md` + `PROJECT_CONFIG.json` migration across four remaining command files** (CPT-141). CPT-124 migrated `install.sh`, `SKILL.md`, `README.md`, and `commands/new.md` but left `audit.md`, `config.md`, `status.md`, and `launch.md` hard-depending on the retired filename. `audit.md` and `config.md` STOPped with errors when `~/.claude/GITHUB_CONFIG.md` was absent; `status.md` marked `GITHUB_CONFIG.md` as a required doc (reported MISSING on modern setups); `launch.md` detected project type from it. The CPT-124 `--check` "healthy" verdict was a lie for 4 of 5 project commands — a freshly-scaffolded `/project:new` repo could not run `/project:audit` or `/project:config`. This release completes the migration: the STOP gates now fire on `~/.claude/PROJECT_STANDARDS.md`, machine-readable config (type, Jira epic, labels, deviations) is read from and written to each repo's `PROJECT_CONFIG.json`, and stale `GITHUB_CONFIG.md` is treated as informational-only (flagged as migration-pending, never a failure). 8 bats regressions in `tests/project-github-config-migration.bats` enforce: no file hard-STOPs on missing `~/.claude/GITHUB_CONFIG.md`, all four reference `PROJECT_STANDARDS.md` or `PROJECT_CONFIG.json`, and `status.md` no longer lists `GITHUB_CONFIG.md` in the required-docs loop.

**Note on version renumbering**: This entry originally targeted 1.2.8 on `fix/CPT-141-github-config-migration-finish`, but CPT-139 (status role-scope fix) landed on `main` first and claimed 1.2.8. Renumbered to 1.2.9 as part of the merge sequence; no code semantics changed from the original branch.

## [1.2.8] - 2026-04-18

### Fixed
- **`/project:status` no longer reports false `[missing role]` for non-software projects** (CPT-139). CPT-114 correctly restored the MSA-sourced ROLES derivation after the CPT-19 tautology, but extracted all 11 session tokens from `MULTI_SESSION_ARCHITECTURE.md` unconditionally. MSA §1 explicitly notes "Non-software projects may skip: chk1, chk2, Playtester", so an 8-worktree non-software project got three false `[missing role]` warnings. The expected-role set is now scoped per project via a three-layer precedence: (1) `PROJECT_CONFIG.json .sessions.roles` explicit list (repo source of truth); (2) `PROJECT_CONFIG.json .project.type` / `.project_type` / `.projectType` set to `"non-software"` drops `chk1`/`chk2`/`playtester` from the MSA catalog; (3) full MSA catalog fallback when neither is present. Projects that don't yet carry `PROJECT_CONFIG.json` or have it without the role-narrowing fields keep the pre-CPT-139 behaviour — zero regression for existing software repos. The set-diff now compares `.worktrees/*/` against THIS project's configured roles, not the catalog of possible roles. Four bats regressions in `tests/project-status-roles-source.bats` enforce the precedence layers.

## [1.2.7] - 2026-04-18

### Fixed
- **Conflicting action flags in `install.sh` now die at parse time** (CPT-123): see the chk1 entry for the full write-up. Same fix, applied identically to project's per-skill installer.

**Note on version renumbering**: This entry originally targeted 1.2.5 on `fix/CPT-123-installer-conflict-detection`, but CPT-114 (project:status role-list) claimed 1.2.5 and CPT-124 (project-standards migration) claimed 1.2.6 first. Renumbered to 1.2.7 as part of the merge sequence; no code semantics changed from the original branch.

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
