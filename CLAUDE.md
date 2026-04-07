# CLAUDE.md — claude-skills

## What This Repo Is

A shell-only skills repository for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Contains 3 installable skills and 1 standalone tool. Runs on macOS, Linux, and WSL.

## Directory Structure

```
claude-skills/
  install.sh           Root installer (skills only)
  scripts/
    validate-skills.sh Validates all skill definitions
    generate-checksums.sh  Generates CHECKSUMS.sha256
  tests/               BATS test suite
  skills/
    chk1/              Adversarial implementation audit
    chk2/              Web service security audit
    rr/                Risk register assessment
    iterm2-tmux/       Standalone tool (own installer, no SKILL.md)
  _template/           Skeleton for new skills
```

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

## Validation

```bash
./scripts/validate-skills.sh    # Must exit 0 with 0 errors
```

## Testing

```bash
brew install bats-core
bats tests/                     # Must pass with 0 failures
```

## Installer Usage

```bash
./install.sh --list             # List available skills
./install.sh --force            # Install all skills
./install.sh --force chk1       # Install one skill
./install.sh --check            # Verify installation health
./install.sh --dry-run          # Preview actions
./install.sh --uninstall chk1   # Remove one skill
./install.sh --uninstall --all  # Remove all skills
```

## CI Jobs

| Job | Runner | What it checks |
|-----|--------|---------------|
| ShellCheck | ubuntu-latest | Shell script linting at warning severity |
| Validate Skills | ubuntu-latest | All SKILL.md definitions pass validation |
| Installer Smoke Test | ubuntu + macos matrix | --list, --force, --check, verify files, --uninstall |
| Verify Checksums | ubuntu-latest | CHECKSUMS.sha256 matches regenerated output |
| File Permissions | ubuntu-latest | All .sh files are executable |
| BATS Unit Tests | macos-latest | Full BATS test suite |

## How to Add a New Skill

1. `cp -r _template skills/my-skill`
2. Edit `skills/my-skill/SKILL.md` — fill frontmatter, write instructions
3. Ensure `name:` field matches directory name
4. Add `help`, `doctor`, `version` subcommands
5. Set `disable-model-invocation: true`
6. Minimize `allowed-tools`
7. Write `skills/my-skill/README.md`
8. Add to README.md skills table
9. Run `./scripts/validate-skills.sh` — must be 0 errors
10. Run `./scripts/generate-checksums.sh` — regenerate checksums
11. Run `bats tests/` — must pass
12. Update CHANGELOG.md

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

When bumping version, update ALL of these:
- `install.sh` line 4: `VERSION="X.Y.Z"`
- Each `skills/*/SKILL.md` frontmatter: `version: X.Y.Z` (skill-specific versions)
- `CHANGELOG.md`: add version section

## Release Process

1. Bump version in all locations above
2. Update CHANGELOG.md with release date
3. Create and push a tag: `git tag vX.Y.Z && git push --tags`
4. `release.yml` triggers automatically — validates, installs, checksums, creates GitHub Release
