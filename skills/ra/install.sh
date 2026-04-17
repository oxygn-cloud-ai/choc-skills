#!/usr/bin/env bash
set -euo pipefail

# Per-skill installer for ra
# Installs SKILL.md to ~/.claude/skills/ra/
# Installs sub-command .md files to ~/.claude/commands/ra/
# Installs reference files to ~/.claude/skills/ra/references/
# chmod +x install.sh

SKILL_NAME="ra"
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
REFERENCES_SOURCE="${SCRIPT_DIR}/references"
FORCE=false

# --- Parse arguments (order-independent; CPT-76) ---
ACTION=""
while [ $# -gt 0 ]; do
  new_action=""
  case "$1" in
    --help|-h)        new_action="help" ;;
    --version|-v)     new_action="version" ;;
    --uninstall)      new_action="uninstall" ;;
    --check|--doctor) new_action="check" ;;
    --force|-f)       FORCE=true; shift; continue ;;
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
${BOLD}ra skill installer${RESET}

${BOLD}USAGE${RESET}
  ./install.sh              Install ra (skill + sub-commands + references)
  ./install.sh --force      Install/overwrite without prompting
  ./install.sh --check      Verify installation health
  ./install.sh --uninstall  Remove ra completely
  ./install.sh --version    Show version
  ./install.sh --help       Show this help

${BOLD}INSTALLS TO${RESET}
  ~/.claude/skills/ra/SKILL.md             Main skill file
  ~/.claude/skills/ra/.source-repo         Repo path marker (for /ra update)
  ~/.claude/skills/ra/references/          Schemas, workflow, context (16+ files)
  ~/.claude/commands/ra/*.md               Sub-command files (7 files)
  ~/.claude/commands/ra.md                 Router file
EOF
  exit 0
fi

# --- Version ---
if [ "$ACTION" = "version" ]; then
  ver=$(grep -m1 '^version:' "$SKILL_SOURCE" 2>/dev/null | sed 's/^version: *//' || true)
  echo "ra v${ver:-unknown}"
  exit 0
fi

# --- Uninstall ---
if [ "$ACTION" = "uninstall" ]; then
  info "Uninstalling ra..."
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
  if [ -f "${HOME}/.claude/commands/ra.md" ]; then
    rm -f "${HOME}/.claude/commands/ra.md"
    ok "Removed router: ~/.claude/commands/ra.md"
  fi
  ok "ra uninstalled"
  exit 0
fi

# --- Health check ---
if [ "$ACTION" = "check" ]; then
  printf "\n${BOLD}ra installation health check${RESET}\n\n"
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
  if [ -f "${HOME}/.claude/commands/ra.md" ]; then
    ok "Router: ~/.claude/commands/ra.md"
  else
    err "Router not found: ~/.claude/commands/ra.md"
    issues=$((issues + 1))
  fi

  # Sub-commands
  if [ -d "$COMMANDS_TARGET" ]; then
    count=$(find "$COMMANDS_TARGET" -name "*.md" | wc -l | tr -d ' ')
    if [ "$count" -ge 7 ]; then
      ok "Sub-commands: ${count} files in ${COMMANDS_TARGET}"
    else
      warn "Sub-commands: only ${count}/7 files in ${COMMANDS_TARGET}"
      issues=$((issues + 1))
    fi
  else
    err "Sub-commands directory not found: ${COMMANDS_TARGET}"
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

  # Workflow steps
  workflow_count=0
  for step in step-1-interview step-2-ingest step-3-assess step-4-adversarial step-5-discuss step-6-output; do
    if [ -f "${SKILL_TARGET}/references/workflow/${step}.md" ]; then
      workflow_count=$((workflow_count + 1))
    fi
  done
  if [ "$workflow_count" -eq 6 ]; then
    ok "Workflow steps: 6 files found"
  else
    warn "Workflow steps: only ${workflow_count}/6 files found"
    issues=$((issues + 1))
  fi

  # Source repo marker
  if [ -f "${SKILL_TARGET}/.source-repo" ]; then
    repo=$(< "${SKILL_TARGET}/.source-repo")
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
      warn "${tool}: not found (required for publish)"
      issues=$((issues + 1))
    fi
  done

  # Environment variables
  for var in JIRA_EMAIL JIRA_API_KEY; do
    if [ -n "${!var:-}" ]; then
      ok "${var}: set"
    else
      warn "${var}: not set (required for publish)"
    fi
  done

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
[ -d "$COMMANDS_SOURCE" ] || die "commands/ directory not found in ${SCRIPT_DIR}"

