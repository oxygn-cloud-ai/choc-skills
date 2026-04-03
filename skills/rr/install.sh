#!/usr/bin/env bash
set -euo pipefail

# Per-skill installer for rr
# Installs SKILL.md to ~/.claude/skills/rr/
# Installs sub-command .md files to ~/.claude/commands/rr/
# Installs orchestrator scripts to ~/.claude/skills/rr/orchestrator/
# Installs reference files to ~/.claude/skills/rr/references/

SKILL_NAME="rr"
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
ORCHESTRATOR_SOURCE="${SCRIPT_DIR}/orchestrator"
REFERENCES_SOURCE="${SCRIPT_DIR}/references"
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
${BOLD}rr skill installer${RESET}

${BOLD}USAGE${RESET}
  ./install.sh              Install rr (skill + sub-commands + orchestrator + references)
  ./install.sh --force      Install/overwrite without prompting
  ./install.sh --check      Verify installation health
  ./install.sh --uninstall  Remove rr completely
  ./install.sh --version    Show version
  ./install.sh --help       Show this help

${BOLD}INSTALLS TO${RESET}
  ~/.claude/skills/rr/SKILL.md             Main skill file
  ~/.claude/skills/rr/.source-repo         Repo path marker (for /rr update)
  ~/.claude/skills/rr/orchestrator/        Batch orchestrator scripts (8 files)
  ~/.claude/skills/rr/references/          Schemas, workflow, context (16+ files)
  ~/.claude/commands/rr/*.md               Sub-command files (4 files)
  ~/.claude/commands/rr.md                 Router file
EOF
  exit 0
fi

# --- Version ---
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-v" ]; then
  ver=$(grep -m1 '^version:' "$SKILL_SOURCE" 2>/dev/null | sed 's/^version: *//' || true)
  echo "rr v${ver:-unknown}"
  exit 0
fi

# --- Uninstall ---
if [ "${1:-}" = "--uninstall" ]; then
  info "Uninstalling rr..."
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
  if [ -f "${HOME}/.claude/commands/rr.md" ]; then
    rm -f "${HOME}/.claude/commands/rr.md"
    ok "Removed router: ~/.claude/commands/rr.md"
  fi
  ok "rr uninstalled"
  exit 0
fi

# --- Health check ---
if [ "${1:-}" = "--check" ]; then
  printf "\n${BOLD}rr installation health check${RESET}\n\n"
  issues=0

  # SKILL.md
  if [ -f "${SKILL_TARGET}/SKILL.md" ]; then
    ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
    ok "SKILL.md installed (v${ver})"
  else
    err "SKILL.md not found at ${SKILL_TARGET}/SKILL.md"
    issues=$((issues + 1))
  fi

  # Router
  if [ -f "${HOME}/.claude/commands/rr.md" ]; then
    ok "Router: ~/.claude/commands/rr.md"
  else
    err "Router not found: ~/.claude/commands/rr.md"
    issues=$((issues + 1))
  fi

  # Sub-commands
  if [ -d "$COMMANDS_TARGET" ]; then
    count=$(find "$COMMANDS_TARGET" -name "*.md" | wc -l | tr -d ' ')
    if [ "$count" -ge 6 ]; then
      ok "Sub-commands: ${count} files in ${COMMANDS_TARGET}"
    else
      warn "Sub-commands: only ${count}/6 files in ${COMMANDS_TARGET}"
      issues=$((issues + 1))
    fi
  else
    err "Sub-commands directory not found: ${COMMANDS_TARGET}"
    issues=$((issues + 1))
  fi

  # Orchestrator
  if [ -d "${SKILL_TARGET}/orchestrator" ]; then
    count=$(find "${SKILL_TARGET}/orchestrator" -name "*.sh" | wc -l | tr -d ' ')
    if [ "$count" -ge 7 ]; then
      ok "Orchestrator: ${count} scripts in ${SKILL_TARGET}/orchestrator"
    else
      warn "Orchestrator: only ${count}/7 scripts in ${SKILL_TARGET}/orchestrator"
      issues=$((issues + 1))
    fi
    if [ -f "${SKILL_TARGET}/orchestrator/sub-agent-system-prompt.txt" ]; then
      ok "Sub-agent prompt: present"
    else
      warn "Sub-agent prompt: missing"
      issues=$((issues + 1))
    fi
  else
    err "Orchestrator directory not found: ${SKILL_TARGET}/orchestrator"
    issues=$((issues + 1))
  fi

  # References
  if [ -d "${SKILL_TARGET}/references" ]; then
    count=$(find "${SKILL_TARGET}/references" -type f | wc -l | tr -d ' ')
    if [ "$count" -ge 16 ]; then
      ok "References: ${count} files in ${SKILL_TARGET}/references"
    else
      warn "References: only ${count}/16 files in ${SKILL_TARGET}/references"
      issues=$((issues + 1))
    fi
  else
    err "References directory not found: ${SKILL_TARGET}/references"
    issues=$((issues + 1))
  fi

  # Source repo marker
  if [ -f "${SKILL_TARGET}/.source-repo" ]; then
    repo=$(cat "${SKILL_TARGET}/.source-repo")
    ok "Source repo: ${repo}"
  else
    warn "Source repo marker not found (update subcommand won't work)"
    issues=$((issues + 1))
  fi

  # External tools
  for tool in curl jq; do
    if command -v "$tool" >/dev/null 2>&1; then
      ok "${tool}: $(which "$tool")"
    else
      warn "${tool}: not found (required for batch mode)"
      issues=$((issues + 1))
    fi
  done

  # Environment variables
  for var in ANTHROPIC_API_KEY JIRA_EMAIL JIRA_API_KEY; do
    if [ -n "${!var:-}" ]; then
      ok "${var}: set"
    else
      warn "${var}: not set (required for batch mode)"
    fi
  done

  if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
    ok "SLACK_WEBHOOK_URL: set"
  else
    info "SLACK_WEBHOOK_URL: not set (optional)"
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
[ -d "$ORCHESTRATOR_SOURCE" ] || die "orchestrator/ directory not found in ${SCRIPT_DIR}"
[ -d "$REFERENCES_SOURCE" ] || die "references/ directory not found in ${SCRIPT_DIR}"

