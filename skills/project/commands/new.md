---
name: project-new
description: Create a new project repository with full multi-session setup
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

<objective>
Create a new project repository fully configured per ~/.claude/MULTI_SESSION_ARCHITECTURE.md and ~/.claude/PROJECT_STANDARDS.md.
</objective>

<process>

## Step 0: Safety checks

Before anything else, verify this is safe to run:

1. **Not inside an existing git repo:**
   ```bash
   git rev-parse --is-inside-work-tree 2>/dev/null
   ```
   If this succeeds (returns "true"), STOP immediately:
   > "You're inside an existing git repository at `$(git rev-parse --show-toplevel)`. Use `/project:audit` to audit it or `/project:config` to modify it. `/project:new` is only for creating brand-new projects."

2. After the user provides the target directory (Step 2), verify it doesn't already exist with content:
   ```bash
   if [ -d "<path>" ] && [ "$(ls -A '<path>' 2>/dev/null)" ]; then
     # Directory exists and is not empty — STOP
   fi
   ```
   If non-empty: "Directory `<path>` already exists and contains files. Choose a different path or empty it first."

3. After the user provides the project name, verify the GitHub repo doesn't already exist:
   ```bash
   gh repo view <owner>/<name> --json name 2>/dev/null
   ```
   If this succeeds: "GitHub repo `<owner>/<name>` already exists. Choose a different name or use `/project:audit` to audit the existing repo."

## Step 1: Verify dependencies and read the architecture

Verify dependencies exist before reading:
- `test -f ~/.claude/MULTI_SESSION_ARCHITECTURE.md` — if missing: **STOP** with error: "~/.claude/MULTI_SESSION_ARCHITECTURE.md not found. This file defines the multi-session workflow and is required for project creation."
- `test -f ~/.claude/PROJECT_STANDARDS.md` — if missing: **STOP** with error: "~/.claude/PROJECT_STANDARDS.md not found. This file defines project standards for branch protection, CI, and documentation."

Read `~/.claude/MULTI_SESSION_ARCHITECTURE.md` for role definitions, worktree layout, and Jira structure. This is the authoritative reference — do not hardcode or inline its contents.

Read `~/.claude/PROJECT_STANDARDS.md` for branch protection, CI templates, and documentation requirements.

## Step 1.5: Preflight check for PreToolUse worktree hook (WARN not STOP)

Tier 1 of the worktree-creation protection (MULTI_SESSION_ARCHITECTURE.md §7.1) depends on `~/.claude/hooks/block-worktree-add.sh` being installed and registered in `~/.claude/settings.json`. Scaffolding a new project on a machine where the hook is missing still produces a valid project, but role sessions on that machine won't have the hook guard. Warn the operator so they can remediate before launching.

```bash
test -x ~/.claude/hooks/block-worktree-add.sh \
  || WARN "worktree hook missing at ~/.claude/hooks/block-worktree-add.sh — run install.sh --force on the /project skill to restore it"

jq -e '.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[]? | select(.command | test("block-worktree-add\\.sh$"))' \
  ~/.claude/settings.json >/dev/null 2>&1 \
  || WARN "block-worktree-add.sh is not registered in ~/.claude/settings.json hooks.PreToolUse[] — run install.sh --force"
```

These are warnings not hard stops — the generated project is still standards-compliant; it's the host machine's enforcement posture that's weak. Operator can clear the warning with a re-install.

## Step 2: Gather basics

Ask via AskUserQuestion:

Question 1: "Project name, description, and type"
- Project name (slug form, e.g., `my-tool`)
- One-line description
- Type: Software / Non-Software

Question 2 (if Software): "Language/framework?"
- Options: Python, Node/TypeScript, Rust, Go, Other

Question 3: "GitHub visibility?"
- Options: Public, Private

Question 4: "Where should the repo live?"
- Default: `~/Repos/<name>` (suggest this, let user override)

## Step 3: Create the GitHub repo

```bash
mkdir -p <path>
cd <path>
git init
# Create initial .gitignore appropriate for language
gh repo create <owner>/<name> --<visibility> --description "<desc>" --source . --push
```

Determine the GitHub owner from `gh api user --jq .login`.

## Step 4: Interview for PHILOSOPHY.md

PHILOSOPHY.md is **mandatory for every project** regardless of type — see `~/.claude/PROJECT_STANDARDS.md` §6 and global CLAUDE.md "Every project must have a PHILOSOPHY.md file." Ask via AskUserQuestion:

1. "What is the vision for this project? What problem does it solve or what goal does it serve?"
2. "What are your non-negotiable design principles?"
3. "What is explicitly out of scope? What will this project NOT do?"

