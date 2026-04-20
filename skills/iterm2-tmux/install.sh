#!/usr/bin/env bash
set -euo pipefail

# iterm2-tmux installer
# Installs tmux+iTerm2 tab orchestration scripts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/bin"
CONFIG_DIR="${HOME}/.config/iterm2-tmux"
CONFIG_FILE="${CONFIG_DIR}/config"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"
TMUX_CONF="${HOME}/.tmux.conf"
TMUX_RECOMMENDED="${SCRIPT_DIR}/tmux.conf.recommended"

SCRIPTS=(tmux-iterm-tabs.sh tmux-attach-session.sh tmux-sessions.sh tmux-picker.sh gen-session-bg.py)

# --- Colors ---
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; RESET=''
fi

info()  { printf "${CYAN}info${RESET}  %s\n" "$*"; }
ok()    { printf "${GREEN}  ok${RESET}  %s\n" "$*"; }
warn()  { printf "${YELLOW}warn${RESET}  %s\n" "$*" >&2; }
err()   { printf "${RED} err${RESET}  %s\n" "$*" >&2; }
die()   { err "$@"; exit 1; }

INTERACTIVE=true
[ -t 0 ] || INTERACTIVE=false
MODE="link"
FORCE=false

# --- Usage ---
usage() {
  cat <<EOF
${BOLD}iterm2-tmux installer${RESET}

${BOLD}USAGE${RESET}
  ./install.sh              Interactive install (default: symlink)
  ./install.sh --copy       Install by copying scripts
  ./install.sh --link       Install by symlinking (default)
  ./install.sh --check      Verify installation health
  ./install.sh --uninstall  Remove installed scripts
  ./install.sh --help       Show this help

${BOLD}OPTIONS${RESET}
  -f, --force     Skip confirmation prompts
  INSTALL_DIR=... Override install directory (default: ~/.local/bin)

${BOLD}EXAMPLES${RESET}
  ./install.sh                          Interactive install with symlinks
  ./install.sh --copy                   Copy scripts instead of symlinking
  INSTALL_DIR=~/bin ./install.sh        Install to ~/bin
  ./install.sh --check                  Verify everything is set up correctly
EOF
}

