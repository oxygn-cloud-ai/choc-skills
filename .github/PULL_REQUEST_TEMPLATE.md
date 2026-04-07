## Summary

<!-- 2-3 sentences: what does this PR do and why? -->

## Type of change

- [ ] New skill
- [ ] Skill update
- [ ] Bug fix
- [ ] Installer / scripts
- [ ] CI / GitHub Actions
- [ ] Documentation

## Checklist — Always

- [ ] ShellCheck passes
- [ ] `./scripts/validate-skills.sh` passes (0 errors)
- [ ] CI is green

## If SKILL.md modified

- [ ] `./scripts/generate-checksums.sh` run and committed
- [ ] Version bumped in SKILL.md
- [ ] CHANGELOG.md updated

## If new skill

- [ ] Directory name matches `name:` field
- [ ] Has `help`, `doctor`, `version` subcommands
- [ ] `allowed-tools` is minimal
- [ ] `disable-model-invocation: true` set
- [ ] README.md exists
- [ ] Skill added to README.md table
- [ ] `install.sh` is executable (if per-skill installer exists)

## If installer/scripts modified

- [ ] BATS tests updated (`tests/`)
- [ ] `bats tests/` passes locally

## Security

- [ ] No hardcoded secrets or credentials
- [ ] No sensitive file access outside `~/.claude/`
- [ ] No undocumented network access
