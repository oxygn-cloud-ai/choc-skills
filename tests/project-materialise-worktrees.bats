#!/usr/bin/env bats

# Tests for skills/project/bin/project-materialise-worktrees.sh
#
# The script materialises missing role worktrees for /project:launch. Tests
# cover presence detection, branch precedence (local > remote > default),
# default-branch detection, graceful failure for common conflict cases, and
# --list vs --execute.
#
# Live Claude Code and tmux are NOT involved — this script only shells to git.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="${REPO_DIR}/skills/project/bin/project-materialise-worktrees.sh"

# Helper: create a remote-bare + local-clone pair with PROJECT_CONFIG.json.
# Returns the local repo path via $TEST_REPO (global), and the remote path via
# $REMOTE_REPO (global). Default branch is `main`.
_make_repos() {
  local default_branch="${1:-main}"

  REMOTE_REPO="$(mktemp -d)"
  git init --quiet --bare --initial-branch="$default_branch" "$REMOTE_REPO"

  TEST_REPO="$(mktemp -d)"
  git -C "$TEST_REPO" init --quiet --initial-branch="$default_branch"
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name  "Test"
  echo "hello" > "$TEST_REPO/README.md"
  git -C "$TEST_REPO" add README.md
  git -C "$TEST_REPO" commit --quiet -m "initial"
  git -C "$TEST_REPO" remote add origin "$REMOTE_REPO"
  git -C "$TEST_REPO" push --quiet -u origin "$default_branch"

  cat > "$TEST_REPO/PROJECT_CONFIG.json" <<EOF
{
  "schemaVersion": 1,
  "project": { "name": "test", "type": "software" },
  "github": { "owner": "org", "repo": "test", "defaultBranch": "$default_branch" },
  "sessions": { "roles": ["master", "planner", "fixer"] }
}
EOF
}

setup() {
  _make_repos main
}

teardown() {
  # git worktree cleanup tolerates missing paths
  [ -n "${TEST_REPO:-}"   ] && rm -rf "$TEST_REPO"
  [ -n "${REMOTE_REPO:-}" ] && rm -rf "$REMOTE_REPO"
}

# --- Help / usage ---

@test "materialise: --help prints usage and exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "materialise: missing --repo when cwd not a repo exits non-zero" {
  run "$SCRIPT" --list --repo "/does/not/exist"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* || "$output" == *"not found"* ]]
}

@test "materialise: missing PROJECT_CONFIG.json exits non-zero with clear message" {
  rm "$TEST_REPO/PROJECT_CONFIG.json"
  run "$SCRIPT" --list --repo "$TEST_REPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"PROJECT_CONFIG.json"* ]]
}

# --- --list output ---

@test "materialise: --list with empty .worktrees/ reports all roles as missing" {
  run "$SCRIPT" --list --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"master"*   ]]
  [[ "$output" == *"planner"*  ]]
  [[ "$output" == *"fixer"*    ]]
}

@test "materialise: --list reports zero missing when all worktrees already exist" {
  for role in master planner fixer; do
    GIT_WORKTREE_OVERRIDE=1 git -C "$TEST_REPO" worktree add -q ".worktrees/$role" -b "session/$role" main
  done
  run "$SCRIPT" --list --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0"* ]]  # some "0 missing" / "nothing to do" indicator
  # And NO action-line entries for the roles
  [[ ! "$output" == *"action=reuse"*  ]]
  [[ ! "$output" == *"action=track"*  ]]
  [[ ! "$output" == *"action=create"* ]]
}

# --- --execute: core creation ---

@test "materialise: --execute creates missing worktrees from sessions.roles" {
  run "$SCRIPT" --execute --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  for role in master planner fixer; do
    [ -d "$TEST_REPO/.worktrees/$role" ]
    git -C "$TEST_REPO" worktree list --porcelain | grep -q "worktree $TEST_REPO/.worktrees/$role"
  done
}

