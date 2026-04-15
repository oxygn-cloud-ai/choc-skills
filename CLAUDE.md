# CLAUDE.md — choc-skills

## What This Repo Is

A monorepo for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills and standalone tools. Each skill is independently versioned and released. Runs on macOS, Linux, and WSL.

Skills are discovered dynamically via `skills/*/SKILL.md` — adding a new skill directory is automatically picked up by the installer, CI, tests, and validation.

## Skill Conventions

Every skill must have a `SKILL.md` with these YAML frontmatter fields:
- `name` (must match directory name)
- `version` (semver: X.Y.Z)
- `description`
- `user-invocable: true`
- `disable-model-invocation: true`
- `allowed-tools` (minimal set)

Every skill must provide `help`, `doctor`, and `version` subcommands, either:
- Inline in SKILL.md as `### help`, `### doctor`, `### version` sections, OR
- As separate command files in `commands/help.md`, `commands/doctor.md`, `commands/version.md`

All subcommands must be colon commands (`skill:subcommand`) with their own command file — no space-separated routing. Each subcommand gets its own file with proper frontmatter, `allowed-tools`, and description.

Skills with standalone scripts (shell, Python) must place them in a `bin/` directory within the skill. The installer copies them to `~/.local/bin/` or `~/.claude/skills/<name>/bin/` and makes them executable. Do not use `orchestrator/` — `bin/` is the standard convention.

Every skill must have its own `CHANGELOG.md` in its directory.

## Validation

```bash
./scripts/validate-skills.sh    # Must exit 0 with 0 errors
```

## Testing

```bash
brew install bats-core          # or: sudo apt-get install -y bats
bats tests/                     # Must pass with 0 failures
```

## Installer Usage

```bash
./install.sh --list             # List available skills
./install.sh --force            # Install all skills (SKILL.md only)
./install.sh --force chk1       # Install one skill
./install.sh --check            # Verify installation health
./install.sh --dry-run          # Preview actions
./install.sh --uninstall chk1   # Remove one skill
./install.sh --uninstall --all  # Remove all skills
```

For skills with sub-commands (chk1, chk2, rr), use the per-skill installer for full setup:
```bash
cd skills/chk1 && ./install.sh --force
```

## CI Jobs

| Job | Runner | What it checks |
|-----|--------|---------------|
| ShellCheck | ubuntu-latest | Shell script linting at warning severity |
| Validate Skills | ubuntu-latest | All SKILL.md definitions pass validation |
| Installer Smoke Test | ubuntu + macos matrix | --list, --force, --check, verify files, --uninstall |
| Verify Checksums | ubuntu-latest | CHECKSUMS.sha256 matches regenerated output |
| File Permissions | ubuntu-latest | All .sh files are executable |
| BATS Unit Tests | ubuntu-latest | Full BATS test suite |

## How to Add a New Skill

1. `cp -r _template skills/my-skill`
2. Edit `skills/my-skill/SKILL.md` — fill frontmatter, write instructions
3. Ensure `name:` field matches directory name
4. Add `help`, `doctor`, `version` subcommands
5. Set `disable-model-invocation: true`
6. Minimize `allowed-tools`
7. Write `skills/my-skill/README.md`
8. Create `skills/my-skill/CHANGELOG.md`
9. Add skill to root `README.md` skills table
10. Run `./scripts/validate-skills.sh` — must be 0 errors
11. Run `./scripts/generate-checksums.sh` — regenerate checksums
12. Run `bats tests/` — must pass
13. Push your branch for review

## Checksums

```bash
./scripts/generate-checksums.sh   # Regenerates CHECKSUMS.sha256
```

Run this after any SKILL.md change. CI verifies the committed file matches.

## ShellCheck Patterns to Follow

- Use `shasum -a 256` (not `sha256sum` — macOS compatibility)
- Always quote variables: `"$var"` not `$var`
- Use `set -euo pipefail` in all scripts
- Use `[[ ]]` for pattern matching, `[ ]` for POSIX tests
- Use `$(command)` not backticks

## Version Locations

Each skill has its own version in its `SKILL.md` frontmatter and its own `CHANGELOG.md`:
- `skills/chk1/SKILL.md` → `version: 2.4.0`
- `skills/chk2/SKILL.md` → `version: 2.2.0`
- `skills/rr/SKILL.md` → `version: 5.1.0`

The root `install.sh` has a separate installer version (`VERSION="2.0.0"`) independent of skill versions.

## Release Process

Skills are released independently via namespaced tags:

```bash
# Release chk1 v2.3.1
git tag chk1/v2.3.1
git push --tags
```

This triggers `.github/workflows/release-skill.yml` which:
1. Validates the skill
2. Extracts the changelog from `skills/<name>/CHANGELOG.md`
3. Creates a GitHub Release named `<skill> v<version>`

The monorepo-wide `release.yml` (triggered by plain `v*` tags) is kept for milestone releases spanning all skills.

## Verification discipline (non-negotiable)

- **Verify before asserting.** Before stating any checkable fact — CLI flag, API behavior, file contents, function signature, library feature, config key, version string — run the check first (`--help`, read the file, grep the source, query the live API). No "I think", no pattern-matching, no guessing. If it is locally checkable and the answer matters, check it every time.
- **Never flip on authority alone.** If the user (or anyone else) contradicts a factual claim you made, re-verify from primary source before changing your position. Disagreeing with evidence is helpful; agreeing without evidence is worse than being wrong once.
- **Subagent output is a hypothesis, not an answer.** Treat agent summaries, tool results, and documentation snippets as claims requiring verification. Verify specific assertions (flag names, file paths, function signatures, endpoint shapes) locally before relaying them. Delegation does not launder the trust problem.
- **Checkable-claim triggers force verification.** Any sentence forming around "the flag is X", "the API returns Y", "the file contains Z", "function F does G", "version V supports W" — pause, verify, then speak.
- **Recalibrate the cost model.** Verification is nearly free. Being wrong — and especially wrong-then-flipping — is expensive. Err on the side of checking.
- **Recursive self-check.** Before reporting a task done, re-examine your solution for correctness. Read the diff. Run the tests. Trace the code paths. Never report completion on faith.
- **Never take shortcuts.** Investigate fully before determining solutions. If a path feels easy, ask whether you have actually understood the problem.
