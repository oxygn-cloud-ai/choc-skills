#!/usr/bin/env bash
set -euo pipefail

VERSION="2.1.7"

# --- Bash version check ---
if [ "${BASH_VERSINFO[0]}" -lt 3 ] 2>/dev/null; then
  printf "Error: bash 3+ required (found %s). Upgrade bash and try again.\n" "$BASH_VERSION" >&2
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${REPO_DIR}/skills"
TARGET_BASE="${HOME}/.claude/skills"

# --- Colors (disabled if not a terminal) ---
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; RESET=''
fi

# --- Output helpers ---
info()  { printf "${CYAN}info${RESET}  %s\n" "$*"; }
ok()    { printf "${GREEN}  ok${RESET}  %s\n" "$*"; }
warn()  { printf "${YELLOW}warn${RESET}  %s\n" "$*" >&2; }
err()   { printf "${RED} err${RESET}  %s\n" "$*" >&2; }
die()   { err "$@"; exit 1; }

# --- Flags ---
FORCE=false
DRY_RUN=false
INTERACTIVE=true
[ -t 0 ] || INTERACTIVE=false  # piped/non-interactive

# --- Pipe detection ---
if [[ -z "${BASH_SOURCE[0]}" || "${BASH_SOURCE[0]}" == "/dev/stdin" || "${BASH_SOURCE[0]}" == "/dev/fd/"* || "${BASH_SOURCE[0]}" == "-" ]]; then
  die "Pipe install not supported. Clone the repo first:
  git clone https://github.com/oxygn-cloud-ai/choc-skills.git && cd choc-skills && ./install.sh"
fi

usage() {
  cat <<EOF
${BOLD}choc-skills installer${RESET} v${VERSION}

${BOLD}USAGE${RESET}
  ./install.sh                    Install all skills
  ./install.sh <name>             Install a specific skill
  ./install.sh --uninstall <name> Uninstall a skill
  ./install.sh --uninstall --all  Uninstall all skills
  ./install.sh --uninstall --orphans <name>
                                  Force-clean orphan router files when the
                                  skill dir is already absent (CPT-112
                                  recovery path; default leaves files alone
                                  to protect user-authored files of the same
                                  name — CPT-138)
  ./install.sh --update           Reinstall all (no prompts)
  ./install.sh --check            Verify installation health
  ./install.sh --list             List available skills
  ./install.sh --dry-run          Show what would happen without changing anything
  ./install.sh --changelog        Show changelog
  ./install.sh --version          Show version
  ./install.sh --help             Show this help

${BOLD}OPTIONS${RESET}
  -f, --force     Overwrite without prompting
  -n, --dry-run   Preview actions without making changes
  -q, --quiet     Suppress non-error output

${BOLD}EXAMPLES${RESET}
  ./install.sh chk1               Install the chk1 skill
  ./install.sh -f chk1            Install/overwrite without prompting
  ./install.sh --dry-run           Preview what would be installed
  ./install.sh --uninstall chk1   Remove chk1
  ./install.sh --check            Verify all installations are healthy

${BOLD}MANUAL INSTALL${RESET} (no clone needed — SKILL.md only, no sub-commands or routers)
  mkdir -p ~/.claude/skills/chk1
  curl -sL https://raw.githubusercontent.com/oxygn-cloud-ai/choc-skills/main/skills/chk1/SKILL.md \\
    -o ~/.claude/skills/chk1/SKILL.md
  # Note: Skills with sub-commands (chk1, chk2, rr) need the per-skill installer
  # for full functionality. Clone the repo and run: cd skills/<name> && ./install.sh
EOF
}

# --- Skill enumeration ---
list_skills() {
  local count=0
  printf "\n${BOLD}Available skills:${RESET}\n\n"
  for dir in "${SKILLS_DIR}"/*/; do
    [ -d "$dir" ] || continue
    local name
    name="$(basename "$dir")"
    [[ "$name" == _* ]] && continue
    [ -f "${dir}/SKILL.md" ] || continue
    local desc=""
    desc=$(grep -m1 '^description:' "${dir}/SKILL.md" 2>/dev/null | sed 's/^description: *//' | cut -c1-70)
    local installed=""
    if [ -f "${TARGET_BASE}/${name}/SKILL.md" ]; then
      installed="${GREEN}[installed]${RESET}"
    fi
    printf "  ${BOLD}%-14s${RESET} %-70s %b\n" "$name" "$desc" "$installed"
    count=$((count + 1))
  done
  echo ""
  if [ "$count" -eq 0 ]; then
    warn "No skills found in ${SKILLS_DIR}"
  else
    printf "  ${DIM}%d skill(s) available${RESET}\n\n" "$count"
  fi
}