# Check for existing install
if [ -f "${SKILL_TARGET}/SKILL.md" ] && ! "$FORCE"; then
  src_ver=$(grep -m1 '^version:' "$SKILL_SOURCE" 2>/dev/null | sed 's/^version: *//' || true)
  dst_ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
  if [ "$src_ver" = "$dst_ver" ]; then
    ok "ra v${dst_ver} already installed and up to date"
    ok "Use --force to reinstall"
    exit 0
  fi
  info "Upgrading ra: v${dst_ver} -> v${src_ver}"
fi

# Check for jq
if ! command -v jq >/dev/null 2>&1; then
  warn "jq not found — publish subcommand requires jq"
  warn "Install with: brew install jq"
fi

info "Installing ra..."

# 1. Install SKILL.md
mkdir -p "$SKILL_TARGET"
cp "$SKILL_SOURCE" "${SKILL_TARGET}/SKILL.md"
ok "SKILL.md -> ${SKILL_TARGET}/SKILL.md"

# 2. Write source repo marker
echo "$SCRIPT_DIR" > "${SKILL_TARGET}/.source-repo"
ok "Source repo marker -> ${SKILL_TARGET}/.source-repo"

# 3. Install router command
mkdir -p "${HOME}/.claude/commands"
cat > "${HOME}/.claude/commands/ra.md" <<'ROUTER'
# ra — Risk Assessment Router

Parse the argument from: $ARGUMENTS

Route to the appropriate sub-skill:

| Argument | Action |
|----------|--------|
| `assess` | Run `/ra:assess` |
| `publish` (with optional flags) | Run `/ra:publish` passing flags |
| `status` | Run `/ra:status` |
| `help`, `--help`, `-h` | Run `/ra:help` |
| `doctor`, `--doctor`, `check` | Run `/ra:doctor` |
| `version`, `--version`, `-v` | Run `/ra:version` |
| `update`, `--update`, `upgrade` | Run `/ra:update` |
| (empty) | Run `/ra:help` |
| anything else | Run `/ra:help` |

Invoke the matching skill using the Skill tool.
ROUTER
ok "Router -> ~/.claude/commands/ra.md"

# 4. Install sub-commands (clean stale files from previous version)
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

# 5. Install reference files (recursive, preserving tree structure)
ref_count=0
if [ -d "$REFERENCES_SOURCE" ]; then
  while IFS= read -r -d '' file; do
    rel_path="${file#${REFERENCES_SOURCE}/}"
    target_dir="${SKILL_TARGET}/references/$(dirname "$rel_path")"
    mkdir -p "$target_dir"
    cp "$file" "${SKILL_TARGET}/references/${rel_path}"
    ref_count=$((ref_count + 1))
  done < <(find "$REFERENCES_SOURCE" -type f -print0)
  ok "References: ${ref_count} files -> ${SKILL_TARGET}/references/"
else
  warn "No references/ directory found — skipping reference files"
fi

# 6. Verify SKILL.md copy
# cmp -s provides byte-level equality check — SHA256 is redundant
if ! cmp -s "${SKILL_SOURCE}" "${SKILL_TARGET}/SKILL.md"; then
  err "Verification failed — source and installed SKILL.md differ"
  die "Installation may be corrupt. Try again with --force"
fi

ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
echo ""
ok "ra v${ver} installed successfully"
echo ""
info "Files installed:"
printf "  ${DIM}%-55s${RESET} (main skill)\n" "${SKILL_TARGET}/SKILL.md"
printf "  ${DIM}%-55s${RESET} (router)\n" "${HOME}/.claude/commands/ra.md"
printf "  ${DIM}%-55s${RESET} (${count} sub-commands)\n" "${COMMANDS_TARGET}/"
printf "  ${DIM}%-55s${RESET} (${ref_count} reference files)\n" "${SKILL_TARGET}/references/"
echo ""
info "Usage: /ra help"
