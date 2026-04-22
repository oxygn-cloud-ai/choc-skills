#!/usr/bin/env bash
# project-materialise-worktrees.sh — create missing role worktrees for /project:launch.
#
# Reads $REPO/PROJECT_CONFIG.json .sessions.roles[] and materialises each
# missing .worktrees/<role>/ using this branch precedence:
#   1. refs/heads/session/<role>           → reuse (plain `worktree add`, no -b)
#   2. refs/remotes/origin/session/<role>  → `worktree add --track -b session/<role> <path> origin/session/<role>`
#   3. neither                             → `worktree add -b session/<role> <path> <default-branch>`
#
# Default branch is detected in this order:
#   1. --default-branch flag (override)
#   2. PROJECT_CONFIG.json .github.defaultBranch
#   3. `git symbolic-ref --short refs/remotes/origin/HEAD` (strip `origin/`)
#   4. error
#
# Policy exception — the block-worktree-add.sh PreToolUse hook forbids bare
# `git worktree add` outside of the /project:launch and /project:new setup
# flows. Every `worktree add` below inlines GIT_WORKTREE_OVERRIDE=1 to bypass
# it as the sanctioned setup-automation boundary. See
# MULTI_SESSION_ARCHITECTURE.md §7.1 and hooks/block-worktree-add.sh.
#
# Exit codes:
#   0 — all requested roles succeeded (or --list completed)
#   1 — usage / arg error
#   2 — missing dependency, unreadable config, or undetectable default branch
#   4 — at least one role could not be materialised (partial failure)
#
# Usage:
#   project-materialise-worktrees.sh (--list | --execute) \
#       [--repo <path>] [--default-branch <name>]

set -euo pipefail

MODE=""
REPO_ROOT=""
DEFAULT_BRANCH_OVERRIDE=""
TEMPLATES_DIR_OVERRIDE=""
SKIP_LOOP_SEED="false"

