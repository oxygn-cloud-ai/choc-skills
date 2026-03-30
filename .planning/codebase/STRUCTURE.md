# Codebase Structure

**Analysis Date:** 2026-03-31

## Directory Layout

```
claude-skills/
├── README.md                   # Project overview, installation, skill listing
├── LICENSE                     # MIT license
├── install.sh                  # Root installer (orchestrates all skill installations)
├── .gitignore                  # Git ignore rules
├── .planning/
│   └── codebase/              # GSD codebase mapping outputs
├── _template/                  # Template for creating new skills
│   ├── SKILL.md               # Skill definition template
│   └── README.md              # Documentation template
└── skills/                     # All skills and standalone tools live here
    ├── chk1/                  # Claude Code skill: Adversarial Implementation Audit
    │   ├── SKILL.md           # Skill definition with instructions
    │   ├── README.md          # User documentation
    │   └── install.sh         # Per-skill installer (delegates to root)
    └── iterm2-tmux/           # Standalone tool: iTerm2 + tmux orchestration
        ├── install.sh         # Tool installer (custom logic, no SKILL.md)
        ├── uninstall.sh       # Tool uninstaller
        ├── README.md          # Tool documentation
        ├── tmux.conf.recommended # Recommended tmux config settings
        ├── iterm2/
        │   └── com.googlecode.iterm2.plist # Pre-configured iTerm2 preferences
        └── bin/               # Executable scripts
            ├── tmux-iterm-tabs.sh      # Main orchestrator for tab creation
            ├── tmux-sessions.sh        # Creates tmux sessions from directories
            ├── tmux-attach-session.sh  # Attaches to session, sets colors/title
            ├── tmux-picker.sh          # Interactive session picker (SSH use)
            └── gen-session-bg.py       # Generates watermark background images
```

## Directory Purposes

**Project Root:**
- Purpose: Central location for installation, licensing, and overall project documentation
- Contains: Installer, README, git configuration
- Key files: `./README.md` (main entry point), `./install.sh` (skill distribution)

