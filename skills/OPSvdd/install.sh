#!/usr/bin/env bash
set -euo pipefail

# Per-skill installer for OPSvdd (Phase 0 — v1.0.0)
#
# Installs:
#   SKILL.md       -> ~/.claude/skills/OPSvdd/SKILL.md
#   references/**  -> ~/.claude/skills/OPSvdd/references/ (recursive, preserves tree)
#   .source-repo   -> ~/.claude/skills/OPSvdd/.source-repo (pointer for /OPSvdd update)
#   router         -> ~/.claude/commands/OPSvdd.md (auto-generated below)
#   commands/*.md  -> ~/.claude/commands/OPSvdd/*.md (help, doctor, version, update + assess/approval/duplicate stubs)
#
# Phase 0 has no bin/ directory (no domain scripts). Later phases add domain helpers
# under bin/; this installer grows step 5 to copy them when they appear.

SKILL_NAME="OPSvdd"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Colors ---
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
ROUTER_TARGET="${HOME}/.claude/commands/${SKILL_NAME}.md"
SKILL_SOURCE="${SCRIPT_DIR}/SKILL.md"
COMMANDS_SOURCE="${SCRIPT_DIR}/commands"
REFERENCES_SOURCE="${SCRIPT_DIR}/references"
BIN_SOURCE="${SCRIPT_DIR}/bin"  # optional — may not exist in Phase 0
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
${BOLD}OPSvdd skill installer${RESET}

${BOLD}USAGE${RESET}
  ./install.sh              Install OPSvdd (skill + router + subcommands + references)
  ./install.sh --force      Install/overwrite without prompting
  ./install.sh --check      Verify installation health
  ./install.sh --uninstall  Remove OPSvdd completely
  ./install.sh --version    Show version
  ./install.sh --help       Show this help

${BOLD}INSTALLS TO${RESET}
  ~/.claude/skills/OPSvdd/SKILL.md          Main skill file
  ~/.claude/skills/OPSvdd/references/       Reference tree (placeholders in v1.0.0)
  ~/.claude/skills/OPSvdd/.source-repo      Repo path marker (for /OPSvdd update)
  ~/.claude/commands/OPSvdd.md              Router file
  ~/.claude/commands/OPSvdd/*.md            Sub-command files

${BOLD}PHASE 0${RESET}
  v1.0.0 ships scaffolding only. Domain subcommands (assess, approval, duplicate)
  return "not yet implemented" stubs. Phase 1 (CPT-87.1) lands the tier framework;
  Phase 2 (CPT-87.2) lands the 9-step workflow + OPS publication; Phase 3 (CPT-87.3)
  lands the APRVL integration + override audit.
EOF
  exit 0
fi

# --- Version ---
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-v" ]; then
  ver=$(grep -m1 '^version:' "$SKILL_SOURCE" 2>/dev/null | sed 's/^version: *//' || true)
  echo "OPSvdd v${ver:-unknown}"
  exit 0
fi

# --- Uninstall ---
if [ "${1:-}" = "--uninstall" ]; then
  info "Uninstalling OPSvdd..."
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
  if [ -f "$ROUTER_TARGET" ]; then
    rm -f "$ROUTER_TARGET"
    ok "Removed router: ${ROUTER_TARGET}"
  fi
  ok "OPSvdd uninstalled"
  exit 0
fi

# --- Health check ---
if [ "${1:-}" = "--check" ]; then
  printf "\n${BOLD}OPSvdd installation health check${RESET}\n\n"
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
  if [ -f "$ROUTER_TARGET" ]; then
    ok "Router: ${ROUTER_TARGET}"
  else
    err "Router not found: ${ROUTER_TARGET}"
    issues=$((issues + 1))
  fi

  # Subcommands — Phase 0 requires at minimum help/doctor/version/update
  if [ -d "$COMMANDS_TARGET" ]; then
    count=$(find "$COMMANDS_TARGET" -name "*.md" -type f | wc -l | tr -d ' ')
    if [ "$count" -ge 4 ]; then
      ok "Sub-commands: ${count} files in ${COMMANDS_TARGET}"
    else
      warn "Sub-commands: only ${count}/4 files in ${COMMANDS_TARGET}"
      issues=$((issues + 1))
    fi
    for required in help doctor version update; do
      if [ ! -f "${COMMANDS_TARGET}/${required}.md" ]; then
        err "Required sub-command missing: ${required}.md"
        issues=$((issues + 1))
      fi
    done
  else
    err "Sub-commands directory not found: ${COMMANDS_TARGET}"
    issues=$((issues + 1))
  fi

  # References tree — directories must exist even if empty
  for subdir in jurisdictions regulatory regulatory/sg tiering schemas workflow; do
    if [ -d "${SKILL_TARGET}/references/${subdir}" ]; then
      ok "references/${subdir}: present"
    else
      err "references/${subdir}: missing"
      issues=$((issues + 1))
    fi
  done

  # Source repo marker
  if [ -f "${SKILL_TARGET}/.source-repo" ]; then
    repo=$(cat "${SKILL_TARGET}/.source-repo")
    ok "Source repo: ${repo}"
  else
    warn "Source repo marker not found (update subcommand won't work)"
    issues=$((issues + 1))
  fi

  # External tools — Phase 0 only cares about bash/shasum/git; jq becomes required in Phase 3
  for tool in bash shasum git; do
    if command -v "$tool" >/dev/null 2>&1; then
      ok "${tool}: $(command -v "$tool")"
    else
      err "${tool}: not found (required)"
      issues=$((issues + 1))
    fi
  done
  if command -v jq >/dev/null 2>&1; then
    ok "jq: $(command -v jq) (Phase 3 ready)"
  else
    warn "jq: not found (required for Phase 3 override hash; OK in Phase 0)"
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
[ -d "$COMMANDS_SOURCE" ] || die "commands/ directory not found in ${SCRIPT_DIR}"
[ -d "$REFERENCES_SOURCE" ] || die "references/ directory not found in ${SCRIPT_DIR}"

