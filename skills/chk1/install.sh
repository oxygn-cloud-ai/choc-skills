#!/usr/bin/env bash
set -euo pipefail

# Per-skill installer for chk1
# Delegates to the root installer for consistency. Can also run standalone.

SKILL_NAME="chk1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_INSTALLER="${SCRIPT_DIR}/../../install.sh"

# If root installer exists, delegate to it
if [ -f "$ROOT_INSTALLER" ]; then
  exec "$ROOT_INSTALLER" "$@" "$SKILL_NAME"
fi

# Standalone fallback (e.g. downloaded this directory only)
TARGET_DIR="${HOME}/.claude/skills/${SKILL_NAME}"
SOURCE_FILE="${SCRIPT_DIR}/SKILL.md"

# Colors
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

ok()   { printf "${GREEN}  ok${RESET}  %s\n" "$*"; }
err()  { printf "${RED} err${RESET}  %s\n" "$*" >&2; }
warn() { printf "${YELLOW}warn${RESET}  %s\n" "$*" >&2; }
info() { printf "${CYAN}info${RESET}  %s\n" "$*"; }
die()  { err "$@"; exit 1; }

if [ ! -f "$SOURCE_FILE" ]; then
  die "SKILL.md not found in ${SCRIPT_DIR}"
fi

# Handle --help
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "chk1 skill installer (standalone mode)"
  echo ""
  echo "Usage:"
  echo "  ./install.sh              Install chk1"
  echo "  ./install.sh --force      Install/overwrite without prompting"
  echo "  ./install.sh --check      Verify installation health"
  echo "  ./install.sh --uninstall  Remove chk1"
  echo "  ./install.sh --help       Show this help"
  echo "  ./install.sh --version    Show version"
  exit 0
fi

# Handle --version
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-v" ]; then
  local_ver=$(grep -m1 '^version:' "$SOURCE_FILE" 2>/dev/null | sed 's/^version: *//' || true)
  echo "chk1 v${local_ver:-unknown}"
  exit 0
fi

# Handle --uninstall
if [ "${1:-}" = "--uninstall" ]; then
  if [ -d "$TARGET_DIR" ]; then
    rm -rf "$TARGET_DIR"
    if [ -d "$TARGET_DIR" ]; then
      die "Failed to remove ${TARGET_DIR}"
    fi
    ok "Uninstalled '${SKILL_NAME}'"
  else
    warn "'${SKILL_NAME}' is not installed"
  fi
  exit 0
fi

# Handle --check
if [ "${1:-}" = "--check" ] || [ "${1:-}" = "--doctor" ]; then
  if [ ! -f "${TARGET_DIR}/SKILL.md" ]; then
    warn "'${SKILL_NAME}' is not installed"
    exit 1
  fi
  if cmp -s "$SOURCE_FILE" "${TARGET_DIR}/SKILL.md"; then
    ok "'${SKILL_NAME}' is installed and up to date"
    exit 0
  else
    warn "'${SKILL_NAME}' is installed but differs from source"
    info "Run: ./install.sh --force to update"
    exit 1
  fi
fi

# Check if already installed and up to date
if [ -f "${TARGET_DIR}/SKILL.md" ]; then
  if cmp -s "$SOURCE_FILE" "${TARGET_DIR}/SKILL.md"; then
    ok "'${SKILL_NAME}' is already installed and up to date"
    exit 0
  fi
  info "'${SKILL_NAME}' is installed but outdated"
  if [ -t 0 ] && [ "${1:-}" != "--force" ] && [ "${1:-}" != "-f" ]; then
    printf "Overwrite? [y/N] "
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
      warn "Skipped"
      exit 0
    fi
  elif [ "${1:-}" != "--force" ] && [ "${1:-}" != "-f" ]; then
    warn "Non-interactive mode: use --force to overwrite"
    exit 1
  fi
fi

# Install
if ! mkdir -p "$TARGET_DIR" 2>/dev/null; then
  die "Cannot create ${TARGET_DIR} — check permissions"
fi

if ! cp "$SOURCE_FILE" "${TARGET_DIR}/SKILL.md" 2>/dev/null; then
  die "Failed to copy SKILL.md — check disk space and permissions"
fi

if ! cmp -s "$SOURCE_FILE" "${TARGET_DIR}/SKILL.md"; then
  die "Verification failed — installed file differs from source"
fi

ok "Installed '${SKILL_NAME}' -> ${TARGET_DIR}"
echo ""
printf "  ${BOLD}Usage in Claude Code:${RESET}\n"
echo "    /chk1                     Audit most recent implementation"
echo "    /chk1 <commit>..<commit>  Audit a specific commit range"
echo "    /chk1 doctor              Check environment health"
echo "    /chk1 help                Display usage guide"