Write `PHILOSOPHY.md` from the answers. If the operator passes `--minimal` (or asks to defer the interview), write a skeleton PHILOSOPHY.md with TODO markers for each question and flag it in the summary so they know to fill it in before the first significant commit.

## Step 5: Scaffold required docs

Create these files at the repo root:

**PHILOSOPHY.md** — from interview above.

**README.md** — title, description, type-appropriate section headings:
- Software: Features, Requirements, Installation, Usage, Configuration, Troubleshooting, Contributing, License
- Non-Software: Overview, Getting Started, Structure, Contributing, License

**ARCHITECTURE.md** (Software only) — title, version 0.1.0, placeholder sections:
- Design Philosophy, System Overview, Module Reference, Endpoints (if applicable), State Files, Security Model, Error Handling

**CLAUDE.md** — project name, type, description, Jira epic (placeholder until step 7), key files, development commands (language-specific). In addition the generated `CLAUDE.md` MUST contain:

- **"## Verification discipline" section** — either inline the 7 non-negotiable rules from global `~/.claude/CLAUDE.md` (verify-before-asserting, never-flip-on-authority, subagent-output-is-a-hypothesis, checkable-claim-triggers, recalibrate-cost-model, recursive-self-check, never-take-shortcuts) OR include an explicit pointer: "See `~/.claude/CLAUDE.md` for global verification discipline — the rules there apply to every project including this one." Inlining is preferred so the rules survive a `/clear` of the role session that forgets to read the global file.
- **"## Coordination" section** stating: "Jira epic `<epic-key>` is the coordination mechanism for this project. GitHub Issues are disabled and GitHub PRs are not used — **do not run `gh pr create`**. Push feature/fix branches; the Reviewer session posts review comments to Jira; the Merger session squash-merges after Triager approval." This captures the no-PR policy so role sessions on new projects don't default to `gh pr create`.

**PROJECT_CONFIG.json** — structured project configuration. Generate from the schema template. Include:
- `schemaVersion: 1`
- `project`: name, type, description
- `jira`: projectKey, cloudId, epicKey (filled in Step 7), boardUrl
- `github`: owner, repo, defaultBranch, `issuesEnabled: false`, branchProtection (Software only)
- `sessions.roles`: 11 for Software, 8 for Non-Software
- `sessions.loops`: default intervals for 8 loop-capable roles with `prompt: "loops/loop.md"`:
  ```json
  "loops": {
    "master":      { "intervalMinutes": 5,  "prompt": "loops/loop.md" },
    "triager":     { "intervalMinutes": 10, "prompt": "loops/loop.md" },
    "reviewer":    { "intervalMinutes": 10, "prompt": "loops/loop.md" },
    "merger":      { "intervalMinutes": 10, "prompt": "loops/loop.md" },
    "chk1":        { "intervalMinutes": 15, "prompt": "loops/loop.md" },
    "chk2":        { "intervalMinutes": 15, "prompt": "loops/loop.md" },
    "fixer":       { "intervalMinutes": 10, "prompt": "loops/loop.md" },
    "implementer": { "intervalMinutes": 10, "prompt": "loops/loop.md" }
  }
  ```
  For Non-Software, omit chk1/chk2.
- `env`: `{ "project": {}, "sessions": {} }` — empty by default, populated via `/project:config`
- `coverage`, `sandbox`, `servers`, `deviations`: as applicable

**PROJECT_CONFIG.schema.json** — copy from `~/.claude/skills/project/PROJECT_CONFIG.schema.json` (installed with the skill). This enables `scripts/validate-config.sh` for the new project.

**Language-specific scaffolding** (Software only):
- Python: `pyproject.toml` (with version 0.1.0), `src/<name>/__init__.py`, `tests/conftest.py`, `.gitignore`
- Node: `package.json`, `src/index.ts`, `tsconfig.json`, `.gitignore`
- Rust: `Cargo.toml`, `src/main.rs`, `.gitignore`
- Go: `go.mod`, `main.go`, `.gitignore`
- Other: `.gitignore`

**`.gitignore` augmentation (all project types, all languages):** after writing the language-specific `.gitignore`, append a `.worktrees/` line so `/project:launch`-created worktree trees don't appear in `git status`. One-line append is sufficient — the language template handles everything else above it.

```bash
# Always append, whether the language template created .gitignore or not
grep -q '^\.worktrees/$' .gitignore 2>/dev/null || printf '\n# Ignore per-role session worktrees created by /project:launch\n.worktrees/\n' >> .gitignore
```

## Step 6: Delete GitHub labels

