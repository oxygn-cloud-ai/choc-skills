#!/usr/bin/env bats

# CPT-87 Phase 0 — OPSvdd skill scaffolding tests.
# Red-TDD: written before the skill exists. Intended to fail until
# skills/OPSvdd/ is populated.
#
# Scope: structure only. Domain logic (assess, approval, tier, override)
# lives in follow-up phases CPT-87.1 / 87.2 / 87.3 and is not covered here.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SKILL_DIR="${REPO_DIR}/skills/OPSvdd"

setup() {
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] || return 0
  rm -rf "$HOME"
}

# ============================================================
# Structure (AC-1)
# ============================================================

@test "skills/OPSvdd/ directory exists" {
  [ -d "$SKILL_DIR" ]
}

@test "skills/OPSvdd/SKILL.md exists" {
  [ -f "${SKILL_DIR}/SKILL.md" ]
}

@test "skills/OPSvdd/CHANGELOG.md exists" {
  [ -f "${SKILL_DIR}/CHANGELOG.md" ]
}

@test "skills/OPSvdd/README.md exists" {
  [ -f "${SKILL_DIR}/README.md" ]
}

@test "skills/OPSvdd/install.sh exists and is executable" {
  [ -x "${SKILL_DIR}/install.sh" ]
}

@test "skills/OPSvdd/commands/ has help/doctor/version/update files" {
  [ -f "${SKILL_DIR}/commands/help.md" ]
  [ -f "${SKILL_DIR}/commands/doctor.md" ]
  [ -f "${SKILL_DIR}/commands/version.md" ]
  [ -f "${SKILL_DIR}/commands/update.md" ]
}

@test "skills/OPSvdd/references/ has the v1.0.0 tree (jurisdictions, regulatory, tiering, schemas, workflow)" {
  [ -d "${SKILL_DIR}/references/jurisdictions" ]
  [ -d "${SKILL_DIR}/references/regulatory" ]
  [ -d "${SKILL_DIR}/references/regulatory/sg" ]
  [ -d "${SKILL_DIR}/references/tiering" ]
  [ -d "${SKILL_DIR}/references/schemas" ]
  [ -d "${SKILL_DIR}/references/workflow" ]
}

# ============================================================
# SKILL.md frontmatter (v1.0.0 contract)
# ============================================================

@test "SKILL.md name field equals OPSvdd" {
  run grep -E '^name: OPSvdd$' "${SKILL_DIR}/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "SKILL.md version is 1.0.0" {
  run grep -E '^version: 1\.0\.0$' "${SKILL_DIR}/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "SKILL.md has user-invocable: true" {
  run grep -E '^user-invocable: true$' "${SKILL_DIR}/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "SKILL.md has disable-model-invocation: true" {
  run grep -E '^disable-model-invocation: true$' "${SKILL_DIR}/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "SKILL.md declares allowed-tools" {
  run grep -E '^allowed-tools:' "${SKILL_DIR}/SKILL.md"
  [ "$status" -eq 0 ]
}

# ============================================================
# Router / routing table coverage
# ============================================================

@test "SKILL.md routing table mentions every Phase 0 subcommand" {
  for cmd in help doctor version update; do
    run grep -iE "(^|[^a-z])${cmd}([^a-z]|$)" "${SKILL_DIR}/SKILL.md"
    [ "$status" -eq 0 ] || { echo "missing routing entry for $cmd"; return 1; }
  done
}

# ============================================================
# install.sh flags (AC-2)
# ============================================================

@test "install.sh --help exits 0 and shows usage" {
  run bash "${SKILL_DIR}/install.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "install.sh --version prints OPSvdd v1.0.0" {
  run bash "${SKILL_DIR}/install.sh" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"OPSvdd v1.0.0"* ]]
}

@test "install.sh --force installs SKILL.md + router + commands + references" {
  run bash "${SKILL_DIR}/install.sh" --force
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.claude/skills/OPSvdd/SKILL.md" ]
  [ -f "${HOME}/.claude/commands/OPSvdd.md" ]
  [ -d "${HOME}/.claude/commands/OPSvdd" ]
  [ -d "${HOME}/.claude/skills/OPSvdd/references" ]
  local count
  count=$(ls "${HOME}/.claude/commands/OPSvdd/"*.md 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -ge 4 ]
}

@test "install.sh --force copies SKILL.md with matching SHA256" {
  bash "${SKILL_DIR}/install.sh" --force >/dev/null
  src_sha=$(shasum -a 256 "${SKILL_DIR}/SKILL.md" | cut -d' ' -f1)
  dst_sha=$(shasum -a 256 "${HOME}/.claude/skills/OPSvdd/SKILL.md" | cut -d' ' -f1)
  [ "$src_sha" = "$dst_sha" ]
}

@test "install.sh writes .source-repo marker for /OPSvdd update" {
  bash "${SKILL_DIR}/install.sh" --force >/dev/null
  [ -f "${HOME}/.claude/skills/OPSvdd/.source-repo" ]
  repo=$(cat "${HOME}/.claude/skills/OPSvdd/.source-repo")
  [ -d "$repo" ]
}

@test "install.sh --check passes after install" {
  bash "${SKILL_DIR}/install.sh" --force >/dev/null
  run bash "${SKILL_DIR}/install.sh" --check
  [ "$status" -eq 0 ]
}

# ============================================================
# Uninstall round-trip (AC-4)
# ============================================================

@test "install.sh --uninstall removes every install-time artefact" {
  bash "${SKILL_DIR}/install.sh" --force >/dev/null
  [ -d "${HOME}/.claude/skills/OPSvdd" ]
  [ -d "${HOME}/.claude/commands/OPSvdd" ]
  [ -f "${HOME}/.claude/commands/OPSvdd.md" ]

  run bash "${SKILL_DIR}/install.sh" --uninstall
  [ "$status" -eq 0 ]
  [ ! -d "${HOME}/.claude/skills/OPSvdd" ]
  [ ! -d "${HOME}/.claude/commands/OPSvdd" ]
  [ ! -f "${HOME}/.claude/commands/OPSvdd.md" ]
}

# ============================================================
# Root installer discovery (AC-3)
# ============================================================

@test "root install.sh --list includes OPSvdd" {
  run bash "${REPO_DIR}/install.sh" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"OPSvdd"* ]]
}

@test "root install.sh --force OPSvdd installs the skill" {
  run bash "${REPO_DIR}/install.sh" --force OPSvdd
  [ "$status" -eq 0 ]
  [ -f "${HOME}/.claude/skills/OPSvdd/SKILL.md" ]
}

# ============================================================
# Validator compliance (AC-1, AC-12)
# ============================================================

@test "validate-skills.sh exits 0 with OPSvdd present" {
  run bash "${REPO_DIR}/scripts/validate-skills.sh"
  [ "$status" -eq 0 ]
}

# ============================================================
# AC-16 — code hygiene (no Desktop-Commander identifiers or /mnt/user-data paths)
# ============================================================

@test "skills/OPSvdd/ contains no forbidden strings" {
  # /mnt/user-data, web_fetch (lower-case), desktop-commander
  run grep -RIE --exclude-dir=.git '(/mnt/user-data|desktop-commander|(^|[^A-Za-z_])web_fetch($|[^A-Za-z_]))' "${SKILL_DIR}"
  [ "$status" -ne 0 ]
}
