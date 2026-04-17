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

Verify dependencies exist (do not read the full files — extract only what is needed):
- `test -f ~/.claude/MULTI_SESSION_ARCHITECTURE.md` — if missing: WARN and continue with reduced output (skip worktree role comparison)
- `test -f ~/.claude/GITHUB_CONFIG.md` — if missing: WARN and continue (skip label/CI standard comparison)

Derive the **expected** role list with this precedence (CPT-139 — the set-diff must compare observed worktrees against THIS project's configured roles, not the full MSA catalog; non-software projects legitimately skip chk1/chk2/playtester per MSA §1):

1. **First** — if `PROJECT_CONFIG.json` exists at the repo root and has `.sessions.roles` as an explicit array, use it verbatim. This is the per-project source of truth.
2. **Else** — if `PROJECT_CONFIG.json.project.type` (or `.project_type` / `.projectType`) is `"non-software"`, derive from `~/.claude/MULTI_SESSION_ARCHITECTURE.md` then drop `chk1`, `chk2`, `playtester`.
3. **Else** — fall back to the full MSA catalog (parse `` `session/<role>` `` tokens from the role table's worktree-branch column). This preserves pre-CPT-139 behaviour for projects that don't yet carry PROJECT_CONFIG.json or have it without role-narrowing fields. CPT-114 fixes the prior tautological derivation that used `.worktrees/*/` as the expected set, which meant missing roles silently vanished and stray worktrees were implicitly accepted — do NOT regress to that.

```bash
ROLES=()

# Layer 1: PROJECT_CONFIG.json .sessions.roles
if [ -f PROJECT_CONFIG.json ] && command -v jq >/dev/null 2>&1; then
  while IFS= read -r role; do
    [ -n "$role" ] && ROLES+=("$role")
  done < <(jq -r '.sessions.roles[]? // empty' PROJECT_CONFIG.json 2>/dev/null)
fi

# Layer 2 + 3: PROJECT_CONFIG.json .project.type, else full MSA
if [ ${#ROLES[@]} -eq 0 ] && [ -f ~/.claude/MULTI_SESSION_ARCHITECTURE.md ]; then
  local project_type=""
  if [ -f PROJECT_CONFIG.json ] && command -v jq >/dev/null 2>&1; then
    project_type=$(jq -r '.project.type // .project_type // .projectType // empty' PROJECT_CONFIG.json 2>/dev/null)
  fi
  while IFS= read -r role; do
    [ -n "$role" ] || continue
    # Non-software: MSA says skip chk1, chk2, playtester
    if [ "$project_type" = "non-software" ]; then
      case "$role" in chk1|chk2|playtester) continue ;; esac
    fi
    ROLES+=("$role")
  done < <(grep -oE '`session/[a-z0-9_-]+`' ~/.claude/MULTI_SESSION_ARCHITECTURE.md \
           | sed 's|`session/||;s|`$||' | sort -u)
fi
```

Derive the **observed** worktree list separately from `.worktrees/*/`:

```bash
WORKTREES=()
for wt in .worktrees/*/; do
  [ -d "$wt" ] && WORKTREES+=("$(basename "$wt")")
done
```

Compute the set differences so Step 4 can surface `[missing role]` and `[unexpected worktree]` flags:

```bash
# Roles that have no matching worktree
MISSING_ROLES=()
for r in "${ROLES[@]}"; do
  found=0
  for w in "${WORKTREES[@]}"; do
    [ "$r" = "$w" ] && { found=1; break; }
  done
  [ "$found" -eq 0 ] && MISSING_ROLES+=("$r")
done

# Worktrees that have no matching role (stray)
STRAY_WORKTREES=()
for w in "${WORKTREES[@]}"; do
  found=0
  for r in "${ROLES[@]}"; do
    [ "$w" = "$r" ] && { found=1; break; }
  done
  [ "$found" -eq 0 ] && STRAY_WORKTREES+=("$w")
done
```

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
  <for each role in MISSING_ROLES: print "  [missing role] <role> — expected by MULTI_SESSION_ARCHITECTURE.md but no .worktrees/<role>/">
  <for each worktree in STRAY_WORKTREES: print "  [unexpected worktree] <name> — present under .worktrees/ but not in MULTI_SESSION_ARCHITECTURE.md role table">

Labels: <count> (<list P1-P4 presence>)
Open Issues: <count by priority>
Tests: <count or n/a>
Memory: <file count in ~/.claude/projects/*/memory/>
```

</process>
