# Architecture

**Analysis Date:** 2026-03-31

## Pattern Overview

**Overall:** Plugin/Skill Distribution System with Standalone Tools

**Key Characteristics:**
- Two distinct artifact types: Claude Code skills and standalone tools
- Skills distributed via central installer and discovered by Claude Code automatically
- Standalone tools have independent installation pipelines
- Modular design with per-skill autonomy (install scripts, READMEs)
- Template-driven skill creation for consistency

## Layers

**Installation & Discovery Layer:**
- Purpose: Manage skill lifecycle (install/uninstall/update) and make skills discoverable to Claude Code
- Location: `./install.sh` (root), `./skills/*/install.sh` (per-skill)
- Contains: Installation scripts, version management, health checks
- Depends on: Bash environment, file system, git (for verification)
- Used by: Users installing skills, Claude Code runtime

**Skill Definition Layer:**
- Purpose: Define skill metadata, capabilities, and behavior via YAML frontmatter and Markdown instructions
- Location: `./skills/*/SKILL.md`
- Contains: YAML frontmatter (name, version, description, tool restrictions), markdown instructions, subcommand definitions (help/doctor/version)
- Depends on: Claude Code parsing and skill invocation system
- Used by: Claude Code to discover, describe, and invoke skills

**Skill Implementation Layer:**
- Purpose: Execute skill behavior when invoked via slash command
- Location: `./skills/*/SKILL.md` instructions section
- Contains: Step-by-step algorithmic instructions, diagnostic checks, verification procedures, output formatting
- Depends on: Tool access (Read, Grep, Glob, Bash), environment state verification
- Used by: Claude Code agent execution runtime

**Documentation Layer:**
- Purpose: Provide user-facing guidance on installation, usage, troubleshooting, and prerequisites
- Location: `./skills/*/README.md`, `./README.md`
- Contains: Installation commands, usage examples, configuration, troubleshooting tables
- Depends on: Skills themselves for context
- Used by: Humans installing and using skills

**Tool/Script Layer:**
- Purpose: Provide executable utilities for standalone tools (not Claude Code skills)
- Location: `./skills/*/bin/*.sh`, `./skills/*/bin/*.py`
- Contains: Shell scripts for tmux/iTerm2 orchestration, Python utilities for image generation
- Depends on: macOS, iTerm2, tmux, Python 3 + Pillow (optional)
- Used by: Direct script invocation, shell initialization

## Data Flow

**Skill Installation Flow:**

1. User runs `./install.sh [skill-name]` at repo root
2. Root installer identifies skill in `./skills/[skill-name]/SKILL.md`
3. Installer reads skill metadata (name, version, description)
4. Installer creates target directory `~/.claude/skills/[skill-name]/`
5. Installer copies `SKILL.md` to target location
6. Claude Code discovers `SKILL.md` at `~/.claude/skills/[skill-name]/SKILL.md` via filesystem scanning
7. Skill becomes available as `/[skill-name]` slash command

**Skill Execution Flow:**

1. User invokes `/[skill-name]` in Claude Code
2. Claude Code reads SKILL.md frontmatter for allowed-tools and metadata
3. Claude Code extracts `$ARGUMENTS` from user input
4. Skill checks if arguments match subcommands (help/doctor/version); if so, runs that subcommand only
5. If not a subcommand, skill executes main instructions with tool access
6. Skill performs pre-flight checks (git available, inside repo, etc.)
7. Skill executes main logic (e.g., audit, analysis)
8. Skill formats and returns structured output

**Standalone Tool Flow (iterm2-tmux):**

1. User runs `cd skills/iterm2-tmux && ./install.sh`
2. Installer asks for configuration (directory, install location)
3. Installer creates `~/.config/iterm2-tmux/config` with settings
4. Installer installs scripts to `~/.local/bin` (symlinked by default)
5. Installer optionally configures auto-startup in `~/.zshrc`
6. On iTerm2 launch, shell runs `tmux-iterm-tabs.sh` in background
7. Script creates tmux sessions, generates backgrounds, opens iTerm2 tabs via AppleScript

**State Management:**
- Skills: State is immutable; each invocation is independent. No persistent state between invocations.
- Standalone tools: Config stored in `~/.config/iterm2-tmux/config`, auto-startup marker in `~/.zshrc`
- Subcommands: Determined purely by `$ARGUMENTS`; no stateful branching

