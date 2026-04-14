# Changelog — project

All notable changes to the project skill will be documented in this file.

## [2.0.4] - 2026-04-14

### Fixed (CPT-41 fourth-pass review — 5 findings Codex caught in v2.0.3)

- **BLOCKER**: `send_single_line()` was shipping broken. It used
  `grep -q $'\n'` to detect multi-line text, but grep treats newlines as
  record separators, making the pattern empty — which matches every
  non-empty string. Result: EVERY valid `/loop` command was rejected, the
  script would `die` with "refuses multi-line text", and v2.0.3's live
  launch path would never succeed. Fixed with bash pattern matching
  `[[ "$text" == *$'\n'* ]]` which actually works. Added a regression
  test that would have caught this.
- **HIGH**: `source '$PANE_SETUP'` runs in the pane's existing login shell,
  not bash. That's fine on macOS/Linux where pane shell is zsh/bash but
  fails anywhere with `sh`/`fish`/`dash`. v2.0.3's changelog claimed
  "executes under bash regardless of pane shell" — the claim was wrong.
  Now uses `exec bash '$PANE_SETUP'` which forces bash regardless of login
  shell. `exec` replaces the pane process chain: login-shell → bash →
  (self-delete) → claude.
- **MEDIUM**: `scripts/validate-config.sh` worktree-aware name check was
  partially broken. `git rev-parse --git-common-dir` returns a RELATIVE
  path (`.git`) when the cwd is already the main repo, but the script
  then `cd`'d relative to the PROCESS cwd, not to `CONFIG_DIR`. Running
  `validate-config.sh /abs/path/config.json` from `/tmp` silently
  resolved the wrong repo. Fixed with `--path-format=absolute` (git
  2.31+) and a fallback branch for older git that normalizes relative
  paths against `CONFIG_DIR`. Regression test added: runs validator
  from `/tmp` against absolute config path; expects PASS with no
  "does not match" warning.
- **MEDIUM**: Temp script handoff collision + leak. v2.0.3 used a stable
  `/tmp/project-launch-<slug>-<role>.sh` path — two concurrent launches
  of the same project+role would overwrite each other. Also the trailing
  `; rm -f` in `tmux send-keys "source …; rm -f …"` NEVER executed
  because `exec claude` inside the sourced script replaced the shell
  before the rm ran. Now: `mktemp` for a unique filename, and the
  generated setup script self-deletes with `rm -f "$0"` (works because
  Unix allows unlinking an open file without affecting the running
  process; bash has already read the script into memory before exec).
- **LOW / documented caveat**: BATS tests exercise dry-run paths,
  argument parsing, env-var quoting, and setup-script generation, but
  NOT the live-tmux paths (`paste-buffer -p` bracketed paste into
  Claude's input box, `capture-pane` readiness polling, `/loop`
  dispatch into a running Claude). Those require an actual TTY +
  live Claude Code + MCP init and cannot be unit-tested from BATS.
  Verification method for those paths is: (1) Codex review — confirmed
  the logic is correct per docs; (2) live test with ONE role before
  restarting all 11 sessions. The user should expect to try
  `/project:launch` first, observe one role, and only proceed with
  all 11 after verifying the bracketed-paste and `/loop` dispatch
  work end-to-end.

### Added

- 3 new BATS tests (78 total): `send_single_line` newline guard
  regression, bash-pattern newline detection positive case, setup
  script self-delete verification; worktree-aware validate-config
  from-different-cwd regression.

### Credits
Third adversarial audit by Codex CLI 0.118.0 found all 5 of these —
one was a hard blocker that my own v2.0.3 tests failed to catch
because they only covered dry-run paths. Testing gap honestly
documented (see LOW above).

## [2.0.3] - 2026-04-14

### Fixed (CPT-41 third-pass review — 11 additional findings from Codex + self adversarial audit of v2.0.2)

