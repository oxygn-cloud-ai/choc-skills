#!/usr/bin/env bats

# CPT-60: CI install-manifest test.
#
# Runs `skills/project/install.sh --force` in a throwaway $HOME and asserts
# that the installed tree matches the skill source. Closes the 2026-04-16
# cave-inversion failure mode at PR time — if a source file is added
# without a corresponding install step, or an install step points to a
# missing source, this test fails loud.
#
# Complementary to:
#   - CPT-58 `install.sh --check` byte-parity mode (runtime check on operator machines)
#   - CPT-59 /project:self-audit (runtime recursive audit)
# This test is the CI gate.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SKILL_SOURCE_DIR="${REPO_ROOT}/skills/project"
INSTALLER="${SKILL_SOURCE_DIR}/install.sh"

# Portable sha256. GNU coreutils ships `sha256sum`; macOS ships `shasum -a 256`.
# install.sh itself uses `shasum -a 256` per CLAUDE.md — match it here for
# byte-compare parity across Linux + macOS runners.
sha256_of() {
  shasum -a 256 "$1" | awk '{print $1}'
}

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  # install.sh only fails if jq is missing (hard dep post-v2.1.0). Other tools
  # (tmux, gh) only trigger WARN lines. Fail fast if jq is absent so the test
  # error is actionable.
  command -v jq >/dev/null 2>&1 || {
    skip "jq is required for install-manifest test (v2.1.0+ hard dep)"
  }
  command -v shasum >/dev/null 2>&1 || {
    skip "shasum is required for byte-parity check"
  }
}

