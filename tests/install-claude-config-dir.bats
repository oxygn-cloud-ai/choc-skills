#!/usr/bin/env bats

# Tests that all six installers honor CLAUDE_CONFIG_DIR (CPT-174).
#
# Baseline behavior: when CLAUDE_CONFIG_DIR is unset or empty, the installer
# falls back to $HOME/.claude — this matches how Claude Code itself resolves
# the config dir at runtime. When CLAUDE_CONFIG_DIR is set and non-empty, the
# installer writes there instead.
#
# PARALLEL-UNSAFE: reassigns HOME + CLAUDE_CONFIG_DIR per test.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ROOT_INSTALLER="${REPO_DIR}/install.sh"

setup() {
  export HOME="$(mktemp -d)"
  export FAKE_CLAUDE="$(mktemp -d)"
  # Never inherit a real CLAUDE_CONFIG_DIR from the ambient env — each test
  # sets it explicitly to keep assertions meaningful.
  unset CLAUDE_CONFIG_DIR
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] && rm -rf "$HOME" || true
  [[ "$FAKE_CLAUDE" == /tmp/* || "$FAKE_CLAUDE" == /var/folders/* || "$FAKE_CLAUDE" == /private/tmp/* || "$FAKE_CLAUDE" == /private/var/* ]] && rm -rf "$FAKE_CLAUDE" || true
}

# --- Root installer ---

@test "CPT-174: root installer writes to \$HOME/.claude when CLAUDE_CONFIG_DIR unset" {
  local first_skill
  first_skill=$(ls "${REPO_DIR}/skills" | grep -v '^_' | head -1)
  run "$ROOT_INSTALLER" --force "$first_skill"
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.claude/skills/${first_skill}/SKILL.md" ]
  # must NOT have leaked to FAKE_CLAUDE
  [ ! -f "${FAKE_CLAUDE}/skills/${first_skill}/SKILL.md" ]
}

@test "CPT-174: root installer writes to \$CLAUDE_CONFIG_DIR when set" {
  local first_skill
  first_skill=$(ls "${REPO_DIR}/skills" | grep -v '^_' | head -1)
  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE" run "$ROOT_INSTALLER" --force "$first_skill"
  [ "$status" -eq 0 ]
  [ -f "${FAKE_CLAUDE}/skills/${first_skill}/SKILL.md" ]
  # must NOT have leaked to \$HOME/.claude
  [ ! -f "${HOME}/.claude/skills/${first_skill}/SKILL.md" ]
}

@test "CPT-174: root installer treats empty CLAUDE_CONFIG_DIR as unset" {
  local first_skill
  first_skill=$(ls "${REPO_DIR}/skills" | grep -v '^_' | head -1)
  CLAUDE_CONFIG_DIR="" run "$ROOT_INSTALLER" --force "$first_skill"
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.claude/skills/${first_skill}/SKILL.md" ]
}

@test "CPT-174: root installer --check sees CLAUDE_CONFIG_DIR installed skills" {
  # Install to FAKE_CLAUDE then verify --check output mentions the skill under
  # the FAKE_CLAUDE tree, not $HOME/.claude. Exit status may be non-zero because
  # other skills are not installed — that's expected and not what this test is
  # asserting. The assertion is path resolution.
  local first_skill
  first_skill=$(ls "${REPO_DIR}/skills" | grep -v '^_' | head -1)
  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE" "$ROOT_INSTALLER" --force "$first_skill"
  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE" run "$ROOT_INSTALLER" --check
  # The resolved target base must be shown in output messages for skills
  # that are NOT installed (their paths resolve to FAKE_CLAUDE, not HOME).
  [[ "$output" == *"${first_skill}"* ]]
  [[ "$output" != *"'${first_skill}' is not installed"* ]]
  # Negative: must not reference the $HOME/.claude tree (since everything is
  # supposed to resolve against FAKE_CLAUDE).
  [[ "$output" != *"${HOME}/.claude"* ]]
}

@test "CPT-174: root installer --uninstall honors CLAUDE_CONFIG_DIR" {
  local first_skill
  first_skill=$(ls "${REPO_DIR}/skills" | grep -v '^_' | head -1)
  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE" "$ROOT_INSTALLER" --force "$first_skill"
  [ -f "${FAKE_CLAUDE}/skills/${first_skill}/SKILL.md" ]
  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE" run "$ROOT_INSTALLER" --force --uninstall "$first_skill"
  [ "$status" -eq 0 ]
  [ ! -d "${FAKE_CLAUDE}/skills/${first_skill}" ]
}

@test "CPT-174: root installer --help prints resolved CLAUDE_DIR" {
  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE" run "$ROOT_INSTALLER" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Resolves to: ${FAKE_CLAUDE}"* ]]
}

# --- Per-skill installers ---

@test "CPT-174: every Claude-skill install.sh defines CLAUDE_DIR fallback" {
  # Only Claude skills (dirs with a SKILL.md) need to honor CLAUDE_CONFIG_DIR.
  # Standalone tools like iterm2-tmux install to ~/.local/bin and are out of scope.
  local f dir
  for f in "${REPO_DIR}"/install.sh "${REPO_DIR}"/skills/*/install.sh; do
    [ -f "$f" ] || continue
    dir="$(dirname "$f")"
    # Root installer is always in scope; per-skill installers only if the
    # sibling SKILL.md exists.
    [ "$f" = "${REPO_DIR}/install.sh" ] || [ -f "${dir}/SKILL.md" ] || continue
    grep -qE 'CLAUDE_DIR="\$\{CLAUDE_CONFIG_DIR:-\$\{?HOME\}?/\.claude\}"' "$f" || {
      echo "FAIL: $f missing CLAUDE_DIR fallback definition" >&2
      return 1
    }
  done
}

@test "CPT-174: every Claude-skill install.sh --help resolves CLAUDE_DIR under CLAUDE_CONFIG_DIR" {
  local installer skill dir
  for installer in "${REPO_DIR}"/skills/*/install.sh; do
    [ -f "$installer" ] || continue
    dir="$(dirname "$installer")"
    [ -f "${dir}/SKILL.md" ] || continue  # skip standalone tools
    skill=$(basename "$dir")
    CLAUDE_CONFIG_DIR="$FAKE_CLAUDE" run bash "$installer" --help
    [ "$status" -eq 0 ] || {
      echo "FAIL: $installer --help exited $status" >&2
      echo "$output" >&2
      return 1
    }
    if grep -qE '^\s*~/.claude/' <<< "$output"; then
      echo "FAIL: $installer --help leaked literal ~/.claude in INSTALLS TO" >&2
      echo "$output" >&2
      return 1
    fi
    [[ "$output" == *"$FAKE_CLAUDE"* ]] || {
      echo "FAIL: $installer --help did not render ${FAKE_CLAUDE}" >&2
      echo "$output" >&2
      return 1
    }
  done
}

@test "CPT-174: project installer writes to CLAUDE_CONFIG_DIR" {
  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE" run bash "${REPO_DIR}/skills/project/install.sh" --force
  [ "$status" -eq 0 ]
  [ -f "${FAKE_CLAUDE}/skills/project/SKILL.md" ]
  [ -f "${FAKE_CLAUDE}/commands/project.md" ]
  [ -d "${FAKE_CLAUDE}/commands/project" ]
  # Must NOT have leaked to \$HOME/.claude
  [ ! -f "${HOME}/.claude/skills/project/SKILL.md" ]
}

@test "CPT-174: project installer --uninstall removes from CLAUDE_CONFIG_DIR" {
  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE" bash "${REPO_DIR}/skills/project/install.sh" --force
  [ -d "${FAKE_CLAUDE}/skills/project" ]
  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE" run bash "${REPO_DIR}/skills/project/install.sh" --uninstall
  [ "$status" -eq 0 ]
  [ ! -d "${FAKE_CLAUDE}/skills/project" ]
  [ ! -f "${FAKE_CLAUDE}/commands/project.md" ]
  [ ! -d "${FAKE_CLAUDE}/commands/project" ]
}

# --- CPT-175: remove_hook_registration must preserve unrelated sibling hooks
#     that share a matcher object. The pre-fix filter `all(.command != $c)`
#     dropped the entire matcher whenever any of its hooks matched,
#     collateral-deleting siblings installed by other tools. ---

@test "CPT-175: project --uninstall preserves unrelated sibling PreToolUse hooks" {
  # Manually prepare a settings.json where /project's block-worktree-add.sh
  # shares a matcher with an unrelated sibling hook, then run the skill's
  # uninstall and assert the sibling survives.
  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE" bash "${REPO_DIR}/skills/project/install.sh" --force >/dev/null 2>&1

  # Verify install registered our block-worktree-add.sh against the Bash matcher.
  [ -f "${FAKE_CLAUDE}/settings.json" ]
  local our_cmd="${FAKE_CLAUDE}/hooks/block-worktree-add.sh"
  local our_count
  our_count=$(jq --arg c "$our_cmd" \
    '[.hooks.PreToolUse[]? | .hooks[]? | select(.command == $c)] | length' \
    "${FAKE_CLAUDE}/settings.json")
  [ "$our_count" -eq 1 ]

  # Inject an unrelated sibling hook into the same matcher object manually.
  local sibling="/home/fake/.local/bin/unrelated-tool.sh"
  local tmp; tmp=$(mktemp)
  jq --arg s "$sibling" \
    '.hooks.PreToolUse |= [.[] | if .matcher == "Bash" then .hooks += [{"type":"command","command":$s}] else . end]' \
    "${FAKE_CLAUDE}/settings.json" > "$tmp"
  mv "$tmp" "${FAKE_CLAUDE}/settings.json"

  # Confirm sibling got added.
  local sibling_count
  sibling_count=$(jq --arg c "$sibling" \
    '[.hooks.PreToolUse[]? | .hooks[]? | select(.command == $c)] | length' \
    "${FAKE_CLAUDE}/settings.json")
  [ "$sibling_count" -eq 1 ]

  # Now uninstall /project. Sibling should survive; our command should go.
  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE" run bash "${REPO_DIR}/skills/project/install.sh" --uninstall
  [ "$status" -eq 0 ]

  local post_sibling_count post_our_count
  post_sibling_count=$(jq --arg c "$sibling" \
    '[.hooks.PreToolUse[]? | .hooks[]? | select(.command == $c)] | length' \
    "${FAKE_CLAUDE}/settings.json")
  post_our_count=$(jq --arg c "$our_cmd" \
    '[.hooks.PreToolUse[]? | .hooks[]? | select(.command == $c)] | length' \
    "${FAKE_CLAUDE}/settings.json")

  if [ "$post_sibling_count" -ne 1 ]; then
    echo "FAIL: unrelated sibling hook ${sibling} was collateral-deleted on uninstall" >&2
    jq . "${FAKE_CLAUDE}/settings.json" >&2
    return 1
  fi
  if [ "$post_our_count" -ne 0 ]; then
    echo "FAIL: our hook ${our_cmd} not properly de-registered on uninstall" >&2
    jq . "${FAKE_CLAUDE}/settings.json" >&2
    return 1
  fi
}

# --- Regression: no installer should contain unwrapped ~/.claude paths
#     outside of the CLAUDE_DIR-definition line, comments, and self-documenting
#     ${CLAUDE_CONFIG_DIR:-~/.claude} mentions. ---

@test "CPT-174: no installer has raw \$HOME/.claude outside CLAUDE_DIR definition" {
  local f bad
  for f in "${REPO_DIR}"/install.sh "${REPO_DIR}"/skills/*/install.sh; do
    [ -f "$f" ] || continue
    # Count matches of ${HOME}/.claude that AREN'T inside the
    # CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}" fallback line.
    bad=$(grep -cE '\$\{HOME\}/\.claude' "$f" | head -1)
    # One legitimate occurrence: the CLAUDE_DIR fallback itself.
    if [ "$bad" -gt 1 ]; then
      echo "FAIL: $f has $bad \$HOME/.claude refs (expected 1 — the CLAUDE_DIR fallback)" >&2
      grep -nE '\$\{HOME\}/\.claude' "$f" >&2
      return 1
    fi
  done
}
