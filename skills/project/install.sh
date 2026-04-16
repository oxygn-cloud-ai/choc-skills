#!/usr/bin/env bash
set -euo pipefail

# Per-skill installer for project
# Installs SKILL.md to ~/.claude/skills/project/
# Installs sub-command .md files to ~/.claude/commands/project/
# Installs router to ~/.claude/commands/project.md
# Installs bin/ scripts to ~/.local/bin/
# Installs hooks/*.sh to ~/.claude/hooks/ and registers them in
# ~/.claude/settings.json hooks.PreToolUse (idempotent).

SKILL_NAME="project"
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
HOOKS_SOURCE="${SCRIPT_DIR}/hooks"
HOOKS_TARGET="${HOME}/.claude/hooks"
SETTINGS_FILE="${HOME}/.claude/settings.json"

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
# Removes ALL PreToolUse entries whose .hooks[].command equals the path.
# Used by --uninstall to de-register without touching unrelated hooks.
remove_hook_registration() {
  local cmd="$1"
  [ -f "$SETTINGS_FILE" ] || return 0
  local tmp; tmp=$(mktemp)
  jq --arg c "$cmd" \
    '.hooks.PreToolUse |= ((. // []) | map(select((.hooks // []) | all(.command != $c))))' \
    "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
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

# sha256_of <path> — print sha256 hex of a file (portable between macOS & Linux).
# Uses shasum if present (macOS default) else sha256sum (Linux default).
# Returns empty on missing file or missing tool.
sha256_of() {
  local p="$1"
  [ -f "$p" ] || return 0
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$p" 2>/dev/null | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$p" 2>/dev/null | awk '{print $1}'
  fi
}

# --- Help ---
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<EOF
${BOLD}project skill installer${RESET}

${BOLD}USAGE${RESET}
  ./install.sh              Install project (skill + sub-commands + hooks)
  ./install.sh --force      Install/overwrite without prompting
  ./install.sh --check      Verify installation health (parity + orphan + registration)
  ./install.sh --uninstall  Remove project completely (keeps hook files)
  ./install.sh --version    Show version
  ./install.sh --help       Show this help

${BOLD}INSTALLS TO${RESET}
  ~/.claude/skills/project/SKILL.md       Main skill file
  ~/.claude/commands/project.md           Router
  ~/.claude/commands/project/*.md         Sub-command files
  ~/.local/bin/project-*.sh               Launch/picker helpers
  ~/.claude/hooks/*.sh                    PreToolUse enforcement hooks
  ~/.claude/settings.json                 hooks.PreToolUse[] registrations

${BOLD}REQUIREMENTS${RESET}
  ~/.claude/MULTI_SESSION_ARCHITECTURE.md  (runtime reference)
  ~/.claude/PROJECT_STANDARDS.md           (runtime reference)
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
  [ -f "${HOME}/.claude/commands/project.md" ] && rm -f "${HOME}/.claude/commands/project.md" && ok "Removed router" || true
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

  if [ -f "${HOME}/.claude/commands/project.md" ]; then
    ok "Router: ~/.claude/commands/project.md"
  else
    err "Router not found"; issues=$((issues + 1))
  fi

  if [ -d "$COMMANDS_TARGET" ]; then
    count=$(find "$COMMANDS_TARGET" -name "*.md" | wc -l | tr -d ' ')
    ok "Sub-commands: ${count} files in ${COMMANDS_TARGET}"
  else
    err "Sub-commands not found"; issues=$((issues + 1))
  fi

  if [ -f "${HOME}/.claude/MULTI_SESSION_ARCHITECTURE.md" ]; then
    ok "Global architecture doc present"
  else
    err "${HOME}/.claude/MULTI_SESSION_ARCHITECTURE.md missing (required at runtime)"; issues=$((issues + 1))
  fi

  if [ -f "${HOME}/.claude/PROJECT_STANDARDS.md" ]; then
    ok "Global project standards present"
  else
    err "${HOME}/.claude/PROJECT_STANDARDS.md missing (required at runtime)"; issues=$((issues + 1))
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

  # Cave-inversion drift gate (CPT-58). The previous check only verified
  # presence. Three read-only verifications catch the drift failure mode:
  #  1. byte-parity: every source file is byte-identical to its install target
  #  2. orphan: no hook is registered in settings.json against one of OUR
  #     matchers unless a source backs it
  #  3. per-matcher registration: every (hook, matcher) pair emitted by
  #     hook_matcher_for() is present in settings.json hooks.PreToolUse[].
  # `fatal` distinguishes exit code 2 (tool failure / malformed settings) from
  # exit code 1 (drift/missing/orphan/not-registered).
  fatal=0

  # Probe hashing tool once so we can emit a single fatal error if missing.
  if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
    err "No sha256 tool available (need shasum or sha256sum) — cannot verify byte-parity"
    fatal=1
  fi

  # Probe settings.json: if present but malformed, that is a fatal precondition
  # for orphan + per-matcher checks (both use jq against this file).
  settings_readable=1
  if [ -f "$SETTINGS_FILE" ]; then
    if ! jq empty "$SETTINGS_FILE" >/dev/null 2>&1; then
      err "${SETTINGS_FILE} is not valid JSON — cannot audit hook registrations"
      fatal=1
      settings_readable=0
    fi
  fi

  # Byte-parity: sources → targets.
  # Each (source dir, target dir) pair is walked; shasum both sides; report
  # ok byte-identical / err DRIFT / err MISSING per file.
  check_parity_dir() {
    local src_dir="$1" tgt_dir="$2" label="$3"
    [ -d "$src_dir" ] || return 0
    local f name tgt src_hash tgt_hash
    for f in "$src_dir"/*; do
      [ -f "$f" ] || continue
      name=$(basename "$f")
      tgt="${tgt_dir}/${name}"
      if [ ! -f "$tgt" ]; then
        err "MISSING: ${label}/${name} (source exists, no install target at ${tgt} — run install.sh --force)"
        issues=$((issues + 1))
        continue
      fi
      src_hash=$(sha256_of "$f")
      tgt_hash=$(sha256_of "$tgt")
      if [ -z "$src_hash" ] || [ -z "$tgt_hash" ]; then
        err "Could not hash ${label}/${name} — sha256 tool unavailable"
        fatal=1
        continue
      fi
      if [ "$src_hash" = "$tgt_hash" ]; then
        ok "byte-identical: ${label}/${name}"
      else
        err "DRIFT: ${label}/${name} — installed copy at ${tgt} differs from source (run install.sh --force)"
        issues=$((issues + 1))
      fi
    done
  }
  check_parity_dir "$HOOKS_SOURCE"    "$HOOKS_TARGET"                  "hooks"
  check_parity_dir "$SCRIPT_DIR/bin"  "${HOME}/.local/bin"             "bin"
  check_parity_dir "$COMMANDS_SOURCE" "$COMMANDS_TARGET"               "commands"

  # Per-matcher registration: every (hook, matcher) pair must appear in
  # settings.json hooks.PreToolUse[] with the correct absolute command path.
  # Replaces the pre-v2.2.0 count-based check, which would have green-lit a
  # hook registered with only one of its required matchers.
  #
  # Also builds SKILL_MATCHERS for the orphan check below.
  SKILL_MATCHERS=""
  SKILL_HOOK_BASENAMES=""
  if [ -d "$HOOKS_SOURCE" ] && [ "$settings_readable" = "1" ]; then
    for source in "${HOOKS_SOURCE}"/*.sh; do
      [ -f "$source" ] || continue
      name=$(basename "$source")
      SKILL_HOOK_BASENAMES="${SKILL_HOOK_BASENAMES} ${name}"
      tgt="${HOOKS_TARGET}/${name}"
      matchers=$(hook_matcher_for "$name")
      if [ -z "$matchers" ]; then
        warn "Hook ${name} has no matcher mapping in hook_matcher_for() — skipping registration check"
        continue
      fi
      for m in $matchers; do
        SKILL_MATCHERS="${SKILL_MATCHERS} ${m}"
        reg_count=0
        if [ -f "$SETTINGS_FILE" ]; then
          reg_count=$(jq --arg m "$m" --arg c "$tgt" \
            '[.hooks.PreToolUse[]? | select(.matcher == $m) | .hooks[]? | select(.command == $c)] | length' \
            "$SETTINGS_FILE" 2>/dev/null)
          if [ -z "$reg_count" ]; then
            err "jq query failed against ${SETTINGS_FILE} for ${name}/${m}"
            fatal=1
            continue
          fi
        fi
        if [ "$reg_count" -gt 0 ]; then
          ok "registered: ${name} / ${m}"
        else
          err "NOT REGISTERED: hook ${name} missing PreToolUse entry for matcher '${m}' (run install.sh --force)"
          issues=$((issues + 1))
        fi
      done
    done
  fi

  # Orphan detection. An orphan is a hook path registered in settings.json
  # hooks.PreToolUse[] against one of OUR matchers but whose basename is not in
  # skills/project/hooks/. This catches the 2026-04-16 failure mode — a hook
  # shipped to ~/.claude/hooks/ without a backing source — which the previous
  # presence-only --check reported as healthy for ~2h.
  #
  # Scope: limited to command paths under ~/.claude/hooks/ whose matcher
  # intersects SKILL_MATCHERS. Other tools' hooks in the same shared directory
  # (GSD, etc.) stay out of scope when they use matchers we do not own.
  if [ "$settings_readable" = "1" ] && [ -f "$SETTINGS_FILE" ] && [ -n "$SKILL_MATCHERS" ]; then
    # Emit tab-separated (matcher, command) tuples for every PreToolUse entry.
    tuples=$(jq -r '
      .hooks.PreToolUse[]? |
      .matcher as $m |
      .hooks[]? |
      [$m, .command] | @tsv
    ' "$SETTINGS_FILE" 2>/dev/null)
    # Read line-by-line to handle tuples with spaces inside the command path.
    while IFS=$'\t' read -r m cmd; do
      [ -n "$m" ] || continue
      [ -n "$cmd" ] || continue
      # Only consider hooks living in the shared ~/.claude/hooks/ directory.
      case "$cmd" in
        "$HOOKS_TARGET"/*) : ;;
        *) continue ;;
      esac
      # Only consider matchers this skill owns.
      case " $SKILL_MATCHERS " in
        *" $m "*) : ;;
        *) continue ;;
      esac
      cmd_base=$(basename "$cmd")
      case " $SKILL_HOOK_BASENAMES " in
        *" $cmd_base "*)
          # In our sources — not an orphan; parity/per-matcher checks cover it.
          continue
          ;;
      esac
      err "ORPHAN: ${cmd} registered in ${SETTINGS_FILE} with matcher '${m}' (one of ours) but no source at ${HOOKS_SOURCE}/${cmd_base} — add source + update install.sh or remove the registration"
      issues=$((issues + 1))
    done <<< "$tuples"
  fi

  echo ""
  if [ "$fatal" -ne 0 ]; then
    printf "  ${RED}check aborted — tool/precondition failure${RESET}\n\n"
    exit 2
  fi
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
command -v jq >/dev/null 2>&1 || die "jq is required for hook registration in settings.json"

info "Installing project..."

# 1. Install SKILL.md
mkdir -p "$SKILL_TARGET"
cp "$SKILL_SOURCE" "${SKILL_TARGET}/SKILL.md"
ok "SKILL.md -> ${SKILL_TARGET}/SKILL.md"

# 2. Install router command
mkdir -p "${HOME}/.claude/commands"
cat > "${HOME}/.claude/commands/project.md" <<'ROUTER'
# project — Project Repository Administration Router

Parse the argument from: $ARGUMENTS

Route to the appropriate sub-command. Every subcommand is a colon-command file under `~/.claude/commands/project/` — there is no inline dispatch:

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
ok "Router -> ~/.claude/commands/project.md"

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

# 6. Install hooks + register each in ~/.claude/settings.json hooks.PreToolUse
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

# 7. Record source repo path (for /project update)
echo "$SCRIPT_DIR" > "${SKILL_TARGET}/.source-repo"
ok "Source repo marker -> ${SKILL_TARGET}/.source-repo"

# 8. Verify
ver=$(grep -m1 '^version:' "${SKILL_TARGET}/SKILL.md" 2>/dev/null | sed 's/^version: *//' || true)
echo ""
ok "project v${ver} installed successfully"
echo ""
info "Files installed:"
printf "  ${DIM}%-50s${RESET} (main skill)\n" "${SKILL_TARGET}/SKILL.md"
printf "  ${DIM}%-50s${RESET} (router)\n" "${HOME}/.claude/commands/project.md"
[ -d "$COMMANDS_TARGET" ] && printf "  ${DIM}%-50s${RESET} (sub-commands)\n" "${COMMANDS_TARGET}/"
[ -f "${BIN_TARGET}/project-picker.sh" ] && printf "  ${DIM}%-50s${RESET} (session picker)\n" "${BIN_TARGET}/project-picker.sh"
[ -f "${BIN_TARGET}/project-launch-session.sh" ] && printf "  ${DIM}%-50s${RESET} (launch helper)\n" "${BIN_TARGET}/project-launch-session.sh"
[ -d "$HOOKS_TARGET" ] && printf "  ${DIM}%-50s${RESET} (enforcement hooks)\n" "${HOOKS_TARGET}/"
echo ""
info "Usage: /project or /project help"
