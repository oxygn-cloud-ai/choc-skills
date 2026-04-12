# GITHUB_CONFIG.md — choc-skills

Inherits from [`~/.claude/GITHUB_CONFIG.md`](file:///Users/oxygnserver01/.claude/GITHUB_CONFIG.md). This file documents project-specific configuration and deviations.

## Project Type

**Software**

## Repository

- **Remote:** https://github.com/oxygn-cloud-ai/choc-skills.git
- **Owner/Repo:** oxygn-cloud-ai/choc-skills
- **Default branch:** main

## Jira

- **Project:** CPT (Claude Progress Tracking)
- **Epic:** CPT-3 (choc-skills)

## Branch Protection

Enabled on `main` with:
- `strict: true` — branches must be up-to-date before merge
- `allow_force_pushes: false`
- `allow_deletions: false`
- `enforce_admins: false`
- Required status checks: ShellCheck, Validate Skills, Installer Smoke Test (ubuntu-latest), Installer Smoke Test (macos-latest), Verify Checksums, File Permissions, BATS Unit Tests

## CI Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | push/PR to main | Primary CI — lint, validate, install, checksums, tests |
| `labels.yml` | manual | Label synchronization |
| `release-skill.yml` | `<skill>/v*` tag | Per-skill release |
| `release.yml` | `v*` tag | Milestone release |

## Issue Tracking

GitHub Issues are disabled. All issue tracking is in Jira under epic CPT-3. CI failure monitoring is handled by the Master session on the local machine (see `~/.claude/MULTI_SESSION_ARCHITECTURE.md` section 2).

## Session Worktrees

Full 11-session architecture per `~/.claude/MULTI_SESSION_ARCHITECTURE.md`:

| Role | Branch | Worktree |
|------|--------|----------|
| master | session/master | .worktrees/master |
| planner | session/planner | .worktrees/planner |
| implementer | session/implementer | .worktrees/implementer |
| fixer | session/fixer | .worktrees/fixer |
| merger | session/merger | .worktrees/merger |
| chk1 | session/chk1 | .worktrees/chk1 |
| chk2 | session/chk2 | .worktrees/chk2 |
| performance | session/performance | .worktrees/performance |
| playtester | session/playtester | .worktrees/playtester |
| reviewer | session/reviewer | .worktrees/reviewer |
| triager | session/triager | .worktrees/triager |

## Coverage

Not configured. No coverage job in CI. SKIP per global audit.

## Deviations

None documented.
