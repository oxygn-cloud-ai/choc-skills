#!/usr/bin/env bats

# CPT-112: `install.sh --uninstall <name>` must clean up router files
# even when the skill directory is already gone.
#
# CPT-36 added router + subcommand-directory cleanup to uninstall_skill
# BUT only after the `[ -d "$target" ]` guard. When the skill directory
# is missing (pre-CPT-36 partial state, or user ran `rm -rf` manually),
# the function returns early via the "not installed" branch and skips
# the new router cleanup — leaving the exact stale state CPT-36 was
# written to fix.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALLER="${REPO_DIR}/install.sh"

setup() {
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] || return 0
  rm -rf "$HOME"
}

@test "--uninstall removes orphan router.md when skill dir is already gone (CPT-112)" {
  # Simulate pre-CPT-36 stale state: router file exists, skill dir doesn't.
  local name="rr"
  local skill_dir="${HOME}/.claude/skills/${name}"
  local router_md="${HOME}/.claude/commands/${name}.md"

  mkdir -p "${HOME}/.claude/commands"
  touch "$router_md"

  # Sanity: skill dir must NOT exist, router MUST exist
  [ ! -d "$skill_dir" ]
  [ -f "$router_md" ]

  run bash "$INSTALLER" --uninstall --force "$name"

  # Post-fix: router must be gone
  [ ! -f "$router_md" ] || {
    echo "orphan router ${router_md} still present after --uninstall" >&2
    echo "uninstall output: $output" >&2
    return 1
  }
}

@test "--uninstall removes orphan commands/<name>/ when skill dir is already gone (CPT-112)" {
  local name="chk2"
  local skill_dir="${HOME}/.claude/skills/${name}"
  local commands_dir="${HOME}/.claude/commands/${name}"

  mkdir -p "$commands_dir"
  touch "$commands_dir/foo.md"

  [ ! -d "$skill_dir" ]
  [ -d "$commands_dir" ]

  run bash "$INSTALLER" --uninstall --force "$name"

  [ ! -d "$commands_dir" ] || {
    echo "orphan commands dir ${commands_dir} still present after --uninstall" >&2
    echo "uninstall output: $output" >&2
    return 1
  }
}

@test "--uninstall with nothing installed still no-ops cleanly (CPT-112)" {
  # No skill dir, no router — must not error out and must not succeed "destructively"
  local name="rr"
  run bash "$INSTALLER" --uninstall --force "$name"

  # Exit 0 (nothing to do) is acceptable. The important thing is no crash.
  [ "$status" -eq 0 ] || {
    echo "--uninstall crashed on empty state: $output" >&2
    return 1
  }
}
