#!/usr/bin/env bats

# Tests for install.sh — the root claude-skills installer.
#
# Each test uses a temporary HOME so it never touches the real environment.
#
# PARALLEL-UNSAFE: This test suite is NOT safe for `bats --jobs N` because
# setup() reassigns the global HOME env var. Under parallel execution,
# multiple tests would race on the same HOME and clobber each other. Run
# serially (the BATS default).
#
# Skill names are discovered dynamically from skills/ rather than hardcoded,
# so adding or renaming a skill does not require updating these tests. The
# only hardcoded name is in `installs a specific skill` where a concrete
# target is needed — it uses the first discovered skill.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALLER="${REPO_DIR}/install.sh"

# Discover all installable skills (same filter the installer uses).
# This runs fresh for each test since BATS re-evaluates the file per test.
discover_skills() {
  local dir name
  for dir in "${REPO_DIR}"/skills/*/; do
    name="$(basename "$dir")"
    [[ "$name" == _* ]] && continue
    [ -f "${dir}/SKILL.md" ] || continue
    printf '%s\n' "$name"
  done
}

setup() {
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"

  # Populate SKILLS array once per test.
  SKILLS=()
  while IFS= read -r name; do
    SKILLS+=("$name")
  done < <(discover_skills)
}

teardown() {
  # Guard: only delete if HOME is a temp directory (safety against real HOME deletion)
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] || return 0
  rm -rf "$HOME"
}

# --- Info commands ---

@test "--version prints version string" {
  run bash "$INSTALLER" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude-skills installer v"* ]]
}

@test "--help prints usage" {
  run bash "$INSTALLER" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "--list shows available skills" {
  run bash "$INSTALLER" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Available skills"* ]]
  # Every skill discovered on disk must appear in --list output
  local skill
  for skill in "${SKILLS[@]}"; do
    [[ "$output" == *"$skill"* ]] || {
      echo "Skill '$skill' missing from --list output" >&2
      return 1
    }
  done
}

# --- Install ---

@test "--force installs all skills" {
  run bash "$INSTALLER" --force
  [ "$status" -eq 0 ]
  local skill
  for skill in "${SKILLS[@]}"; do
    [ -f "${HOME}/.claude/skills/${skill}/SKILL.md" ] || {
      echo "Expected ${HOME}/.claude/skills/${skill}/SKILL.md after --force" >&2
      return 1
    }
  done
}

@test "installs a specific skill" {
  # Use the first discovered skill as the target; assert the other skills
  # are NOT installed.
  local target="${SKILLS[0]}"
  run bash "$INSTALLER" --force "$target"
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.claude/skills/${target}/SKILL.md" ]
  local skill
  for skill in "${SKILLS[@]}"; do
    [ "$skill" = "$target" ] && continue
    [ ! -f "${HOME}/.claude/skills/${skill}/SKILL.md" ] || {
      echo "Unexpected install of '$skill' when only '$target' was requested" >&2
      return 1
    }
  done
}

@test "--force overwrites tampered install" {
  local target="${SKILLS[0]}"
  # Install first
  bash "$INSTALLER" --force "$target"
  # Tamper
  echo "tampered" > "${HOME}/.claude/skills/${target}/SKILL.md"
  # Reinstall
  run bash "$INSTALLER" --force "$target"
  [ "$status" -eq 0 ]
  # Verify it matches the source
  cmp -s "${REPO_DIR}/skills/${target}/SKILL.md" "${HOME}/.claude/skills/${target}/SKILL.md"
}

# --- Health check ---

@test "--check fails with nothing installed" {
  run bash "$INSTALLER" --check
  [ "$status" -ne 0 ]
}

@test "--check passes after --force install" {
  bash "$INSTALLER" --force
  run bash "$INSTALLER" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"healthy"* ]]
}

# --- Uninstall ---

@test "--uninstall --all --force removes all skills" {
  bash "$INSTALLER" --force
  # Sanity check: at least one skill got installed
  [ -d "${HOME}/.claude/skills/${SKILLS[0]}" ]
  run bash "$INSTALLER" --uninstall --all --force
  [ "$status" -eq 0 ]
  local skill
  for skill in "${SKILLS[@]}"; do
    [ ! -d "${HOME}/.claude/skills/${skill}" ] || {
      echo "Skill '$skill' still present after --uninstall --all --force" >&2
      return 1
    }
  done
}

@test "--uninstall --force removes one skill, leaves others" {
  # Requires at least 2 skills for the assertion to be meaningful
  [ "${#SKILLS[@]}" -ge 2 ]

  bash "$INSTALLER" --force
  local target="${SKILLS[0]}"
  run bash "$INSTALLER" --uninstall --force "$target"
  [ "$status" -eq 0 ]
  [ ! -d "${HOME}/.claude/skills/${target}" ]
  # Every OTHER skill must still be present
  local skill
  for skill in "${SKILLS[@]}"; do
    [ "$skill" = "$target" ] && continue
    [ -f "${HOME}/.claude/skills/${skill}/SKILL.md" ] || {
      echo "Skill '$skill' missing after uninstalling only '$target'" >&2
      return 1
    }
  done
}

# --- Input validation ---

@test "rejects path traversal" {
  run bash "$INSTALLER" --force "../etc/passwd"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid skill name"* ]]
}

@test "rejects unknown skill name" {
  run bash "$INSTALLER" --force nonexistent-skill-xyz
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

# --- Dry run ---

@test "--dry-run exits 0 and makes no changes" {
  run bash "$INSTALLER" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]
  # Verify nothing was actually installed
  local skill
  for skill in "${SKILLS[@]}"; do
    [ ! -d "${HOME}/.claude/skills/${skill}" ] || {
      echo "--dry-run created ${HOME}/.claude/skills/${skill}" >&2
      return 1
    }
  done
}

# --- Changelog ---

@test "--changelog prints changelog" {
  run bash "$INSTALLER" --changelog
  [ "$status" -eq 0 ]
  [[ "$output" == *"Changelog"* ]]
}

# --- Quiet mode ---

@test "--quiet --force suppresses non-error output" {
  local target="${SKILLS[0]}"
  run bash "$INSTALLER" --quiet --force "$target"
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.claude/skills/${target}/SKILL.md" ]
  # Quiet mode should produce no normal output lines
  [ -z "$output" ]
}
