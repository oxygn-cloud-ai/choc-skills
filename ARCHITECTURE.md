# ARCHITECTURE.md — choc-skills

## System Overview

choc-skills is a monorepo of independently versioned Claude Code skills and standalone tools. Skills are Markdown-driven — each skill is a `SKILL.md` file with YAML frontmatter and structured instructions that Claude Code loads at invocation time.

```
choc-skills/
├── install.sh              # Root installer (copies SKILL.md files)
├── PROJECT_CONFIG.json      # Structured project config (Jira, GitHub, sessions, loops)
├── PROJECT_CONFIG.schema.json # JSON Schema for validation
├── scripts/
│   ├── validate-skills.sh  # Frontmatter and structure validation
│   ├── validate-config.sh  # PROJECT_CONFIG.json schema + semantic validation
│   └── generate-checksums.sh
├── skills/
│   ├── _template/          # Skeleton for new skills
│   ├── chk1/               # Adversarial implementation audit
│   ├── chk2/               # Web security audit
│   ├── project/            # Project repo administration
│   ├── ra/                 # Bespoke risk assessment
│   ├── rr/                 # Risk register assessment
│   └── iterm2-tmux/        # Standalone tool (not a Claude skill)
├── tests/                  # BATS test suite
└── .github/workflows/
    ├── ci.yml              # Primary CI (ShellCheck, validate, install, checksums, BATS)
    ├── release-skill.yml   # Per-skill release (triggered by <skill>/v* tags)
    └── release.yml         # Milestone release (triggered by v* tags)
```

## Skill Anatomy

Every skill lives in `skills/<name>/` and must contain:

| File | Purpose |
|------|---------|
| `SKILL.md` | Primary definition — frontmatter + instructions. Installed to `~/.claude/skills/<name>/SKILL.md` |
| `README.md` | Human-readable documentation |
| `CHANGELOG.md` | Version history |
| `commands/*.md` | Subcommand definitions (colon-separated: `skill:subcommand`) |
| `bin/` | Standalone scripts (shell, Python) copied to `~/.local/bin/` or skill bin dir |
| `install.sh` | Optional per-skill installer for complex skills with routers and bin scripts |

### Frontmatter Contract

```yaml
---
name: <must match directory name>
version: X.Y.Z
description: <one-line>
user-invocable: true
disable-model-invocation: true
allowed-tools: [<minimal set>]
---
```

### Required Subcommands

Every skill must provide `help`, `doctor`, and `version` — either inline in SKILL.md or as separate `commands/*.md` files.

## Installer Architecture

The root `install.sh` handles discovery, installation, verification, and uninstallation:

- **Discovery:** Scans `skills/*/SKILL.md` dynamically — adding a directory is auto-detected
- **Install:** Copies SKILL.md (and commands/, bin/) to `~/.claude/skills/<name>/`
- **Verify:** `--check` validates all installed skills match source
- **Uninstall:** Removes skill directory from `~/.claude/skills/`

Skills with complex setups (routers, bin scripts, multiple command files) have per-skill `install.sh` scripts that handle the full setup.

## Project Configuration

Each project using the multi-session architecture has two config layers:

| File | Scope | Format | Purpose |
|------|-------|--------|---------|
| `PROJECT_CONFIG.json` | Per-project (repo root) | JSON (schema-validated) | Jira epic, GitHub settings, session roles, loop intervals, coverage, deviations |
| `~/.claude/PROJECT_STANDARDS.md` | Global (all projects) | Markdown | Narrative standards: branch protection, CI monitoring, push discipline, coverage philosophy, documentation requirements |

`PROJECT_CONFIG.json` is validated by `scripts/validate-config.sh` against `PROJECT_CONFIG.schema.json`. The schema enforces required fields, valid enums, and structural correctness. The script adds semantic checks (epic key matches project key, loop roles exist in roles list).

## CI Pipeline

Primary workflow: `.github/workflows/ci.yml`

| Job | What it validates |
|-----|-------------------|
| ShellCheck | Shell script linting (warning severity) |
| Validate Skills | All SKILL.md pass `validate-skills.sh` |
| Installer Smoke Test | Install/check/uninstall on ubuntu + macos matrix |
| Verify Checksums | CHECKSUMS.sha256 matches regenerated output |
| File Permissions | All .sh files are executable |
| BATS Unit Tests | Full test suite |

## Release Model

Skills are released independently via namespaced git tags:

```
chk1/v2.4.0  →  triggers release-skill.yml  →  GitHub Release "chk1 v2.4.0"
v1.0.0       →  triggers release.yml         →  milestone release spanning all skills
```

Each release validates the skill and extracts the changelog for the release body.

## Multi-Session Integration

Skills are session-aware per the multi-session architecture. The `/project` skill manages worktree creation, session prompts, and configuration. Skills like `/chk1` and `/chk2` are designed to be invoked by their respective auditor sessions.

## Security Model

- Skills run with minimal `allowed-tools` — each skill declares only the tools it needs
- `disable-model-invocation: true` prevents skills from being auto-invoked
- No skill stores or handles credentials directly
- External system interactions (Jira, GitHub) use the host environment's authenticated CLIs (`gh`, Atlassian MCP)

## State Files

- `CHECKSUMS.sha256` — integrity verification for all SKILL.md files
- `PROJECT_CONFIG.json` — structured project configuration (validated against schema)
- `~/.claude/skills/<name>/SKILL.md` — installed skill definitions (managed by installer)
- `.claude/sessions/<role>.md` — session startup prompts (per multi-session architecture)
