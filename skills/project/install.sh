#!/usr/bin/env bash
set -euo pipefail

# Per-skill installer for project
# Installs SKILL.md to ${CLAUDE_CONFIG_DIR:-~/.claude}/skills/project/
# Installs sub-command .md files to ${CLAUDE_CONFIG_DIR:-~/.claude}/commands/project/
# Installs router to ${CLAUDE_CONFIG_DIR:-~/.claude}/commands/project.md
# Installs bin/ scripts to ~/.local/bin/
# Installs hooks/*.sh to ${CLAUDE_CONFIG_DIR:-~/.claude}/hooks/ and registers them in
# ${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json hooks.PreToolUse (idempotent).

SKILL_NAME="project"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# CLAUDE_CONFIG_DIR honoured (CPT-174). Falls back to ~/.claude when unset or
# empty, matching how Claude Code itself resolves the config dir at runtime.
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"

# Colors
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; RESET=''
fi

ok()   { printf "${GREEN}  ok${RESET}  %s\n" "$*"; }
err()  { printf "${RED} err${RESET}  %s\n" "$*" >&2; }
warn() { printf "${YELLOW}warn${RESET}  %s\n" "$*" >&2; }
info() { printf "${CYAN}info${RESET}  %s\n" "$*"; }
die()  { err "$@"; exit 1; }

SKILL_TARGET="${CLAUDE_DIR}/skills/${SKILL_NAME}"
COMMANDS_TARGET="${CLAUDE_DIR}/commands/${SKILL_NAME}"
SKILL_SOURCE="${SCRIPT_DIR}/SKILL.md"
COMMANDS_SOURCE="${SCRIPT_DIR}/commands"
HOOKS_SOURCE="${SCRIPT_DIR}/hooks"
HOOKS_TARGET="${CLAUDE_DIR}/hooks"
GLOBAL_SOURCE="${SCRIPT_DIR}/global"
GLOBAL_TARGET="${CLAUDE_DIR}"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"

# Files installed to ~/.claude/ root (multi-session architecture + project standards).
# Listed explicitly so --uninstall knows what to target and --check stays in sync.
GLOBAL_DOCS=(MULTI_SESSION_ARCHITECTURE.md PROJECT_STANDARDS.md)

# hook_matcher_for <basename> — emit the space-separated matcher(s) a hook
# must be registered against in ~/.claude/settings.json hooks.PreToolUse.
# Single source of truth for install + uninstall + check.
hook_matcher_for() {
  case "$1" in
    block-worktree-add.sh)
      echo "Bash"
      ;;
    verify-jira-parent.sh)
      echo "mcp__claude_ai_Atlassian__createJiraIssue mcp__claude_ai_Atlassian__editJiraIssue"
      ;;
    *)
      echo ""
      ;;
  esac
}

# register_hook_in_settings <matcher> <absolute-cmd-path>
# Idempotent: no-op if the exact (matcher, command) tuple already exists.
# Creates hooks.PreToolUse[] if missing. Preserves any other PreToolUse entries.
register_hook_in_settings() {
  local matcher="$1"
  local cmd="$2"
  [ -f "$SETTINGS_FILE" ] || echo '{}' > "$SETTINGS_FILE"
  local count
  count=$(jq --arg m "$matcher" --arg c "$cmd" \
    '[.hooks.PreToolUse[]? | select(.matcher == $m) | .hooks[]? | select(.command == $c)] | length' \
    "$SETTINGS_FILE" 2>/dev/null || echo 0)
  if [ "$count" != "0" ]; then
    return 0
  fi
  local tmp; tmp=$(mktemp)
  jq --arg m "$matcher" --arg c "$cmd" \
    '.hooks = (.hooks // {}) | .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{"matcher": $m, "hooks": [{"type": "command", "command": $c}]}])' \
    "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
}