# --- Confirm prompt (respects --force and non-interactive) ---
confirm() {
  local prompt="$1"
  "$FORCE" && return 0
  if ! "$INTERACTIVE"; then
    warn "Non-interactive mode: skipping (use --force to override)"
    return 1
  fi
  printf "%s [y/N] " "$prompt"
  local answer
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# --- Version from SKILL.md frontmatter ---
get_skill_version() {
  local skill_file="$1"
  [ -f "$skill_file" ] || return 1
  local ver
  ver=$(grep -m1 '^version:' "$skill_file" 2>/dev/null | sed 's/^version: *//' || true)
  echo "${ver:-unknown}"
}

# --- Skill name validation (prevent path traversal) ---
validate_name() {
  local name="$1"
  if [ -z "$name" ]; then
    die "Empty skill name"
  fi
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    die "Invalid skill name '${name}' — only letters, numbers, hyphens, and underscores allowed"
  fi
}

# --- Install a single skill ---
install_skill() {
  local name="$1"
  validate_name "$name"
  local source="${SKILLS_DIR}/${name}"
  local target="${TARGET_BASE}/${name}"

  # Validate source
  if [ ! -d "$source" ]; then
    err "Skill '${name}' not found in ${SKILLS_DIR}"
    info "Run ./install.sh --list to see available skills"
    return 1
  fi

  if [ ! -f "${source}/SKILL.md" ]; then
    die "Skill '${name}' is missing SKILL.md — broken skill definition"
  fi

  # Check if already installed
  if [ -f "${target}/SKILL.md" ]; then
    local src_ver dst_ver
    src_ver=$(get_skill_version "${source}/SKILL.md")
    dst_ver=$(get_skill_version "${target}/SKILL.md")
    if [ "$src_ver" = "$dst_ver" ] && ! "$FORCE"; then
      if "$DRY_RUN"; then
        info "[dry-run] '${name}' v${dst_ver} is already up to date — no action needed"
      else
        ok "'${name}' is already installed (v${dst_ver}) and up to date"
      fi
      return 0
    fi
    if [ "$src_ver" != "$dst_ver" ]; then
      info "'${name}' installed: v${dst_ver}, available: v${src_ver}"
    fi
    if ! confirm "Overwrite '${name}'?"; then
      warn "Skipped '${name}'"
      return 0
    fi
  fi

  # Dry-run mode
  if "$DRY_RUN"; then
    local src_ver
    src_ver=$(get_skill_version "${source}/SKILL.md")
    if [ -f "${target}/SKILL.md" ]; then
      local dst_ver
      dst_ver=$(get_skill_version "${target}/SKILL.md")
      info "[dry-run] Would upgrade '${name}' v${dst_ver} -> v${src_ver} in ${target}"
    else
      info "[dry-run] Would install '${name}' v${src_ver} to ${target}"
    fi
    return 0
  fi

  # Create target directory
  if ! mkdir -p "$target" 2>/dev/null; then
    die "Cannot create ${target} — check permissions on ~/.claude/"
  fi

  # Copy SKILL.md
  if ! cp "${source}/SKILL.md" "${target}/SKILL.md" 2>/dev/null; then
    die "Failed to copy SKILL.md to ${target} — check disk space and permissions"
  fi

  # Verify copy with byte-level comparison against the source we just
  # copied from. cmp -s short-circuits on the first differing byte and
  # is the correct tool here: a SHA256 hash would only add value if we
  # were verifying against an external reference (see CHECKSUMS.sha256),
  # not against the source file itself.
  if ! cmp -s "${source}/SKILL.md" "${target}/SKILL.md"; then
    err "Verification failed — source and installed SKILL.md differ"
    err "Source: ${source}/SKILL.md"
    err "Target: ${target}/SKILL.md"
    die "Installation may be corrupt. Try again with --force"
  fi

  local ver
  ver=$(get_skill_version "${target}/SKILL.md")
  ok "Installed '${name}' v${ver} -> ${target}"

  # Hint: if this skill has a per-skill installer, it provides full setup
  # (routers, sub-commands, references) beyond just SKILL.md
  if [ -f "${source}/install.sh" ] && [ -x "${source}/install.sh" ]; then
    info "For full setup (sub-commands, router): bash ${source}/install.sh --force"
  fi
}

# --- Uninstall a single skill ---
uninstall_skill() {
  local name="$1"
  validate_name "$name"
  local target="${TARGET_BASE}/${name}"
  local commands_base="${HOME}/.claude/commands"
  local router_md="${commands_base}/${name:?}.md"
  local commands_dir="${commands_base}/${name:?}"

  # CPT-138: the default uninstall only touches router files when the skill
  # directory is present — that's the only provenance the installer has that
  # those files are ours to delete. When the skill directory is absent, a
  # matching-named router.md or commands/<name>/ is most likely user-authored
  # (e.g. someone wrote their own /rr command that never came from this repo).
  # The CPT-112 recovery path (clean stale router files left by a pre-CPT-36
  # uninstall or manual rm -rf of skills/<name>/) is still reachable, but only
  # when the user explicitly opts in with `--orphans`.
  local skill_present=0
  local router_present=0
  [ -d "$target" ] && skill_present=1
  { [ -f "$router_md" ] || [ -d "$commands_dir" ]; } && router_present=1

  if [ "$skill_present" -eq 0 ]; then
    if [ "$router_present" -eq 1 ] && [ "${ORPHANS_FLAG:-false}" != "true" ]; then
      warn "Skill '${name}' is not installed (skills/${name}/ absent)."
      info "Found router files at ${router_md} or ${commands_dir} but not touching them —"
      info "they may be user-authored. To force-clean orphan router files, run:"
      info "  ./install.sh --uninstall --orphans ${name}"
      return 0
    fi
    if [ "$router_present" -eq 0 ]; then
      warn "Skill '${name}' is not installed"
      return 0
    fi
    # skill absent, router present, --orphans set — fall through to cleanup.
  fi

  local prompt
  if [ "$skill_present" -eq 1 ]; then
    prompt="Uninstall '${name}' from ${target}?"
  else
    prompt="Force-clean '${name}' orphan router files from ${commands_base}? (--orphans)"
  fi
  if ! confirm "$prompt"; then
    warn "Skipped '${name}'"
    return 0
  fi

  if [ "$skill_present" -eq 1 ]; then
    rm -rf "$target"
    if [ -d "$target" ]; then
      die "Failed to remove ${target} — check permissions"
    fi
  fi

  # Clean up router file and subcommand directory if they exist
  [ -f "$router_md" ] && rm -f "$router_md"
  [ -d "$commands_dir" ] && rm -rf "$commands_dir"

  ok "Uninstalled '${name}'"
}

# --- Health check ---
check_health() {
  local issues=0
  local checked=0

  printf "\n${BOLD}Installation health check${RESET}\n\n"

  # Check ~/.claude/skills exists
  if [ ! -d "$TARGET_BASE" ]; then
    warn "Skills directory does not exist: ${TARGET_BASE}"
    info "Run ./install.sh to create it and install skills"
    return 1
  fi

  # Check each available skill
  for dir in "${SKILLS_DIR}"/*/; do
    [ -d "$dir" ] || continue
    local name
    name="$(basename "$dir")"
    [[ "$name" == _* ]] && continue
    [ -f "${dir}/SKILL.md" ] || continue
    checked=$((checked + 1))

    local target="${TARGET_BASE}/${name}"

    # Installed?
    if [ ! -f "${target}/SKILL.md" ]; then
      warn "'${name}' is not installed"
      issues=$((issues + 1))
      continue
    fi

    # Version match?
    local src_ver dst_ver
    src_ver=$(get_skill_version "${dir}/SKILL.md")
    dst_ver=$(get_skill_version "${target}/SKILL.md")
    if [ "$src_ver" != "$dst_ver" ]; then
      warn "'${name}' is outdated: installed v${dst_ver}, available v${src_ver}"
      issues=$((issues + 1))
      continue
    fi

    # Content match?
    if ! cmp -s "${dir}/SKILL.md" "${target}/SKILL.md"; then
      warn "'${name}' content differs from repo (same version but modified)"
      issues=$((issues + 1))
      continue
    fi

    ok "'${name}' v${src_ver} SKILL.md verified (router/sub-commands/hooks NOT checked — run \"${REPO_DIR}/skills/${name}/install.sh\" --check for full health)"
  done

  # Check for orphaned skills (installed but not in repo)
  if [ -d "$TARGET_BASE" ]; then
    for dir in "${TARGET_BASE}"/*/; do
      [ -d "$dir" ] || continue
      local name
      name="$(basename "$dir")"
      if [ ! -d "${SKILLS_DIR}/${name}" ]; then
        info "'${name}' is installed but not in this repo (orphan or from elsewhere)"
      fi
    done
  fi

  echo ""
  if [ "$issues" -gt 0 ]; then
    warn "${issues} issue(s) found across ${checked} skill(s)"
    info "Run ./install.sh --update to fix outdated/missing skills"
    return 1
  else
    ok "All ${checked} skill(s) SKILL.md verified (scope: this checker verifies SKILL.md only; run \"${REPO_DIR}/skills/NAME/install.sh\" --check for router/sub-commands/hooks, replacing NAME with the skill name)"
    return 0
  fi
}

# --- Pre-flight checks ---
preflight() {
  # Verify skills directory exists
  if [ ! -d "$SKILLS_DIR" ]; then
    die "Skills directory not found at ${SKILLS_DIR}. Is this repo cloned correctly?"
  fi

  # Verify we can write to ~/.claude
  if [ ! -d "${HOME}/.claude" ]; then
    if ! mkdir -p "${HOME}/.claude" 2>/dev/null; then
      die "Cannot create ${HOME}/.claude — check home directory permissions"
    fi
  fi

  if [ ! -w "${HOME}/.claude" ]; then
    die "${HOME}/.claude is not writable — check permissions"
  fi
}

# --- Parse arguments ---
ACTION="install"
TARGETS=()
ALL_FLAG=false
QUIET=false
ORPHANS_FLAG=false

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)       usage; exit 0 ;;
    --version|-v)    echo "choc-skills installer v${VERSION}"; exit 0 ;;
    --list|-l)       list_skills; exit 0 ;;
    --check|--doctor) check_health; exit $? ;;
    --force|-f)      FORCE=true; shift ;;
    --dry-run|-n)    DRY_RUN=true; shift ;;
    --quiet|-q)      QUIET=true; shift ;;
    --uninstall)     ACTION="uninstall"; shift ;;
    --orphans)       ORPHANS_FLAG=true; shift ;;
    --update)        ACTION="install"; FORCE=true; shift ;;
    --all)           ALL_FLAG=true; shift ;;
    --changelog)     if [ -f "${REPO_DIR}/CHANGELOG.md" ]; then cat "${REPO_DIR}/CHANGELOG.md"; else err "No CHANGELOG.md found"; fi; exit 0 ;;
    -*)              die "Unknown option: $1 (try --help)" ;;
    *)               TARGETS+=("$1"); shift ;;
  esac
