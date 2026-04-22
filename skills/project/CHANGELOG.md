# Changelog — project

All notable changes to the project skill will be documented in this file.

## [2.4.1] - 2026-04-22

### Fixed (audit remediation from v2.4.0 /chk1 findings)

- **Bug 1 — `seed_loop_prompt` now self-heals an untracked `loops/loop.md`** on re-run. v2.4.0 left loop.md permanently untracked when the initial `git commit` failed (e.g. no `user.email` configured, or a pre-commit hook blocked) because the worktree was registered and the outer loop skipped the role entirely on subsequent runs. v2.4.1 rewrites `seed_loop_prompt` as a three-case handler — (A) tracked → no-op, (B) untracked → commit + push (`[heal]` line), (C) missing → seed from template — and the outer role loop now calls `seed_loop_prompt` in `--execute` mode even for already-registered worktrees so the heal path is reachable. New BATS test 21 reproduces the v2.4.0 failure state and confirms v2.4.1 commits the orphaned file.

- **Bug 2 — `commands/config.md` "Install missing loop.md" example no longer assumes `loops/` parent.** The example code used `mkdir -p ".worktrees/$role/loops"` but wrote to `".worktrees/$role/<prompt-path>"`, which only matched when `<prompt-path>` was the default `loops/loop.md`. For user-customised prompt paths (e.g. `custom/foo.md`) the `mkdir` created the wrong dir and the `cp` failed. Replaced the hardcoded `"loops"` with `"$(dirname ".worktrees/$role/<prompt-path>")"` so any prompt-path is handled correctly. Natural-language instruction to Claude; no runtime script change.

- **Bug 3 — `install.sh` Step 5.5 now warns loudly when zero templates are installed.** v2.4.0 reported `ok "loop templates: 0 file(s)"` when `templates/loops/` was present but empty — silent success for a broken install. Added `[ "$template_count" -gt 0 ] || warn "Zero loop templates found …"` so developers notice immediately.

- **Risk 2 — removed hardcoded `LOOP_CAPABLE_ROLES` array in `install.sh`.** v2.4.0 maintained the canonical role list in four places (`install.sh`, `commands/launch.md`, `commands/new.md`, `commands/config.md`) — a drift risk. v2.4.1 derives the expected template set from `${TEMPLATES_SOURCE}/loops/*.md` filenames. The templates directory itself is now the single source of truth: dropping a new `templates/loops/<role>.md` and re-running `install.sh --force` makes `--check` pick it up automatically. If the source templates directory is missing or empty, `--check` emits a dedicated warning/error rather than silently reporting a match against a zero-element list.

- **Risk 1 — `git push` failures in `seed_loop_prompt` are no longer silent.** v2.4.0 piped `git push` stderr to `/dev/null` and swallowed failures via `|| true`, so network / auth / protected-branch / diverging-tip errors never reached the operator and the single-machine vs multi-machine divergence claim was too strong. v2.4.1 captures stderr and emits a `[warn]` line with the failure reason on push failure. Commit still happens locally; only the transport-layer failure is surfaced. New `_push_loop_commit` helper is shared between seed and heal paths.

### Added

- **BATS test 21 — TRACK path + loop seeding.** v2.4.0 exercised seeding on REUSE and CREATE paths but not TRACK (local branch missing, remote branch exists). Closed the coverage gap.
- **BATS test 22 — heal path.** Explicitly reproduces the v2.4.0 Bug 1 scenario (worktree registered, loop.md untracked on disk) and asserts v2.4.1 commits it with a `[heal]` output line.

Full BATS suite: 121 → 123 pass. `install.sh --check`: still 16/16 with the new source-derived template check.

### Known out-of-scope (unchanged from v2.4.0)

- `/project:new` Step 9's worktree-creation loop still uses bare `git worktree add` — separate ticket.

## [2.4.0] - 2026-04-22

### Added

- **Shipped per-role loop.md templates** (`skills/project/templates/loops/<role>.md`, 8 files for master, triager, reviewer, merger, chk1, chk2, fixer, implementer). Previously loop prompts existed only as an inline triager example + bullet descriptions in `commands/new.md` Step 10.5 — every new project had to hand-author them and existing projects that skipped this step had empty loops. Templates now ship with the skill and are installed to `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/project/templates/loops/`. `install.sh --check` verifies all 8 files are present.