# remove_hook_registration <absolute-cmd-path>
# Removes the specific hook command entry from every PreToolUse matcher's
# .hooks[] array, and drops matcher objects whose .hooks[] becomes empty.
# Preserves unrelated sibling hooks that share a matcher object (CPT-175).
#
# Prior filter (`all(.command != $c)`) dropped the entire matcher object when
# any of its hooks matched — collateral-deleting unrelated siblings. The
# current two-step rebuild surgically removes only the caller-specified
# command and only prunes matchers that become truly empty.
remove_hook_registration() {
  local cmd="$1"
  [ -f "$SETTINGS_FILE" ] || return 0
  local tmp; tmp=$(mktemp)
  jq --arg c "$cmd" '
    .hooks.PreToolUse = (
      (.hooks.PreToolUse // [])
      | map(.hooks = ((.hooks // []) | map(select(.command != $c))))
      | map(select((.hooks // []) | length > 0))
    )
  ' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
}

# --force is accepted for command-line symmetry with the root install.sh, but
# this per-skill installer has no interactive prompts — cp always overwrites —
# so the flag is a no-op. Kept in the arg parser so wrapper scripts that pass
# --force continue to work.
for arg in "$@"; do
  case "$arg" in
    -f|--force) : ;;
  esac
done

# --- Help ---
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<EOF
${BOLD}project skill installer${RESET}

${BOLD}USAGE${RESET}
  ./install.sh              Install project (skill + sub-commands + hooks)
  ./install.sh --force      Install/overwrite without prompting
  ./install.sh --check      Verify installation health
  ./install.sh --uninstall  Remove project completely (keeps hook files)
  ./install.sh --version    Show version
  ./install.sh --help       Show this help

${BOLD}INSTALLS TO${RESET}
  ${CLAUDE_DIR}/skills/project/SKILL.md            Main skill file
  ${CLAUDE_DIR}/commands/project.md                Router
  ${CLAUDE_DIR}/commands/project/*.md              Sub-command files
  ~/.local/bin/project-*.sh                    Launch/picker helpers
  ${CLAUDE_DIR}/hooks/*.sh                         PreToolUse enforcement hooks
  ${CLAUDE_DIR}/settings.json                      hooks.PreToolUse[] registrations
  ${CLAUDE_DIR}/MULTI_SESSION_ARCHITECTURE.md      Global multi-session architecture
  ${CLAUDE_DIR}/PROJECT_STANDARDS.md               Global project standards

${BOLD}REQUIREMENTS${RESET}
  git, gh (authenticated), jq (for settings.json merge)
EOF
  exit 0
fi

# --- Version ---
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-v" ]; then
  ver=$(grep -m1 '^version:' "$SKILL_SOURCE" 2>/dev/null | sed 's/^version: *//' || true)
  echo "project v${ver:-unknown}"
  exit 0
fi

# --- Uninstall ---
if [ "${1:-}" = "--uninstall" ]; then
  info "Uninstalling project..."
  [ -d "$SKILL_TARGET" ] && rm -rf "$SKILL_TARGET" && ok "Removed ${SKILL_TARGET}" || warn "Skill not installed"
  [ -d "$COMMANDS_TARGET" ] && rm -rf "$COMMANDS_TARGET" && ok "Removed ${COMMANDS_TARGET}" || warn "Commands not installed"
  [ -f "${CLAUDE_DIR}/commands/project.md" ] && rm -f "${CLAUDE_DIR}/commands/project.md" && ok "Removed router" || true
  [ -f "${HOME}/.local/bin/project-picker.sh" ] && rm -f "${HOME}/.local/bin/project-picker.sh" && ok "Removed picker script" || true
  [ -f "${HOME}/.local/bin/project-launch-session.sh" ] && rm -f "${HOME}/.local/bin/project-launch-session.sh" && ok "Removed launch-session script" || true

  # De-register hooks from settings.json but leave the hook files in place.
  # Rationale: other tools / future skills may share the hook files; settings.json
  # entries pointing at commands we installed are the part we own and must remove.
  if [ -d "$HOOKS_SOURCE" ]; then
    deregistered=0
    for source in "${HOOKS_SOURCE}"/*.sh; do
      [ -f "$source" ] || continue
      tgt="${HOOKS_TARGET}/$(basename "$source")"
      remove_hook_registration "$tgt"
      deregistered=$((deregistered + 1))
    done
    [ "$deregistered" -gt 0 ] && ok "De-registered ${deregistered} hook(s) from ${SETTINGS_FILE}"
    info "Hook files kept at ${HOOKS_TARGET}/ (delete manually if not needed by other tools)"
  fi

  ok "project uninstalled"
  exit 0
fi

# --- Health check ---
if [ "${1:-}" = "--check" ] || [ "${1:-}" = "--doctor" ]; then
  printf "\n${BOLD}project installation health check${RESET}\n\n"
  issues=0

  if [ -f "${SKILL_TARGET}/SKILL.md" ]; then
    ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
    ok "SKILL.md installed (v${ver})"
  else
    err "SKILL.md not found at ${SKILL_TARGET}/SKILL.md"; issues=$((issues + 1))
  fi

  if [ -f "${CLAUDE_DIR}/commands/project.md" ]; then
    ok "Router: ${CLAUDE_DIR}/commands/project.md"
  else
    err "Router not found"; issues=$((issues + 1))
  fi

  if [ -d "$COMMANDS_TARGET" ]; then
    count=$(find "$COMMANDS_TARGET" -name "*.md" | wc -l | tr -d ' ')
    ok "Sub-commands: ${count} files in ${COMMANDS_TARGET}"
  else
    err "Sub-commands not found"; issues=$((issues + 1))
  fi

  if [ -f "${CLAUDE_DIR}/MULTI_SESSION_ARCHITECTURE.md" ]; then
    ok "Global architecture doc present"
  else
    err "${CLAUDE_DIR}/MULTI_SESSION_ARCHITECTURE.md missing (required at runtime)"; issues=$((issues + 1))
  fi

  if [ -f "${CLAUDE_DIR}/PROJECT_STANDARDS.md" ]; then
    ok "Global project standards present"
  else
    err "${CLAUDE_DIR}/PROJECT_STANDARDS.md missing (required at runtime)"; issues=$((issues + 1))
  fi

  if command -v git >/dev/null 2>&1; then
    ok "git: $(command -v git)"
  else
    err "git: not found"; issues=$((issues + 1))
  fi

  if command -v gh >/dev/null 2>&1; then
    ok "gh: $(command -v gh)"
  else
    err "gh: not found (required for /project:new and /project:config)"; issues=$((issues + 1))
  fi

  if command -v jq >/dev/null 2>&1; then
    ok "jq: $(command -v jq)"
  else
    err "jq: not found (required for settings.json hook registration + validate-config.sh)"; issues=$((issues + 1))
  fi

  if command -v tmux >/dev/null 2>&1; then
    ok "tmux: $(command -v tmux)"
  else
    warn "tmux: not found (required for /project:launch and project-picker.sh)"
  fi

  if [ -f "${HOME}/.local/bin/project-picker.sh" ]; then
    ok "Picker script: ${HOME}/.local/bin/project-picker.sh"
  else
    warn "Picker script: not installed (run install.sh --force to install)"
  fi

  if [ -f "${HOME}/.local/bin/project-launch-session.sh" ]; then
    ok "Launch-session script: ${HOME}/.local/bin/project-launch-session.sh"
  else
    err "Launch-session script: not installed (run install.sh --force) — /project:launch will fail without it"; issues=$((issues + 1))
  fi

  # Hook file + registration check
  if [ -d "$HOOKS_SOURCE" ]; then
    for source in "${HOOKS_SOURCE}"/*.sh; do
      [ -f "$source" ] || continue
      name=$(basename "$source")
      tgt="${HOOKS_TARGET}/${name}"
      if [ -x "$tgt" ]; then
        reg_count=0
        if [ -f "$SETTINGS_FILE" ]; then
          reg_count=$(jq --arg c "$tgt" \
            '[.hooks.PreToolUse[]? | .hooks[]? | select(.command == $c)] | length' \
            "$SETTINGS_FILE" 2>/dev/null || echo 0)
        fi
        if [ "$reg_count" -gt 0 ]; then
          ok "Hook installed + registered: ${name} (${reg_count} matcher entry/entries)"
        else
          err "Hook file at ${tgt} but NOT registered in ${SETTINGS_FILE} (run install.sh --force)"
          issues=$((issues + 1))
        fi
      else
        err "Hook missing: ${tgt} (run install.sh --force)"; issues=$((issues + 1))
      fi
    done
  fi

  echo ""
  if [ "$issues" -eq 0 ]; then
    printf "  ${GREEN}All checks passed${RESET}\n\n"
  else
    printf "  ${YELLOW}${issues} issue(s) found${RESET}\n\n"
  fi
  exit 0
fi

# --- Install ---
[ -f "$SKILL_SOURCE" ] || die "SKILL.md not found in ${SCRIPT_DIR}"
command -v jq >/dev/null 2>&1 || die "jq is required for hook registration in settings.json"

info "Installing project..."

# 1. Install SKILL.md
mkdir -p "$SKILL_TARGET"
cp "$SKILL_SOURCE" "${SKILL_TARGET}/SKILL.md"
ok "SKILL.md -> ${SKILL_TARGET}/SKILL.md"

# 2. Install router command
mkdir -p "${CLAUDE_DIR}/commands"
cat > "${CLAUDE_DIR}/commands/project.md" <<'ROUTER'
# project — Project Repository Administration Router

Parse the argument from: $ARGUMENTS

Route to the appropriate sub-command. Every subcommand is a colon-command file under `${CLAUDE_DIR}/commands/project/` — there is no inline dispatch:

| Argument | Action |
|----------|--------|
| (empty) or `status` | Run `/project:status` |
| `new` | Run `/project:new` |
| `audit` | Run `/project:audit` |
| `config` | Run `/project:config` |
| `launch` (with optional flags) | Run `/project:launch` passing flags |
| `update`, `--update`, `upgrade` | Run `/project:update` |
| `help`, `--help`, `-h` | Run `/project:help` |
| `doctor`, `--doctor`, `check` | Run `/project:doctor` |
| `version`, `--version`, `-v` | Run `/project:version` |
| anything else | Show: "Unknown command. Run `/project help` for usage." |

Invoke the matching skill using the Skill tool.
ROUTER
ok "Router -> ${CLAUDE_DIR}/commands/project.md"

# 3. Install sub-commands (if directory exists)
if [ -d "$COMMANDS_SOURCE" ]; then
  # Clean stale command files from previous version
  if [ -d "$COMMANDS_TARGET" ]; then
    rm -rf "$COMMANDS_TARGET"
  fi
  mkdir -p "$COMMANDS_TARGET"
  count=0
  for file in "${COMMANDS_SOURCE}"/*.md; do
    [ -f "$file" ] || continue
    cp "$file" "${COMMANDS_TARGET}/$(basename "$file")"
    count=$((count + 1))
  done
  ok "Sub-commands: ${count} files -> ${COMMANDS_TARGET}/"
else
  warn "No commands/ directory found — sub-commands not installed"
fi

# 4. Install bin/ scripts (picker + launch-session helper)
BIN_SOURCE="${SCRIPT_DIR}/bin"
BIN_TARGET="${HOME}/.local/bin"
if [ -d "$BIN_SOURCE" ]; then
  mkdir -p "$BIN_TARGET"
  bin_count=0
  for file in "${BIN_SOURCE}"/*.sh; do
    [ -f "$file" ] || continue
    cp "$file" "${BIN_TARGET}/$(basename "$file")"
    chmod +x "${BIN_TARGET}/$(basename "$file")"
    bin_count=$((bin_count + 1))
  done
  ok "bin/ scripts: ${bin_count} file(s) -> ${BIN_TARGET}/"
else
  warn "No bin/ directory found — project-picker.sh and project-launch-session.sh not installed"
fi

# 5. Install PROJECT_CONFIG.schema.json (for /project:new)
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCHEMA_SOURCE="${REPO_ROOT}/PROJECT_CONFIG.schema.json"
if [ -f "$SCHEMA_SOURCE" ]; then
  cp "$SCHEMA_SOURCE" "${SKILL_TARGET}/PROJECT_CONFIG.schema.json"
  ok "Schema -> ${SKILL_TARGET}/PROJECT_CONFIG.schema.json"
else
  warn "PROJECT_CONFIG.schema.json not found at repo root — /project:new won't be able to copy it to new projects"
fi

# 6. Install global reference docs (MULTI_SESSION_ARCHITECTURE.md, PROJECT_STANDARDS.md)
# These live at ~/.claude/ root because session prompts and audit.md reference
# them via absolute paths (see skills/project/commands/audit.md). Shipped from
# the skill source tree so every install is consistent; any customisation belongs
# upstream in skills/project/global/ then re-install, not in the live copy.
if [ -d "$GLOBAL_SOURCE" ]; then
  mkdir -p "$GLOBAL_TARGET"
  global_count=0
  for name in "${GLOBAL_DOCS[@]}"; do
    source="${GLOBAL_SOURCE}/${name}"
    if [ -f "$source" ]; then
      cp "$source" "${GLOBAL_TARGET}/${name}"
      global_count=$((global_count + 1))
    else
      warn "Expected global doc missing from source: ${source}"
    fi
  done
  ok "global docs: ${global_count} file(s) -> ${GLOBAL_TARGET}/"
else
  warn "No global/ directory found — MULTI_SESSION_ARCHITECTURE.md / PROJECT_STANDARDS.md not installed"
fi

# 7. Install hooks + register each in ~/.claude/settings.json hooks.PreToolUse
# Hook files live in ~/.claude/hooks/ (machine-global, shared with other tools).
# Registration is idempotent: re-running --force does not duplicate entries.
if [ -d "$HOOKS_SOURCE" ]; then
  mkdir -p "$HOOKS_TARGET"
  hook_count=0
  reg_count=0
  for source in "${HOOKS_SOURCE}"/*.sh; do
    [ -f "$source" ] || continue
    name=$(basename "$source")
    tgt="${HOOKS_TARGET}/${name}"
    cp "$source" "$tgt"
    chmod +x "$tgt"
    hook_count=$((hook_count + 1))

    matchers=$(hook_matcher_for "$name")
    if [ -n "$matchers" ]; then
      for m in $matchers; do
        register_hook_in_settings "$m" "$tgt"
        reg_count=$((reg_count + 1))
      done
    else
      warn "Hook ${name} has no matcher mapping in hook_matcher_for() — file installed but NOT registered"
    fi
  done
  ok "hooks: ${hook_count} file(s) -> ${HOOKS_TARGET}/ (${reg_count} matcher entry/entries in ${SETTINGS_FILE})"
else
  warn "No hooks/ directory found — enforcement hooks not installed"
fi

# 8. Record source repo path (for /project update)
echo "$SCRIPT_DIR" > "${SKILL_TARGET}/.source-repo"
ok "Source repo marker -> ${SKILL_TARGET}/.source-repo"

# 9. Verify
ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
echo ""
ok "project v${ver} installed successfully"
echo ""
info "Files installed:"
printf "  ${DIM}%-50s${RESET} (main skill)\n" "${SKILL_TARGET}/SKILL.md"
printf "  ${DIM}%-50s${RESET} (router)\n" "${CLAUDE_DIR}/commands/project.md"
[ -d "$COMMANDS_TARGET" ] && printf "  ${DIM}%-50s${RESET} (sub-commands)\n" "${COMMANDS_TARGET}/"
[ -f "${BIN_TARGET}/project-picker.sh" ] && printf "  ${DIM}%-50s${RESET} (session picker)\n" "${BIN_TARGET}/project-picker.sh"
[ -f "${BIN_TARGET}/project-launch-session.sh" ] && printf "  ${DIM}%-50s${RESET} (launch helper)\n" "${BIN_TARGET}/project-launch-session.sh"
[ -d "$HOOKS_TARGET" ] && printf "  ${DIM}%-50s${RESET} (enforcement hooks)\n" "${HOOKS_TARGET}/"
echo ""
info "Usage: /project or /project help"
