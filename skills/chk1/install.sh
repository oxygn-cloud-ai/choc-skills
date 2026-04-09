#!/usr/bin/env bash
set -euo pipefail

# Per-skill installer for chk1
# Installs SKILL.md to ~/.claude/skills/chk1/
# Installs sub-command .md files to ~/.claude/commands/chk1/
# Installs router to ~/.claude/commands/chk1.md

SKILL_NAME="chk1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

SKILL_TARGET="${HOME}/.claude/skills/${SKILL_NAME}"
COMMANDS_TARGET="${HOME}/.claude/commands/${SKILL_NAME}"
SKILL_SOURCE="${SCRIPT_DIR}/SKILL.md"
COMMANDS_SOURCE="${SCRIPT_DIR}/commands"

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
${BOLD}chk1 skill installer${RESET}

${BOLD}USAGE${RESET}
  ./install.sh              Install chk1 (skill + sub-commands)
  ./install.sh --force      Install/overwrite without prompting
  ./install.sh --check      Verify installation health
  ./install.sh --uninstall  Remove chk1 completely
  ./install.sh --version    Show version
  ./install.sh --help       Show this help

${BOLD}INSTALLS TO${RESET}
  ~/.claude/skills/chk1/SKILL.md       Main skill file
  ~/.claude/commands/chk1.md           Router
  ~/.claude/commands/chk1/*.md         Sub-command files
EOF
  exit 0
fi

# --- Version ---
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-v" ]; then
  ver=$(grep -m1 '^version:' "$SKILL_SOURCE" 2>/dev/null | sed 's/^version: *//' || true)
  echo "chk1 v${ver:-unknown}"
  exit 0
fi

# --- Uninstall ---
if [ "${1:-}" = "--uninstall" ]; then
  info "Uninstalling chk1..."
  [ -d "$SKILL_TARGET" ] && rm -rf "$SKILL_TARGET" && ok "Removed ${SKILL_TARGET}" || warn "Skill not installed"
  [ -d "$COMMANDS_TARGET" ] && rm -rf "$COMMANDS_TARGET" && ok "Removed ${COMMANDS_TARGET}" || warn "Commands not installed"
  [ -f "${HOME}/.claude/commands/chk1.md" ] && rm -f "${HOME}/.claude/commands/chk1.md" && ok "Removed router" || true
  ok "chk1 uninstalled"
  exit 0
fi

# --- Health check ---
if [ "${1:-}" = "--check" ] || [ "${1:-}" = "--doctor" ]; then
  printf "\n${BOLD}chk1 installation health check${RESET}\n\n"
  issues=0

  if [ -f "${SKILL_TARGET}/SKILL.md" ]; then
    ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
    ok "SKILL.md installed (v${ver})"
  else
    err "SKILL.md not found at ${SKILL_TARGET}/SKILL.md"; issues=$((issues + 1))
  fi

  if [ -f "${HOME}/.claude/commands/chk1.md" ]; then
    ok "Router: ~/.claude/commands/chk1.md"
  else
    err "Router not found"; issues=$((issues + 1))
  fi

  if [ -d "$COMMANDS_TARGET" ]; then
    count=$(find "$COMMANDS_TARGET" -name "*.md" | wc -l | tr -d ' ')
    ok "Sub-commands: ${count} files in ${COMMANDS_TARGET}"
  else
    err "Sub-commands not found"; issues=$((issues + 1))
  fi

  if command -v git >/dev/null 2>&1; then
    ok "git: $(command -v git)"
  else
    err "git: not found"; issues=$((issues + 1))
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

info "Installing chk1..."

# 1. Install SKILL.md
mkdir -p "$SKILL_TARGET"
cp "$SKILL_SOURCE" "${SKILL_TARGET}/SKILL.md"
ok "SKILL.md -> ${SKILL_TARGET}/SKILL.md"

# 2. Install router command
mkdir -p "${HOME}/.claude/commands"
cat > "${HOME}/.claude/commands/chk1.md" <<'ROUTER'
# chk1 — Adversarial Implementation Audit Router

Parse the argument from: $ARGUMENTS

Route to the appropriate sub-skill based on the argument:

| Argument | Action |
|----------|--------|
| (empty) or `all` | Run the full audit from the main `/chk1` skill |
| `quick` | Run `/chk1:quick` |
| `security` | Run `/chk1:security` |
| `scope` | Run `/chk1:scope` |
| `architecture` | Run `/chk1:architecture` |
| `fix` | Run `/chk1:fix` |
| `github` | Run `/chk1:github` |
| `update` | Run `/chk1:update` |
| `help` | Run `/chk1 help` (the main skill) |
| `doctor` | Run `/chk1 doctor` (the main skill) |
| `version` | Run `/chk1 version` (the main skill) |
| anything else | Treat as a scope specifier (commit range, branch, SHA) and run the full audit |

Invoke the matching skill using the Skill tool.
ROUTER
ok "Router -> ~/.claude/commands/chk1.md"

# 3. Install sub-commands (if directory exists)
if [ -d "$COMMANDS_SOURCE" ]; then
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

# 4. Record source repo path (for /chk1 update)
echo "$SCRIPT_DIR" > "${SKILL_TARGET}/.source-repo"
ok "Source repo marker -> ${SKILL_TARGET}/.source-repo"

# 5. Verify
ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
echo ""
ok "chk1 v${ver} installed successfully"
echo ""
info "Files installed:"
printf "  ${DIM}%-50s${RESET} (main skill)\n" "${SKILL_TARGET}/SKILL.md"
printf "  ${DIM}%-50s${RESET} (router)\n" "${HOME}/.claude/commands/chk1.md"
[ -d "$COMMANDS_TARGET" ] && printf "  ${DIM}%-50s${RESET} (sub-commands)\n" "${COMMANDS_TARGET}/"
echo ""
info "Usage: /chk1 or /chk1 help"
