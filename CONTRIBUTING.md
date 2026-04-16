# Contributing to Claude Skills

## Quick Start

1. Copy the template: `cp -r _template skills/my-skill`
2. Edit `skills/my-skill/SKILL.md` — fill in frontmatter and instructions
3. Edit `skills/my-skill/README.md` — document usage
4. Validate: `./scripts/validate-skills.sh`
5. Test: `./install.sh my-skill && /my-skill help && /my-skill doctor`
6. Submit a PR

## Skill Requirements

### SKILL.md Frontmatter (required fields)

```yaml
---
name: my-skill              # Must match directory name
version: 1.0.0              # Semantic versioning (MAJOR.MINOR.PATCH)
description: What it does    # One-line description
user-invocable: true         # Must be true
---
```

### Optional frontmatter fields

```yaml
disable-model-invocation: true   # Recommended — prevents Claude from self-invoking
allowed-tools: Read, Grep, Glob  # Restrict tool access (security best practice)
argument-hint: [args | help]     # Shown in command completion
```

### Required Subcommands

Every skill MUST implement these three subcommands in its SKILL.md:

1. **`help`** — Display usage guide and stop
2. **`doctor`** — Run environment health checks with `[PASS]`/`[WARN]`/`[FAIL]` verdicts
3. **`version`** — Output version string and stop

Check $ARGUMENTS before proceeding to main logic. If it matches a subcommand, execute it and stop.

### Pre-flight Checks

Skills should silently verify prerequisites before running. If any check fails, output a clear error message and stop. Do not attempt the main operation.

## allowed-tools Policy

Follow the principle of least privilege:

| If your skill needs to... | Use |
|---------------------------|-----|
| Read files only | `Read, Grep, Glob` |
| Read files + git history | `Read, Grep, Glob, Bash(git *)` |
| Read files + run any command | `Read, Grep, Glob, Bash(*)` |
| Full access (rare) | `Read, Grep, Glob, Bash(*), Write, Edit` |

**Never** request more tools than needed. Skills that write files or make network calls require extra scrutiny during review.

## Commit Messages

Follow the existing convention:

```
feat: add new feature
fix: fix a bug
docs: documentation only
refactor: code change that neither fixes nor adds
test: add or update tests
chore: maintenance (CI, deps, etc.)
```

Keep the first line under 72 characters. Add a body for context when the change is non-trivial.

## Pull Request Process

1. Ensure `./scripts/validate-skills.sh` passes
2. Ensure `shellcheck` passes on any `.sh` files you changed
3. Update the **per-skill** `CHANGELOG.md` (e.g., `skills/chk1/CHANGELOG.md`) under `## [Unreleased]`
4. Update root `README.md` if adding a new skill (add to the skills table)
5. Regenerate checksums: `./scripts/generate-checksums.sh`
6. One approval required to merge

## Security Review Checklist

For new skills or significant changes, reviewers will check:

- [ ] `allowed-tools` is minimal
- [ ] No hardcoded secrets or credentials
- [ ] No instructions to access sensitive user files
- [ ] No unrestricted network access
- [ ] No file writes outside the skill's intended scope
- [ ] `disable-model-invocation: true` is set
- [ ] Subcommands (help, doctor, version) are implemented
- [ ] Pre-flight checks fail gracefully with clear errors
- [ ] Version follows semver

## Testing

### Local validation

```bash
./scripts/validate-skills.sh
```

### Manual testing

```bash
./install.sh my-skill
# In Claude Code:
/my-skill help      # Should show usage
/my-skill doctor    # Should show health checks
/my-skill version   # Should show version
/my-skill           # Should run main logic
```

### CI

All PRs run the CI pipeline automatically (`.github/workflows/ci.yml`):
- ShellCheck on all `.sh` files
- Skill validation
- Installer smoke test
- File permission checks

## File Structure

```
skills/my-skill/
  SKILL.md       # Required — skill definition
  README.md      # Required — user documentation
  CHANGELOG.md   # Required — per-skill changelog (Keep a Changelog format)
  install.sh     # Optional — per-skill installer for sub-commands/routers
  commands/      # Optional — sub-command .md files
```

Standalone tools (no SKILL.md) are ignored by the root installer and must have their own install/uninstall scripts.

## Releasing a Skill

Skills are released independently via namespaced tags:

```bash
# 1. Bump version in skills/my-skill/SKILL.md
# 2. Add release entry to skills/my-skill/CHANGELOG.md
# 3. Regenerate checksums: ./scripts/generate-checksums.sh
# 4. Commit and push
# 5. Tag and push:
git tag my-skill/v1.2.0
git push --tags
```

This triggers the per-skill release workflow which creates a GitHub Release with the skill's changelog.