@test "materialise: --execute reuses existing local session/<role> branch (no -b)" {
  # Pre-create local branch (simulating branches created by prior /project:new)
  git -C "$TEST_REPO" branch session/master main
  run "$SCRIPT" --execute --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  # The worktree should be on session/master, and the branch SHA should match
  # the pre-existing one (i.e. the script reused, didn't recreate).
  head=$(git -C "$TEST_REPO/.worktrees/master" rev-parse --abbrev-ref HEAD)
  [ "$head" = "session/master" ]
}

@test "materialise: --execute tracks origin/session/<role> when only remote branch exists" {
  # Seed origin with session/planner but not locally
  git -C "$TEST_REPO" branch planner-seed main
  git -C "$TEST_REPO" push --quiet origin planner-seed:session/planner
  git -C "$TEST_REPO" branch -D planner-seed

  # No local refs/heads/session/planner, origin has it
  run git -C "$TEST_REPO" show-ref --verify --quiet refs/heads/session/planner
  [ "$status" -ne 0 ]

  run "$SCRIPT" --execute --repo "$TEST_REPO"
  [ "$status" -eq 0 ]

  # Local branch now exists and the worktree is on it
  git -C "$TEST_REPO" show-ref --verify --quiet refs/heads/session/planner

  head=$(git -C "$TEST_REPO/.worktrees/planner" rev-parse --abbrev-ref HEAD)
  [ "$head" = "session/planner" ]

  # Upstream should be set (--track semantics)
  upstream=$(git -C "$TEST_REPO/.worktrees/planner" rev-parse --abbrev-ref 'session/planner@{upstream}' 2>&1 || true)
  [[ "$upstream" == "origin/session/planner" ]]
}

@test "materialise: --execute creates new branch from default branch when neither local nor remote exists" {
  run "$SCRIPT" --execute --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  # All 3 branches now exist locally, all on the default-branch SHA
  main_sha=$(git -C "$TEST_REPO" rev-parse main)
  for role in master planner fixer; do
    role_sha=$(git -C "$TEST_REPO" rev-parse "session/$role")
    [ "$role_sha" = "$main_sha" ]
  done
}

# --- Default-branch detection ---

@test "materialise: uses PROJECT_CONFIG.json .github.defaultBranch" {
  # Reinit with default branch 'develop' and update the config to match.
  teardown
  _make_repos develop
  run "$SCRIPT" --execute --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  develop_sha=$(git -C "$TEST_REPO" rev-parse develop)
  master_sha=$(git -C "$TEST_REPO" rev-parse session/master)
  [ "$master_sha" = "$develop_sha" ]
}

@test "materialise: falls back to git symbolic-ref when config omits defaultBranch" {
  # Strip defaultBranch from config; script must discover it via origin/HEAD
  teardown
  _make_repos main
  # remove the defaultBranch key
  python3 -c "
import json,sys
p='$TEST_REPO/PROJECT_CONFIG.json'
with open(p) as f: d=json.load(f)
del d['github']['defaultBranch']
with open(p,'w') as f: json.dump(d,f)
"
  # Ensure origin/HEAD symref exists so symbolic-ref can resolve it
  git -C "$TEST_REPO" remote set-head origin main

  run "$SCRIPT" --execute --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  main_sha=$(git -C "$TEST_REPO" rev-parse main)
  master_sha=$(git -C "$TEST_REPO" rev-parse session/master)
  [ "$master_sha" = "$main_sha" ]
}

@test "materialise: --default-branch flag overrides detection" {
  # Create a second branch to target
  git -C "$TEST_REPO" checkout --quiet -b experimental
  echo "x" >> "$TEST_REPO/README.md"
  git -C "$TEST_REPO" commit --quiet -am "experimental commit"
  git -C "$TEST_REPO" checkout --quiet main
  run "$SCRIPT" --execute --repo "$TEST_REPO" --default-branch experimental
  [ "$status" -eq 0 ]
  exp_sha=$(git -C "$TEST_REPO" rev-parse experimental)
  master_sha=$(git -C "$TEST_REPO" rev-parse session/master)
  [ "$master_sha" = "$exp_sha" ]
}

