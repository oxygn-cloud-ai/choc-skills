# project — Project Repository Administration

A Claude Code skill that creates, audits, configures, and reports on project repositories using the multi-session workflow defined in `$CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md` and `$CLAUDE_DIR/PROJECT_STANDARDS.md` (where `$CLAUDE_DIR = ${CLAUDE_CONFIG_DIR:-$HOME/.claude}`).

> **Paths note** (CPT-174): throughout this README, `$CLAUDE_DIR` means the Claude Code config directory, resolved from `$CLAUDE_CONFIG_DIR` when set, otherwise `$HOME/.claude`. On machines where `CLAUDE_CONFIG_DIR` is set (e.g. to `/workspace/.claude`), every `~/.claude/...` path mentioned below lives under that relocated root instead.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- `git` installed and available in PATH
- `gh` installed and authenticated (`gh auth status` succeeds)
- `jq` installed (required for `settings.json` hook registration)

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
/project launch           Launch tmux sessions with Claude in each worktree
/project audit            Audit against global standards, report gaps
/project config           Change project config: worktrees, Jira, CI, loops
/project update           Update to latest version from source repo
/project help             Display full usage guide
/project doctor           Check skill installation health
/project version          Show installed version
```

## What it does

The `project` skill administers project repositories that follow the Oxygn multi-session workflow:

- **`new`** — Scaffolds a brand-new repo with GitHub remote (Issues disabled, 9 GitHub-default labels deleted — Jira is source of truth; project-specific labels via `.github/labels.yml` optional), Jira epic reference, docs (README/ARCHITECTURE/PHILOSOPHY/CLAUDE/PROJECT_CONFIG.json), session worktrees (11 for Software, 8 for Non-Software), startup prompts, loop prompts, CI workflow (failure tracking defaults to Master-session; workflow-jobs `notify-failure`/`notify-recovery` are opt-in), and branch protection.
- **`status`** — Reports the current project's config, worktrees, CI state, Jira epic key, loop configuration, open Jira issues by priority, and docs completeness.
- **`audit`** — Runs the compliance audit against global standards. Reports per-check verdicts (`PASS`/`FAIL`/`WARN`/`SKIP`) across docs, worktrees, CI, branch protection, loops, and coverage.
- **`config`** — Interactively modifies project configuration: toggle project type, add/remove worktrees, enable/disable CI or branch protection, set Jira epic key, configure loop intervals, manage env vars, document deviations.
- **`launch`** — Creates tmux session per project with named windows per worktree role, launches Claude Code in each with `--effort max` always-on; configurable options via Step 5 checklist (prompt pipe, --dangerously-skip-permissions, resume, model override, skip idle, verbose, dry run).
- **`update`** — Pulls latest from source repo and re-installs the skill.

## Subcommand reference

| Subcommand | Purpose | Location |
|---|---|---|
| `new` | Create a new project | `commands/new.md` |
| `status` | Show project status | `commands/status.md` |
| `audit` | Compliance audit | `commands/audit.md` |
| `config` | Modify configuration | `commands/config.md` |
| `launch` | Launch tmux sessions | `commands/launch.md` |
| `update` | Update from source | `commands/update.md` |
| `help` | Usage guide | `commands/help.md` |
| `doctor` | Skill health check | `commands/doctor.md` |
| `version` | Version string | `commands/version.md` |

## Runtime dependencies

The skill's subcommands read these files at runtime and will fail without them:

- `$CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md` — role definitions, worktree layout, Jira structure, 11-session protocol
- `$CLAUDE_DIR/PROJECT_STANDARDS.md` — CI templates, branch protection spec, docs requirements, label/issue deletion policy
- `$CLAUDE_DIR/CLAUDE.md` — global rules (referenced, not required; user-owned, not shipped by this skill)

As of v2.2.0, `MULTI_SESSION_ARCHITECTURE.md` and `PROJECT_STANDARDS.md` are **shipped as skill product** — the installer copies them from `skills/project/global/` into `$CLAUDE_DIR/` on every `--force` run. Run `/project doctor` to verify presence.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `/project:new` fails with "gh not authenticated" | Run `gh auth login` |
| `/project:audit` reports all FAIL | Run inside a real project repo, not in `$CLAUDE_DIR` |
| `$CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md missing` | Re-run the per-skill installer: `bash skills/project/install.sh --force` |
| Skill not appearing in Claude Code | Verify: `ls "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/project/SKILL.md"` |
| Skill is outdated | `./install.sh --force project` from the choc-skills repo root |
| `doctor` reports `.source-repo` unreachable | External drive unmounted — mount it and re-run |
| Hooks don't fire on CLAUDE_CONFIG_DIR machine | Re-run `bash skills/project/install.sh --force` — pre-CPT-174 installers wrote registrations to `$HOME/.claude/settings.json` regardless of `$CLAUDE_CONFIG_DIR` |

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
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
rm -rf "$CLAUDE_DIR/skills/project"
rm -rf "$CLAUDE_DIR/commands/project"
rm -f  "$CLAUDE_DIR/commands/project.md"
# Note: hook files at $CLAUDE_DIR/hooks/{block-worktree-add,verify-jira-parent}.sh
# are preserved; settings.json PreToolUse[] entries pointing at them are removed
# by the installer's --uninstall path, not by rm.
```

## Version

Current: **2.2.2**

## License

MIT
