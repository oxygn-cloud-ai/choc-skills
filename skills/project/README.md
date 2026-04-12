# project — Project Repository Administration

A Claude Code skill that creates, audits, configures, and reports on project repositories using the multi-session workflow defined in `~/.claude/MULTI_SESSION_ARCHITECTURE.md` and `~/.claude/GITHUB_CONFIG.md`.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- `git` installed and available in PATH
- `gh` installed and authenticated (`gh auth status` succeeds)
- `~/.claude/MULTI_SESSION_ARCHITECTURE.md` present (authoritative role/worktree/Jira definitions)
- `~/.claude/GITHUB_CONFIG.md` present (authoritative CI/branch-protection/issue-tracking spec)

## Installation

### From repo root (recommended)

```bash
git clone https://github.com/oxygn-cloud-ai/choc-skills.git
cd choc-skills
./install.sh project
```

### Standalone (from this directory)

```bash
./install.sh
```

### Verify installation

```bash
./install.sh --check
```

## Usage

In Claude Code:

```
/project                  Show status for current project (same as /project status)
/project status           Show project config, worktrees, Jira, CI, docs
/project new              Create a new project with full multi-session setup
/project audit            Audit against global standards, report gaps
/project config           Change project config: worktrees, labels, Jira, CI
/project help             Display full usage guide
/project doctor           Check skill installation health
/project version          Show installed version
```

## What it does

The `project` skill administers project repositories that follow the Oxygn multi-session workflow:

- **`new`** — Scaffolds a brand-new repo with GitHub remote, Jira epic reference, docs (README/ARCHITECTURE/PHILOSOPHY/CLAUDE/GITHUB_CONFIG), session worktrees (11 for Software, 8 for Non-Software), startup prompts, CI workflow, and branch protection. Disables GitHub Issues (Jira is sole tracker).
- **`status`** — Reports the current project's config, worktrees, CI state, Jira epic key, and docs completeness.
- **`audit`** — Runs the compliance audit against global standards. Reports per-check verdicts (`PASS`/`FAIL`/`WARN`/`SKIP`) across docs, worktrees, CI, branch protection, Jira config, and coverage.
- **`config`** — Interactively modifies project configuration: toggle project type, add/remove worktrees, enable/disable branch protection, disable GitHub Issues, set Jira epic key, document deviations.

## Subcommand reference

| Subcommand | Purpose | Location |
|---|---|---|
| `new` | Create a new project | `commands/new.md` |
| `status` | Show project status | `commands/status.md` |
| `audit` | Compliance audit | `commands/audit.md` |
| `config` | Modify configuration | `commands/config.md` |
| `help` | Usage guide | inline in `SKILL.md` |
| `doctor` | Skill health check | inline in `SKILL.md` |
| `version` | Version string | inline in `SKILL.md` |

## Runtime dependencies

The skill's subcommands read these files at runtime and will fail without them:

- `~/.claude/MULTI_SESSION_ARCHITECTURE.md` — role definitions, worktree layout, Jira structure, 11-session protocol
- `~/.claude/GITHUB_CONFIG.md` — CI, branch protection, issue tracking (Jira-only) spec
- `~/.claude/CLAUDE.md` — global rules (referenced, not required)

These files are NOT installed by this skill — they're expected to exist as part of the user's Claude Code configuration. Run `/project doctor` to verify.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `/project:new` fails with "gh not authenticated" | Run `gh auth login` |
| `/project:audit` reports all FAIL | Run inside a real project repo, not in `~/.claude` |
| `~/.claude/MULTI_SESSION_ARCHITECTURE.md missing` | Restore the file or write one from your local conventions |
| Skill not appearing in Claude Code | Verify: `ls ~/.claude/skills/project/SKILL.md` |
| Skill is outdated | `./install.sh --force project` from the choc-skills repo root |
| `doctor` reports `.source-repo` unreachable | External drive unmounted — mount it and re-run |

## Update

```bash
cd choc-skills && git pull && ./install.sh --force project
```

## Uninstall

### Via installer

```bash
./install.sh --uninstall project
```

### Manual

```bash
rm -rf ~/.claude/skills/project
rm -rf ~/.claude/commands/project
rm -f  ~/.claude/commands/project.md
```

## Version

Current: **1.3.0**

## License

MIT