# --- Conflict handling ---

@test "materialise: stray plain directory at .worktrees/<role>/ is detected, not treated as worktree" {
  mkdir -p "$TEST_REPO/.worktrees/master"
  echo "marker" > "$TEST_REPO/.worktrees/master/stray-file"
  run "$SCRIPT" --list --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  # master should be reported as missing (because it's not a registered worktree)
  # with an indication of the stray-dir situation.
  [[ "$output" == *"master"* ]]
  [[ "$output" == *"stray"* || "$output" == *"not a worktree"* || "$output" == *"conflict"* ]]
}

@test "materialise: --execute skips role whose branch is already checked out elsewhere, with clear message" {
  # Create a branch and check it out in a separate worktree (simulating main-repo
  # being on session/master, or another worktree holding the ref)
  git -C "$TEST_REPO" branch session/master main
  OTHER_WT="$(mktemp -d)/other"
  GIT_WORKTREE_OVERRIDE=1 git -C "$TEST_REPO" worktree add --quiet "$OTHER_WT" session/master

  run "$SCRIPT" --execute --repo "$TEST_REPO"
  [ "$status" -ne 0 ]
  # Error must name the role and the conflicting location
  [[ "$output" == *"master"* ]]
  [[ "$output" == *"checked out"* || "$output" == *"conflict"* ]]

  # Other roles should still succeed
  [ -d "$TEST_REPO/.worktrees/planner" ]
  [ -d "$TEST_REPO/.worktrees/fixer" ]

  # cleanup
  git -C "$TEST_REPO" worktree remove --force "$OTHER_WT" 2>/dev/null || true
  rm -rf "$(dirname "$OTHER_WT")"
}

@test "materialise: prunes stale .git/worktrees admin data before adding" {
  # Simulate a stale worktree admin entry — directory removed but metadata left.
  GIT_WORKTREE_OVERRIDE=1 git -C "$TEST_REPO" worktree add --quiet ".worktrees/master" -b "session/master" main
  rm -rf "$TEST_REPO/.worktrees/master"
  # Now .git/worktrees/master/ exists but the directory is gone. Without prune,
  # `git worktree add .worktrees/master ...` would fail with "already registered".
  run "$SCRIPT" --execute --repo "$TEST_REPO"
  [ "$status" -eq 0 ]
  [ -d "$TEST_REPO/.worktrees/master" ]
}

# --- Loop.md template seeding ---

# Helper: create a templates dir with minimal loop.md content for a given role.
_mk_template() {
  local role="$1" dir="$2"
  mkdir -p "$dir"
  printf '# %s loop template\n\nRecurring task for %s.\n' "$role" "$role" > "$dir/$role.md"
}

@test "materialise: seeds loop.md for loop-configured role with template" {
  TPL_DIR="$(mktemp -d)"
  _mk_template master "$TPL_DIR"
  # Add loops config for master so the role is loop-capable in this project
  python3 -c "
import json
p='$TEST_REPO/PROJECT_CONFIG.json'
with open(p) as f: d=json.load(f)
d['sessions']['loops'] = {'master': {'intervalMinutes': 10, 'prompt': 'loops/loop.md'}}
with open(p,'w') as f: json.dump(d,f)
"
  run "$SCRIPT" --execute --repo "$TEST_REPO" --templates-dir "$TPL_DIR"
  [ "$status" -eq 0 ]
  [ -f "$TEST_REPO/.worktrees/master/loops/loop.md" ]
  # Content comes from the template
  grep -q "master loop template" "$TEST_REPO/.worktrees/master/loops/loop.md"
  # The loop.md is committed to session/master (not left as untracked)
  run git -C "$TEST_REPO/.worktrees/master" status --porcelain loops/loop.md
  [ -z "$output" ]
  rm -rf "$TPL_DIR"
}