- **`project-materialise-worktrees.sh --execute` now seeds `loops/loop.md`** for loop-configured roles. For each role whose worktree is newly created and that has an entry in `PROJECT_CONFIG.json` `sessions.loops`, the matching template from `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/project/templates/loops/<role>.md` is copied into `.worktrees/<role>/loops/loop.md` and committed to `session/<role>`. Idempotent — does not overwrite an existing `loop.md` (user customisations survive re-materialisation). `/project:launch` Step 2.5 therefore produces a fully-loop-capable set of worktrees in one shot. `/project:audit` check #13 (loop prompt files) stops FAILing post-materialisation.
  - New helper flags: `--templates-dir <path>` (override for tests + air-gapped setups), `--skip-loop-seed` (worktree-only mode).
  - Warn-and-continue semantics: a loop-configured role with a missing template file prints a `[warn]` line and the worktree is still materialised. No hard failure on seeding.

- **`commands/config.md` "Configure loops" auto-installs missing `loop.md`** from the templates directory when the user selects a role whose prompt file does not exist. Previously the instructions said "offer to create it with a role-appropriate template" but didn't specify the source — now it's explicit: copy `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/project/templates/loops/<role>.md` and commit to `session/<role>`. No confirmation prompt because installing a file that does not exist cannot destroy anything.

- **`commands/new.md` Step 10.5 rewritten** to copy from the shipped templates directory instead of inline template strings + bullet-list role descriptions. Single source of truth for template content across `/project:new`, `/project:config`, and the materialise helper.

- **`/project:audit` check #17 — `AskUserQuestion` declared in installed skill files.** Verifies `${CLAUDE_CONFIG_DIR}/skills/project/SKILL.md` and `commands/project/{config,launch,new}.md` still contain the string `AskUserQuestion` in their frontmatter — guards against tampering with installed outputs that would silently break interactive prompts. Explicitly documents that runtime availability of `AskUserQuestion` is a Claude Code harness property and cannot be verified by a shell audit.

- **`install.sh --check` now verifies the `AskUserQuestion` declaration is intact** and prints a one-line note explaining that runtime availability is harness-controlled. Error on missing declaration directs the user to `install.sh --force` to restore.

- **Graceful `AskUserQuestion` fallback in `commands/config.md`, `launch.md`, `new.md`.** Each file now opens `<process>` with a "Prompting fallback" section that documents the pattern once: when `AskUserQuestion` is unavailable, the command falls back to a numbered-list plain-text prompt and prints a one-line install hint (`AskUserQuestion is a Claude Code built-in. Update Claude Code or enable it in your harness configuration to get structured prompts.`). Individual "Use AskUserQuestion" references throughout the files are subject to this fallback without needing to restate it.

- **BATS coverage extended** to 20 tests in `tests/project-materialise-worktrees.bats` — 5 new cases covering loop.md seeding: template-present happy path, non-loop-configured role (no seed), template-missing role (warn, continue), `--skip-loop-seed` flag, and idempotent re-seeding (existing `loop.md` on branch preserved).

### Changed

- **`install.sh`** adds a new Step 5.5 that copies `templates/` to `${SKILL_TARGET}/templates/`. `--check` grows two new checks: "Loop templates: 8/8 roles present" and "AskUserQuestion declared in SKILL.md + config/launch/new command files". `--help` INSTALLS TO section lists the templates dir and clarifies that bin scripts include the new materialise helper. Post-install summary shows the templates dir.

- **`hooks/block-worktree-add.sh`** unchanged in v2.4.0 — its v2.3.0 comment naming `/project:new` and `/project:launch` as the authorised `GIT_WORKTREE_OVERRIDE=1` boundaries remains accurate.

### Known out-of-scope

- `/project:new` Step 9's worktree-creation loop still uses bare `git worktree add` (no `GIT_WORKTREE_OVERRIDE=1`) — unchanged from v2.3.0's known-issue note. That's a separate ticket.

## [2.3.0] - 2026-04-21

### Added