# --- Confirm ---
confirm() {
  local prompt="$1"
  "$FORCE" && return 0
  if ! "$INTERACTIVE"; then
    warn "Non-interactive: skipping (use --force to override)"
    return 1
  fi
  printf "${GREEN}?${RESET} ${BOLD}%s${RESET} ${DIM}(y/N)${RESET}${BOLD}:${RESET} " "$prompt"
  local answer
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# --- Prompt with default ---
prompt_with_default() {
  local prompt="$1" default="$2"
  if ! "$INTERACTIVE"; then
    REPLY="$default"
    return
  fi
  printf "${GREEN}?${RESET} ${BOLD}%s${RESET} ${DIM}(%s)${RESET}${BOLD}:${RESET} " "$prompt" "$default"
  local answer
  read -r answer
  REPLY="${answer:-$default}"
}

# --- Health check ---
check_health() {
  local issues=0

  printf "\n${BOLD}iterm2-tmux health check${RESET}\n\n"

  # Check config
  if [ -f "$CONFIG_FILE" ]; then
    ok "Config file exists: ${CONFIG_FILE}"
    local repos_dir
    repos_dir=$(grep '^TMUX_REPOS_DIR=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
    if [ -n "$repos_dir" ]; then
      if [ -d "$repos_dir" ]; then
        ok "Sessions directory exists: ${repos_dir}"
      else
        warn "Sessions directory missing: ${repos_dir}"
        issues=$((issues + 1))
      fi
    fi
  else
    warn "Config file missing: ${CONFIG_FILE}"
    issues=$((issues + 1))
  fi

  # Check tmux.conf
  if [ -f "$TMUX_CONF" ]; then
    if grep -q 'set-option.*set-titles.*off' "$TMUX_CONF" 2>/dev/null && \
       grep -q 'set-option.*allow-rename.*off' "$TMUX_CONF" 2>/dev/null; then
      ok "tmux.conf has required settings"
    else
      warn "tmux.conf missing required settings (set-titles off, allow-rename off)"
      issues=$((issues + 1))
    fi
    if grep -Eq '^[[:space:]]*bind-key.*(project-picker|tmux-picker)\.sh' "$TMUX_CONF" 2>/dev/null; then
      ok "tmux.conf has picker keybind (Prefix+P)"
    else
      warn "tmux.conf missing picker keybind — Blink/iOS role-switching will fall back to raw Ctrl-b s"
      issues=$((issues + 1))
    fi
  else
    warn "File ~/.tmux.conf does not exist"
    issues=$((issues + 1))
  fi

  # Check installed scripts
  local install_dir="$INSTALL_DIR"
  if [ -f "$CONFIG_FILE" ]; then
    local cfg_dir
    cfg_dir=$(grep '^INSTALL_DIR=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
    [ -n "$cfg_dir" ] && install_dir="$cfg_dir"
  fi

  for script in "${SCRIPTS[@]}"; do
    local target="${install_dir}/${script}"
    if [ -f "$target" ] || [ -L "$target" ]; then
      ok "${script} installed at ${target}"
    else
      warn "${script} not found at ${target}"
      issues=$((issues + 1))
    fi
  done

  # Check dependencies
  if command -v tmux &>/dev/null; then
    ok "tmux found: $(tmux -V)"
  else
    warn "tmux not found in PATH"
    issues=$((issues + 1))
  fi

  if command -v python3 &>/dev/null; then
    if python3 -c "import PIL" 2>/dev/null; then
      ok "Python 3 + Pillow available (background images enabled)"
    else
      info "Python 3 found but Pillow not installed (background images disabled)"
    fi
  else
    info "Python 3 not found (background images disabled)"
  fi

  # Check auto-startup
  if [ -f "$HOME/.zshrc" ] && grep -qF "# --- iterm2-tmux auto-start" "$HOME/.zshrc"; then
    ok "Auto-startup configured in ~/.zshrc"
  else
    info "Auto-startup not configured (manual launch only)"
  fi

  # Check iTerm2 startup behaviour
  local live_plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
  if [ -f "$live_plist" ]; then
    local open_no_win
    open_no_win=$(/usr/libexec/PlistBuddy -c "Print :OpenNoWindowsAtStartup" "$live_plist" 2>/dev/null || echo "unknown")
    if [ "$open_no_win" = "true" ]; then
      warn "iTerm2 opens no windows at startup — auto-start will not trigger"
      issues=$((issues + 1))
    elif [ "$open_no_win" = "false" ]; then
      ok "iTerm2 opens a window at startup"
    fi
  fi

  echo ""
  if [ "$issues" -gt 0 ]; then
    warn "${issues} issue(s) found"
    return 1
  else
    ok "All checks passed"
    return 0
  fi
}

# --- Parse arguments ---
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)       usage; exit 0 ;;
    --check|--doctor) check_health; exit $? ;;
    --uninstall)     exec "${SCRIPT_DIR}/uninstall.sh"; ;;
    --copy)          MODE="copy"; shift ;;
    --link)          MODE="link"; shift ;;
    --force|-f)      FORCE=true; shift ;;
    -*)              die "Unknown option: $1 (try --help)" ;;
    *)               die "Unexpected argument: $1 (try --help)" ;;
  esac
done

# --- Platform check ---
if [ "$(uname -s)" != "Darwin" ]; then
  die "Requires iTerm2 on macOS!"
fi

# --- Preflight ---
if [ ! -d "$BIN_DIR" ]; then
  die "Script bin directory not found: ${BIN_DIR}"
fi

for script in "${SCRIPTS[@]}"; do
  if [ ! -f "${BIN_DIR}/${script}" ]; then
    die "Missing script: ${BIN_DIR}/${script}"
  fi
