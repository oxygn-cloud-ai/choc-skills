#!/usr/bin/env bats

# CPT-82: three-tier context-strategy preamble, delivered via template-and-inject
# (centralised canonical file referenced at /loop dispatch time, not per-branch
# loop.md edits). The template is the single source of truth — every /loop tick
# on every role instructs the model to read it first.
#
# Tests verify:
#   1. Template file exists at skills/project/templates/loop-preamble.md
#   2. Template contains all required markers per CPT-82 spec
#   3. install.sh copies template to ~/.claude/skills/project/templates/
#   4. project-launch-session.sh /loop dispatch references the installed path
#   5. launch.md documents the mechanism

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SKILL_SRC="${REPO_DIR}/skills/project"
TEMPLATE_SRC="${SKILL_SRC}/templates/loop-preamble.md"
INSTALLER="${SKILL_SRC}/install.sh"
LAUNCH_SESSION="${SKILL_SRC}/bin/project-launch-session.sh"
LAUNCH_MD="${SKILL_SRC}/commands/launch.md"

# --- Source file presence ---

@test "loop-preamble (CPT-82): template file exists at skills/project/templates/loop-preamble.md" {
  [ -f "$TEMPLATE_SRC" ] || { echo "info: missing $TEMPLATE_SRC"; return 1; }
}

# --- Required content markers (per CPT-82 spec §3.2) ---

@test "loop-preamble (CPT-82): template mentions 60% compact threshold" {
  grep -q '60%' "$TEMPLATE_SRC"
}

@test "loop-preamble (CPT-82): template mentions 85% clear threshold" {
  grep -q '85%' "$TEMPLATE_SRC"
}

@test "loop-preamble (CPT-82): template references /compact command" {
  grep -qE '(/compact|`/compact`)' "$TEMPLATE_SRC"
}

@test "loop-preamble (CPT-82): template references /clear command" {
  grep -qE '(/clear|`/clear`)' "$TEMPLATE_SRC"
}

@test "loop-preamble (CPT-82): template references --continue relaunch" {
  grep -qE -- '--continue' "$TEMPLATE_SRC"
}

@test "loop-preamble (CPT-82): template distinguishes monitor roles" {
  grep -qiE '(monitor[[:space:]]+role|monitor-role)' "$TEMPLATE_SRC"
}

@test "loop-preamble (CPT-82): template distinguishes code-writing roles" {
  grep -qiE '(code[-[:space:]]+writing|fixer.*implementer|code-writing[[:space:]]+role)' "$TEMPLATE_SRC"
}

@test "loop-preamble (CPT-82): template points at MEMORY.md for state re-establishment" {
  grep -qF 'MEMORY.md' "$TEMPLATE_SRC"
}

@test "loop-preamble (CPT-82): template names all 8 polling roles (master/planner not — planner is on-demand)" {
  # All 8 loop-capable roles must be named so operators know which tuning applies.
  for role in master triager reviewer merger chk1 chk2 fixer implementer; do
    grep -q "$role" "$TEMPLATE_SRC" || { echo "info: role '$role' not mentioned in template"; return 1; }
  done
}

@test "loop-preamble (CPT-82): on-demand roles (planner/performance/playtester) NOT listed as loop-preamble consumers" {
  # These roles don't loop. If they're listed as receiving the preamble, the
  # template is misleading. We allow them to be MENTIONED (e.g., "not these roles")
  # but check that they aren't listed in a role-tuning table entry.
  # Heuristic: should NOT have a line like "planner: ..." or "performance: ..."
  # as a tuning row.
  for role in planner performance playtester; do
    if grep -qE "^[[:space:]]*[-*|][[:space:]]+\*?\*?${role}\*?\*?[[:space:]]*:" "$TEMPLATE_SRC"; then
      echo "info: on-demand role '$role' appears as a tuning row — should be excluded"
      return 1
    fi
  done
}

# --- Installer wiring ---

@test "loop-preamble (CPT-82): install.sh installs the templates/ dir" {
  grep -qE '(templates|loop-preamble)' "$INSTALLER" \
    || { echo "info: install.sh has no templates/loop-preamble install step"; return 1; }
}

# --- Launch dispatch wiring ---

@test "loop-preamble (CPT-82): project-launch-session.sh /loop dispatch references loop-preamble.md" {
  grep -qF 'loop-preamble.md' "$LAUNCH_SESSION" \
    || { echo "info: /loop dispatch does not reference loop-preamble.md"; return 1; }
}

@test "loop-preamble (CPT-82): /loop dispatch command includes the preamble path before the loop.md path" {
  # Extract the loop_cmd assignment and check ordering.
  # Preamble reference must appear BEFORE the role-specific loops/loop.md read.
  local preamble_line loop_line
  preamble_line=$(grep -n 'loop-preamble.md' "$LAUNCH_SESSION" | head -1 | cut -d: -f1)
  loop_line=$(grep -n 'LOOP_PROMPT_ABS' "$LAUNCH_SESSION" | grep -v '^#' | tail -1 | cut -d: -f1)
  [ -n "$preamble_line" ] && [ -n "$loop_line" ] && [ "$preamble_line" -le "$loop_line" ] \
    || { echo "info: preamble reference should appear before/with LOOP_PROMPT_ABS in launch script"; return 1; }
}

# --- Docs wiring ---

@test "loop-preamble (CPT-82): launch.md documents the loop-preamble mechanism" {
  grep -qi 'loop-preamble\|step-0 preamble\|three-tier context' "$LAUNCH_MD" \
    || { echo "info: launch.md does not document the preamble mechanism"; return 1; }
}
