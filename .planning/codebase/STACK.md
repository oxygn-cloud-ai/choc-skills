# Technology Stack

**Analysis Date:** 2026-03-31

## Languages

**Primary:**
- Bash 4+ - Core scripting, installation, and tool orchestration
- Python 3 - Optional background image generation for iTerm2

**Secondary:**
- YAML - Skill metadata (frontmatter in SKILL.md files)
- AppleScript - iTerm2 tab control (via bash AppleScript escapes)
- Markdown - Documentation and skill definitions

## Runtime

**Environment:**
- Bash 4+ (installed by default on macOS, Linux, and WSL)
- Python 3 (optional, only for iTerm2 background image generation)
- tmux (required for iterm2-tmux tool)
- iTerm2 (required for iterm2-tmux tool; macOS only)

**Package Manager:**
- Homebrew (macOS package manager used in scripts and documentation)
- pip3 (for optional Python dependencies: `pip3 install Pillow`)
- None for primary skills (bash-based)

## Frameworks

**Skill Framework:**
- Claude Code Skills Framework - Custom YAML/Markdown-based system for slash commands
  - Location: Defined in `install.sh` and README.md
  - SKILL.md format: YAML frontmatter + Markdown instructions
  - Discovery: Automatic discovery by Claude Code from `~/.claude/skills/`

**Orchestration:**
- tmux - Terminal multiplexer for session management
  - Version: Any current version supporting `set-option`, `set-titles`, `allow-rename`
  - Config location: `~/.tmux.conf`
  - Required settings: `set-option -g set-titles off` and `set-option -g allow-rename off`

**UI/Desktop Integration:**
- iTerm2 AppleScript API - Tab creation and control (via escape sequences)
  - Version: Any version supporting iTerm2 proprietary escape sequences
  - Requires: macOS with iTerm2 installed

## Key Dependencies

**Critical:**
- Bash core utilities (`test`, `read`, `printf`, etc.) - All scripts depend on these
- git - Required by most skills for repository analysis (`git log`, `git diff`, `git status`)
  - Usage: chk1 skill performs git-based code audits
  - Required for environment checks and commit history analysis
- tmux - Required for iterm2-tmux tool
  - Required settings: `start-server`, `has-session`, `new-session`, `send-keys`, `attach`
  - Version check: Scripts use `tmux -V` for diagnostics

**Optional (Image Generation):**
- Pillow (PIL) - Python image library for background watermark generation
  - Package: `pip3 install Pillow`
  - Usage: `gen-session-bg.py` generates 1920x1080 PNG images with watermarks
  - Install: Only if user chooses to enable background images
  - System fonts used: Menlo, Monaco (with fallback to default)

**Build/Dev:**
- No build system required
- No package.json, Cargo.toml, or equivalent
- Scripts are shell and Python files installed as-is via `install.sh`

## Configuration

**Environment:**
- Configuration directory: `~/.config/iterm2-tmux/config` (for iterm2-tmux tool)
- Configuration sourced by: `tmux-sessions.sh`, `tmux-iterm-tabs.sh`, and related scripts
- Key config variables:
  - `TMUX_REPOS_DIR` - Directory containing subdirectories for tmux sessions (default: `~/Repos`)
  - `INSTALL_DIR` - Where scripts are installed (default: `~/.local/bin`)
  - `TMUX_SESSIONS_SCRIPT` - Path to tmux-sessions.sh (auto-detected)

**tmux Configuration:**
- File: `~/.tmux.conf`
- Required settings added by installer:
  - `set-option -g set-titles off` - Prevents tmux from overwriting tab titles
  - `set-option -g allow-rename off` - Prevents automatic tab renaming

**Shell Profile Configuration (Optional):**
- File: `~/.zshrc` or equivalent
- Auto-start snippet: Added by installer to run `tmux-iterm-tabs.sh` on iTerm2 launch
- Features:
  - Detects iTerm2 (skips in VS Code terminal, SSH, other terminals)
  - Uses lockfile guard to prevent duplicate tab creation
  - Runs in background to avoid blocking shell init

**Claude Code Integration:**
- Installation location: `~/.claude/skills/<skill-name>/SKILL.md`
- Discovery: Automatic via Claude Code's skill discovery mechanism
- SKILL.md format: YAML frontmatter defining name, version, description, allowed tools

## Platform Requirements

**Development:**
- macOS, Linux, or WSL on Windows (bash and basic shell tools)
- git (for cloning repository and using chk1 skill)
- curl (for manual install method without cloning)

**iterm2-tmux Tool:**
- macOS only (uses AppleScript for iTerm2 tab control)
- Requires: iTerm2 (installed via Homebrew: `brew install --cask iterm2`)
- Requires: tmux (installed via Homebrew: `brew install tmux`)
- Optional: Python 3 + Pillow for background image generation

**Claude Code Skills:**
- Claude Code installed and working
- Works on any platform where Claude Code runs (platform-agnostic)

## Distribution & Installation

**Repository:**
- GitHub: https://github.com/oxygn-cloud-ai/claude-skills.git
- License: MIT

**Installation Methods:**
1. Clone and run root installer: `git clone ... && cd claude-skills && ./install.sh`
2. Selective installation: `./install.sh <skill-name>`
3. Manual download: `curl -sL https://raw.githubusercontent.com/oxygn-cloud-ai/claude-skills/main/skills/chk1/SKILL.md`
4. Per-tool installers: Each standalone tool has its own `install.sh`

**Uninstallation:**
- Root installer: `./install.sh --uninstall <name>` or `./install.sh --uninstall --all`
- Per-tool: `./uninstall.sh` in tool directory (e.g., `skills/iterm2-tmux/uninstall.sh`)

---

*Stack analysis: 2026-03-31*
