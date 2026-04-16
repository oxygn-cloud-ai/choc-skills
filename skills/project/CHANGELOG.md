# Changelog — project

All notable changes to the project skill will be documented in this file.

## [2.2.0] - 2026-04-17

### Added (CPT-58 — cave-inversion protection, tool layer)

`install.sh --check` is promoted from presence-only to a four-part
read-only audit. This closes the diagnostic gap that let the
2026-04-16 drift persist unnoticed for roughly two hours: the old
check would have reported "All checks passed" even though two hooks
had been shipped to `~/.claude/hooks/` with no backing source in
`skills/project/hooks/`.

1. **Byte-parity (source → target).** For every file under
   `skills/project/{hooks,bin,commands}/`, `sha256` of the source is
   compared to the installed target. Reports `ok byte-identical:
   <file>`, `err DRIFT: <file>` (hash mismatch), or `err MISSING:
   <file>` (source exists, no install target). Suggests
   `install.sh --force` on any failure.
2. **Orphan detection (target → source).** For every hook registered
   in `~/.claude/settings.json` `hooks.PreToolUse[]` with a matcher
   this skill owns (per `hook_matcher_for()`), the command path's
   basename must appear in `skills/project/hooks/`. If not:
   `err ORPHAN: ...`. Scope is limited to matchers we emit, so
   other tools' hooks sharing `~/.claude/hooks/` under unrelated
   matchers stay out of scope.
3. **Per-matcher registration integrity.** Replaces the pre-v2.2.0
   count-based registration check, which would have passed a hook
   registered with only one of its required matchers. Now, for
   every `(hook, matcher)` tuple emitted by `hook_matcher_for()`,
   `settings.json` must contain an entry for that exact tuple
   (matcher + absolute command path). If not: `err NOT REGISTERED:
   <name> / <matcher>`.
4. **Exit codes.** Previously `--check` always exited 0. Now:
   `0` all OK, `1` any `DRIFT` / `MISSING` / `ORPHAN` / `NOT
   REGISTERED`, `2` the check itself errored (missing `sha256`
   tool, malformed `settings.json`, `jq` query failure). Existing
   ok/err/warn/info output prefixes and the `All checks passed` /
   `N issue(s) found` footer are preserved.

Added `tests/project-install-check-parity.bats` — ten red→green
regression tests covering each failure mode (DRIFT on all three
managed dirs, MISSING, ORPHAN, NOT REGISTERED, malformed settings,
idempotency, output-format preservation). Running
`bats tests/project-install-check-parity.bats` against pre-v2.2.0
would have produced seven failures; against v2.2.0 it is all green.

### Out of scope (sibling tickets, not in this release)

- `--fix` auto-repair mode that re-runs `install.sh --force` on
  detected drift.
- `/project:self-audit` subcommand for bidirectional rules ↔
  mechanisms audit of the skill itself (CPT-59).
- CI install-manifest regression test (CPT-60).
- Cross-skill parity (this change only audits `/project` against
  its own source; other skills would get their own similar check).

## [2.1.1] - 2026-04-16

### Added (cave-inversion protection — behavioural layer)

This repo is the home of the `/project` skill; editing `~/.claude/`
directly (instead of `skills/project/` + reinstall) produces hidden
drift. Session 2026-04-16 hit this twice in ~2 hours. The v2.1.0
commit fixed the immediate instance; this patch adds the behavioural
layer that prevents recurrence before the tool-layer (CPT-58) and
CI-layer (CPT-60) defences land.

- `CLAUDE.md` — new top-level section **"Skill-is-product rule
  (choc-skills-specific, non-negotiable)"** with the 3-question check
  operators must run before editing `~/.claude/<anything>`, the
  failure-mode narrative from 2026-04-16, and cross-refs to CPT-58 /
  CPT-59 / CPT-60 for the planned verification mechanisms.
- `.claude/sessions/*.md` × 11 — each role's startup prompt gains a
  **"Cave rule"** section so sessions load the reminder at launch.

### Tickets filed for the code-layer protection

- **CPT-58** (Bug, High) — upgrade `install.sh --check` to byte-parity
  + orphan detection. Closes the diagnostic gap that let the 2026-04-16
  drift persist unnoticed.
- **CPT-59** (Feature, Medium) — `/project:self-audit` subcommand for
  bidirectional rules ↔ mechanisms audit of the skill itself.
- **CPT-60** (Feature, Medium) — CI bats test that runs `install.sh`
  in a temp HOME and asserts the installed tree matches the skill
  source. PR-time gate.

No code changes in v2.1.1 — docs + session prompts only. Install is
idempotent: re-running `install.sh --force` after this update only
propagates the updated session prompts; existing hook registrations
and bin scripts stay put.

