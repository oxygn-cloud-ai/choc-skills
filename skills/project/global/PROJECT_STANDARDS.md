# Project Standards

This file defines **narrative standards** that apply to all projects using the multi-session architecture. Machine-readable configuration lives in each project's `PROJECT_CONFIG.json` (validated against `PROJECT_CONFIG.schema.json`).

Referenced by:
- `$CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md` (session lifecycle)
- Each project's `PROJECT_CONFIG.json` (structured config)
- The `/project` skill (auditing, scaffolding, status)

---

## 1. Branch Protection

Every repo must have branch protection enabled on the default branch (usually `main`).

Required settings (configured via `gh api` or GitHub UI):
- `strict` — branches must be up-to-date with default branch before merge
- `allow_force_pushes: false` — prevent history rewrites
- `allow_deletions: false` — prevent accidental branch deletion
- `enforce_admins: false` — repo owner can bypass in emergencies (flip to `true` once workflow is stable)
- `required_pull_request_reviews: null` — reviews happen via Reviewer session + Jira, not GitHub PR reviews
- **Only include status checks that CONSISTENTLY pass** — adding a flaky or aspirational check will block merges. Aspirational checks run informationally.

Specific required status check names are listed in each project's `PROJECT_CONFIG.json` under `github.branchProtection.requiredStatusChecks`.

### Applying branch protection

```bash
# Read values from PROJECT_CONFIG.json, then:
gh api "repos/<owner>/<repo>/branches/main/protection" -X PUT --input - <<'EOF'
{
  "required_status_checks": { "strict": <strict>, "contexts": [<checks>] },
  "enforce_admins": <enforceAdmins>,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": <allowForcePushes>,
  "allow_deletions": <allowDeletions>
}
EOF
```

## 2. GitHub Issues

**GitHub Issues are NOT used for issue tracking.** Jira is the single source of truth (see `$CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md` section 5).

Every new repo should have GitHub Issues disabled:
```bash
gh repo edit <owner>/<name> --enable-issues=false
```

Delete all GitHub default labels — they serve no purpose with Issues disabled:
```bash
for label in "good first issue" "help wanted" "invalid" "wontfix" "question" "duplicate" "bug" "documentation" "enhancement"; do
  gh label delete "$label" --yes 2>/dev/null || true
done
```