GitHub Issues are disabled project-wide (Jira is the single source of truth per
`~/.claude/PROJECT_STANDARDS.md`). GitHub labels serve no purpose and must be
removed so they don't appear on any accidental PRs or stray issues.

```bash
# Disable GitHub Issues on the repo
gh repo edit --enable-issues=false 2>/dev/null || true

# Delete all default GitHub labels
for label in "good first issue" "help wanted" "invalid" "wontfix" "question" "duplicate" "bug" "documentation" "enhancement"; do
  gh label delete "$label" --yes 2>/dev/null || true
done
```

Do not create any labels. All priority/category information lives on Jira issues.

## Step 7: Jira epic

Ask the user:
> "Does a Jira epic already exist in CPT for this project? If yes, provide the key (e.g., CPT-42). If no, create one in Jira and provide the key."

Once the user provides the key:
- Update CLAUDE.md with the Jira epic key
- Update PROJECT_CONFIG.json with the Jira epic key

## Step 8: Initial commit + push

Stage only the files created by the scaffold — do NOT use `git add -A` (risks staging pre-existing sensitive files):

```bash
git add README.md CLAUDE.md PROJECT_CONFIG.json PROJECT_CONFIG.schema.json PHILOSOPHY.md .gitignore
# Loop prompts are created later (Step 10.5) per worktree — not added to the initial commit on main
# Software only — add language-specific scaffolding:
# Python: git add pyproject.toml src/ tests/
# Node: git add package.json src/ tsconfig.json
# Rust: git add Cargo.toml src/
# Go: git add go.mod main.go
# If ARCHITECTURE.md was created: git add ARCHITECTURE.md
git commit -m "chore: initial project scaffold"
git push -u origin main
```

## Step 9: Create session worktrees

Read the worktree setup from `~/.claude/MULTI_SESSION_ARCHITECTURE.md` section 7.

For Software (all 11 sessions):
```bash
mkdir -p .worktrees
for name in master planner implementer fixer merger chk1 chk2 performance playtester reviewer triager; do
  git worktree add ".worktrees/$name" -b "session/$name" main
done
```

For Non-Software (8 sessions — skip chk1, chk2, playtester):
```bash
mkdir -p .worktrees
for name in master planner implementer fixer merger performance reviewer triager; do
  git worktree add ".worktrees/$name" -b "session/$name" main
done
```

Push all session branches:
```bash
for branch in $(git branch --list 'session/*' --format='%(refname:short)'); do
  git push -u origin "$branch" 2>/dev/null || true
done
```

## Step 10: Create session startup prompts

Create `.claude/sessions/<role>.md` for each session role. Each prompt is thin — it states the role, points at the architecture doc for protocol, and includes project-specific references.

Template:
```markdown
# <Role> Session — <project-name>

You are the **<Role>** for <project-name>.

## Protocol
Read ~/.claude/MULTI_SESSION_ARCHITECTURE.md section <N> for your full protocol.

## Project
- Jira epic: <epic-key>
- Repo: <owner>/<name>
- Read CLAUDE.md and ARCHITECTURE.md for project context.

## Worktree rule (non-negotiable)
Do NOT create new git worktrees. The role worktrees are fixed — you work in yours. Feature/fix work is a **branch** created inside this worktree via `git checkout -b feature/<epic-prefix>-<n>-<slug>` or `git checkout -b fix/<epic-prefix>-<n>`, never `git worktree add`. See `~/.claude/MULTI_SESSION_ARCHITECTURE.md` §7.1. Attempts to `git worktree add` are hard-blocked by a `PreToolUse` hook unless the human inlines `GIT_WORKTREE_OVERRIDE=1` — do not use that override yourself.
```

Add a brief quick-reference section specific to each role (3-5 bullet points summarizing the protocol steps). **The Worktree rule block above is mandatory for every role's prompt** — do not omit it. `<epic-prefix>` is the Jira project key (e.g., `CPT`, `ACME`) so branch naming stays consistent with the project's ticket numbering.

## Step 10.5: Create loop prompts (8 loop-capable roles)

Loop prompts live at `.worktrees/<role>/loops/loop.md` — each worktree owns its own loop config. Create one for each of the 8 loop-capable roles (master, triager, reviewer, merger, chk1, chk2, fixer, implementer). Skip planner, performance, playtester — they are on-demand only.

Each role's loop file lives on that role's branch (`session/<role>`). Commit + push from within the role's worktree so the file is on the right branch:

```bash
for role in master triager reviewer merger chk1 chk2 fixer implementer; do
  # Skip chk1/chk2 for Non-Software
  WT=".worktrees/$role"
  [ -d "$WT" ] || continue
  mkdir -p "$WT/loops"
  # Write role-specific loop prompt (see templates below) to "$WT/loops/loop.md"
  git -C "$WT" add loops/loop.md
  git -C "$WT" commit -m "feat: add loop prompt for $role"
  git -C "$WT" push
done
```