@test "materialise: does NOT seed loop.md for a role with no loops entry" {
  TPL_DIR="$(mktemp -d)"
  _mk_template planner "$TPL_DIR"   # template exists
  # But planner is NOT in sessions.loops (no loop entry in default fixture)
  run "$SCRIPT" --execute --repo "$TEST_REPO" --templates-dir "$TPL_DIR"
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_REPO/.worktrees/planner/loops/loop.md" ]
  rm -rf "$TPL_DIR"
}

@test "materialise: warns but proceeds when loop-configured role has no template file" {
  # Configure loops for master but don't create the template
  python3 -c "
import json
p='$TEST_REPO/PROJECT_CONFIG.json'
with open(p) as f: d=json.load(f)
d['sessions']['loops'] = {'master': {'intervalMinutes': 10, 'prompt': 'loops/loop.md'}}
with open(p,'w') as f: json.dump(d,f)
"
  TPL_DIR="$(mktemp -d)"   # empty directory, no master.md
  run "$SCRIPT" --execute --repo "$TEST_REPO" --templates-dir "$TPL_DIR"
  [ "$status" -eq 0 ]
  # Worktree IS created
  [ -d "$TEST_REPO/.worktrees/master" ]
  # loop.md is NOT seeded
  [ ! -f "$TEST_REPO/.worktrees/master/loops/loop.md" ]
  # Warning appears in output
  [[ "$output" == *"loop template missing"* ]]
  rm -rf "$TPL_DIR"
}

@test "materialise: --skip-loop-seed suppresses seeding even when everything is configured" {
  TPL_DIR="$(mktemp -d)"
  _mk_template master "$TPL_DIR"
  python3 -c "
import json
p='$TEST_REPO/PROJECT_CONFIG.json'
with open(p) as f: d=json.load(f)
d['sessions']['loops'] = {'master': {'intervalMinutes': 10, 'prompt': 'loops/loop.md'}}
with open(p,'w') as f: json.dump(d,f)
"
  run "$SCRIPT" --execute --repo "$TEST_REPO" --templates-dir "$TPL_DIR" --skip-loop-seed
  [ "$status" -eq 0 ]
  [ -d "$TEST_REPO/.worktrees/master" ]
  [ ! -f "$TEST_REPO/.worktrees/master/loops/loop.md" ]
  rm -rf "$TPL_DIR"
}

@test "materialise: seeds loop.md on TRACK path (remote-only branch) for loop-configured role" {
  TPL_DIR="$(mktemp -d)"
  _mk_template planner "$TPL_DIR"
  # Push planner-seed to origin as session/planner, then delete the local copy.
  # After this, session/planner exists only on origin — TRACK path is triggered.
  git -C "$TEST_REPO" branch planner-seed main
  git -C "$TEST_REPO" push --quiet origin planner-seed:session/planner
  git -C "$TEST_REPO" branch -D planner-seed
  # Configure planner in sessions.loops so seed_loop_prompt engages
  python3 -c "
import json
p='$TEST_REPO/PROJECT_CONFIG.json'
with open(p) as f: d=json.load(f)
d['sessions']['loops'] = {'planner': {'intervalMinutes': 10, 'prompt': 'loops/loop.md'}}
with open(p,'w') as f: json.dump(d,f)
"
  run "$SCRIPT" --execute --repo "$TEST_REPO" --templates-dir "$TPL_DIR"
  [ "$status" -eq 0 ]
  # Worktree created via TRACK path, loop.md seeded + tracked on session/planner
  [ -f "$TEST_REPO/.worktrees/planner/loops/loop.md" ]
  grep -q "planner loop template" "$TEST_REPO/.worktrees/planner/loops/loop.md"
  run git -C "$TEST_REPO/.worktrees/planner" ls-files --error-unmatch loops/loop.md
  [ "$status" -eq 0 ]
  rm -rf "$TPL_DIR"
}

