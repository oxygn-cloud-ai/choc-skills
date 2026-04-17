# Changelog — chk1

All notable changes to the chk1 skill will be documented in this file.

## [2.4.8] - 2026-04-18

### Fixed
- **Conflicting action flags in `install.sh` now die at parse time**: CPT-76's order-independent argparse silently overwrote `ACTION` on every mode flag, so `./install.sh --help --uninstall` ran uninstall, `--uninstall --check` ran check (skipping the uninstall the user intended). Wrapper scripts that composed flags to go "verify then uninstall" got unpredictable behaviour and could turn a read-only probe into an unexpected destructive action. Parser now rejects conflicting action flags with `Conflicting action flags: --<prev> and <current> — pick one` while still accepting the same flag twice (idempotent) and freely combining `--force` with any action (CPT-123).

**Note on version renumbering**: This entry originally targeted 2.4.7 on `fix/CPT-123-installer-conflict-detection`, but CPT-115 (update xargs allowed-tools) landed on `main` and claimed 2.4.7 first. Renumbered to 2.4.8 as part of the merge sequence; no code semantics changed from the original branch.

## [2.4.7] - 2026-04-17

### Fixed
- **`/chk1 update` tool-denied under CPT-32 enforcement**: CPT-19 rewrote the update body to fetch sub-commands in parallel via `echo "…" | tr ' ' '\n' | xargs -P 4 -I{} curl ...` but didn't extend `skills/chk1/commands/update.md`'s `allowed-tools` frontmatter. Under per-command enforcement, `xargs`, `echo`, and `tr` were denied and the parallel-download stage failed silently, leaving sub-commands un-updated. Added `Bash(xargs *), Bash(echo *), Bash(tr *)` to the update allowed-tools list (CPT-115).

## [2.4.6] - 2026-04-17

### Fixed
- **`chk1:fix` iteration cap trigger scope**: Round 2 of the fix→audit→fix loop no longer requires a new-regression to trigger. The cap now fires when `/chk1 quick` reports any remaining findings — new regressions OR unresolved original findings — matching the commit-message / CHANGELOG contract of "maximum of 2 fix→audit rounds total". Prior text silently denied Round 2 to the common partial-fix case (CPT-95).

## [2.4.5] - 2026-04-17

### Fixed
- **Exit-code contract**: `install.sh --check` now exits non-zero when issues are reported (was unconditional `exit 0`). Aligns with root `install.sh --check` behavior so CI/automation can detect unhealthy installations by exit code (CPT-77).

### Note on version renumbering
- CPT-77's source branch bumped 2.4.3 → 2.4.4 in isolation. By merge time, 2.4.4 (CPT-76) had already shipped, so the Merger renumbered CPT-77 to 2.4.5. No code semantics changed.

## [2.4.4] - 2026-04-17

### Fixed
- **Argument parsing**: `install.sh` now uses an order-independent while-loop parser instead of positional `$1` checks. `-f --uninstall` (and other flag combinations) now uninstalls instead of silently re-installing. Unknown flags now exit non-zero (CPT-76).

## [2.4.3] - 2026-04-17

### Added
- **Security**: YAML frontmatter with scoped `allowed-tools` added to all 8 chk1 sub-command files. Tool allocations follow least-privilege (CPT-39):
  - `all`, `architecture`, `quick`, `scope`, `security`: `Read, Grep, Glob, Bash(git *)`
  - `fix`: adds `Edit, Write, AskUserQuestion`
  - `github`: adds `Bash(gh *), AskUserQuestion`
  - `update`: scoped `Bash` (`git`, `bash install.sh`, `curl`, `mkdir`, `grep`, `sed`) — no catch-all

### Note on version renumbering
- CPT-39's source branch bumped 2.4.0 → 2.4.1 in isolation. By merge time, 2.4.1 (CPT-13) and 2.4.2 (CPT-19) had both shipped, so the Merger renumbered CPT-39 to 2.4.3. No code semantics changed.

## [2.4.2] - 2026-04-17

### Changed
- **Performance**: `all.md` no longer re-reads SKILL.md (already loaded by router). `SKILL.md` scope detection references pre-flight `git diff --stat` instead of re-running (CPT-19).
- **Performance**: `update.md` parallelises curl downloads with `xargs -P 4` (was sequential `for` loop) (CPT-19).

### Note on version renumbering
- CPT-19's source branch bumped 2.4.0 → 2.4.1 in isolation. By merge time, 2.4.1 (CPT-13) had already shipped, so the Merger renumbered CPT-19 to 2.4.2. No code semantics changed.

## [2.4.1] - 2026-04-14

### Fixed
- `/chk1:fix` now has a maximum of 2 fix→audit rounds. After the cap, remaining findings are presented as a summary instead of continuing to loop. (CPT-13)

## [2.4.0] - 2026-04-09

### Changed
- **Security**: Restricted `Bash(*)` to explicit command patterns (`Bash(git *)`, `Bash(gh *)`, `Bash(curl *)`)
- Per-skill installer now cleans stale command files before installing new version
- Per-skill installer now creates `.source-repo` marker for `/chk1 update`

### Fixed
- Stale sub-command files no longer persist after upgrade

## [2.3.0] - 2026-04-07

### Added
- New `/chk1 github` subcommand logs audit findings as GitHub Issues with P1-P4 priority labels, duplicate detection, milestone assignment, and automatic label creation
- New `/chk1 update` subcommand pulls latest chk1 from the GitHub repo (uses `.source-repo` marker if present, falls back to curl)
- Added `Bash(gh *)` and `Bash(curl *)` to allowed-tools

## [2.1.0] - 2026-04-03

### Added
- 8 adversarial audit checks added to the full audit mode

## [2.0.0] - 2026-04-03

### Added
- Sub-command architecture: `/chk1 quick`, `/chk1 security`, `/chk1 scope`, `/chk1 architecture`, `/chk1 fix`
- Per-skill installer with router and command file installation

## [1.1.0] - 2026-03-31

### Added
- Initial release: adversarial implementation audit with 8 audit sections
- Auto-scope detection (commit range, branch, SHA, or auto-detect recent changes)
- Structured output format with audit metadata, per-file analysis, and remediation plan
