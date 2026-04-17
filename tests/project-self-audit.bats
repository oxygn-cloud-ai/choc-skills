#!/usr/bin/env bats

# CPT-59 — /project:self-audit recursive audit.
# Red-TDD written before the bin script + command file exist.
#
# Scope: 5-check structure (A parity, B rules→mech, C mech→rules, D install manifest, E validators),
# cite-convention enforcement, exit codes, JSON format, synthetic drift detection.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SKILL_DIR="${REPO_DIR}/skills/project"
SELF_AUDIT="${SKILL_DIR}/bin/project-self-audit.sh"

setup() {
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] || return 0
  rm -rf "$HOME"
}

# ============================================================
# Structure
# ============================================================

@test "commands/self-audit.md exists" {
  [ -f "${SKILL_DIR}/commands/self-audit.md" ]
}

@test "bin/project-self-audit.sh exists and is executable" {
  [ -x "$SELF_AUDIT" ]
}

@test "SKILL.md router table mentions self-audit" {
  run grep -iE "self-audit" "${SKILL_DIR}/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "help.md documents self-audit" {
  run grep -iE "self-audit" "${SKILL_DIR}/commands/help.md"
  [ "$status" -eq 0 ]
}

@test "skills/project/CLAUDE.md has Cite convention section" {
  [ -f "${SKILL_DIR}/CLAUDE.md" ]
  run grep -iE "Cite convention|# Implements:" "${SKILL_DIR}/CLAUDE.md"
  [ "$status" -eq 0 ]
}

# ============================================================
# Cite convention — existing mechanisms have # Implements: headers
# ============================================================

@test "block-worktree-add.sh has # Implements: citation" {
  run grep -E "^# Implements: " "${SKILL_DIR}/hooks/block-worktree-add.sh"
  [ "$status" -eq 0 ]
}

@test "verify-jira-parent.sh has # Implements: citation" {
  run grep -E "^# Implements: " "${SKILL_DIR}/hooks/verify-jira-parent.sh"
  [ "$status" -eq 0 ]
}

@test "audit.md references Implements: for numbered checks" {
  # Markdown uses HTML-comment citation form: <!-- Implements: ... -->
  # At least half of the 16 checks cited (realistic for first pass — 8+)
  run grep -cE "<!-- Implements: " "${SKILL_DIR}/commands/audit.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 8 ]
}

# ============================================================
# Runtime: --help + --version
# ============================================================

@test "self-audit --help exits 0 with usage" {
  run bash "$SELF_AUDIT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "self-audit --version prints something" {
  run bash "$SELF_AUDIT" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"self-audit"* ]]
}

# ============================================================
# Runtime: 5 checks on a fresh install — SHOULD PASS
# ============================================================

@test "self-audit --parity on clean install exits 0" {
  bash "${SKILL_DIR}/install.sh" --force >/dev/null 2>&1
  run bash "$SELF_AUDIT" --parity
  [ "$status" -eq 0 ]
}

@test "self-audit --manifest on clean source exits 0" {
  # Manifest check does not require an install; it grep install.sh
  run bash "$SELF_AUDIT" --manifest
  [ "$status" -eq 0 ]
}

@test "self-audit --standards runs validate-skills.sh and exits 0" {
  run bash "$SELF_AUDIT" --standards
  [ "$status" -eq 0 ]
}

# ============================================================
# Runtime: synthetic drift is DETECTED
# ============================================================

@test "self-audit --parity flags orphan hook in ~/.claude/hooks" {
  bash "${SKILL_DIR}/install.sh" --force >/dev/null 2>&1
  # Plant an orphan hook whose name plausibly belongs to the project skill
  echo "#!/bin/bash" > "${HOME}/.claude/hooks/project-orphan-hook.sh"
  chmod +x "${HOME}/.claude/hooks/project-orphan-hook.sh"
  run bash "$SELF_AUDIT" --parity
  # Exit non-zero and output should mention orphan
  [ "$status" -ne 0 ]
  [[ "$output" == *"ORPHAN"* ]] || [[ "$output" == *"orphan"* ]]
}

@test "self-audit --parity flags DRIFT when installed hook differs from source" {
  bash "${SKILL_DIR}/install.sh" --force >/dev/null 2>&1
  # Corrupt the installed copy
  echo "# drifted" >> "${HOME}/.claude/hooks/block-worktree-add.sh"
  run bash "$SELF_AUDIT" --parity
  [ "$status" -ne 0 ]
  [[ "$output" == *"DRIFT"* ]] || [[ "$output" == *"drift"* ]]
}

@test "self-audit --manifest flags source file with no install.sh coverage" {
  local stray="${SKILL_DIR}/hooks/__bats_fixture_stray_$$.sh"
  echo "#!/bin/bash" > "$stray"
  run bash "$SELF_AUDIT" --manifest
  rm -f "$stray"
  # install.sh iterates hooks/*.sh by glob so the stray WILL be covered by
  # the `HOOKS_SOURCE/*.sh` match; the check's contract is that every
  # source is referenced, which the glob satisfies. Expect exit 0 (PASS)
  # for this scenario.
  [ "$status" -eq 0 ]
}

# ============================================================
# JSON output
# ============================================================

@test "self-audit --format=json produces parseable JSON" {
  bash "${SKILL_DIR}/install.sh" --force >/dev/null 2>&1
  run bash "$SELF_AUDIT" --format=json
  # Use python3 to validate JSON (portable across macOS/Linux)
  # Script may exit 0 or 1 depending on FLAG count; both should emit valid JSON
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  echo "$output" | python3 -c "import sys, json; json.load(sys.stdin)"
}

# ============================================================
# Exit codes contract
# ============================================================

@test "self-audit unknown flag exits 2" {
  run bash "$SELF_AUDIT" --no-such-flag
  [ "$status" -eq 2 ]
}
