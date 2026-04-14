---
name: project-status
description: Show current project config, worktrees, Jira, CI, docs
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

<objective>
Display comprehensive status of the current project's configuration and health.
</objective>

<process>

## Step 1: Detect project

```bash
git rev-parse --show-toplevel 2>/dev/null
```
If not in a git repo, say "Not in a git repository. Navigate to a project and try again."

## Step 2: Verify dependencies and read references

Verify dependencies exist before reading:
- `test -f ~/.claude/MULTI_SESSION_ARCHITECTURE.md` — if missing: WARN and continue with reduced output (skip worktree role comparison)
- `test -f ~/.claude/PROJECT_STANDARDS.md` — if missing: WARN and continue (skip CI standard comparison)

Read `~/.claude/MULTI_SESSION_ARCHITECTURE.md` for role list and expected worktree layout (if available).
Read the project's `CLAUDE.md` and `PROJECT_CONFIG.json` if they exist.

## Step 3: Gather data

Run these in parallel:

```bash
# Basics
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
REPO_PATH=$(git rev-parse --show-toplevel)
REMOTE=$(git remote get-url origin 2>/dev/null || echo "none")
BRANCH=$(git branch --show-current)

# Version (check common locations)
VERSION=$(python3 -c "
import json, pathlib, re
try:
    import tomllib
except ImportError:
    try:
        import tomli as tomllib
    except ImportError:
        tomllib = None
if tomllib:
    for f in ['pyproject.toml']:
        p = pathlib.Path(f)
        if p.exists():
            d = tomllib.loads(p.read_text())
            v = d.get('project',{}).get('version') or d.get('tool',{}).get('poetry',{}).get('version')
            if v: print(v); exit()
else:
    # Regex fallback for pyproject.toml without tomllib
    p = pathlib.Path('pyproject.toml')
    if p.exists():
        m = re.search(r'^version\s*=\s*[\"'']([^\"'']+)[\"'']', p.read_text(), re.M)
        if m: print(m.group(1)); exit()
for f in ['package.json']:
    p = pathlib.Path(f)
    if p.exists():
        print(json.loads(p.read_text()).get('version','?')); exit()
print('n/a')
" 2>/dev/null || echo "n/a")

# Docs
for doc in README.md ARCHITECTURE.md PHILOSOPHY.md CLAUDE.md PROJECT_CONFIG.json; do
  if [ -f "$doc" ]; then
    echo "[x] $doc ($(stat -f '%Sm' -t '%Y-%m-%d' "$doc" 2>/dev/null || stat -c '%Y' "$doc" 2>/dev/null | xargs -I{} date -d @{} +%Y-%m-%d 2>/dev/null || echo '?'))"
  else
    echo "[ ] $doc (MISSING)"
  fi
done

# CI
ls .github/workflows/*.yml 2>/dev/null
gh run list --limit 1 --json status,conclusion,createdAt --jq '.[0] | "\(.status) \(.conclusion) \(.createdAt)"' 2>/dev/null

# Branch protection (derive owner/repo from remote URL)
OWNER_REPO=$(git remote get-url origin 2>/dev/null | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
gh api "repos/$OWNER_REPO/branches/main/protection" --jq '.required_status_checks.strict // "none"' 2>/dev/null || echo "none"

# Worktrees
git worktree list

# Open Jira issues for this project epic (via Atlassian MCP when available)
# GitHub labels and issues are intentionally not queried — Jira is source of truth.

# Tests (detect test framework without running tests)
if [ -f "pyproject.toml" ] || [ -d "tests" ]; then
  python3 -m pytest --co -q 2>/dev/null | tail -1 || echo "pytest (not runnable)"
elif [ -f "package.json" ]; then
  node -e "const p=require('./package.json'); console.log(p.scripts?.test ? 'npm test configured' : 'no test script')" 2>/dev/null || echo "node project (no test info)"
elif [ -f "Cargo.toml" ]; then
  echo "cargo test (Rust)"
else
  echo "n/a"
fi
```

## Step 4: Display status

Format all gathered data into the status display:

```
Project: <name>
Type: <from PROJECT_CONFIG.json or infer from presence of CI/tests>
Path: <path>
GitHub: <remote URL>
Jira Epic: <from CLAUDE.md or "not configured">
Version: <version>

Docs:
  [x] README.md          (2026-04-10)
  [x] ARCHITECTURE.md    (2026-04-10)
  [x] PHILOSOPHY.md      (2026-04-08)
  [x] CLAUDE.md          (2026-04-10)
  [ ] PROJECT_CONFIG.json   (MISSING)

CI:
  Workflow: <filename or "none">
  Last run: <status> (<date>)
  notify-failure: <configured/missing>

Branch: <branch> (protected: <yes/no>, force-push: <blocked/allowed>)

Worktrees:
  <for each worktree from git worktree list, show branch, path, ahead/behind main>

Loops (from PROJECT_CONFIG.json sessions.loops):
  <role>     <intervalMinutes>m   <prompt-path>   [file exists?]
  master     5m                   loops/loop.md   [x]
  triager    10m                  loops/loop.md   [x]
  ...

Env vars:
  project:   <count>   (e.g., CHOC_SKILLS_PATH auto-set at launch — sanitized dir name)
  sessions:  <count>   (keyed by role)

Open Jira Issues: <count by priority from Atlassian MCP>
Tests: <count or n/a>
Memory: <file count in ~/.claude/projects/*/memory/>
```

</process>