# Check for existing install
if [ -f "${SKILL_TARGET}/SKILL.md" ] && ! "$FORCE"; then
  src_ver=$(grep -m1 '^version:' "$SKILL_SOURCE" 2>/dev/null | sed 's/^version: *//' || true)
  dst_ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
  if [ "$src_ver" = "$dst_ver" ]; then
    ok "OPSvdd v${dst_ver} already installed and up to date"
    ok "Use --force to reinstall"
    exit 0
  fi
  info "Upgrading OPSvdd: v${dst_ver} -> v${src_ver}"
fi

info "Installing OPSvdd..."

# 1. Install SKILL.md
mkdir -p "$SKILL_TARGET"
cp "$SKILL_SOURCE" "${SKILL_TARGET}/SKILL.md"
ok "SKILL.md -> ${SKILL_TARGET}/SKILL.md"

# 2. Write source repo marker
echo "$SCRIPT_DIR" > "${SKILL_TARGET}/.source-repo"
ok "Source repo marker -> ${SKILL_TARGET}/.source-repo"

# 3. Install router command
mkdir -p "${HOME}/.claude/commands"
cat > "$ROUTER_TARGET" <<'ROUTER'
# OPSvdd — MAS-aligned Vendor Due Diligence Router

Parse the argument from: $ARGUMENTS

Route to the appropriate sub-skill based on the argument:

| Argument pattern | Action |
|------------------|--------|
| `assess <vendor-slug>` | Run `/OPSvdd:assess` passing the slug and any trailing flags |
| `approval <OPS-KEY>` | Run `/OPSvdd:approval` passing the Jira key |
| `duplicate <vendor-slug>` | Run `/OPSvdd:duplicate` passing the slug |
| `help`, `--help`, `-h`, (empty) | Run `/OPSvdd:help` |
| `doctor`, `--doctor`, `check` | Run `/OPSvdd:doctor` |
| `version`, `--version`, `-v` | Run `/OPSvdd:version` |
| `update`, `--update`, `upgrade` | Run `/OPSvdd:update` |
| anything else | Run `/OPSvdd:help` |

Invoke the matching sub-skill using the Skill tool.

Phase 0 (v1.0.0): `assess`, `approval`, `duplicate` emit "not yet implemented" and exit.
ROUTER
ok "Router -> ${ROUTER_TARGET}"

# 4. Install subcommands (clean stale files from previous version)
if [ -d "$COMMANDS_TARGET" ]; then
  rm -rf "$COMMANDS_TARGET"
fi
mkdir -p "$COMMANDS_TARGET"
cmd_count=0
for file in "${COMMANDS_SOURCE}"/*.md; do
  [ -f "$file" ] || continue
  name=$(basename "$file")
  cp "$file" "${COMMANDS_TARGET}/${name}"
  cmd_count=$((cmd_count + 1))
done
ok "Sub-commands: ${cmd_count} files -> ${COMMANDS_TARGET}/"

# 5. Install bin scripts (optional — Phase 0 may not have any)
bin_count=0
if [ -d "$BIN_SOURCE" ]; then
  rm -rf "${SKILL_TARGET:?}/bin"
  mkdir -p "${SKILL_TARGET:?}/bin"
  for file in "${BIN_SOURCE}"/*; do
    [ -f "$file" ] || continue
    name=$(basename "$file")
    cp "$file" "${SKILL_TARGET}/bin/${name}"
    if [[ "$name" == *.sh || "$name" == *.py ]]; then
      chmod +x "${SKILL_TARGET}/bin/${name}"
    fi
    bin_count=$((bin_count + 1))
  done
  ok "Bin scripts: ${bin_count} files -> ${SKILL_TARGET}/bin/"
else
  info "bin/ directory absent (Phase 0) — skipped"
fi

# 6. Install reference files (recursive, preserving tree structure)
ref_count=0
while IFS= read -r -d '' file; do
  rel_path="${file#"${REFERENCES_SOURCE}"/}"
  target_dir="${SKILL_TARGET}/references/$(dirname "$rel_path")"
  mkdir -p "$target_dir"
  cp "$file" "${SKILL_TARGET}/references/${rel_path}"
  ref_count=$((ref_count + 1))
done < <(find "$REFERENCES_SOURCE" -type f -print0)
ok "References: ${ref_count} files -> ${SKILL_TARGET}/references/"

# 7. Verify SKILL.md copy (SHA-256 parity)
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
ok "OPSvdd v${ver} installed successfully"
echo ""
info "Files installed:"
printf "  ${DIM}%-55s${RESET} (main skill)\n" "${SKILL_TARGET}/SKILL.md"
printf "  ${DIM}%-55s${RESET} (router)\n" "$ROUTER_TARGET"
printf "  ${DIM}%-55s${RESET} (${cmd_count} sub-commands)\n" "${COMMANDS_TARGET}/"
printf "  ${DIM}%-55s${RESET} (${ref_count} reference files)\n" "${SKILL_TARGET}/references/"
echo ""
info "Usage: /OPSvdd help"