## Key Abstractions

**Skill Abstraction:**
- Purpose: Encapsulate a reusable Claude Code agent behavior
- Examples: `./skills/chk1/SKILL.md`
- Pattern: YAML frontmatter declares metadata + markdown instructions declare behavior; skill is self-contained and versioned

**Subcommand Pattern:**
- Purpose: Provide standard interface for help, diagnostics, and versioning across all skills
- Examples: All skills must support `help`, `doctor`, `version` subcommands
- Pattern: Check `$ARGUMENTS` at start, dispatch to subcommand handler, stop execution

**Installation Abstraction:**
- Purpose: Abstract installation complexity for both central (skills) and standalone (tools) distributions
- Examples: `./install.sh`, `./skills/chk1/install.sh`, `./skills/iterm2-tmux/install.sh`
- Pattern: Delegated to per-skill installer when needed; root installer orchestrates skill-directory discovery

**Tool Restriction Abstraction:**
- Purpose: Limit skill access to safe tools via frontmatter declaration
- Examples: `allowed-tools: Read, Grep, Glob, Bash(git *)` restricts skill to git commands only
- Pattern: Claude Code enforces restrictions at runtime based on frontmatter

## Entry Points

**Root Installer:**
- Location: `./install.sh`
- Triggers: Manual execution by user (`./install.sh [skill-name]`)
- Responsibilities: Discover skills, validate SKILL.md format, copy to `~/.claude/skills/`, list available skills, check health, uninstall

**Per-Skill Installer:**
- Location: `./skills/*/install.sh` (optional)
- Triggers: Root installer delegates to per-skill installer for skills that need custom logic
- Responsibilities: Custom installation steps (chk1 uses delegation, iterm2-tmux has standalone installer)

**Skill Invocation:**
- Location: `./skills/*/SKILL.md` (main instructions)
- Triggers: `/[skill-name]` slash command in Claude Code with optional `$ARGUMENTS`
- Responsibilities: Execute skill logic, perform pre-flight checks, handle subcommands, produce structured output

**Skill Help/Doctor/Version:**
- Location: `./skills/*/SKILL.md` (subcommand handlers)
- Triggers: `/[skill-name] help`, `/[skill-name] doctor`, `/[skill-name] version`
- Responsibilities: Return help text, run diagnostics, return version string

**Standalone Tool Auto-Startup:**
- Location: `~/.zshrc` (snippet added during install)
- Triggers: Shell initialization when iTerm2 is the active terminal
- Responsibilities: Run `tmux-iterm-tabs.sh` in background if not already running (lockfile guard)

## Error Handling

**Strategy:** Explicit pre-flight checks with clear error messages; fail-fast approach; errors are fatal and stop execution.

**Patterns:**

1. **Pre-flight check failure** → Clear error message with fix instructions, exit with code 1
   - Example: "chk1 error: git is not installed or not in PATH. Install git and try again."
   - Used in: All skills (chk1 verifies git, repo status)

2. **Argument validation failure** → Report expected syntax, show examples
   - Example: "chk1 error: Could not interpret scope. Expected: commit range (abc..def), branch name, commit SHA, or file path."
   - Used in: Skills that take arguments (chk1 scope parsing)

3. **Silent condition checking** → Verify conditions silently before proceeding; don't report normal state
   - Example: Pre-flight checks run `git --version` but only report failure, not success
   - Used in: All skills during initialization

4. **Warning vs. Error distinction** → Warnings allow execution to continue; errors stop execution
   - Example: chk1 warns about large diffs but proceeds; errors on missing git and exits
   - Used in: Doctor subcommand produces PASS/WARN/FAIL; skill execution uses errors only

## Cross-Cutting Concerns

**Logging:** No centralized logging. Skills output to stdout/stderr directly. Installer uses colored output (info/ok/warn/err helpers in `install.sh`).

**Validation:** Pre-flight checks are the primary validation mechanism. Each skill declares its requirements in the `doctor` subcommand. Argument validation is skill-specific (e.g., chk1 validates commit ranges).

**Authentication:** None. Skills run in the context of the user invoking them. Standalone tools may require user configuration (e.g., iTerm2 credentials for tab creation).

---

*Architecture analysis: 2026-03-31*