done

# --- Step 1: Ask for sessions directory ---
printf "\n${BOLD}iterm2-tmux setup${RESET}\n"
printf "${DIM}Answer each question below. Press Enter to accept the default shown in brackets.${RESET}\n\n"

default_repos="$HOME/Repos"
if [ -f "$CONFIG_FILE" ]; then
  existing=$(grep '^TMUX_REPOS_DIR=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
  [ -n "$existing" ] && default_repos="$existing"
fi

prompt_with_default "Directory containing subdirectories for tmux sessions" "$default_repos"
repos_dir="$REPLY"

# Expand ~
repos_dir="${repos_dir/#\~/$HOME}"

if [ ! -d "$repos_dir" ]; then
  if confirm "Directory '${repos_dir}' does not exist. Create it?"; then
    mkdir -p "$repos_dir"
    ok "Created ${repos_dir}"
  else
    warn "Proceeding without creating directory — scripts will fail until it exists"
  fi
fi

# Write config
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" <<EOF
# iterm2-tmux configuration (generated by install.sh)
TMUX_REPOS_DIR="${repos_dir}"
INSTALL_DIR="${INSTALL_DIR}"
EOF
ok "Saved config to ${CONFIG_FILE}"

# --- Step 2: Install tmux.conf ---
printf "\n${BOLD}tmux configuration${RESET}\n\n"

needs_set_titles=true
needs_allow_rename=true
needs_picker_bind=true

if [ -f "$TMUX_CONF" ]; then
  grep -q 'set-option.*set-titles.*off' "$TMUX_CONF" 2>/dev/null && needs_set_titles=false
  grep -q 'set-option.*allow-rename.*off' "$TMUX_CONF" 2>/dev/null && needs_allow_rename=false
  grep -Eq '^[[:space:]]*bind-key.*(project-picker|tmux-picker)\.sh' "$TMUX_CONF" 2>/dev/null && needs_picker_bind=false
fi

if "$needs_set_titles" || "$needs_allow_rename" || "$needs_picker_bind"; then
  if [ -f "$TMUX_CONF" ]; then
    info "Appending iterm2-tmux settings to ${TMUX_CONF}"
    echo "" >> "$TMUX_CONF"
    if "$needs_set_titles" || "$needs_allow_rename"; then
      echo "# iterm2-tmux: required settings for tab title persistence" >> "$TMUX_CONF"
      "$needs_set_titles" && echo "set-option -g set-titles off" >> "$TMUX_CONF"
      "$needs_allow_rename" && echo "set-option -g allow-rename off" >> "$TMUX_CONF"
    fi
    if "$needs_picker_bind"; then
      echo "# iterm2-tmux: picker popup (primary role-switcher on Blink/iOS)." >> "$TMUX_CONF"
      echo "# Prefers project-picker.sh (project skill) when installed; falls back to iterm2-tmux's own tmux-picker.sh." >> "$TMUX_CONF"
      echo 'bind-key P display-popup -E -w 60 -h 20 "if [ -x ~/.local/bin/project-picker.sh ]; then ~/.local/bin/project-picker.sh; else ~/.local/bin/tmux-picker.sh; fi"' >> "$TMUX_CONF"
    fi
  else
    info "Creating ${TMUX_CONF} with required settings"
    cp "$TMUX_RECOMMENDED" "$TMUX_CONF"
  fi
  ok "tmux configuration updated"
else
  ok "tmux.conf already has required settings"
fi

# --- Step 3: Install scripts ---
printf "\n${BOLD}Installing scripts${RESET}\n\n"

mkdir -p "$INSTALL_DIR"
mkdir -p "$HOME/.local/share/iterm2-tmux/backgrounds"
ok "Backgrounds directory: ~/.local/share/iterm2-tmux/backgrounds/"

for script in "${SCRIPTS[@]}"; do
  source_path="${BIN_DIR}/${script}"
  target_path="${INSTALL_DIR}/${script}"

  # Remove existing if present
  if [ -f "$target_path" ] || [ -L "$target_path" ]; then
    rm "$target_path"
  fi

  if [ "$MODE" = "link" ]; then
    ln -s "$source_path" "$target_path"
    ok "Linked ${script} -> ${target_path}"
  else
    cp "$source_path" "$target_path"
    chmod +x "$target_path"
    ok "Copied ${script} -> ${target_path}"
  fi
done

# --- Step 5: Auto-startup on iTerm2 open ---
printf "\n${BOLD}Auto-startup${RESET}\n\n"

ZSHRC="${HOME}/.zshrc"
AUTOSTART_MARKER="# --- iterm2-tmux auto-start"

already_installed=false
if [ -f "$ZSHRC" ] && grep -qF "$AUTOSTART_MARKER" "$ZSHRC"; then
  already_installed=true
fi

if "$already_installed"; then
  ok "Auto-startup already configured in ${ZSHRC}"
else
  if confirm "Auto-start tmux tabs when iTerm2 opens? (adds snippet to ~/.zshrc)"; then
    touch "$ZSHRC"

    cat >> "$ZSHRC" <<AUTOSTART_BLOCK

# --- iterm2-tmux auto-start (managed by install.sh — do not edit) ---
if [[ "\$TERM_PROGRAM" == "iTerm.app" && -z "\$TMUX" ]]; then
  _itmlk="/tmp/.iterm2-tmux-autostart"
  [[ -d "\$_itmlk" ]] && (( \$(date +%s) - \$(/usr/bin/stat -f%m "\$_itmlk") > 15 )) && rm -rf "\$_itmlk"
  if mkdir "\$_itmlk" 2>/dev/null; then
    "${INSTALL_DIR}/tmux-iterm-tabs.sh" >/dev/null 2>&1 || true
  fi
  unset _itmlk
fi
# --- end iterm2-tmux auto-start ---
AUTOSTART_BLOCK

    ok "Added auto-startup snippet to ${ZSHRC}"

    # Ensure iTerm2 opens a window on launch (required for auto-start)
    live_plist="${HOME}/Library/Preferences/com.googlecode.iterm2.plist"
    if [ -f "$live_plist" ]; then
      open_no_win=$(/usr/libexec/PlistBuddy -c "Print :OpenNoWindowsAtStartup" "$live_plist" 2>/dev/null || echo "unknown")
      if [ "$open_no_win" = "true" ]; then
        /usr/libexec/PlistBuddy -c "Set :OpenNoWindowsAtStartup false" "$live_plist" 2>/dev/null
        ok "Configured iTerm2 to open a window at startup"
      fi
    fi

    info "tmux tabs will open automatically when iTerm2 launches"
  else
    info "Skipped auto-startup — run tmux-iterm-tabs.sh manually"
  fi
fi

# --- Summary ---
printf "\n${BOLD}Setup complete${RESET}\n\n"

ok "Sessions directory: ${repos_dir}"
ok "Scripts installed to: ${INSTALL_DIR}"
ok "Config saved to: ${CONFIG_FILE}"

# Check if INSTALL_DIR is in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  echo ""
  warn "${INSTALL_DIR} is not in your PATH"
  info "Add this to your shell profile (~/.zshrc or ~/.bashrc):"
  echo ""
  printf "  ${DIM}export PATH=\"%s:\$PATH\"${RESET}\n" "$INSTALL_DIR"
  echo ""
fi

echo ""
info "Usage:"
printf "  ${BOLD}tmux-iterm-tabs.sh${RESET}   Open iTerm2 tabs for all tmux sessions\n"
printf "  ${BOLD}tmux-sessions.sh${RESET}     Create tmux sessions from directories\n"
printf "  ${BOLD}tmux-picker.sh${RESET}       Interactive session picker\n"
echo ""
