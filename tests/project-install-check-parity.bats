#!/usr/bin/env bats

# CPT-58: install.sh --check must detect drift, missing, orphan, and
# partial matcher registration in addition to the pre-existing presence
# checks. The 2026-04-16 cave-inversion failure mode shipped two hooks to
# ~/.claude/ with no backing source and --check reported "All checks
# passed" for roughly two hours. These tests lock in the diagnostics that
# would have caught it.
#
# PARALLEL-UNSAFE: each test reassigns HOME (same pattern as
# per-skill-install.bats / install.bats).

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALL_SH="${REPO_DIR}/skills/project/install.sh"

setup() {
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
  # Global architecture doc presence is independent of CPT-58 — stub so the
  # generic --check preflight checks don't dominate every failure signal.
  touch "${HOME}/.claude/MULTI_SESSION_ARCHITECTURE.md"
  touch "${HOME}/.claude/PROJECT_STANDARDS.md"
  bash "$INSTALL_SH" --force >/dev/null 2>&1
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] || return 0
  rm -rf "$HOME"
}

@test "CPT-58: --check after clean install exits 0 and reports All checks passed" {
  run bash "$INSTALL_SH" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"All checks passed"* ]]
}

@test "CPT-58: --check detects DRIFT when a hook's installed copy diverges from source" {
  echo "# injected drift $(date)" >> "${HOME}/.claude/hooks/block-worktree-add.sh"
  run bash "$INSTALL_SH" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"DRIFT"* ]]
  [[ "$output" == *"block-worktree-add.sh"* ]]
}

@test "CPT-58: --check detects DRIFT when a commands/ file diverges" {
  echo "# tampered" >> "${HOME}/.claude/commands/project/doctor.md"
  run bash "$INSTALL_SH" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"DRIFT"* ]]
  [[ "$output" == *"doctor.md"* ]]
}

@test "CPT-58: --check detects DRIFT when a bin/ script diverges" {
  echo "# tampered" >> "${HOME}/.local/bin/project-picker.sh"
  run bash "$INSTALL_SH" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"DRIFT"* ]]
  [[ "$output" == *"project-picker.sh"* ]]
}

@test "CPT-58: --check detects MISSING when a hook target is deleted but source still exists" {
  rm -f "${HOME}/.claude/hooks/verify-jira-parent.sh"
  run bash "$INSTALL_SH" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISSING"* ]]
  [[ "$output" == *"verify-jira-parent.sh"* ]]
}

@test "CPT-58: --check detects ORPHAN hook registered with one of our matchers but not in our sources" {
  # Emulate the 2026-04-16 failure mode exactly: a hook file in
  # ~/.claude/hooks/, registered in settings.json with a matcher this skill
  # owns (Bash), but no source file under skills/project/hooks/.
  local fake="${HOME}/.claude/hooks/ghost-hook.sh"
  printf '#!/bin/bash\nexit 0\n' > "$fake"
  chmod +x "$fake"
  local tmp
  tmp="$(mktemp)"
  jq --arg c "$fake" \
    '.hooks = (.hooks // {}) | .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{"matcher":"Bash","hooks":[{"type":"command","command":$c}]}])' \
    "${HOME}/.claude/settings.json" > "$tmp" && mv "$tmp" "${HOME}/.claude/settings.json"
  run bash "$INSTALL_SH" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"ORPHAN"* ]]
  [[ "$output" == *"ghost-hook.sh"* ]]
}

@test "CPT-58: --check detects NOT REGISTERED when a hook's matcher entry is absent from settings.json" {
  # verify-jira-parent.sh requires two matchers (createJiraIssue +
  # editJiraIssue). Remove one entry; expect NOT REGISTERED for that matcher
  # specifically. The pre-existing count>0 check would have passed this case.
  local tmp
  tmp="$(mktemp)"
  jq '.hooks.PreToolUse |= map(select(.matcher != "mcp__claude_ai_Atlassian__editJiraIssue"))' \
    "${HOME}/.claude/settings.json" > "$tmp" && mv "$tmp" "${HOME}/.claude/settings.json"
  run bash "$INSTALL_SH" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"NOT REGISTERED"* ]]
  [[ "$output" == *"editJiraIssue"* ]]
}

@test "CPT-58: --check exits 2 when settings.json is malformed JSON" {
  echo "{not valid json" > "${HOME}/.claude/settings.json"
  run bash "$INSTALL_SH" --check
  [ "$status" -eq 2 ]
}

@test "CPT-58: --check is idempotent (pure read, no writes under ~/.claude)" {
  local before after
  before=$(find "${HOME}/.claude" "${HOME}/.local/bin" -type f 2>/dev/null -exec shasum -a 256 {} \; | sort)
  bash "$INSTALL_SH" --check >/dev/null 2>&1 || true
  after=$(find "${HOME}/.claude" "${HOME}/.local/bin" -type f 2>/dev/null -exec shasum -a 256 {} \; | sort)
  [ "$before" = "$after" ]
}

@test "CPT-58: --check output retains existing ok/err/warn/info prefix format and footer" {
  run bash "$INSTALL_SH" --check
  [ "$status" -eq 0 ]
  # Existing format: "  ok  <msg>" lines for passing checks, and either
  # "All checks passed" or "N issue(s) found" footer.
  [[ "$output" == *"  ok"* ]]
  [[ "$output" == *"All checks passed"* || "$output" == *"issue(s) found"* ]]
}