**_template/**
- Purpose: Skeleton for creating new Claude Code skills
- Contains: Example SKILL.md with frontmatter format and subcommand patterns, example README.md
- Key files: `_template/SKILL.md`, `_template/README.md`

**skills/**
- Purpose: Container for all skills and standalone tools
- Contains: Subdirectories for each skill/tool
- Key files: Per-skill SKILL.md files discovered by Claude Code at `~/.claude/skills/`

**skills/chk1/**
- Purpose: Claude Code skill for adversarial implementation audits
- Contains: Skill definition, user documentation, installer
- Key files: `SKILL.md` (declares metadata and audit instructions), `README.md` (usage guide)
- Installed to: `~/.claude/skills/chk1/SKILL.md` (discovered by Claude Code)

**skills/iterm2-tmux/**
- Purpose: Standalone tool for macOS iTerm2 + tmux tab orchestration
- Contains: Installation scripts, shell utilities, Python image generator, iTerm2 config
- Key files: `install.sh` (custom installer), `README.md` (installation and configuration guide)
- Installed to: `~/.local/bin/` (scripts), `~/.config/iterm2-tmux/config` (configuration)

**skills/iterm2-tmux/bin/**
- Purpose: Executable utilities for iTerm2 + tmux integration
- Contains: Shell scripts (Bash) and Python utilities
- Key files:
  - `tmux-iterm-tabs.sh`: Main orchestrator; calls tmux-sessions.sh and AppleScript
  - `tmux-sessions.sh`: Creates one tmux session per subdirectory in TMUX_REPOS_DIR
  - `tmux-attach-session.sh`: Sets tab color, title, background, then attaches to session
  - `tmux-picker.sh`: Interactive session selector for SSH/remote use
  - `gen-session-bg.py`: Generates watermark background PNG images

**skills/iterm2-tmux/iterm2/**
- Purpose: Pre-configured iTerm2 application settings
- Contains: iTerm2 preferences plist file
- Key files: `com.googlecode.iterm2.plist` (can be imported during installation)

## Key File Locations

**Entry Points:**
- `./install.sh`: Root installer; entry point for all skill installations
- `/[skill-name]`: Slash command invocation (not a file; discovered by Claude Code from `~/.claude/skills/[skill-name]/SKILL.md`)
- `~/.zshrc`: Auto-startup entry point for iterm2-tmux (shell initialization snippet added during install)

**Configuration:**
- `./skills/chk1/SKILL.md`: Skill metadata and audit instructions (YAML + Markdown)
- `./skills/iterm2-tmux/README.md`: Installation and configuration guide
- `~/.config/iterm2-tmux/config`: Runtime configuration for iterm2-tmux (created during install)
- `~/.tmux.conf`: tmux configuration (installer adds required settings)

**Core Logic:**
- `./skills/chk1/SKILL.md`: Complete audit logic (8 audit phases, pre-flight checks, scope detection)
- `./skills/iterm2-tmux/bin/tmux-iterm-tabs.sh`: Orchestration logic for tab creation
- `./skills/iterm2-tmux/bin/tmux-sessions.sh`: Session creation from directory structure
- `./skills/iterm2-tmux/bin/gen-session-bg.py`: Background image generation with watermarks

**Testing:**
- No automated tests; verification via `./install.sh --check` (health checks skill installations)
- Each skill has a `doctor` subcommand that performs environment diagnostics

## Naming Conventions

**Files:**

- `SKILL.md`: Skill definition file; required for Claude Code skills; contains YAML frontmatter + Markdown instructions
- `README.md`: User documentation; present in project root, skill directories, and tool directories
- `install.sh`: Installation script; present at root, per-skill, and per-tool levels
- `*-*.sh`: Multi-word shell scripts use hyphens (e.g., `tmux-iterm-tabs.sh`, `tmux-sessions.sh`)
- `*.py`: Python utilities (e.g., `gen-session-bg.py`)

**Directories:**

- `skills/[skill-name]/`: Lowercase skill/tool names with hyphens for multi-word names (e.g., `iterm2-tmux`)
- `bin/`: Executable scripts directory (iterm2-tmux specific)
- `iterm2/`: Platform-specific configuration storage

**Skill/Tool Names:**

- Lowercase with hyphens: `chk1` (single word), `iterm2-tmux` (compound)
- Used in: Directory name, YAML frontmatter `name:` field, CLI invocation

## Where to Add New Code

**New Claude Code Skill:**

1. Copy template: `cp -r _template skills/my-skill`
2. Edit `skills/my-skill/SKILL.md`:
   - Update YAML frontmatter (name, version, description, allowed-tools, argument-hint)
   - Replace instructions in markdown section
3. Edit `skills/my-skill/README.md` with usage, prerequisites, troubleshooting
4. Test locally: `./install.sh my-skill` then `/my-skill help` in Claude Code
5. (Optional) Add per-skill `install.sh` if custom logic is needed

**New Standalone Tool:**

1. Create `skills/my-tool/` directory
2. Do NOT add `SKILL.md` (this marks it as a standalone tool, not a Claude Code skill)
3. Add custom `install.sh` and `uninstall.sh` scripts
4. Add `README.md` with installation and usage instructions
5. Add executable scripts to `skills/my-tool/bin/` directory
6. Test: `cd skills/my-tool && ./install.sh`
7. Root `./install.sh` will automatically skip this directory (lacks SKILL.md)

**Skill Subcommands:**

All skills must implement these patterns in `SKILL.md`:
- `help` subcommand: Display usage guide
- `doctor` subcommand: Run diagnostics, check environment
- `version` subcommand: Output version string
- Check `$ARGUMENTS` first; if it matches a subcommand, execute that and stop

**Installer Changes:**

Modify `./install.sh` when:
- Changing skill discovery logic
- Changing installation target path (`~/.claude/skills/`)
- Adding new global options or flags
- Changing version format

Avoid modifying when adding a new skill (just add `skills/my-skill/SKILL.md`).

## Special Directories

**.planning/codebase/**
- Purpose: GSD codebase mapping outputs
- Generated: Yes (generated by GSD mapping commands)
- Committed: Yes
- Contents: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md, STACK.md, INTEGRATIONS.md

**.git/**
- Purpose: Git repository metadata
- Generated: Yes (created by git init)
- Committed: N/A (git internal)

**skills/[skill-name]/**
- Purpose: Skill-specific files (SKILL.md, README, per-skill installer)
- Generated: No (manually created by copying template)
- Committed: Yes (part of repo)

**~/.claude/skills/[skill-name]/**
- Purpose: Installed skill location (discovered by Claude Code)
- Generated: Yes (created by root installer)
- Committed: No (user-local directory)

**~/.local/bin/**
- Purpose: Installed standalone tool scripts
- Generated: Yes (symlinked or copied by tool installer)
- Committed: No (user-local directory)

**~/.config/iterm2-tmux/**
- Purpose: Runtime configuration for iterm2-tmux tool
- Generated: Yes (created by tool installer)
- Committed: No (user-local directory)

---

*Structure analysis: 2026-03-31*