## [2.1.0] - 2026-04-16

### Added (hooks ship with skill — closes gap identified mid-session)

The skill now bundles its PreToolUse enforcement hooks as first-class
artefacts under `skills/project/hooks/` and installs them automatically.
Previously the hooks lived only in `~/.claude/hooks/` as one-off per-machine
additions — meaning a fresh install on a new machine had **zero** enforcement
until the operator manually replicated the hook files and settings.json
entries. This breaks the skill-install-is-sufficient contract.

- `skills/project/hooks/block-worktree-add.sh` — blocks
  `git worktree add` per MULTI_SESSION_ARCHITECTURE.md §7.1. Bypass:
  inline `GIT_WORKTREE_OVERRIDE=1` prefix per invocation.
- `skills/project/hooks/verify-jira-parent.sh` — blocks
  `mcp__claude_ai_Atlassian__createJiraIssue` and `editJiraIssue` when
  the proposed parent doesn't match `PROJECT_CONFIG.json` `.jira.epicKey`
  in the current project. Bypass: `JIRA_PARENT_OVERRIDE=1` env var (for
  deliberate cross-cutting tickets that span multiple projects).

### Changed (installer)

- `install.sh` grew a `hooks/` install step that:
  - Copies every `skills/project/hooks/*.sh` to `~/.claude/hooks/` with
    executable bit set.
  - Registers each hook in `~/.claude/settings.json` `hooks.PreToolUse[]`
    idempotently via `jq`. Mapping of hook basename → matcher(s) lives
    in a single `hook_matcher_for()` function — adding a new hook only
    requires dropping it into `hooks/` and extending that map.
  - Re-running `install.sh --force` does NOT duplicate settings.json
    entries — the (matcher, command) tuple is the idempotency key.
- `install.sh --check` now verifies each hook file exists AND is
  registered in settings.json; flags the "installed but not registered"
  edge case.
- `install.sh --uninstall` removes the skill's hook entries from
  settings.json but leaves the hook files in place at
  `~/.claude/hooks/` (they may be used by other tools; operator can
  delete manually). Prints a clear note to that effect.
- `install.sh --help` documents the new install targets and the
  `jq` dependency.
- Health-check output adds a `jq: …` line (jq is now a hard dependency
  for registration).

## [2.0.6] - 2026-04-16

### Added (worktree-creation protection, per session audit finding)

- `audit` check #16: **No unauthorised worktrees** — `/project:audit`
  now FAILs on any `.worktrees/<name>/` whose `<name>` is not a member
  of `PROJECT_CONFIG.json` `sessions.roles`, and on any role worktree
  whose HEAD branch is not `session/<role>`. Previously the audit only
  verified expected worktrees existed; it silently tolerated
  unauthorised extras and wrong-branch parking. This closes the gap
  that let `.worktrees/implementer` drift onto
  `feature/CPT-42-shell-loop-polling` undetected for a day.
- Companion pieces shipped outside the skill (all required for full
  enforcement):
  - `~/.claude/hooks/block-worktree-add.sh` — `PreToolUse` hook that
    exits 2 on any Bash tool call matching `git worktree add` unless
    the command inlines `GIT_WORKTREE_OVERRIDE=1`.
  - `~/.claude/settings.json` `hooks.PreToolUse` registration for the
    above.
  - `~/.claude/MULTI_SESSION_ARCHITECTURE.md` §7.1 — explicit
    prohibition + three-layer enforcement description.
  - `.claude/sessions/<role>.md` × 11 — each role's startup prompt
    gained a "Worktree rule" section.

## [2.0.5] - 2026-04-15

### Fixed (Codex consolidation review — P1)

- **P1**: `/loop` dispatch was silently skipping for every role when
  `PROJECT_CONFIG.json` used the default `loops/loop.md` path. The
  launcher resolved the prompt as `$WORKTREE/loops/loop.md`, but the
  file ships at the main repo root; worktrees don't carry it. Result:
  every loop-capable role (master, triager, reviewer, merger, chk1,
  chk2, fixer, implementer) hit "loop prompt file missing — skipping
  /loop dispatch" and never started its recurring task. Fix: cascade
  resolution now tries `$WORKTREE/`, then `.worktrees/master/`, then
  `$REPO_ROOT/` (same pattern already used for session prompts). The
  dispatched `/loop` command also passes the resolved absolute path so
  Claude reads the correct file regardless of cwd.

### Added

- `.worktrees/` added to root `.gitignore` — was missing on
  session/master baseline, caused `git status` noise after
  `/project:launch` creates worktree trees.

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