Example template for triager:

```markdown
# Triager Loop — <project-name>

Recurring task: scan Jira for issues needing triage.

1. Query CPT epic <epic-key> for issues in "Needs Triage" status
2. For each issue:
   - Verify priority (P1-P4), description depth, reproduction steps
   - If missing: comment requesting info, leave in Needs Triage
   - If complete: transition to "Ready for Coding"
3. Check "Ready for Coding" queue: flag aging issues (>7 days) to Master
4. Escalate anything P1 directly to Master

Read ~/.claude/MULTI_SESSION_ARCHITECTURE.md section 11 for full triager protocol.
```

Tailor the loop content per role:
- **master**: scan for release-gate state, blocked issues, 3-strikes escalations
- **triager**: as above
- **reviewer**: scan `session/*` branches for new commits since last review, post structured review comments to Jira
- **merger**: scan for approved branches in "Ready to Merge" state, squash-merge to main
- **chk1**: run `/chk1:all` if new commits landed on main since last run
- **chk2**: run `/chk2:all` against test/staging/production servers on schedule
- **fixer**: check Changes Requested first; if none, pick highest-priority bug in Ready for Coding
- **implementer**: check Changes Requested first; if none, pick highest-priority Feature Request in Ready for Coding

Default loop intervals (written to PROJECT_CONFIG.json in Step 5):
- master: 5m
- triager, reviewer, merger, fixer, implementer: 10m
- chk1, chk2: 15m

## Step 11: CI workflow (Software only)

Create `.github/workflows/test.yml` with a language-appropriate test job.

**CI failure notification is pending a design decision — `CPT-52` / `CPT-53` will resolve whether `notify-failure` / `notify-recovery` jobs live in CI (requires `JIRA_API_KEY` as an Actions secret) OR whether the Master session's loop polls `gh run list` for failures (avoids CI-side secrets).** Until those tickets land, ship only the test job and inform the operator that failure-monitoring path is TBD:

```
CI test job: configured
CI failure monitoring: pending CPT-52 / CPT-53 resolution — no notify-failure/notify-recovery jobs shipped yet
```

If the operator needs failure monitoring immediately, document the chosen path as a deviation in `PROJECT_CONFIG.json.deviations[]` with justification, and point at the relevant ticket once the design lands.

When CPT-52/CPT-53 resolve, update this step to ship the chosen reference implementation.

## Step 12: Branch protection (Software)

Wait for CI to complete first, then:
```bash
gh api "repos/<owner>/<name>/branches/main/protection" -X PUT --input - <<'EOF'
{
  "required_status_checks": { "strict": false, "contexts": ["test"] },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

## Step 13: Initialize project memory

```bash
ENCODED=$(echo "<path>" | sed 's|/|-|g' | sed 's|^-||')
mkdir -p "$HOME/.claude/projects/$ENCODED/memory"
```

Write initial `MEMORY.md` (index) and `project_status.md` with project name, type, version, creation date, and Jira epic key.

## Step 14: Summary

Display:
```
Project <name> created successfully.

  Type:       <Software|Non-Software>
  Path:       <path>
  GitHub:     https://github.com/<owner>/<name>
  Jira Epic:  <epic-key>
  Branch:     main (protected: <yes/no>)
  CI:         <.github/workflows/test.yml | n/a>
  Docs:       PHILOSOPHY.md, README.md, ARCHITECTURE.md, CLAUDE.md, PROJECT_CONFIG.json
  Worktrees:  <count> sessions in .worktrees/
  Prompts:    .claude/sessions/*.md
  Loops:      <count> loop-capable roles with loops/loop.md configured

  To start working:
    cd <path>/.worktrees/master && claude
    # Paste the startup prompt from .claude/sessions/master.md
```

</process>

<success_criteria>
- [ ] GitHub repo created with correct visibility
- [ ] All required docs present at repo root
- [ ] GitHub Issues disabled and all default labels deleted
- [ ] Jira epic key documented in CLAUDE.md and PROJECT_CONFIG.json
- [ ] All session worktrees created with correct branch names
- [ ] Session startup prompts created in .claude/sessions/
- [ ] Loop prompts created in .worktrees/<role>/loops/loop.md for 8 (Software) or 6 (Non-Software) loop-capable roles
- [ ] CI workflow present (Software only) with notify-failure/recovery
- [ ] Branch protection set (Software only)
- [ ] Project memory initialized
- [ ] Initial commit pushed to main
- [ ] All session branches pushed to origin
</success_criteria>
