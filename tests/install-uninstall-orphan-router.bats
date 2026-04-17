#!/usr/bin/env bats

# CPT-112 (original): `install.sh --uninstall <name>` should be able to clean
# up router files even when the skill directory is already gone.
# CPT-138 (follow-up): the post-CPT-112 unconditional cleanup also deletes
# user-authored ~/.claude/commands/<name>.md files that were never installed
# by this repo (same basename, coincidental collision). Data-loss regression.
#
# Fix: Option C — the default uninstall only touches router files when the
# skill dir exists (the installer knows it put them there). A new
# `--orphans` flag opts into the force-cleanup path for the CPT-112 recovery
# scenario. Existing tests updated to use the opt-in flag; new tests guard
# the safe-default behaviour.

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

# --- CPT-112 recovery path — now opt-in via --orphans ---

@test "--uninstall --orphans removes orphan router.md when skill dir is already gone (CPT-112)" {
  # Simulate pre-CPT-36 stale state: router file exists, skill dir doesn't.
  local name="rr"
  local skill_dir="${HOME}/.claude/skills/${name}"
  local router_md="${HOME}/.claude/commands/${name}.md"

  mkdir -p "${HOME}/.claude/commands"
  touch "$router_md"

  [ ! -d "$skill_dir" ]
  [ -f "$router_md" ]

  run bash "$INSTALLER" --uninstall --orphans --force "$name"

  [ ! -f "$router_md" ] || {
    echo "orphan router ${router_md} still present after --uninstall --orphans" >&2
    echo "uninstall output: $output" >&2
    return 1
  }
}

@test "--uninstall --orphans removes orphan commands/<name>/ when skill dir is already gone (CPT-112)" {
  local name="chk2"
  local skill_dir="${HOME}/.claude/skills/${name}"
  local commands_dir="${HOME}/.claude/commands/${name}"

  mkdir -p "$commands_dir"
  touch "$commands_dir/foo.md"

  [ ! -d "$skill_dir" ]
  [ -d "$commands_dir" ]

  run bash "$INSTALLER" --uninstall --orphans --force "$name"

  [ ! -d "$commands_dir" ] || {
    echo "orphan commands dir ${commands_dir} still present after --uninstall --orphans" >&2
    echo "uninstall output: $output" >&2
    return 1
  }
}

@test "--uninstall with nothing installed still no-ops cleanly (CPT-112)" {
  local name="rr"
  run bash "$INSTALLER" --uninstall --force "$name"

  [ "$status" -eq 0 ] || {
    echo "--uninstall crashed on empty state: $output" >&2
    return 1
  }
}

# --- CPT-138: safe-default — user-authored router files are NEVER deleted
#     unless the user explicitly opts into --orphans. ---

@test "--uninstall (no --orphans) does NOT delete a user-authored router.md when skill dir absent (CPT-138)" {
  # User wrote their own ~/.claude/commands/rr.md — no rr skill installed.
  # Running `./install.sh --uninstall rr` must leave their file alone.
  local name="rr"
  local skill_dir="${HOME}/.claude/skills/${name}"
  local router_md="${HOME}/.claude/commands/${name}.md"

  mkdir -p "${HOME}/.claude/commands"
  printf 'user-authored rr command\n' > "$router_md"

  [ ! -d "$skill_dir" ]
  [ -f "$router_md" ]

  run bash "$INSTALLER" --uninstall --force "$name"

  # File must still exist AND must still have the user's content
  [ -f "$router_md" ] || {
    echo "DATA LOSS: user-authored $router_md deleted by --uninstall without --orphans" >&2
    echo "uninstall output: $output" >&2
    return 1
  }
  content=$(cat "$router_md")
  [[ "$content" == "user-authored rr command" ]] || {
    echo "User content corrupted: $content" >&2
    return 1
  }
}

@test "--uninstall (no --orphans) does NOT delete a user-authored commands/<name>/ dir when skill dir absent (CPT-138)" {
  local name="chk2"
  local skill_dir="${HOME}/.claude/skills/${name}"
  local commands_dir="${HOME}/.claude/commands/${name}"

  mkdir -p "$commands_dir"
  printf 'user-authored subcommand\n' > "$commands_dir/custom.md"

  [ ! -d "$skill_dir" ]
  [ -d "$commands_dir" ]

  run bash "$INSTALLER" --uninstall --force "$name"

  [ -d "$commands_dir" ] || {
    echo "DATA LOSS: user-authored $commands_dir deleted by --uninstall without --orphans" >&2
    return 1
  }
  [ -f "$commands_dir/custom.md" ]
}

@test "--uninstall (no --orphans) with skill dir present still cleans router files (CPT-138)" {
  # Normal case: skill is installed, we installed the router — must still clean.
  local name="rr"
  local skill_dir="${HOME}/.claude/skills/${name}"
  local router_md="${HOME}/.claude/commands/${name}.md"

  mkdir -p "$skill_dir"
  touch "$skill_dir/SKILL.md"
  mkdir -p "${HOME}/.claude/commands"
  touch "$router_md"

  run bash "$INSTALLER" --uninstall --force "$name"

  [ ! -d "$skill_dir" ]
  [ ! -f "$router_md" ] || {
    echo "router file still present after --uninstall with skill dir: $router_md" >&2
    echo "uninstall output: $output" >&2
    return 1
  }
}