# Check for existing install
if [ -f "${SKILL_TARGET}/SKILL.md" ] && ! "$FORCE"; then
  src_ver=$(grep -m1 '^version:' "$SKILL_SOURCE" 2>/dev/null | sed 's/^version: *//' || true)
  dst_ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
  if [ "$src_ver" = "$dst_ver" ]; then
    ok "rr v${dst_ver} already installed and up to date"
    ok "Use --force to reinstall"
    exit 0
  fi
  info "Upgrading rr: v${dst_ver} -> v${src_ver}"
fi

# Check for jq
if ! command -v jq >/dev/null 2>&1; then
  warn "jq not found — batch mode orchestrator requires jq"
  warn "Install with: brew install jq"
fi

info "Installing rr..."

# 1. Install SKILL.md
mkdir -p "$SKILL_TARGET"
cp "$SKILL_SOURCE" "${SKILL_TARGET}/SKILL.md"
ok "SKILL.md -> ${SKILL_TARGET}/SKILL.md"

# 2. Write source repo marker
echo "$SCRIPT_DIR" > "${SKILL_TARGET}/.source-repo"
ok "Source repo marker -> ${SKILL_TARGET}/.source-repo"

# 3. Install router command
mkdir -p "${HOME}/.claude/commands"
cat > "${HOME}/.claude/commands/rr.md" <<'ROUTER'
# rr — Risk Register Assessment Router

Parse the argument from: $ARGUMENTS

Route to the appropriate sub-skill based on the argument:

| Argument | Action |
|----------|--------|
| Matches `RR-\d+` (case-insensitive) | Run `/rr:review` with the key |
| `all` (with optional flags) | Run `/rr:all` |
| `status` | Run `/rr:status` |
| `fix` | Run `/rr:fix` |
| `help` | Run `/rr help` (the main skill) |
| `doctor` | Run `/rr doctor` (the main skill) |
| `version` | Run `/rr version` (the main skill) |
| `update` | Run `/rr update` (the main skill) |
| (empty) | Run `/rr help` (the main skill) |
| anything else | Show available commands |

Invoke the matching skill using the Skill tool.
ROUTER
ok "Router -> ~/.claude/commands/rr.md"

# 4. Install sub-commands
mkdir -p "$COMMANDS_TARGET"
count=0
for file in "${COMMANDS_SOURCE}"/*.md; do
  [ -f "$file" ] || continue
  name=$(basename "$file")
  cp "$file" "${COMMANDS_TARGET}/${name}"
  count=$((count + 1))
done
ok "Sub-commands: ${count} files -> ${COMMANDS_TARGET}/"

# 5. Install orchestrator scripts
mkdir -p "${SKILL_TARGET}/orchestrator"
orch_count=0
for file in "${ORCHESTRATOR_SOURCE}"/*; do
  [ -f "$file" ] || continue
  name=$(basename "$file")
  cp "$file" "${SKILL_TARGET}/orchestrator/${name}"
  # Make .sh files executable
  if [[ "$name" == *.sh ]]; then
    chmod +x "${SKILL_TARGET}/orchestrator/${name}"
  fi
  orch_count=$((orch_count + 1))
done
ok "Orchestrator: ${orch_count} files -> ${SKILL_TARGET}/orchestrator/"

# 6. Install reference files (recursive, preserving tree structure)
ref_count=0
while IFS= read -r -d '' file; do
  rel_path="${file#${REFERENCES_SOURCE}/}"
  target_dir="${SKILL_TARGET}/references/$(dirname "$rel_path")"
  mkdir -p "$target_dir"
  cp "$file" "${SKILL_TARGET}/references/${rel_path}"
  ref_count=$((ref_count + 1))
done < <(find "$REFERENCES_SOURCE" -type f -print0)
ok "References: ${ref_count} files -> ${SKILL_TARGET}/references/"

# 7. Verify SKILL.md copy
if ! cmp -s "${SKILL_SOURCE}" "${SKILL_TARGET}/SKILL.md"; then
  err "Verification failed — source and installed SKILL.md differ"
  die "Installation may be corrupt. Try again with --force"
fi
src_sha=$(shasum -a 256 "${SKILL_SOURCE}" | cut -d' ' -f1)
dst_sha=$(shasum -a 256 "${SKILL_TARGET}/SKILL.md" | cut -d' ' -f1)
if [ "$src_sha" != "$dst_sha" ]; then
  err "SHA256 mismatch after copy"
  die "Installation may be corrupt. Try again with --force"
fi

ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
echo ""
ok "rr v${ver} installed successfully"
echo ""
info "Files installed:"
printf "  ${DIM}%-55s${RESET} (main skill)\n" "${SKILL_TARGET}/SKILL.md"
printf "  ${DIM}%-55s${RESET} (router)\n" "${HOME}/.claude/commands/rr.md"
printf "  ${DIM}%-55s${RESET} (${count} sub-commands)\n" "${COMMANDS_TARGET}/"
printf "  ${DIM}%-55s${RESET} (${orch_count} orchestrator files)\n" "${SKILL_TARGET}/orchestrator/"
printf "  ${DIM}%-55s${RESET} (${ref_count} reference files)\n" "${SKILL_TARGET}/references/"
echo ""
info "Usage: /rr help"