- **HIGH**: Extracted all per-role launch logic from `commands/launch.md`
  (prompt pseudocode) into `skills/project/bin/project-launch-session.sh`
  (real bash script installed to `~/.local/bin/`). Prior pseudocode assumed
  "helpers defined once persist across Bash calls" — false for Claude Code's
  tool model, where each Bash invocation is a fresh subshell. Now /project:launch
  invokes the script per role, which keeps all helpers in one process.
- **HIGH**: Replaced tab-delimited `jq` env-var serialization with `jq @sh`.
  Tab-delimited `key<TAB>value` + `IFS=$'\t' read` silently corrupted values
  containing tabs (truncation) or newlines (value split across multiple
  iterations). `@sh` produces POSIX-compatible single-quoted strings; lossless
  for any value.
- **HIGH**: `/loop` dispatch is now SINGLE-LINE. Previous approach pasted
  `/loop <N>m <multi-line prompt text>` as a bracketed-paste block, but
  `/loop`'s parser behavior on multi-line pasted args is undocumented (and a
  prompt line starting with `/` could flip into slash-command mode). New form:
  `/loop <N>m Read the file loops/loop.md in this worktree and execute the
  recurring task described there.` — deterministic, and the session re-reads
  the file on every tick (edits take effect immediately).
- **HIGH**: `/project:launch` now resolves REPO_ROOT via
  `git rev-parse --git-common-dir` + parent — works correctly whether invoked
  from the main repo OR from inside a `.worktrees/<role>/` subdirectory.
  Previous `git rev-parse --show-toplevel` returned the worktree path in a
  worktree, so `.worktrees/` was never found.
- **HIGH**: Identity-prompt processing timeout now SKIPS loop dispatch
  (exit 4) instead of firing `/loop` into a busy Claude. Previous `|| echo`
  just warned and fell through to /loop, which is the failure mode we were
  trying to prevent.
- **MEDIUM**: Launch script requires bash explicitly (declared in pre-checks).
  `printf %q` + `$'...'` quoting was claimed portable; actually bash/zsh-only.
  Now the generated setup script has `#!/usr/bin/env bash` shebang and is
  executed under bash regardless of the pane's login shell.
- **MEDIUM**: `scripts/validate-config.sh` is now worktree-aware. It was
  comparing `project.name` ("choc-skills") against `basename $CONFIG_DIR`
  ("master" when run from a worktree), producing spurious WARN noise. Now
  resolves the main repo name via `git rev-parse --git-common-dir`.
- **MEDIUM**: Config lookup fallback. `/project:launch` now checks both
  `$REPO_ROOT/PROJECT_CONFIG.json` and
  `$REPO_ROOT/.worktrees/master/PROJECT_CONFIG.json`, so launch works even
  before the config is merged to `main`.
- **LOW**: `USER_GUIDE.md` Launch section and example both said
  `cat .claude/sessions/<role>.md | claude [flags]` — which is the exact
  stdin-pipe approach v2.0.2 was supposed to eliminate. Updated both to
  describe the bracketed-paste flow.
- **LOW**: `skills/project/install.sh` health check now verifies
  `~/.local/bin/project-launch-session.sh` is installed; missing it is an
  ERROR (not WARN) because `/project:launch` cannot function without it.
- **LOW**: New `tests/project-launch-session.bats` — 19 smoke tests covering
  arg parsing, pre-flight validation, sanitized env var name, safe quoting of
  values containing single quotes, rejection of invalid identifiers,
  override precedence, idle-skip, and config-fallback. Total BATS: 74.

### Added

- `skills/project/bin/project-launch-session.sh` — per-role launcher (~250
  lines of real, shellcheck-clean bash). Supports `--dry-run` and `--help`.
  Installed to `~/.local/bin/` by `skills/project/install.sh`.

### Credits
Second adversarial audit by Codex CLI 0.118.0 + self-review against commit
fca9a9d. All 11 findings resolved. 74/74 BATS tests pass.

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
