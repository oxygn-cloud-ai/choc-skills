# Security Policy

## Trust Model

Claude Code skills are **Markdown instruction files**, not executable code. When you install a skill via `./install.sh`, the installer copies a single `SKILL.md` file to `~/.claude/skills/<name>/`. Claude Code reads this file and follows its instructions using the tools permitted by the `allowed-tools` frontmatter field.

### What the installer does

- Creates directories under `~/.claude/skills/` and `~/.claude/commands/`
- Copies `SKILL.md` files into skill directories
- Per-skill installers (e.g., `skills/rr/install.sh`) additionally install:
  - Router files (`~/.claude/commands/<skill>.md`) for slash-command routing
  - Sub-command `.md` files (`~/.claude/commands/<skill>/*.md`)
  - Orchestrator scripts (shell scripts, Python files) for skills that need them (e.g., rr)
  - Reference files (schemas, workflow definitions, context documents)
  - Source repo markers (`.source-repo`) for the update subcommand
- Verifies copies match source (byte-level comparison + SHA256 checksum)

### What the installer does NOT do

- Modify shell configuration files (`.bashrc`, `.zshrc`, etc.)
- Install system packages or binaries
- Run any code from the skill definitions
- Access the network (except `git clone` if you install from a URL)
- Modify files outside `~/.claude/skills/`

### Tool restrictions

Each skill declares an `allowed-tools` field in its YAML frontmatter. Claude Code enforces these restrictions at runtime. For example, `allowed-tools: Read, Grep, Glob, Bash(git *)` means the skill can only read files and run git commands — it cannot write files, make network requests, or execute arbitrary shell commands.

## Integrity Verification

After installation, you can verify installed skills against published checksums:

```bash
# Check all installations are healthy
./install.sh --check

# Verify checksums (if CHECKSUMS.sha256 exists)
cd choc-skills
shasum -a 256 -c CHECKSUMS.sha256
```

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly:

1. **Do NOT open a public issue**
2. Email: security@oxygn.cloud (or use GitHub Security Advisories)
3. Include: description, reproduction steps, and impact assessment
4. We will acknowledge within 48 hours and provide a fix timeline

## Scope

This policy covers:
- The root installer (`install.sh`)
- Per-skill installers (`skills/*/install.sh`)
- Skill definitions (`skills/*/SKILL.md`)
- CI/CD workflows (`.github/workflows/`)
- Validation scripts (`scripts/`)

Standalone tools (e.g., `iterm2-tmux`) have their own security considerations documented in their respective READMEs.

## Security Checklist for Contributors

Before submitting a skill, verify:

- [ ] `allowed-tools` is as restrictive as possible
- [ ] No hardcoded secrets, tokens, or API keys
- [ ] No instructions to read sensitive files (`~/.ssh/`, `~/.aws/`, `.env`)
- [ ] No instructions to modify files outside the audit target
- [ ] No network access unless absolutely required and documented
- [ ] `disable-model-invocation: true` is set (skill only runs when user invokes it)
