# Changelog — project

All notable changes to the project skill will be documented in this file.

## [2.0.2] - 2026-04-14

### Fixed (CPT-41 logic-review follow-up — dual audit by self + Codex)

- **P1/BLOCKER**: Sanitize the auto-exported project-path env var. Previous
  `basename | tr upper` produced invalid shell identifiers for any repo with
  a hyphen or dot in its name (e.g., `CHOC-SKILLS_PATH`). `export` rejects
  those with "not a valid identifier." Now the name is uppercased with
  non-`[A-Z0-9_]` chars replaced by underscore, yielding e.g.
  `CHOC_SKILLS_PATH`. Schema docstring, launch.md, config.md, USER_GUIDE.md
  all updated.
- **P1/BLOCKER**: Don't launch Claude with `cat prompt | claude …`. Piped
  stdin closes at EOF; subsequent `tmux send-keys "/loop …"` would either
  land in the shell (Claude having exited) or hit a process with closed
  stdin. Now Claude is launched attached to the pane TTY, identity prompt is
  pasted as a single bracketed-paste block, then `/loop` is pasted the same
  way. All via new helpers `_paste_file_and_submit` and `_send_loop_command`.
- **P2/HIGH**: Inline the loop prompt text into the `/loop` command. The
  `/loop` skill accepts "a prompt or a slash command" — passing a path
  argument like `loops/loop.md` would schedule the literal string, not the
  file contents. `_send_loop_command` now reads the file and inlines the
  text after `/loop <N>m ` as a single pasted block.
- **P2/HIGH**: Replace `sleep 3` with `_wait_pane_stable` — poll the pane
  for output stability (no changes for N consecutive 1-second samples, up
  to a timeout). Used both before identity-prompt paste (Claude+MCP init)
  and before `/loop` dispatch (identity-prompt processing).
- **P2/HIGH**: Validate env var keys as legal shell identifiers
  (`^[A-Za-z_][A-Za-z0-9_]*$`) and quote values with `printf '%q'` before
  `tmux send-keys "export KEY=…"`. Previous single-quote templating broke
  on values containing single quotes or unescaped dollar signs, and no key
  validation meant `export` could fail silently mid-launch.
- **P3/LOW**: Expand `scripts/validate-config.sh` semantic checks beyond
  schema validation — now also errors on env var keys that aren't valid
  shell identifiers, errors on `env.sessions.<role>` where the role isn't
  in `sessions.roles`, and warns on loop-capable roles in `sessions.roles`
  that have no `sessions.loops` entry. 4 new BATS tests (24 total).

### Credits
Dual review by self + Codex CLI 0.118.0 against commit 0f0ea4b before
session restart. Both reviews converged on the same blockers.

## [2.0.1] - 2026-04-14

### Removed
- `/project:new` no longer writes a `Co-Authored-By: Claude` trailer into the initial scaffold commit. Per global rule in `~/.claude/CLAUDE.md`, Claude is a tool, not an author.

## [2.0.0] - 2026-04-14

### Breaking

- **Router refactor (Option C)**: `doctor`, `help`, `version` are now
  proper colon-command files (`commands/doctor.md`, `commands/help.md`,
  `commands/version.md`) instead of inline sections in `SKILL.md`.
  Router owns ALL alias routing. Fixes silent `--doctor`, `check`,
  `--version`, `-v` aliases that never worked through the router.
- **GitHub labels stripped**: `/project:new` no longer creates labels;
  it disables GitHub Issues (`gh repo edit --enable-issues=false`) and
  deletes all default labels. `/project:audit` replaces 4 label checks
  with "GitHub Issues disabled" and "No labels present" checks.
  `/project:config` no longer offers label management. Rationale:
  PROJECT_STANDARDS.md already required no-labels/no-Issues; the skill
  was contradicting its own standard.
- **PROJECT_CONFIG schema v1 extended**: `sessions.loops` now restricted
  to 8 loop-capable roles (master, triager, reviewer, merger, chk1,
  chk2, fixer, implementer). planner/performance/playtester can no
  longer have loop entries. Each loop entry accepts an optional
  `prompt` field (default `loops/loop.md`).

### Added

- **CPT-41: Loop integration**. `/project:launch` now dispatches
  `/loop <N>m loops/loop.md` to each loop-capable session after init.
  Intervals and prompt paths read from `PROJECT_CONFIG.json
  sessions.loops`.
- **Env vars at launch**. `/project:launch` exports
  `<DIRNAME_UPPER>_PATH` into every session (e.g.,
  `CHOC-SKILLS_PATH`). Plus `env.project` (project-level) and
  `env.sessions.<role>` (per-role) from PROJECT_CONFIG.json.
- **New schema section `env`** with `project` and `sessions` maps.
  Additional properties prohibited. Secrets NOT stored here —
  future BWS/AWS Secrets Manager integration planned.
- **Loop prompt scaffolding**. `/project:new` Step 10.5 creates
  `.worktrees/<role>/loops/loop.md` for each loop-capable role with
  role-specific recurring-task templates, committed on each role's
  `session/<role>` branch.
- **`/project:config` gains "Configure loops"** (edit intervals +
  prompt paths) and **"Manage env vars"** actions.
- **`/project:audit` gains loop checks**: loop configuration validity
  (all loop-capable roles configured, no loops on on-demand roles)
  and loop prompt file existence.
- **USER_GUIDE.md documents loops, env vars, and the two config
  layers** with concrete examples.

### Changed

- `SKILL.md` reduced to a pure fallback — invokes `/project:help` if
  Claude self-invokes the skill without a matching subcommand.
- Doctor check 4 now expects 9 subcommand files (was 6).

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