@test "materialise: heals an untracked loops/loop.md on an already-registered worktree" {
  # Reproduces the Bug 1 (v2.4.0) scenario: a prior run copied loop.md to
  # disk but git commit failed (e.g., git user.email unset at the time), so
  # the file was left untracked. In v2.4.0 the role was skipped on re-run
  # because the worktree was registered. v2.4.1 heals it.
  TPL_DIR="$(mktemp -d)"
  _mk_template master "$TPL_DIR"
  python3 -c "
import json
p='$TEST_REPO/PROJECT_CONFIG.json'
with open(p) as f: d=json.load(f)
d['sessions']['loops'] = {'master': {'intervalMinutes': 10, 'prompt': 'loops/loop.md'}}
with open(p,'w') as f: json.dump(d,f)
"
  # Simulate the failure state: worktree registered, loop.md present on disk
  # but untracked on the branch.
  GIT_WORKTREE_OVERRIDE=1 git -C "$TEST_REPO" worktree add --quiet ".worktrees/master" -b "session/master" main
  mkdir -p "$TEST_REPO/.worktrees/master/loops"
  cp "$TPL_DIR/master.md" "$TEST_REPO/.worktrees/master/loops/loop.md"
  # Deliberately NO commit here — this is the bug's aftermath.
  run git -C "$TEST_REPO/.worktrees/master" ls-files --error-unmatch loops/loop.md
  [ "$status" -ne 0 ]   # confirm untracked

  # Re-run — v2.4.1's heal path should commit the existing file.
  run "$SCRIPT" --execute --repo "$TEST_REPO" --templates-dir "$TPL_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[heal]"* ]]
  [[ "$output" == *"master"* ]]

  # Now tracked on session/master.
  run git -C "$TEST_REPO/.worktrees/master" ls-files --error-unmatch loops/loop.md
  [ "$status" -eq 0 ]

  rm -rf "$TPL_DIR"
}

@test "materialise: seeding is idempotent — existing loop.md not overwritten on re-run" {
  TPL_DIR="$(mktemp -d)"
  _mk_template master "$TPL_DIR"
  python3 -c "
import json
p='$TEST_REPO/PROJECT_CONFIG.json'
with open(p) as f: d=json.load(f)
d['sessions']['loops'] = {'master': {'intervalMinutes': 10, 'prompt': 'loops/loop.md'}}
with open(p,'w') as f: json.dump(d,f)
"
  # First run seeds it
  run "$SCRIPT" --execute --repo "$TEST_REPO" --templates-dir "$TPL_DIR"
  [ "$status" -eq 0 ]
  # Overwrite the seeded file with user content
  echo "USER CUSTOMISATION" > "$TEST_REPO/.worktrees/master/loops/loop.md"
  git -C "$TEST_REPO/.worktrees/master" add loops/loop.md
  git -C "$TEST_REPO/.worktrees/master" commit --quiet -m "custom"

  # Remove the worktree (but keep the branch + commits). .git/worktrees/ admin
  # entry is also cleaned so re-materialisation is from scratch.
  GIT_WORKTREE_OVERRIDE=1 git -C "$TEST_REPO" worktree remove --force ".worktrees/master"

  # Re-run — worktree re-materialises (REUSE of session/master), loop.md is already
  # on the branch from the customisation commit, so it won't be re-seeded.
  run "$SCRIPT" --execute --repo "$TEST_REPO" --templates-dir "$TPL_DIR"
  [ "$status" -eq 0 ]
  grep -q "USER CUSTOMISATION" "$TEST_REPO/.worktrees/master/loops/loop.md"
  rm -rf "$TPL_DIR"
}
