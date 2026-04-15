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

For Software projects (and Non-Software if user opts in), ask:

1. "What is the vision for this project? What problem does it solve or what goal does it serve?"
2. "What are your non-negotiable design principles?"
3. "What is explicitly out of scope? What will this project NOT do?"

Write `PHILOSOPHY.md` from the answers.

## Step 5: Scaffold required docs

Create these files at the repo root:

**PHILOSOPHY.md** — from interview above.

**README.md** — title, description, type-appropriate section headings:
- Software: Features, Requirements, Installation, Usage, Configuration, Troubleshooting, Contributing, License
- Non-Software: Overview, Getting Started, Structure, Contributing, License

**ARCHITECTURE.md** (Software only) — title, version 0.1.0, placeholder sections:
- Design Philosophy, System Overview, Module Reference, Endpoints (if applicable), State Files, Security Model, Error Handling

**CLAUDE.md** — project name, type, description, Jira epic (placeholder until step 7), key files, development commands (language-specific).

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
```

Add a brief quick-reference section specific to each role (3-5 bullet points summarizing the protocol steps).

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

Create `.github/workflows/test.yml` with:
- Language-appropriate test job
- `notify-failure` job from `~/.claude/PROJECT_STANDARDS.md` section 3 reference implementation
- `notify-recovery` job

Adapt the `needs:` list to match the actual test job name(s).

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
