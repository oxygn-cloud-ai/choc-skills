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
Create a new project repository fully configured per ~/.claude/MULTI_SESSION_ARCHITECTURE.md and ~/.claude/GITHUB_CONFIG.md.
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
- `test -f ~/.claude/GITHUB_CONFIG.md` — if missing: **STOP** with error: "~/.claude/GITHUB_CONFIG.md not found. This file defines CI and branch protection standards."

Read `~/.claude/MULTI_SESSION_ARCHITECTURE.md` for role definitions, worktree layout, and Jira structure. This is the authoritative reference — do not hardcode or inline its contents.

Read `~/.claude/GITHUB_CONFIG.md` for CI, branch protection, and issue tracking policy.

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

**GITHUB_CONFIG.md** — inherits from global, documents project type, Jira epic, any deviations.

**Language-specific scaffolding** (Software only):
- Python: `pyproject.toml` (with version 0.1.0), `src/<name>/__init__.py`, `tests/conftest.py`, `.gitignore`
- Node: `package.json`, `src/index.ts`, `tsconfig.json`, `.gitignore`
- Rust: `Cargo.toml`, `src/main.rs`, `.gitignore`
- Go: `go.mod`, `main.go`, `.gitignore`
- Other: `.gitignore`

## Step 6: Disable GitHub Issues

Jira is the single source of truth for all issue tracking (see `~/.claude/MULTI_SESSION_ARCHITECTURE.md` section 5). GitHub Issues are not used.

Disable GitHub Issues on the repo:
```bash
gh repo edit <owner>/<name> --enable-issues=false
```

Delete all GitHub default labels (they serve no purpose with Issues disabled):
```bash
for label in "good first issue" "help wanted" "invalid" "wontfix" "question" "duplicate" "bug" "documentation" "enhancement"; do
  gh label delete "$label" --yes 2>/dev/null || true
done
```

## Step 7: Jira epic (MANDATORY)

**A Jira epic is required. The project cannot proceed without one.**

Ask the user:
> "Does a Jira epic already exist in CPT for this project? If yes, provide the key (e.g., CPT-42). If no, create one in Jira and provide the key."

If the user says they don't have one, haven't created one, or wants to skip this step: **STOP** with error:
> "A Jira epic key is required before project setup can continue. Every session must be scoped to an epic to prevent cross-project leakage in the shared CPT Jira project. Create an epic in CPT and re-run `/project:new`."

Do NOT proceed with a placeholder or empty epic. Do NOT offer to continue without one.

Once the user provides the key (must match pattern `CPT-<number>`):
- Update CLAUDE.md with the Jira epic key
- Update GITHUB_CONFIG.md with the Jira epic key

## Step 8: Initial commit + push

Stage only the files created by the scaffold — do NOT use `git add -A` (risks staging pre-existing sensitive files):

```bash
git add README.md CLAUDE.md GITHUB_CONFIG.md PHILOSOPHY.md .gitignore
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

```bash
mkdir -p .claude/sessions
```

Create `.claude/sessions/<role>.md` for each session role. Each prompt states the role, points at the correct architecture doc section, includes project references, and has a 3-5 bullet quick-reference.

### Section mapping

| Role | Architecture section |
|------|---------------------|
| Master | 2 |
| Planner | 3 |
| Fixer | 4 |
| Implementer | 5 |
| Merger | 6 |
| chk1 | 7 |
| chk2 | 8 |
| PerformanceReviewer | 9 |
| Playtester | 10 |
| Reviewer | 11 |
| Triager | 12 |

### Template

```markdown
# <Role> Session — <project-name>

You are the **<Role>** for <project-name>.

## Protocol
Read ~/.claude/MULTI_SESSION_ARCHITECTURE.md section <N> for your full protocol.

## Project
- Jira epic: <epic-key>
- Repo: <owner>/<name>
- Read CLAUDE.md and ARCHITECTURE.md for project context.

## Jira Scoping Rule
**All Jira queries and issue creation must be scoped to epic <epic-key>.** Never search or operate on the full CPT project — other epics belong to other projects.

## Quick Reference
- <3-5 bullet points summarizing the key protocol steps for this role>
- Every bullet that references a Jira search, filing, or dedup operation must explicitly name the epic (<epic-key>)
```

Each prompt must include all five sections: role identity, protocol reference with correct section number, project block, Jira scoping rule, and quick reference. Every Quick Reference bullet that touches Jira must explicitly reference the project's epic key — never use unscoped "search Jira" or "file to Jira".

## Step 11: CI workflow (Software only)

Create `.github/workflows/test.yml` with:
- Language-appropriate test job(s)

CI failure monitoring is handled by the **Master session** running on the local machine, not by GitHub Actions. The Master session polls CI status via `gh run list` and files failures as Jira tasks under the project's epic. See `~/.claude/MULTI_SESSION_ARCHITECTURE.md` section 2 for the Master's monitoring duties.

## Step 12: Branch protection (Software)

Wait for CI to complete first, then:
```bash
gh api "repos/<owner>/<name>/branches/main/protection" -X PUT --input - <<'EOF'
{
  "required_status_checks": { "strict": true, "contexts": ["test"] },
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
  Issues:     GitHub Issues disabled (Jira-only)
  Docs:       PHILOSOPHY.md, README.md, ARCHITECTURE.md, CLAUDE.md, GITHUB_CONFIG.md
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
- [ ] GitHub Issues disabled on repo
- [ ] GitHub default labels deleted
- [ ] Jira epic key documented in CLAUDE.md and GITHUB_CONFIG.md
- [ ] All session worktrees created with correct branch names
- [ ] Session startup prompts created in .claude/sessions/ with Jira scoping rule referencing the project's epic
- [ ] CI workflow present (Software only)
- [ ] Branch protection set (Software only)
- [ ] Project memory initialized
- [ ] Initial commit pushed to main
- [ ] All session branches pushed to origin
</success_criteria>