usage() {
  cat <<EOF
Usage: project-materialise-worktrees.sh (--list | --execute) [--repo <path>] [--default-branch <name>]

Flags:
  --list                 Print the plan of missing roles without creating anything.
  --execute              Create missing worktrees.
  --repo <path>          Repo root (default: auto-detect via \`git rev-parse --git-common-dir\`).
  --default-branch <n>   Override detected default branch.
  --templates-dir <path> Override where per-role loop.md templates are read from
                         (default: \${CLAUDE_CONFIG_DIR:-\$HOME/.claude}/skills/project/templates/loops).
  --skip-loop-seed       Do not seed loop.md files (worktree creation only).
  -h, --help             Show this help.

Exit: 0 on success (or empty --list), 1 on usage error, 2 on missing deps,
      4 on partial failure.
EOF
  exit "${1:-1}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --list)            MODE="list"; shift ;;
    --execute)         MODE="execute"; shift ;;
    --repo)            REPO_ROOT="${2:-}"; shift 2 ;;
    --default-branch)  DEFAULT_BRANCH_OVERRIDE="${2:-}"; shift 2 ;;
    --templates-dir)   TEMPLATES_DIR_OVERRIDE="${2:-}"; shift 2 ;;
    --skip-loop-seed)  SKIP_LOOP_SEED="true"; shift ;;
    -h|--help)         usage 0 ;;
    *)                 echo "Unknown arg: $1" >&2; usage 1 ;;
  esac
done

[ -n "$MODE" ] || { echo "one of --list or --execute required" >&2; usage 1; }

# Repo resolution ------------------------------------------------------------
if [ -z "$REPO_ROOT" ]; then
  common=$(git rev-parse --git-common-dir 2>/dev/null) || {
    echo "not in a git repository (and --repo not supplied)" >&2
    exit 2
  }
  REPO_ROOT=$(cd "$common/.." && pwd)
fi
[ -d "$REPO_ROOT" ] || { echo "repo path does not exist: $REPO_ROOT" >&2; exit 2; }
git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "not a git repository: $REPO_ROOT" >&2; exit 2; }

# Config + roles -------------------------------------------------------------
CONFIG="$REPO_ROOT/PROJECT_CONFIG.json"
[ -f "$CONFIG" ] || { echo "PROJECT_CONFIG.json not found at $CONFIG" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

mapfile -t ROLES < <(jq -r '.sessions.roles[]?' "$CONFIG" 2>/dev/null || true)
[ "${#ROLES[@]}" -gt 0 ] || { echo "PROJECT_CONFIG.json has no .sessions.roles[]" >&2; exit 2; }

# Default branch detection ---------------------------------------------------
detect_default_branch() {
  if [ -n "$DEFAULT_BRANCH_OVERRIDE" ]; then
    printf '%s' "$DEFAULT_BRANCH_OVERRIDE"; return 0
  fi
  local from_config
  from_config=$(jq -r '.github.defaultBranch // empty' "$CONFIG" 2>/dev/null || true)
  if [ -n "$from_config" ]; then
    printf '%s' "$from_config"; return 0
  fi
  local symref
  symref=$(git -C "$REPO_ROOT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)
  if [ -n "$symref" ]; then
    printf '%s' "${symref#origin/}"; return 0
  fi
  return 1
}

DB=$(detect_default_branch) || {
  echo "cannot determine default branch: not in PROJECT_CONFIG.json, --default-branch not supplied, and origin/HEAD is not set. Fix one of those and retry." >&2
  exit 2
}

# Resolve templates directory (for per-role loop.md seeding).
if [ -n "$TEMPLATES_DIR_OVERRIDE" ]; then
  TEMPLATES_DIR="$TEMPLATES_DIR_OVERRIDE"
else
  TEMPLATES_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/project/templates/loops"
fi

# Clear stale worktree admin entries so a previously `rm -rf`'d worktree
# doesn't block `git worktree add` with "already registered".
git -C "$REPO_ROOT" worktree prune 2>/dev/null || true

# Helpers --------------------------------------------------------------------
is_registered_worktree() {
  # $1: absolute path. True iff `git worktree list --porcelain` lists it.
  local path="$1"
  git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null \
    | awk -v p="$path" 'BEGIN{f=0} /^worktree / { if ($2==p) { f=1; exit } } END { exit !f }'
}

branch_checkout_location() {
  # $1: short branch name (e.g. "session/master"). Prints the worktree path
  # where that branch is currently checked out, or empty if nowhere.
  local branch="$1"
  git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | awk -v b="refs/heads/$branch" '
    /^worktree / { cur=$2 }
    /^branch /   { if ($2==b) { print cur; exit } }
  '
}

has_local_branch()  { git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$1"; }
has_remote_branch() { git -C "$REPO_ROOT" show-ref --verify --quiet "refs/remotes/origin/$1"; }

# seed_loop_prompt <role> <worktree-abs-path>
# Copy the role's loop.md template into the worktree and commit to session/<role>,
# iff the role is loop-configured in PROJECT_CONFIG.json, the template file exists,
# and no loop.md is already present. Idempotent.
seed_loop_prompt() {
  local role="$1" wt="$2"
  [ "$SKIP_LOOP_SEED" = "true" ] && return 0
  local is_looping
  is_looping=$(jq -r --arg r "$role" '.sessions.loops[$r] // empty' "$CONFIG" 2>/dev/null || true)
  [ -n "$is_looping" ] || return 0   # role not loop-configured for this project
  local template="${TEMPLATES_DIR}/${role}.md"
  if [ ! -f "$template" ]; then
    printf "  [warn]  %-12s  loop template missing at %s — loop.md not seeded\n" "$role" "$template" >&2
    return 0
  fi
  local target="$wt/loops/loop.md"
  [ -f "$target" ] && return 0       # already there, idempotent
  mkdir -p "$wt/loops"
  cp "$template" "$target"
  # Commit to session/<role>, best-effort push. Failures are non-fatal —
  # the helper's contract is worktree materialisation; loop.md seeding is
  # additive.
  if git -C "$wt" add "loops/loop.md" >/dev/null 2>&1 \
     && git -C "$wt" commit --quiet -m "feat: add loop prompt for $role" >/dev/null 2>&1; then
    git -C "$wt" push --quiet -u origin HEAD 2>/dev/null || true
    printf "  [seed]  %-12s  loops/loop.md  (from template %s)\n" "$role" "${role}.md"
  else
    printf "  [warn]  %-12s  loops/loop.md written but git commit failed\n" "$role" >&2
  fi
}

# Build plan -----------------------------------------------------------------
# Each plan entry is a TAB-separated tuple: ROLE<TAB>ACTION<TAB>DETAILS.
# ACTION ∈ REUSE | TRACK | CREATE | CONFLICT | STRAY
declare -a PLAN=()
for role in "${ROLES[@]}"; do
  wt="$REPO_ROOT/.worktrees/$role"
  branch="session/$role"

  if is_registered_worktree "$wt"; then
    continue
  fi

  if [ -e "$wt" ]; then
    PLAN+=("$role	STRAY	.worktrees/$role exists but is not a registered worktree (stray directory)")
    continue
  fi

  if has_local_branch "$branch"; then
    loc=$(branch_checkout_location "$branch" || true)
    if [ -n "$loc" ]; then
      PLAN+=("$role	CONFLICT	branch $branch already checked out at $loc")
      continue
    fi
    PLAN+=("$role	REUSE	reuse existing local branch $branch")
  elif has_remote_branch "$branch"; then
    PLAN+=("$role	TRACK	track origin/$branch (local branch will be created)")
  else
    PLAN+=("$role	CREATE	new branch $branch from $DB")
  fi
done

# --list --------------------------------------------------------------------
if [ "$MODE" = "list" ]; then
  if [ "${#PLAN[@]}" -eq 0 ]; then
    echo "0 missing worktrees — nothing to do"
    exit 0
  fi
  echo "Missing worktrees (${#PLAN[@]}):"
  for line in "${PLAN[@]}"; do
    IFS=$'\t' read -r role action details <<<"$line"
    printf "  %-12s  action=%s  %s\n" "$role" "$action" "$details"
  done
  exit 0
fi

# --execute ------------------------------------------------------------------
[ "$MODE" = "execute" ] || { echo "internal: unknown MODE=$MODE" >&2; exit 1; }

mkdir -p "$REPO_ROOT/.worktrees"

failed=0
for line in "${PLAN[@]}"; do
  IFS=$'\t' read -r role action details <<<"$line"
  wt="$REPO_ROOT/.worktrees/$role"
  branch="session/$role"

  case "$action" in
    REUSE)
      if GIT_WORKTREE_OVERRIDE=1 git -C "$REPO_ROOT" worktree add --quiet "$wt" "$branch" 2>/dev/null; then
        printf "  [OK]    %-12s  worktree created (reused %s)\n" "$role" "$branch"
        seed_loop_prompt "$role" "$wt"
      else
        printf "  [ERROR] %-12s  git worktree add failed for %s\n" "$role" "$branch" >&2
        failed=$((failed + 1))
      fi
      ;;
    TRACK)
      if GIT_WORKTREE_OVERRIDE=1 git -C "$REPO_ROOT" worktree add --quiet --track -b "$branch" "$wt" "origin/$branch" 2>/dev/null; then
        printf "  [OK]    %-12s  worktree created (tracking origin/%s)\n" "$role" "$branch"
        seed_loop_prompt "$role" "$wt"
      else
        printf "  [ERROR] %-12s  git worktree add --track failed for %s\n" "$role" "$branch" >&2
        failed=$((failed + 1))
      fi
      ;;
    CREATE)
      if GIT_WORKTREE_OVERRIDE=1 git -C "$REPO_ROOT" worktree add --quiet -b "$branch" "$wt" "$DB" 2>/dev/null; then
        printf "  [OK]    %-12s  worktree created (new branch %s from %s)\n" "$role" "$branch" "$DB"
        seed_loop_prompt "$role" "$wt"
      else
        printf "  [ERROR] %-12s  git worktree add -b failed for %s (from %s)\n" "$role" "$branch" "$DB" >&2
        failed=$((failed + 1))
      fi
      ;;
    CONFLICT)
      printf "  [ERROR] %-12s  %s\n" "$role" "$details" >&2
      failed=$((failed + 1))
      ;;
    STRAY)
      printf "  [ERROR] %-12s  %s — remove or inspect before retrying\n" "$role" "$details" >&2
      failed=$((failed + 1))
      ;;
  esac
done

if [ "$failed" -gt 0 ]; then
  echo "$failed role(s) failed to materialise; see errors above" >&2
  exit 4
fi
echo "All missing worktrees materialised (${#PLAN[@]})."
exit 0