done

# --- Flag combination validation ---
# CPT-154: --orphans is an opt-in recovery path that only applies to the
# uninstall flow (it force-cleans orphan router files when the skill dir
# is already gone — CPT-138). Using it outside --uninstall is always a
# user mistake (typo, or `--orphans` on its own in a wrapper script) and
# the installer previously silently dropped the flag and proceeded to
# install every skill. Fail fast with a clear message instead, matching
# the CPT-123 "reject conflicting action flags at parse time" principle
# established for per-skill installers.
if [ "$ORPHANS_FLAG" = "true" ] && [ "$ACTION" != "uninstall" ]; then
  die "--orphans requires --uninstall (see ./install.sh --help for usage)"
fi

# Suppress non-error output in quiet mode
if "$QUIET"; then
  info()  { :; }
  ok()    { :; }
fi

# --- Execute ---
case "$ACTION" in
  install)
    preflight
    if [ ${#TARGETS[@]} -eq 0 ]; then
      # Install all
      count=0
      failed=0
      for dir in "${SKILLS_DIR}"/*/; do
        [ -d "$dir" ] || continue
        name="$(basename "$dir")"
        [[ "$name" == _* ]] && continue
        [ -f "${dir}/SKILL.md" ] || continue
        if install_skill "$name"; then
          count=$((count + 1))
        else
          failed=$((failed + 1))
        fi
      done
      echo ""
      ok "${count} skill(s) installed"
      if [ "$failed" -gt 0 ]; then
        warn "${failed} skill(s) failed"
      fi
    else
      for name in "${TARGETS[@]}"; do
        install_skill "$name"
      done
    fi
    ;;
  uninstall)
    if "$ALL_FLAG"; then
      if ! confirm "Uninstall ALL skills from ${TARGET_BASE}?"; then
        die "Aborted"
      fi
      _saved_force="$FORCE"
      FORCE=true
      for dir in "${TARGET_BASE}"/*/; do
        [ -d "$dir" ] || continue
        name="$(basename "$dir")"
        uninstall_skill "$name"
      done
      FORCE="$_saved_force"
      ok "All skills uninstalled"
    elif [ ${#TARGETS[@]} -eq 0 ]; then
      die "Specify a skill name: ./install.sh --uninstall <name> (or --all)"
    else
      for name in "${TARGETS[@]}"; do
        uninstall_skill "$name"
      done
    fi
    ;;
esac
