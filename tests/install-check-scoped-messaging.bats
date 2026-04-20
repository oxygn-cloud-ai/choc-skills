#!/usr/bin/env bats

# CPT-78: Root install.sh --check reports the unqualified word "healthy" even
# though it only verifies SKILL.md — it does NOT check per-skill routers,
# sub-commands, bin scripts, hooks, or references. Users see "All N skill(s)
# healthy" rc=0 after ./install.sh --force but the skills are not functionally
# installed (no /chk1:quick, no /project:audit, etc.).
#
# Fix (Option A from ticket): scope the wording to "SKILL.md" so the message
# is honest about what's actually verified.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALLER="$REPO_DIR/install.sh"

setup() {
  unset CLAUDE_CONFIG_DIR  # CPT-174: ensure tests never inherit ambient CLAUDE_CONFIG_DIR
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] || return 0
  rm -rf "$HOME"
}

@test "install.sh --check per-skill line does not use unqualified 'healthy'" {
  bash "$INSTALLER" --force >/dev/null 2>&1
  run bash "$INSTALLER" --check
  [ "$status" -eq 0 ]
  # Must NOT contain the unqualified "is healthy" wording for individual skills
  if [[ "$output" == *"is healthy"* ]]; then
    echo "Per-skill line still says 'is healthy' — misleading about scope" >&2
    echo "$output" >&2
    return 1
  fi
}

@test "install.sh --check per-skill line mentions SKILL.md (honest scope)" {
  bash "$INSTALLER" --force >/dev/null 2>&1
  run bash "$INSTALLER" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKILL.md"* ]] || {
    echo "Per-skill verdict does not mention SKILL.md — scope unclear" >&2
    return 1
  }
}

@test "install.sh --check summary line does not use unqualified 'healthy'" {
  bash "$INSTALLER" --force >/dev/null 2>&1
  run bash "$INSTALLER" --check
  [ "$status" -eq 0 ]
  # Must NOT say "All N skill(s) healthy" — it's only SKILL.md verified
  if [[ "$output" =~ "skill(s) healthy" ]]; then
    echo "Summary still says 'skill(s) healthy' — misleading" >&2
    return 1
  fi
}