- **`/project:launch` now materialises missing role worktrees on demand** (CPT follow-up to `/project:audit` gaps). Previously Step 1 / Step 2 STOPped with "No worktrees found at $REPO_ROOT/.worktrees/. Run /project:new …" whenever `.worktrees/` was missing or incomplete, forcing the user to pivot to a different command. Now the user invokes `/project:launch` once; the new Step 2.5 surfaces a plan of missing role worktrees and — on `y` confirmation — creates them via a new helper script before proceeding to the normal tmux + Claude launch flow. Scope is intentionally **single-project mode only**: `--all` still skips repos without `.worktrees/` (documented, not a bug — a repo without `.worktrees/` is signalling that it isn't multi-session, and bulk materialisation would silently promote unrelated repos).

- **New helper `skills/project/bin/project-materialise-worktrees.sh`** owns the mechanics. Installed automatically by `install.sh` to `~/.local/bin/`. Contracts:
  - `--list` prints the missing-worktree plan (one line per role with action ∈ REUSE / TRACK / CREATE / CONFLICT / STRAY) and exits 0. `--execute` performs the `git worktree add` calls.
  - Branch precedence: local `refs/heads/session/<role>` (REUSE, no `-b`) → `refs/remotes/origin/session/<role>` (TRACK with `--track -b`) → default branch (CREATE with `-b`). Branch already checked out elsewhere is reported as CONFLICT — never silently moved.
  - Presence uses `git worktree list --porcelain`, not `[ -d .worktrees/<role> ]` — stray plain directories are flagged as STRAY so the operator can inspect before the script stomps them.
  - Default-branch detection order: `--default-branch` flag → `PROJECT_CONFIG.json .github.defaultBranch` → `git symbolic-ref --short refs/remotes/origin/HEAD` → exit 2. No hardcoded `main` fallback (fixes repos on `master` / `develop` / custom defaults).
  - Runs `git worktree prune` at start so a previously `rm -rf`'d worktree doesn't block re-materialisation with "already registered".
  - Exit codes: 0 success, 1 usage, 2 missing deps / undetectable default branch, 4 partial failure. `/project:launch` Step 2.5 surfaces exit 4's stderr and aborts the launch; operator fixes conflicts and re-runs.

- **BATS coverage:** new `tests/project-materialise-worktrees.bats` — 15 tests covering `--help`, `--list`, `--execute`, branch precedence (REUSE / TRACK / CREATE), default-branch detection (config / symbolic-ref / `--default-branch` override), stray-directory detection, branch-in-use CONFLICT handling, and stale-admin-data pruning. All 15 green against the v2.3.0 implementation.

### Changed

- **`hooks/block-worktree-add.sh` banner comment** now names the two authorised automation boundaries for inline `GIT_WORKTREE_OVERRIDE=1` — `/project:new` (scaffold) and `/project:launch` Step 2.5 (gap-fill). Any other skill-level bypass is a policy violation. Hook behaviour unchanged — this is documentation only, addressing a gap raised in pre-merge review: "you're normalising around a policy exception without writing down the policy".

- **`skills/project/commands/launch.md`** success-criteria list expanded with 7 new items covering Step 2.5, presence-check semantics, branch precedence, default-branch detection, `--dry-run` and `--all`-mode interactions, and the `GIT_WORKTREE_OVERRIDE` policy exception.

### Known out-of-scope

- `/project:new` Step 9's worktree-creation loop still uses bare `git worktree add` (no `GIT_WORKTREE_OVERRIDE=1` prefix) — a pre-existing issue that makes `/project:new` fail on machines with the hook installed. Filed for a follow-up change; not fixed here to keep this change focused.

## [2.2.2] - 2026-04-21

### Fixed (CPT-175 — Codex adversarial-review follow-ups to CPT-174)

- **`/project --uninstall` no longer collateral-deletes unrelated PreToolUse sibling hooks** (P2, CPT-175). The previous `remove_hook_registration()` jq filter `map(select((.hooks // []) | all(.command != $c)))` dropped the entire matcher object whenever any of its hooks matched — so if a user or another tool had grouped commands under the same matcher (legal `settings.json` shape), uninstalling `/project` silently corrupted their config by removing the siblings too. Reproduction: a `Bash` matcher containing `[block-worktree-add.sh, unrelated-other-tool.sh]` lost both on uninstall. Replaced with a two-step rebuild — `map(.hooks = ((.hooks // []) | map(select(.command != $c))))` strips only the target command from each matcher's `.hooks[]`, then `map(select((.hooks // []) | length > 0))` drops matchers that genuinely became empty. Unrelated siblings survive; empty matcher objects are cleaned up. New BATS regression in `tests/install-claude-config-dir.bats` ("CPT-175: project --uninstall preserves unrelated sibling PreToolUse hooks") asserts sibling survival directly; bats suite 12/12 post-fix.

- **Hardcoded `~/.claude/` leftovers cleaned across shipped skill product** (P3, CPT-175):
  - `hooks/{block-worktree-add,verify-jira-parent}.sh` — banner lines `BLOCKED by ~/.claude/hooks/...` replaced with `BLOCKED by ${BASH_SOURCE[0]}` so the printed path matches the hook's actual install location on `CLAUDE_CONFIG_DIR` machines.
  - `global/PROJECT_STANDARDS.md` "Finding this document" — removed the leaked machine-specific `/Users/oxygnserver01/.claude/PROJECT_STANDARDS.md` line and generalized the path discussion to `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/PROJECT_STANDARDS.md`.
  - `global/MULTI_SESSION_ARCHITECTURE.md` — same fix for its own "Finding this document" block (removed second `/Users/oxygnserver01/...` leak), and generalized the header "Referenced by" list to factor the prefix. All body-text `~/.claude/` references converted to `$CLAUDE_DIR/` to match the paths-note convention.
  - `README.md` — added a Paths note box at the top defining `$CLAUDE_DIR`; updated prerequisites (removed stale "NOT installed by this skill" claim — v2.2.0 does ship them); fixed manual-uninstall snippet to resolve `$CLAUDE_DIR` inline; added a troubleshooting row for "hooks don't fire on CLAUDE_CONFIG_DIR machine".
  - `USER_GUIDE.md` — added same Paths note; replaced every literal `~/.claude/` in body with `$CLAUDE_DIR/`; version stamp bumped to 2.2.2.
  - Final sweep: `grep -rn '/Users/' skills/project/` returns zero hits; no runtime `~/.claude/` references remain in shipped product except the single Paths-note explaining the convention.

## [2.2.1] - 2026-04-20

### Fixed

- **Installer + skill runtime now honour `CLAUDE_CONFIG_DIR`** (CPT-174 part 2). The v2.2.0 installer introduced `HOOKS_SOURCE` / `HOOKS_TARGET` / `GLOBAL_SOURCE` / `GLOBAL_TARGET` / `SETTINGS_FILE` — all hardcoded against `${HOME}/.claude`. On machines where Claude Code resolves its config dir via `$CLAUDE_CONFIG_DIR` (e.g. `/workspace/.claude`), the installer's PreToolUse hook registrations landed in the wrong `settings.json` and the enforcement hooks (`block-worktree-add.sh`, `verify-jira-parent.sh`) were silently inert — the exact cave-rule failure mode the skill was built to prevent (see `skills/project/CLAUDE.md` "Failure mode this rule exists to prevent"). Installer now resolves `CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"` and uses `${CLAUDE_DIR}` for all install targets including hooks, global docs, and `settings.json`. All nine command files (`audit`, `config`, `doctor`, `help`, `launch`, `new`, `status`, `update`, `version`) + `SKILL.md` now use inline `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/` for every runtime path, so `/project:audit` etc. work correctly on `CLAUDE_CONFIG_DIR` machines. Companion to PR #45 on `main` which fixes the same pattern at the v1.2.10-level code.

Zero behaviour change for machines without `CLAUDE_CONFIG_DIR` set — the `:-` fallback preserves the default `$HOME/.claude` resolution.

## [2.2.0] - 2026-04-19

### Added

- **`skills/project/global/`** directory ships two previously-unshipped
  runtime dependencies as skill product:
  - `MULTI_SESSION_ARCHITECTURE.md` — full role protocol and §-numbered
    rules referenced by every `session/<role>` prompt and by
    `commands/audit.md` rules 8/9/16.
  - `PROJECT_STANDARDS.md` — branch-protection, CI, and documentation
    contract referenced by `commands/audit.md` rules 3/8/10/11.

  `install.sh` now copies both into `~/.claude/` on every `--force` run
  (idempotent, overwrites any stale local copy — customisation belongs
  upstream in the skill source, not in the installed artefact). Previously
  these were treated as user-owned global config; a fresh machine install
  would pass `install.sh --check` with 2 errors because nothing bootstrapped
  them. This closes that gap.

### Changed

- `install.sh --help` moves the two docs from **REQUIREMENTS** to
  **INSTALLS TO** — they are now skill-shipped.
- Project-level `CLAUDE.md` § "Skill-is-product rule" updated to reflect
  that `~/.claude/MULTI_SESSION_ARCHITECTURE.md` and
  `~/.claude/PROJECT_STANDARDS.md` are skill product (installed by
  `skills/project/install.sh`), not user-owned global config.

## [2.1.6] - 2026-04-17

### Fixed

- **[CPT-50]** `project-launch-session.sh` mktemp templates at lines 197 and
  312 used `-XXXXXX.sh` — BSD `mktemp(1)` (macOS) and GNU `mktemp(1)` both
  require the `X` placeholders to be trailing, so a filename suffix after
  them silently returns the literal template unchanged. Changed both
  templates to `.XXXXXX` (trailing). The setup script is invoked via
  `exec bash <path>` so the `.sh` extension was never functional. Without
  this fix, two concurrent `/project:launch` runs of the same role (or any
  re-launch over a stale `/tmp` file) would collide on the deterministic
  path and the second attempt would die with `mkstemp failed: File exists`.

### Tests

- Added two regression tests to `tests/project-launch-session.bats`:
  - `launch-session: setup script path is randomized (CPT-50)` — asserts the
    printed setup-script path matches `/tmp/project-launch-<role>.<6alnum>$`
    and does not contain the literal `XXXXXX` placeholder.
  - `launch-session: two sequential dry-runs produce distinct setup script
    paths (CPT-50)` — asserts two back-to-back dry runs of the same
    project+role produce different `/tmp` paths.

## [2.1.5] - 2026-04-17

### Changed

- `/project:launch` now hardcodes `--effort max` into every Claude launch so
  every role-session starts in maximum thinking-effort mode (suited to the
  deep coordination, planning, and audit work role-sessions do). Seeded in the
  Step 5 flag builder before any conditional flags; not a Step 5 UI checkbox.

### Removed

- `--max-turns` launch option (Step 5 item #5 and follow-up question) removed.
  The `claude` CLI no longer accepts `--max-turns`; passing it would have
  produced an "unknown option" error at launch — the option was dead code.
  Step 5 UI now has 7 options (prompt pipe, skip-permissions, resume, model,
  skip idle, verbose, dry run) instead of 8. `USER_GUIDE.md` and `README.md`
  updated in lockstep.

## [2.1.4] - 2026-04-17

**Supersedes 2.1.3.** 2.1.3 introduced three audit-check refinements; a Codex
review on the same day identified a semantic inversion in the CI-tracking
deviation mechanism, an over-permissive #16 regex, and drift across skill
docs. 2.1.4 lands the corrected design and propagates it through every
affected surface. 2.1.3 was never released outside the source repo.

### Changed

- **`/project:audit` check #8 (CI failure tracking) and #9 (CI recovery
  tracking) now auto-detect mode by presence of `notify-failure` /
  `notify-recovery` jobs in workflow files.** Present → PASS (workflow-jobs
  mode: CI files to Jira directly using GitHub Actions secrets). Absent →
  SKIP (Master-session mode: the default per PROJECT_STANDARDS.md §3 and
  MULTI_SESSION_ARCHITECTURE.md §5 — Master polls `gh run list` on the host
  machine and files Jira tasks; no Jira secrets in GitHub Actions). The
  2.1.3 deviation-entry mechanism (which had inverted semantics between
  global CLAUDE.md and this check) is removed — no deviation entry is
  required to express either mode. `~/.claude/CLAUDE.md` rule updated to
  match.

- **`/project:audit` check #16 (worktree HEAD branches) is now role-aware.**
  Per MULTI_SESSION_ARCHITECTURE.md §1, only the fixer and implementer roles
  write code; all other roles are read-only. The check now permits: fixer
  HEAD on `session/fixer` OR matching `^fix/<JIRA_KEY>-[0-9]+`; implementer
  HEAD on `session/implementer` OR matching `^feature/<JIRA_KEY>-[0-9]+`;
  all other role worktrees must be on `session/<role>` exactly. Any other
  HEAD value FAILs (indicates a re-pointed worktree, forbidden). 2.1.3's
  regex was too permissive — it would have silently blessed a reviewer or
  chk1 worktree accidentally left on a feature branch. `<JIRA_KEY>` is read
  from `jira.projectKey` in PROJECT_CONFIG.json.

- **`/project:audit` check #11 softened.** The check now FAILs only when the
  9 GitHub-default label names are present (`bug`, `documentation`,
  `duplicate`, `enhancement`, `good first issue`, `help wanted`, `invalid`,
  `question`, `wontfix`). Project-specific labels declared in
  `.github/labels.yml` (scope labels like `skill:*`, category labels,
  dependabot labels, etc.) are intentional PR-labelling taxonomy and do not
  FAIL the check. Previously the check required `length == 0`, which was
  incompatible with any repo using `labels.yml` to label PRs (dependabot,
  scoped review workflows, etc.).

- **`/project:new` Step 6 no longer claims to delete "all labels".** It now
  deletes only the 9 GitHub-defaults, and guides the user to `.github/labels.yml`
  + sync workflow for any project-specific PR-labelling taxonomy. The
  Step 11 CI scaffolding no longer mandates `notify-failure` /
  `notify-recovery` jobs — by default scaffolds a bare CI workflow and
  documents the workflow-jobs alternative as opt-in.

- **`/project:status` reports `CI failure tracking: <mode>`** instead of the
  one-mode `notify-failure: configured/missing`, matching the two-mode model.

- **Standards documents updated in lockstep:**
  `~/.claude/MULTI_SESSION_ARCHITECTURE.md §7.1` and
  `~/.claude/PROJECT_STANDARDS.md §7` now describe the role-aware #16 rule.
  `~/.claude/PROJECT_STANDARDS.md §8` audit checklist now says "No default
  GitHub labels present" and cross-references `.github/labels.yml` as the
  acceptable taxonomy source.

- **`USER_GUIDE.md` updated:** check count corrected from 13 to 16 and
  re-synced with `commands/audit.md`; labels / CI rows reflect the new
  two-mode / project-labels-allowed model; skill version stamps refreshed
  to 2.1.4.

- **`PHILOSOPHY.md` restored from commit `62c467c` and refreshed:** design
  principle #3 updated — `GITHUB_CONFIG.md` reference replaced with
  `PROJECT_CONFIG.json` (the config format has moved per schema description).

- **`CLAUDE.md` (choc-skills, the cave rule) extended** with an explicit
  "user-owned global config" exception category. Files that are never
  copied by any skill's `install.sh` (the user's `~/.claude/CLAUDE.md`,
  the standards docs, keybindings, memory, the non-hook sections of
  `settings.json`) are editable in place because they have no skill
  source-of-truth by design. The cave rule still forbids direct edits to
  skill install outputs.

