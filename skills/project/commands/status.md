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
- `test -f ~/.claude/GITHUB_CONFIG.md` — if missing: WARN and continue (skip label/CI standard comparison)

Read `~/.claude/MULTI_SESSION_ARCHITECTURE.md` for role list and expected worktree layout (if available).
Read the project's `CLAUDE.md` and `GITHUB_CONFIG.md` if they exist.

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
for doc in README.md ARCHITECTURE.md PHILOSOPHY.md CLAUDE.md GITHUB_CONFIG.md; do
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

# Labels
gh label list --json name --jq '.[].name' 2>/dev/null | sort

# Open issues (Jira — via Atlassian MCP if available, otherwise note)
# Fallback: check GitHub issues
gh issue list --state open --json number,labels --jq '[.[] | {label: (.labels[0].name // "unlabeled")}] | group_by(.label) | map({key: .[0].label, count: length}) | .[]' 2>/dev/null

# Tests
python3 -m pytest --co -q 2>/dev/null | tail -1 || npm test --dry-run 2>/dev/null || echo "n/a"
```

## Step 4: Display status

Format all gathered data into the status display:

```
Project: <name>
Type: <from GITHUB_CONFIG.md or infer from presence of CI/tests>
Path: <path>
GitHub: <remote URL>
Jira Epic: <from CLAUDE.md or "not configured">
Version: <version>

Docs:
  [x] README.md          (2026-04-10)
  [x] ARCHITECTURE.md    (2026-04-10)
  [x] PHILOSOPHY.md      (2026-04-08)
  [x] CLAUDE.md          (2026-04-10)
  [ ] GITHUB_CONFIG.md   (MISSING)

CI:
  Workflow: <filename or "none">
  Last run: <status> (<date>)
  notify-failure: <configured/missing>

Branch: <branch> (protected: <yes/no>, force-push: <blocked/allowed>)

Worktrees:
  <for each worktree from git worktree list, show branch, path, ahead/behind main>

Labels: <count> (<list P1-P4 presence>)
Open Issues: <count by priority>
Tests: <count or n/a>
Memory: <file count in ~/.claude/projects/*/memory/>
```

</process>
