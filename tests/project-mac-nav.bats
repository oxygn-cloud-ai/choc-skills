#!/usr/bin/env bats

# CPT-73 — /project:launch Mac-native navigation (Option 6 + Option 7 stacked).
# Red-TDD before the bin scripts + docs exist.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SKILL_DIR="${REPO_DIR}/skills/project"
FZF_PICKER="${SKILL_DIR}/bin/project-picker-fzf.sh"
TTYD_FLEET="${SKILL_DIR}/bin/project-ttyd-fleet.sh"
KEYMAP="${SKILL_DIR}/docs/iterm2-keymap.json"

# Stub directory for PATH-first tmux/ttyd/fzf overrides
STUB_DIR=""

setup() {
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
  STUB_DIR="$(mktemp -d)"
  export PATH="${STUB_DIR}:${PATH}"
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] || return 0
  rm -rf "$HOME"
  [ -n "$STUB_DIR" ] && rm -rf "$STUB_DIR"
}

# ============================================================
# File presence (Option 6)
# ============================================================

@test "bin/project-picker-fzf.sh exists and is executable" {
  [ -x "$FZF_PICKER" ]
}

@test "docs/iterm2-keymap.json exists and is parseable JSON" {
  [ -f "$KEYMAP" ]
  python3 -c "import json; json.load(open('$KEYMAP'))"
}

@test "iterm2-keymap references the project-picker-fzf.sh path" {
  run grep -E "project-picker-fzf" "$KEYMAP"
  [ "$status" -eq 0 ]
}

# ============================================================
# File presence (Option 7)
# ============================================================

@test "bin/project-ttyd-fleet.sh exists and is executable" {
  [ -x "$TTYD_FLEET" ]
}

# ============================================================
# FZF picker runtime behaviour
# ============================================================

@test "project-picker-fzf.sh --help exits 0 with usage" {
  run bash "$FZF_PICKER" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "project-picker-fzf.sh falls back gracefully when fzf missing" {
  # PATH doesn't have fzf; create a minimal tmux stub so the script reaches the fzf check
  cat > "${STUB_DIR}/tmux" <<'EOF'
#!/bin/bash
case "$1" in
  list-windows) echo "0: a master"; echo "1: b planner" ;;
  has-session) exit 0 ;;
  select-window) exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "${STUB_DIR}/tmux"
  # Ensure fzf is definitely absent
  run env PATH="${STUB_DIR}:/usr/bin:/bin" bash "$FZF_PICKER" --list 2>&1
  # --list should NOT require fzf; it just enumerates
  [ "$status" -eq 0 ] || [ "$status" -eq 2 ]
}

# ============================================================
# ttyd fleet runtime behaviour
# ============================================================

@test "project-ttyd-fleet.sh --help exits 0 with usage" {
  run bash "$TTYD_FLEET" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "project-ttyd-fleet.sh errors cleanly when ttyd is missing" {
  # No ttyd stub — just a minimal tmux
  cat > "${STUB_DIR}/tmux" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "${STUB_DIR}/tmux"
  run env PATH="${STUB_DIR}:/usr/bin:/bin" bash "$TTYD_FLEET" start choc-skills
  [ "$status" -ne 0 ]
  [[ "$output" == *"ttyd"* ]]
}

@test "project-ttyd-fleet.sh start|stop|status are documented in --help" {
  run bash "$TTYD_FLEET" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"start"* ]]
  [[ "$output" == *"stop"* ]]
  [[ "$output" == *"status"* ]]
}

@test "project-ttyd-fleet.sh start with ttyd stub writes PID file per role" {
  # Stub ttyd: fork-into-background, record PID to a file
  cat > "${STUB_DIR}/ttyd" <<'EOF'
#!/bin/bash
# Stub ttyd — sleeps forever to simulate a long-running process
sleep 3600 &
echo $!
wait
EOF
  chmod +x "${STUB_DIR}/ttyd"
  cat > "${STUB_DIR}/tmux" <<'EOF'
#!/bin/bash
case "$1" in
  has-session) exit 0 ;;
  list-windows) echo "0: a master"; echo "1: b planner"; exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "${STUB_DIR}/tmux"

  # Run in background, check state, stop
  export TTYD_FLEET_STATE_DIR="${HOME}/.ttyd-fleet"
  run env PATH="${STUB_DIR}:/usr/bin:/bin" \
    bash "$TTYD_FLEET" start test-project --base-port 17681 --roles master,planner
  [ "$status" -eq 0 ]
  # State dir should have PID files for each role
  [ -f "${TTYD_FLEET_STATE_DIR}/test-project.pids" ]

  # Stop cleanly
  run env PATH="${STUB_DIR}:/usr/bin:/bin" \
    bash "$TTYD_FLEET" stop test-project
  [ "$status" -eq 0 ]
  [ ! -f "${TTYD_FLEET_STATE_DIR}/test-project.pids" ]
}

@test "project-ttyd-fleet.sh status reports 'not running' when no PID file" {
  export TTYD_FLEET_STATE_DIR="${HOME}/.ttyd-fleet"
  run bash "$TTYD_FLEET" status test-project
  # Non-zero exit when nothing is running is fine
  [[ "$output" == *"not running"* ]] || [[ "$output" == *"No fleet"* ]] || [[ "$output" == *"no fleet"* ]]
}

# ============================================================
# install.sh ttyd availability check (warn, not fail)
# ============================================================

@test "install.sh --check mentions ttyd presence or documents it" {
  # We just verify install.sh checks for ttyd — either by name or brew formula
  run grep -E "ttyd" "${SKILL_DIR}/install.sh"
  [ "$status" -eq 0 ]
}

# ============================================================
# launch.md Step 8 report documents both access modes
# ============================================================

@test "launch.md Step 8 report references FZF picker (⌘⇧P or picker-fzf)" {
  run grep -iE "(picker-fzf|⌘⇧P|Cmd\+Shift\+P)" "${SKILL_DIR}/commands/launch.md"
  [ "$status" -eq 0 ]
}

@test "launch.md Step 8 report references ttyd browser access" {
  run grep -iE "(ttyd|browser|localhost:7681)" "${SKILL_DIR}/commands/launch.md"
  [ "$status" -eq 0 ]
}

# ============================================================
# CHANGELOG entry for v2.3.0
# ============================================================

@test "CHANGELOG.md has a v2.3.0 entry" {
  run grep -E "^## \[2\.3\.0\]" "${SKILL_DIR}/CHANGELOG.md"
  [ "$status" -eq 0 ]
}

@test "SKILL.md version is 2.3.0" {
  run grep -E "^version: 2\.3\.0$" "${SKILL_DIR}/SKILL.md"
  [ "$status" -eq 0 ]
}