If a project has legacy GitHub Issues, migrate them to Jira (as tasks under the project's epic) and close the GitHub copies.

## 3. CI Failure Monitoring

CI failures are tracked in **Jira**, not GitHub Issues. The mechanism:

1. **Master session** monitors CI status on the local machine via `gh run list` and `gh run view`
2. When a failure is detected on the default branch, Master files a Jira task under the project's epic with:
   - Type: CI Issue
   - Priority: P1
   - Description: run URL, commit SHA, last 50 lines of failed log
3. When CI recovers, Master comments on the Jira task and transitions it to Done

Jira credentials are injected into the shell environment from AWS Secrets Manager by `~/.bashrc` (see §9). CI workflows in GitHub Actions do **not** need Jira secrets — they only run tests and report pass/fail status.

## 4. Push Discipline

Anything that exists only in the local working tree is one filesystem event away from being lost. Defenses:

1. **Push feature branches immediately after first commit.** Don't accumulate local-only commits.
2. **Commit in small increments.** More reflog entries = more recovery surface area.
3. **Run `git push` before any destructive operation** — `git reset --hard`, `git checkout -f`, running test suites that may touch git state.
4. **Sub-agents in worktrees must push their feature branch as soon as they have a working commit**, not wait until the end of the task.
5. **Branch protection blocks force-push on default branches**, but local branches remain vulnerable until pushed.

## 5. Coverage Thresholds

Two rules:

1. **Thresholds reflect actual reality, not aspirations.** Set them slightly below current actual values so any regression fails CI without blocking on unmet targets.
2. **Ratchet UP as coverage improves. Never lower silently.** Every threshold reduction must be documented in both the test config and the project's `PROJECT_CONFIG.json` deviations array with the reason.

If a `coverage` job is currently failing on aspirational thresholds, lower them to match actuals before adding `coverage` to required status checks.

Specific threshold values are in each project's `PROJECT_CONFIG.json` under `coverage.thresholds`.

## 6. Required Documentation Files

Every repo must have, at the root:

| File | Purpose |
|------|---------|
| `README.md` | Features, install, usage, config, troubleshooting, contributing, license |
| `ARCHITECTURE.md` | Design philosophy, system overview, request flows, module reference, endpoints, state files, security model, error handling |
| `PHILOSOPHY.md` | Vision, mission, objectives, design principles, non-negotiables |
| `CLAUDE.md` | Project-specific Claude instructions (overrides global CLAUDE.md where relevant) |
| `PROJECT_CONFIG.json` | Structured project configuration (validated against PROJECT_CONFIG.schema.json) |

## 7. Worktree Strategy

Projects that use parallel Claude Code sessions use git worktrees for isolation. Each worktree runs in its own directory with its own branch.

Worktree directories live under `.worktrees/` (gitignored). Branch names use `session/<role>` convention.

### Setup (one-time per repo)

```bash
mkdir -p .worktrees
for name in master planner implementer fixer merger chk1 chk2 performance playtester reviewer triager; do
  if ! git worktree list | grep -q ".worktrees/$name "; then
    git worktree add ".worktrees/$name" -b "session/$name" main
  fi
done
```

Loop prompt files live at `.worktrees/<role>/loops/`, not `.claude/loops/`. Each role's loop config belongs in that role's worktree directory.

### Worktree creation is fixed (no new worktrees permitted)

The setup above creates **exactly** the role worktrees and no others. Once a project is set up, **no session — not Claude, not sub-agents, not the human in normal flow — may create additional worktrees**. Feature/fix work is always a branch created inside the existing role worktree:

```bash
# Correct — branch inside the existing worktree
cd .worktrees/fixer
git checkout -b fix/PROJ-<n>
# …red-green TDD, commits…
git push -u origin fix/PROJ-<n>
git checkout session/fixer          # return to parked state when work ships

# Incorrect — creating new worktrees is forbidden
git worktree add .worktrees/my-feature -b feature/foo   # ❌
git worktree add ../fix-proj-42 -b fix/PROJ-42          # ❌
```

See `$CLAUDE_DIR/MULTI_SESSION_ARCHITECTURE.md` §7.1 for the full rule, correct/incorrect examples, and enforcement architecture. Enforcement has three layers:

1. **Tool-layer hook (hard block):** `$CLAUDE_DIR/hooks/block-worktree-add.sh` is registered as a `PreToolUse` hook in `$CLAUDE_DIR/settings.json`. Any Bash tool call matching `git worktree add` exits 2 unless the command inlines `GIT_WORKTREE_OVERRIDE=1`.
2. **Audit detection (soft block):** `/project:audit` check #16 FAILs on any `.worktrees/<name>/` whose `<name>` is not in `PROJECT_CONFIG.json` `sessions.roles`. It also validates each role worktree's HEAD branch against a role-aware rule — **fixer** may be on `session/fixer` or `^fix/<JIRA_KEY>-[0-9]+` (active-work per §7.1); **implementer** may be on `session/implementer` or `^feature/<JIRA_KEY>-[0-9]+`; **all other roles** must be on `session/<role>` because they are read-only on source. Anything else FAILs.
3. **Session-prompt guidance:** every `.claude/sessions/<role>.md` includes a "Worktree rule" reminder at session startup.

**Human override** (rare — e.g., isolated review of a hostile branch, independent experiment) — bypass the hook with an inline prefix, per invocation, no long-lived env var:

```bash
GIT_WORKTREE_OVERRIDE=1 git worktree add <path> <args...>
```

## 8. Workflow Auditing Checklist

When auditing an existing repo against this standard:

- [ ] Branch protection on default branch, strict, force-push blocked
- [ ] GitHub Issues disabled
- [ ] No default GitHub labels present (bug, documentation, duplicate, enhancement, good first issue, help wanted, invalid, question, wontfix). Project-specific labels declared in `.github/labels.yml` are allowed; they are the repo's intentional PR-labelling taxonomy.
- [ ] README.md, ARCHITECTURE.md, PHILOSOPHY.md, CLAUDE.md, PROJECT_CONFIG.json all present
- [ ] Coverage thresholds match actual reach (or `coverage` job is excluded from required checks with documented deviation)
- [ ] Jira epic configured in PROJECT_CONFIG.json
- [ ] Deviations from these standards documented in PROJECT_CONFIG.json deviations array
- [ ] Worktrees match `sessions.roles` — no extras, no missing, each parked on `session/<role>` (enforced by `/project:audit` check #16 and the `PreToolUse` hook in `$CLAUDE_DIR/settings.json` — see §7)

## 9. Secrets and Environment

All API credentials required by Claude sessions are injected into the shell environment from **AWS Secrets Manager** by `~/.bashrc` at startup on `choc-aws` (Ubuntu 24.04 on AWS Lightsail). Code and tool calls MUST reference these by env var name only — never by value — per the global rule in `$CLAUDE_DIR/CLAUDE.md`.

AWS credentials themselves come from the Lightsail instance role; no long-lived AWS keys exist on disk.

**Env vars populated** (identifiers only — values never live in any file):

| Env var | Purpose | Secrets Manager entry |
|---|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN` | Claude Code login | `claude-code/oauth-token` |
| `JIRA_API_KEY` | Atlassian / Jira API | `claude-code/atlassian` |
| `JIRA_URL` | Jira site base URL | `claude-code/jira-url` |
| `JIRA_EMAIL` | Jira account email | `claude-code/jira-email` |
| `BB_API_KEY` | Bitbucket API | `claude-code/choc-bb` |
| `GH_TOKEN` | GitHub PAT | `claude-code/github` |
| `HF_TOKEN` | Hugging Face | `claude-code/huggingface` |
| `OPENROUTER_API_KEY` | OpenRouter | `claude-code/openrouter` |
| `RUNPOD_API_KEY` | RunPod | `claude-code/runpod` |
| `TELEGRAM_BOT_TOKEN` | Telegram bot | `claude-code/telegram` |

**Rules:**

- NEVER write a secret value into any file, command-line arg, PR description, log, commit message, or tool parameter.
- NEVER `echo` a secret value. To verify a var is set, check its length: `[ -n "$GH_TOKEN" ] && echo set`.
- **Rotation:** update the value in AWS Secrets Manager and `source ~/.bashrc`. No file edits required.
- **Adding a secret:** create it under the `claude-code/<name>` namespace, then add a guarded `if tok=$(sm claude-code/<name>) …` block to `~/.bashrc`. Never paste the raw value into the file — `sm` fetches it at runtime.
- **Non-`choc-aws` hosts:** if/when sessions run on a different host, the mechanism may differ; the rule (reference by env var, never by value) is invariant.

---

## Finding this document

This file ships as part of the `/project` skill (skill product). At runtime it is installed to `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/PROJECT_STANDARDS.md` — i.e. under `$CLAUDE_CONFIG_DIR` when that env var is set (e.g. `/workspace/.claude/PROJECT_STANDARDS.md`), otherwise `$HOME/.claude/PROJECT_STANDARDS.md`. Source of truth lives in `skills/project/global/PROJECT_STANDARDS.md` in the choc-skills repo; the installer copies it into the Claude config dir on every `--force` run.

For the `/project` skill or any tool that needs to understand project standards:
- **Path:** resolved via `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/PROJECT_STANDARDS.md`
- **What it contains:** branch protection, CI monitoring, push discipline, coverage, documentation requirements, worktree strategy
- **How to use it:** reference this file for narrative standards. Machine-readable config is in each project's `PROJECT_CONFIG.json`.
