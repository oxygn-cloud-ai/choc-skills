#!/usr/bin/env bash
set -euo pipefail

# Per-skill installer for chk2
# Installs SKILL.md to ${CLAUDE_CONFIG_DIR:-~/.claude}/skills/chk2/
# Installs sub-command .md files to ${CLAUDE_CONFIG_DIR:-~/.claude}/commands/chk2/

SKILL_NAME="chk2"
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
FORCE=false

# --- Flags ---
for arg in "$@"; do
  case "$arg" in
    -f|--force) FORCE=true ;;
  esac
done

# --- Help ---
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<EOF
${BOLD}chk2 skill installer${RESET}

${BOLD}USAGE${RESET}
  ./install.sh              Install chk2 (skill + sub-commands)
  ./install.sh --force      Install/overwrite without prompting
  ./install.sh --check      Verify installation health
  ./install.sh --uninstall  Remove chk2 completely
  ./install.sh --version    Show version
  ./install.sh --help       Show this help

${BOLD}INSTALLS TO${RESET}
  ${CLAUDE_DIR}/skills/chk2/SKILL.md        Main skill file
  ${CLAUDE_DIR}/commands/chk2/*.md           Sub-command files (35 files)
EOF
  exit 0
fi

# --- Version ---
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-v" ]; then
  ver=$(grep -m1 '^version:' "$SKILL_SOURCE" 2>/dev/null | sed 's/^version: *//' || true)
  echo "chk2 v${ver:-unknown}"
  exit 0
fi

# --- Uninstall ---
if [ "${1:-}" = "--uninstall" ]; then
  info "Uninstalling chk2..."
  if [ -d "$SKILL_TARGET" ]; then
    rm -rf "$SKILL_TARGET"
    ok "Removed ${SKILL_TARGET}"
  else
    warn "Skill not installed at ${SKILL_TARGET}"
  fi
  if [ -d "$COMMANDS_TARGET" ]; then
    rm -rf "$COMMANDS_TARGET"
    ok "Removed ${COMMANDS_TARGET}"
  else
    warn "Commands not installed at ${COMMANDS_TARGET}"
  fi
  # Remove router file
  if [ -f "${CLAUDE_DIR}/commands/chk2.md" ]; then
    rm -f "${CLAUDE_DIR}/commands/chk2.md"
    ok "Removed router: ${CLAUDE_DIR}/commands/chk2.md"
  fi
  ok "chk2 uninstalled"
  exit 0
fi

# --- Health check ---
if [ "${1:-}" = "--check" ]; then
  printf "\n${BOLD}chk2 installation health check${RESET}\n\n"
  issues=0

  if [ -f "${SKILL_TARGET}/SKILL.md" ]; then
    ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
    ok "SKILL.md installed (v${ver})"
  else
    err "SKILL.md not found at ${SKILL_TARGET}/SKILL.md"
    issues=$((issues + 1))
  fi

  if [ -f "${CLAUDE_DIR}/commands/chk2.md" ]; then
    ok "Router: ${CLAUDE_DIR}/commands/chk2.md"
  else
    err "Router not found: ${CLAUDE_DIR}/commands/chk2.md"
    issues=$((issues + 1))
  fi

  if [ -d "$COMMANDS_TARGET" ]; then
    count=$(find "$COMMANDS_TARGET" -name "*.md" | wc -l | tr -d ' ')
    if [ "$count" -ge 35 ]; then
      ok "Sub-commands: ${count} files in ${COMMANDS_TARGET}"
    else
      warn "Sub-commands: only ${count}/35 files in ${COMMANDS_TARGET}"
      issues=$((issues + 1))
    fi
  else
    err "Sub-commands directory not found: ${COMMANDS_TARGET}"
    issues=$((issues + 1))
  fi

  for tool in curl dig openssl python3; do
    if command -v "$tool" >/dev/null 2>&1; then
      ok "${tool}: $(which "$tool")"
    else
      warn "${tool}: not found"
      issues=$((issues + 1))
    fi
  done

  if python3 -c "import websockets" 2>/dev/null; then
    ok "python3 websockets: installed"
  else
    warn "python3 websockets: not installed (pip3 install websockets)"
    issues=$((issues + 1))
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
[ -d "$COMMANDS_SOURCE" ] || die "commands/ directory not found in ${SCRIPT_DIR}"