### Fixed

- Branch protection on `main` no longer carries a
  `required_pull_request_reviews: {count: 1}` field (set null per
  PROJECT_STANDARDS.md §1 — reviews happen via the Reviewer session + Jira,
  not GitHub PR reviews).

- `PHILOSOPHY.md` restored to the repo root (was missing — restored
  content from commit `62c467c`; the file had been added and
  subsequently reverted without restoration).

## [2.1.3] - 2026-04-17 (superseded by 2.1.4)

Initial attempt at the audit-check refinements that 2.1.4 delivers in
corrected form. Introduced a CI-tracking deviation mechanism whose semantics
contradicted `~/.claude/CLAUDE.md`; and a `#16` regex that accepted active-work
branch patterns in any role worktree (including read-only roles, which
should never carry such branches). Codex review caught both. 2.1.4 ships the
corrected design. Do not pin to 2.1.3.

## [2.1.2] - 2026-04-17

### Fixed

- `/project:launch` now opens one iTerm2 window with one tab per role on macOS,
  scoped to the current project's tmux session. Previously the command created
  the tmux session + 11 windows but never touched iTerm2, so the user had to
  attach manually from whichever terminal was focused. A sibling
  `tmux-iterm-tabs.sh` script existed but iterated `tmux ls` globally and
  filtered by tmux env vars `PROJECT`/`ROLE`/`ROLE_INDEX` that
  `project-launch-session.sh` never set — it found zero matches and did
  nothing useful. See `skills/iterm2-tmux/CHANGELOG.md` for the helper-side
  change.

### Added

- **Step 8a — iTerm2 tab open**: after all roles launch, `launch.md` invokes
  `~/.local/bin/tmux-iterm-tabs.sh --session "$PROJECT_SLUG"` in single-project
  mode on macOS with iTerm2 running. Dry-run, `--all` mode, non-macOS, and no
  iTerm2 all skip the step. AppleScript/helper failure does not abort the
  launch — the tmux session stays up and the report tells the user how to
  attach manually.
- Launch report now includes an `iTerm2:` line (`opened` / `skipped` / `failed`).

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
