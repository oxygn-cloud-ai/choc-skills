#!/usr/bin/env bash
set -euo pipefail

# Per-skill installer for project
# Installs SKILL.md to ${CLAUDE_CONFIG_DIR:-~/.claude}/skills/project/
# Installs sub-command .md files to ${CLAUDE_CONFIG_DIR:-~/.claude}/commands/project/
# Installs router to ${CLAUDE_CONFIG_DIR:-~/.claude}/commands/project.md

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

# --- Parse arguments (order-independent; CPT-76) ---
# --force is a no-op for project (cp always overwrites, no interactive prompt)
# but accepted for command-line symmetry with the root install.sh.
ACTION=""
while [ $# -gt 0 ]; do
  new_action=""
  case "$1" in
    --help|-h)        new_action="help" ;;
    --version|-v)     new_action="version" ;;
    --uninstall)      new_action="uninstall" ;;
    --check|--doctor) new_action="check" ;;
    --force|-f)       shift; continue ;;
    -*)               die "Unknown option: $1 (try --help)" ;;
    *)                die "Unexpected argument: $1 (try --help)" ;;
  esac
  # CPT-123: conflicting action flags (help vs uninstall, etc.) die at parse
  # time rather than silently last-wins. Same flag twice is idempotent.
  if [ -n "$ACTION" ] && [ "$ACTION" != "$new_action" ]; then
    die "Conflicting action flags: --${ACTION} and $1 — pick one"
  fi
  ACTION="$new_action"
  shift
done
ACTION="${ACTION:-install}"

# --- Help ---
if [ "$ACTION" = "help" ]; then
  cat <<EOF
${BOLD}project skill installer${RESET}

${BOLD}USAGE${RESET}
  ./install.sh              Install project (skill + sub-commands)
  ./install.sh --force      Install/overwrite without prompting
  ./install.sh --check      Verify installation health
  ./install.sh --uninstall  Remove project completely
  ./install.sh --version    Show version
  ./install.sh --help       Show this help

${BOLD}INSTALLS TO${RESET}
  ${CLAUDE_DIR}/skills/project/SKILL.md       Main skill file
  ${CLAUDE_DIR}/commands/project.md           Router
  ${CLAUDE_DIR}/commands/project/*.md         Sub-command files

${BOLD}REQUIREMENTS${RESET}
  ${CLAUDE_DIR}/MULTI_SESSION_ARCHITECTURE.md  (runtime reference)
  ${CLAUDE_DIR}/PROJECT_STANDARDS.md           (runtime reference — label/CI/branch-protection narrative; per-project config lives in PROJECT_CONFIG.json)
  git, gh (authenticated)
EOF
  exit 0
fi

# --- Version ---
if [ "$ACTION" = "version" ]; then
  ver=$(grep -m1 '^version:' "$SKILL_SOURCE" 2>/dev/null | sed 's/^version: *//' || true)
  echo "project v${ver:-unknown}"
  exit 0
fi

# --- Uninstall ---
if [ "$ACTION" = "uninstall" ]; then
  info "Uninstalling project..."
  [ -d "$SKILL_TARGET" ] && rm -rf "$SKILL_TARGET" && ok "Removed ${SKILL_TARGET}" || warn "Skill not installed"
  [ -d "$COMMANDS_TARGET" ] && rm -rf "$COMMANDS_TARGET" && ok "Removed ${COMMANDS_TARGET}" || warn "Commands not installed"
  [ -f "${CLAUDE_DIR}/commands/project.md" ] && rm -f "${CLAUDE_DIR}/commands/project.md" && ok "Removed router" || true
  [ -f "${HOME}/.local/bin/project-picker.sh" ] && rm -f "${HOME}/.local/bin/project-picker.sh" && ok "Removed picker script" || true
  ok "project uninstalled"
  exit 0
fi

# --- Health check ---
if [ "$ACTION" = "check" ]; then
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

  # CPT-124: GITHUB_CONFIG.md was retired in favour of PROJECT_STANDARDS.md
  # (narrative) and PROJECT_CONFIG.json (per-project). CPT-77's exit-nonzero
  # contract would otherwise fail every modern install that only has the
  # new files.
  if [ -f "${CLAUDE_DIR}/PROJECT_STANDARDS.md" ]; then
    ok "Global project standards present (${CLAUDE_DIR}/PROJECT_STANDARDS.md)"
  else
    err "${CLAUDE_DIR}/PROJECT_STANDARDS.md missing (required at runtime; replaces retired GITHUB_CONFIG.md)"; issues=$((issues + 1))
  fi

  # Migration nudge: flag the retired GITHUB_CONFIG.md so users don't keep
  # editing a file that is superseded. Informational only, does not
  # increment the issues counter.
  stale_github_config="${CLAUDE_DIR}/GITHUB_CONFIG.md"
  if [ -f "$stale_github_config" ]; then
    warn "$stale_github_config exists but is retired — safe to remove (superseded by PROJECT_STANDARDS.md + PROJECT_CONFIG.json)"
  fi
  unset stale_github_config

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

  echo ""
  if [ "$issues" -eq 0 ]; then
    printf "  ${GREEN}All checks passed${RESET}\n\n"
    exit 0
  else
    printf "  ${YELLOW}${issues} issue(s) found${RESET}\n\n"
    exit 1
  fi
fi

# --- Install ---
[ -f "$SKILL_SOURCE" ] || die "SKILL.md not found in ${SCRIPT_DIR}"

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

Route to the appropriate sub-command:

| Argument | Action |
|----------|--------|
| (empty) or `status` | Run `/project:status` |
| `new` | Run `/project:new` |
| `audit` | Run `/project:audit` |
| `config` | Run `/project:config` |
| `launch` (with optional flags) | Run `/project:launch` passing flags |
| `update`, `--update`, `upgrade` | Run `/project:update` |
| `help`, `--help`, `-h` | Run `/project help` (the main skill) |
| `doctor` | Run `/project doctor` (the main skill) |
| `version` | Run `/project version` (the main skill) |
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

# 4. Install picker script (if bin/ directory exists)
BIN_SOURCE="${SCRIPT_DIR}/bin"
PICKER_TARGET="${HOME}/.local/bin"
if [ -d "$BIN_SOURCE" ]; then
  mkdir -p "$PICKER_TARGET"
  for file in "${BIN_SOURCE}"/*.sh; do
    [ -f "$file" ] || continue
    cp "$file" "${PICKER_TARGET}/$(basename "$file")"
    chmod +x "${PICKER_TARGET}/$(basename "$file")"
  done
  ok "Picker script -> ${PICKER_TARGET}/project-picker.sh"
else
  warn "No bin/ directory found — picker script not installed"
fi

# 5. Record source repo path (for /project update)
echo "$SCRIPT_DIR" > "${SKILL_TARGET}/.source-repo"
ok "Source repo marker -> ${SKILL_TARGET}/.source-repo"

# 6. Verify
ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
echo ""
ok "project v${ver} installed successfully"
echo ""
info "Files installed:"
printf "  ${DIM}%-50s${RESET} (main skill)\n" "${SKILL_TARGET}/SKILL.md"
printf "  ${DIM}%-50s${RESET} (router)\n" "${CLAUDE_DIR}/commands/project.md"
[ -d "$COMMANDS_TARGET" ] && printf "  ${DIM}%-50s${RESET} (sub-commands)\n" "${COMMANDS_TARGET}/"
[ -f "${PICKER_TARGET}/project-picker.sh" ] && printf "  ${DIM}%-50s${RESET} (session picker)\n" "${PICKER_TARGET}/project-picker.sh"
echo ""
info "Usage: /project or /project help"
