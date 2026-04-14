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

**PROJECT_CONFIG.json** — structured project configuration (schemaVersion, project, jira, github, sessions, coverage, deviations). Copy PROJECT_CONFIG.schema.json from choc-skills repo for validation.

**Language-specific scaffolding** (Software only):
- Python: `pyproject.toml` (with version 0.1.0), `src/<name>/__init__.py`, `tests/conftest.py`, `.gitignore`
- Node: `package.json`, `src/index.ts`, `tsconfig.json`, `.gitignore`
- Rust: `Cargo.toml`, `src/main.rs`, `.gitignore`
- Go: `go.mod`, `main.go`, `.gitignore`
- Other: `.gitignore`

## Step 6: Create GitHub labels

Read label definitions from `~/.claude/PROJECT_STANDARDS.md` section 2.

For Software projects — full set:
```bash
gh label create "P1" --color "b60205" --description "Critical — blocks progress, fix immediately" 2>/dev/null || true
gh label create "P2" --color "d93f0b" --description "High — fix soon, before next release" 2>/dev/null || true
gh label create "P3" --color "fbca04" --description "Medium — fix when touching related code" 2>/dev/null || true
gh label create "P4" --color "c5def5" --description "Low — cosmetic, infra, or nice-to-have" 2>/dev/null || true
gh label create "bug" --color "d73a4a" --description "Something isn't working" 2>/dev/null || true
gh label create "enhancement" --color "a2eeef" --description "New feature or improvement" 2>/dev/null || true
gh label create "security" --color "ee0701" --description "Security vulnerability or hardening" 2>/dev/null || true
gh label create "performance" --color "f9d0c4" --description "Performance issue or optimization" 2>/dev/null || true
gh label create "code-quality" --color "bfdadc" --description "Code quality, maintainability, or correctness" 2>/dev/null || true
gh label create "documentation" --color "0075ca" --description "Documentation update needed" 2>/dev/null || true
gh label create "ci-failure" --color "b60205" --description "Automated CI failure report" 2>/dev/null || true
```

For Non-Software — reduced set (P1-P4 + bug, enhancement, documentation only).

Delete GitHub's default labels that aren't in our set:
```bash
for label in "good first issue" "help wanted" "invalid" "wontfix" "question" "duplicate"; do
  gh label delete "$label" --yes 2>/dev/null || true
done
```

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
# Software only — add language-specific scaffolding:
# Python: git add pyproject.toml src/ tests/
# Node: git add package.json src/ tsconfig.json
# Rust: git add Cargo.toml src/
# Go: git add go.mod main.go
# If ARCHITECTURE.md was created: git add ARCHITECTURE.md
git commit -m "$(cat <<'EOF'
chore: initial project scaffold

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
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
  Labels:     <count> created
  Docs:       PHILOSOPHY.md, README.md, ARCHITECTURE.md, CLAUDE.md, PROJECT_CONFIG.json
  Worktrees:  <count> sessions in .worktrees/
  Prompts:    .claude/sessions/*.md

  To start working:
    cd <path>/.worktrees/master && claude
    # Paste the startup prompt from .claude/sessions/master.md
```

</process>

<success_criteria>
- [ ] GitHub repo created with correct visibility
- [ ] All required docs present at repo root
- [ ] Labels match PROJECT_STANDARDS.md spec for project type
- [ ] Jira epic key documented in CLAUDE.md and PROJECT_CONFIG.json
- [ ] All session worktrees created with correct branch names
- [ ] Session startup prompts created in .claude/sessions/
- [ ] CI workflow present (Software only) with notify-failure/recovery
- [ ] Branch protection set (Software only)
- [ ] Project memory initialized
- [ ] Initial commit pushed to main
- [ ] All session branches pushed to origin
</success_criteria>