# Check for existing install
if [ -f "${SKILL_TARGET}/SKILL.md" ] && ! "$FORCE"; then
  src_ver=$(grep -m1 '^version:' "$SKILL_SOURCE" 2>/dev/null | sed 's/^version: *//' || true)
  dst_ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
  if [ "$src_ver" = "$dst_ver" ]; then
    ok "chk2 v${dst_ver} already installed and up to date"
    ok "Use --force to reinstall"
    exit 0
  fi
  info "Upgrading chk2: v${dst_ver} -> v${src_ver}"
fi

info "Installing chk2..."

# 1. Install SKILL.md
mkdir -p "$SKILL_TARGET"
cp "$SKILL_SOURCE" "${SKILL_TARGET}/SKILL.md"
ok "SKILL.md -> ${SKILL_TARGET}/SKILL.md"

# 2. Install router command
mkdir -p "${CLAUDE_DIR}/commands"
# Generate router from SKILL.md routing table
cat > "${CLAUDE_DIR}/commands/chk2.md" <<'ROUTER'
# chk2 — Security Check Router

Parse the argument from: $ARGUMENTS

Route to the appropriate sub-skill based on the argument:

| Argument | Action |
|----------|--------|
| (empty) or `all` | Run `/chk2:all` |
| `headers` | Run `/chk2:headers` |
| `tls` | Run `/chk2:tls` |
| `dns` | Run `/chk2:dns` |
| `cors` | Run `/chk2:cors` |
| `api` | Run `/chk2:api` |
| `ws` | Run `/chk2:ws` |
| `waf` | Run `/chk2:waf` |
| `infra` | Run `/chk2:infra` |
| `brute` | Run `/chk2:brute` |
| `scale` | Run `/chk2:scale` |
| `disclosure` | Run `/chk2:disclosure` |
| `quick` | Run `/chk2:quick` |
| `fix` | Run `/chk2:fix` |
| `github` | Run `/chk2:github` |
| `update` | Run `/chk2:update` |
| `help` | Run `/chk2 help` (the main skill) |
| `doctor` | Run `/chk2 doctor` (the main skill) |
| `version` | Run `/chk2 version` (the main skill) |
| anything else | Show available switches |

Invoke the matching skill using the Skill tool.
ROUTER
ok "Router -> ${CLAUDE_DIR}/commands/chk2.md"

# 3. Install sub-commands (clean stale files from previous version)
if [ -d "$COMMANDS_TARGET" ]; then
  rm -rf "$COMMANDS_TARGET"
fi
mkdir -p "$COMMANDS_TARGET"
count=0
for file in "${COMMANDS_SOURCE}"/*.md; do
  [ -f "$file" ] || continue
  name=$(basename "$file")
  cp "$file" "${COMMANDS_TARGET}/${name}"
  count=$((count + 1))
done
ok "Sub-commands: ${count} files -> ${COMMANDS_TARGET}/"

# 4. Record source repo path (for /chk2 update)
echo "$SCRIPT_DIR" > "${SKILL_TARGET}/.source-repo"
ok "Source repo marker -> ${SKILL_TARGET}/.source-repo"

# 5. Verify
ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
echo ""
ok "chk2 v${ver} installed successfully"
echo ""
info "Files installed:"
printf "  ${DIM}%-50s${RESET} (main skill)\n" "${SKILL_TARGET}/SKILL.md"
printf "  ${DIM}%-50s${RESET} (router)\n" "${CLAUDE_DIR}/commands/chk2.md"
printf "  ${DIM}%-50s${RESET} (${count} sub-commands)\n" "${COMMANDS_TARGET}/"
echo ""
info "Usage: /chk2 or /chk2 help"