teardown() {
  # Be paranoid: only rm if the dir looks like a tmp dir we owned.
  if [[ -n "${TEST_HOME:-}" && "$TEST_HOME" == /*/tmp.*  ]] \
     || [[ -n "${TEST_HOME:-}" && "$TEST_HOME" == /var/folders/* ]] \
     || [[ -n "${TEST_HOME:-}" && "$TEST_HOME" == /tmp/* ]]; then
    rm -rf "$TEST_HOME"
  fi
}

# -----------------------------------------------------------------------------
# One test per install category keeps failures specific — operators reading CI
# output see exactly which shim is missing without wading through one mega-test.
# -----------------------------------------------------------------------------

@test "install-manifest: install.sh --force exits 0 in a fresh HOME" {
  run "$INSTALLER" --force
  [ "$status" -eq 0 ] || { echo "info: installer exit $status; output:"; echo "$output"; return 1; }
}

@test "install-manifest: SKILL.md copied byte-identical to \$HOME/.claude/skills/project/SKILL.md" {
  "$INSTALLER" --force >/dev/null 2>&1
  local tgt="${TEST_HOME}/.claude/skills/project/SKILL.md"
  [ -f "$tgt" ] || { echo "info: MISSING $tgt"; return 1; }
  [ "$(sha256_of "${SKILL_SOURCE_DIR}/SKILL.md")" = "$(sha256_of "$tgt")" ] \
    || { echo "info: DRIFT on SKILL.md"; return 1; }
}

@test "install-manifest: every hook in skills/project/hooks/ has a byte-identical target in ~/.claude/hooks/" {
  "$INSTALLER" --force >/dev/null 2>&1
  local missing=0 drift=0
  for src in "${SKILL_SOURCE_DIR}/hooks/"*.sh; do
    [ -f "$src" ] || continue
    local name tgt
    name="$(basename "$src")"
    tgt="${TEST_HOME}/.claude/hooks/${name}"
    if [ ! -f "$tgt" ]; then
      echo "info: MISSING $tgt (source added without install step?)"
      missing=$((missing + 1))
      continue
    fi
    if [ "$(sha256_of "$src")" != "$(sha256_of "$tgt")" ]; then
      echo "info: DRIFT on $name (source vs install target differ)"
      drift=$((drift + 1))
    fi
    [ -x "$tgt" ] || { echo "info: NOT EXECUTABLE $tgt"; return 1; }
  done
  [ "$missing" -eq 0 ] || return 1
  [ "$drift" -eq 0 ] || return 1
}

@test "install-manifest: every hook file in ~/.claude/hooks/ has a source in skills/project/hooks/ (orphan detection)" {
  "$INSTALLER" --force >/dev/null 2>&1
  local orphans=0
  if [ -d "${TEST_HOME}/.claude/hooks" ]; then
    for tgt in "${TEST_HOME}/.claude/hooks/"*.sh; do
      [ -f "$tgt" ] || continue
      local name src
      name="$(basename "$tgt")"
      src="${SKILL_SOURCE_DIR}/hooks/${name}"
      if [ ! -f "$src" ]; then
        echo "info: ORPHAN $tgt (installed but no source — probably a forgotten-deletion or a hook from a previous/other skill)"
        orphans=$((orphans + 1))
      fi
    done
  fi
  [ "$orphans" -eq 0 ] || return 1
}

@test "install-manifest: every bin/ script copied byte-identical + executable to ~/.local/bin/" {
  "$INSTALLER" --force >/dev/null 2>&1
  local missing=0 drift=0
  for src in "${SKILL_SOURCE_DIR}/bin/"*.sh; do
    [ -f "$src" ] || continue
    local name tgt
    name="$(basename "$src")"
    tgt="${TEST_HOME}/.local/bin/${name}"
    if [ ! -f "$tgt" ]; then
      echo "info: MISSING $tgt"
      missing=$((missing + 1))
      continue
    fi
    if [ "$(sha256_of "$src")" != "$(sha256_of "$tgt")" ]; then
      echo "info: DRIFT on $name"
      drift=$((drift + 1))
    fi
    [ -x "$tgt" ] || { echo "info: NOT EXECUTABLE $tgt"; return 1; }
  done
  [ "$missing" -eq 0 ] || return 1
  [ "$drift" -eq 0 ] || return 1
}

@test "install-manifest: every commands/*.md copied byte-identical to ~/.claude/commands/project/" {
  "$INSTALLER" --force >/dev/null 2>&1
  local missing=0 drift=0
  for src in "${SKILL_SOURCE_DIR}/commands/"*.md; do
    [ -f "$src" ] || continue
    local name tgt
    name="$(basename "$src")"
    tgt="${TEST_HOME}/.claude/commands/project/${name}"
    if [ ! -f "$tgt" ]; then
      echo "info: MISSING $tgt"
      missing=$((missing + 1))
      continue
    fi
    if [ "$(sha256_of "$src")" != "$(sha256_of "$tgt")" ]; then
      echo "info: DRIFT on $name"
      drift=$((drift + 1))
    fi
  done
  [ "$missing" -eq 0 ] || return 1
  [ "$drift" -eq 0 ] || return 1
}

@test "install-manifest: PROJECT_CONFIG.schema.json copied into the installed skill dir" {
  "$INSTALLER" --force >/dev/null 2>&1
  local src="${REPO_ROOT}/PROJECT_CONFIG.schema.json"
  local tgt="${TEST_HOME}/.claude/skills/project/PROJECT_CONFIG.schema.json"
  [ -f "$src" ] || skip "schema source not at repo root — nothing to install"
  [ -f "$tgt" ] || { echo "info: MISSING $tgt"; return 1; }
  [ "$(sha256_of "$src")" = "$(sha256_of "$tgt")" ] \
    || { echo "info: DRIFT on PROJECT_CONFIG.schema.json"; return 1; }
}

@test "install-manifest: router ~/.claude/commands/project.md exists after install" {
  "$INSTALLER" --force >/dev/null 2>&1
  [ -f "${TEST_HOME}/.claude/commands/project.md" ] \
    || { echo "info: MISSING router at ${TEST_HOME}/.claude/commands/project.md"; return 1; }
}

@test "install-manifest: settings.json PreToolUse contains one entry per installed hook" {
  "$INSTALLER" --force >/dev/null 2>&1
  local settings="${TEST_HOME}/.claude/settings.json"
  [ -f "$settings" ] || { echo "info: settings.json missing after install"; return 1; }
  for src in "${SKILL_SOURCE_DIR}/hooks/"*.sh; do
    [ -f "$src" ] || continue
    local name
    name="$(basename "$src")"
    # Every installed hook path must appear at least once in hooks.PreToolUse[].hooks[].command.
    # Run jq against the whole tree and grep for the hook filename.
    jq -r '(.hooks.PreToolUse // [])[] .hooks[]? .command // empty' "$settings" \
      | grep -qF "$name" \
      || { echo "info: hook $name not registered in $settings"; jq . "$settings"; return 1; }
  done
}

@test "install-manifest: source-repo marker file written with correct path" {
  "$INSTALLER" --force >/dev/null 2>&1
  local marker="${TEST_HOME}/.claude/skills/project/.source-repo"
  [ -f "$marker" ] || { echo "info: MISSING $marker"; return 1; }
  local recorded
  recorded="$(cat "$marker")"
  [ "$recorded" = "$SKILL_SOURCE_DIR" ] \
    || { echo "info: source-repo marker has '$recorded', expected '$SKILL_SOURCE_DIR'"; return 1; }
}

@test "install-manifest: deliberate-break sanity — hook file in TEST_HOME with no source is detected as orphan" {
  # Simulate the drift we want the orphan detection to catch.
  "$INSTALLER" --force >/dev/null 2>&1
  local fake="${TEST_HOME}/.claude/hooks/orphan-from-elsewhere.sh"
  echo '#!/usr/bin/env bash' > "$fake"
  chmod +x "$fake"

  local orphans=0
  for tgt in "${TEST_HOME}/.claude/hooks/"*.sh; do
    [ -f "$tgt" ] || continue
    local name src
    name="$(basename "$tgt")"
    src="${SKILL_SOURCE_DIR}/hooks/${name}"
    [ -f "$src" ] || orphans=$((orphans + 1))
  done
  [ "$orphans" -eq 1 ] \
    || { echo "info: expected exactly 1 orphan, found $orphans"; return 1; }
}
