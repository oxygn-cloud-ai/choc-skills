#!/usr/bin/env bats

# Tests for install.sh — the root choc-skills installer.
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
  unset CLAUDE_CONFIG_DIR  # CPT-174: ensure tests never inherit ambient CLAUDE_CONFIG_DIR
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
  [[ "$output" == *"choc-skills installer v"* ]]
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
  # CPT-78: per-skill --check scope is SKILL.md only, no longer unqualified "healthy"
  [[ "$output" == *"SKILL.md verified"* ]]
}

# --- Uninstall ---

@test "--uninstall --all --force removes all skills" {
  bash "$INSTALLER" --force
  # Sanity check: at least one skill got installed
  [ -d "${HOME}/.claude/skills/${SKILLS[0]}" ]
  # Simulate per-skill installs: create router files and command dirs
  local skill
  for skill in "${SKILLS[@]}"; do
    mkdir -p "${HOME}/.claude/commands/${skill}"
    echo "router" > "${HOME}/.claude/commands/${skill}.md"
    echo "sub-cmd" > "${HOME}/.claude/commands/${skill}/help.md"
  done
  run bash "$INSTALLER" --uninstall --all --force
  [ "$status" -eq 0 ]
  for skill in "${SKILLS[@]}"; do
    [ ! -d "${HOME}/.claude/skills/${skill}" ] || {
      echo "Skill '$skill' still present after --uninstall --all --force" >&2
      return 1
    }
    [ ! -f "${HOME}/.claude/commands/${skill}.md" ] || {
      echo "Router '${skill}.md' still present after --uninstall --all --force" >&2
      return 1
    }
    [ ! -d "${HOME}/.claude/commands/${skill}" ] || {
      echo "Commands dir '${skill}/' still present after --uninstall --all --force" >&2
      return 1
    }
  done
}

@test "--uninstall --force removes one skill, leaves others" {
  # Requires at least 2 skills for the assertion to be meaningful
  [ "${#SKILLS[@]}" -ge 2 ]

  bash "$INSTALLER" --force
  local target="${SKILLS[0]}"
  # Simulate per-skill installs: create router + command dirs for all
  local skill
  for skill in "${SKILLS[@]}"; do
    mkdir -p "${HOME}/.claude/commands/${skill}"
    echo "router" > "${HOME}/.claude/commands/${skill}.md"
    echo "sub-cmd" > "${HOME}/.claude/commands/${skill}/help.md"
  done
  run bash "$INSTALLER" --uninstall --force "$target"
  [ "$status" -eq 0 ]
  [ ! -d "${HOME}/.claude/skills/${target}" ]
  [ ! -f "${HOME}/.claude/commands/${target}.md" ] || {
    echo "Router '${target}.md' still present after uninstalling '$target'" >&2
    return 1
  }
  [ ! -d "${HOME}/.claude/commands/${target}" ] || {
    echo "Commands dir '${target}/' still present after uninstalling '$target'" >&2
    return 1
  }
  # Every OTHER skill must still be present (skills + router + commands)
  for skill in "${SKILLS[@]}"; do
    [ "$skill" = "$target" ] && continue
    [ -f "${HOME}/.claude/skills/${skill}/SKILL.md" ] || {
      echo "Skill '$skill' missing after uninstalling only '$target'" >&2
      return 1
    }
    [ -f "${HOME}/.claude/commands/${skill}.md" ] || {
      echo "Router '${skill}.md' missing after uninstalling only '$target'" >&2
      return 1
    }
    [ -d "${HOME}/.claude/commands/${skill}" ] || {
      echo "Commands dir '${skill}/' missing after uninstalling only '$target'" >&2
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

@test "--changelog lists every skills/*/CHANGELOG.md owner (CPT-113 hardened)" {
  run bash "$INSTALLER" --changelog
  [ "$status" -eq 0 ]
  # CPT-113: the previous shape iterated `${SKILLS[@]}` which
  # discover_skills() builds by filtering on SKILL.md presence. Standalone
  # tools like iterm2-tmux have CHANGELOG.md but no SKILL.md, so they
  # were silently excluded from the coverage check. Iterate directly over
  # skills/*/ and require every directory with a CHANGELOG.md to appear
  # as a `[<name>]` entry in the root --changelog output — matches the
  # invariant the CPT-37 commit message claims to enforce.
  local d name
  for d in "${REPO_DIR}"/skills/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    [[ "$name" == _* ]] && continue
    [ -f "${d}CHANGELOG.md" ] || continue
    [[ "$output" == *"[${name}]"* ]] || {
      echo "'$name' has CHANGELOG.md but is missing from --changelog output (expected [${name}] link)" >&2
      return 1
    }
  done
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

# --- Security: allowed-tools ---

@test "rr SKILL.md does not grant dangerous Bash wildcards" {
  # CPT-25: Verify rr's allowed-tools does not include overly broad patterns
  local skill_md="${REPO_DIR}/skills/rr/SKILL.md"
  local frontmatter
  frontmatter=$(sed -n '/^---$/,/^---$/p' "$skill_md" | head -20)

  # These patterns must NOT appear in allowed-tools
  for pattern in 'Bash(rm ' 'Bash(bash ' 'Bash(chmod ' 'Bash(cp ' 'Bash(xargs '; do
    if echo "$frontmatter" | grep -qF "$pattern"; then
      echo "FAIL: rr SKILL.md allowed-tools contains dangerous pattern: $pattern" >&2
      return 1
    fi
  done
}

# --- Security: no hardcoded org identifiers ---

@test "no hardcoded Jira Cloud ID in skill files" {
  # CPT-27: The literal Cloud ID must not appear anywhere in skills/ —
  # all references should use $JIRA_CLOUD_ID env var placeholder
  local cloud_id="81a55da4-28c8-4a49-8a47-03a98a73f152"
  local hits
  hits=$(grep -r "$cloud_id" "${REPO_DIR}/skills/" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "Hardcoded Cloud ID found in:" >&2
    echo "$hits" >&2
    return 1
  fi
}

@test "no hardcoded Assignee Account ID in skill files" {
  # CPT-27: The literal account ID must not appear anywhere in skills/ —
  # all references should use $RR_ASSIGNEE_ID env var placeholder
  local account_id="712020:fd08a63d-8c2c-4412-8761-834339d9475c"
  local hits
  hits=$(grep -r "$account_id" "${REPO_DIR}/skills/" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "Hardcoded Assignee ID found in:" >&2
    echo "$hits" >&2
    return 1
  fi
}

# --- Security: credential handling ---

@test "rr bin scripts do not echo credentials to process list" {
  # CPT-28: echo -n with credential vars creates visible process entries.
  # All credential encoding must use printf (shell built-in) instead.
  local bin_dir="${REPO_DIR}/skills/rr/bin"
  local found=0
  for script in "$bin_dir"/*.sh; do
    if grep -n 'echo.*JIRA_EMAIL\|echo.*JIRA_API_KEY\|echo.*JIRA_AUTH' "$script" 2>/dev/null; then
      echo "FAIL: $(basename "$script") uses echo with credential variables" >&2
      found=1
    fi
  done
  [ "$found" -eq 0 ]
}
