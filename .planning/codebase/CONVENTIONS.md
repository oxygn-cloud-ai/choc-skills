# Coding Conventions

**Analysis Date:** 2026-03-31

## Naming Patterns

**Files:**
- Bash scripts: lowercase with hyphens (kebab-case) — `tmux-iterm-tabs.sh`, `tmux-sessions.sh`
- Python scripts: lowercase with hyphens — `gen-session-bg.py`
- Skill definitions: `SKILL.md` (uppercase, fixed name)
- Documentation: `README.md`, `SKILL.md` (uppercase)
- Installers: `install.sh`, `uninstall.sh` (lowercase, fixed names)

**Functions (Bash):**
- Lowercase with underscores (snake_case) — `sanitize_name()`, `lookup_label()`, `check_health()`, `install_skill()`
- Action-verb prefixes: `install_`, `uninstall_`, `validate_`, `get_`, `check_`, `list_`, `confirm_`
- Output helpers use short names: `info()`, `ok()`, `warn()`, `err()`, `die()`

**Variables (Bash):**
- All caps for constants and environment variables: `REPO_DIR`, `SKILLS_DIR`, `TARGET_BASE`, `FORCE`, `QUIET`
- All caps for configuration overrides: `NO_COLOR`, `TMUX_REPOS_DIR`, `TMUX_SESSIONS_SCRIPT`
- Lowercase with underscores for local variables: `count`, `failed`, `src_ver`, `dst_ver`
- Array variables use lowercase: `TARGETS=()`, `names=()`, `new_sessions=()`

**Types (Bash):**
- No explicit type declarations; types managed through variable naming conventions
- Numeric indices use lowercase: `idx`, `i`
- Boolean flags use descriptive uppercase: `FORCE=false`, `INTERACTIVE=true`

## Code Style

**Formatting:**
- Bash: 2-space indentation (consistent across all shell scripts)
- Python: 4-space indentation (PEP 8 style in `gen-session-bg.py`)
- Strict mode in Bash: All scripts begin with `set -euo pipefail` (errexit, nounset, pipefail)
- Line length: No hard limit enforced; generally 100 characters or less

**Linting:**
- No explicit linter configuration found
- Code follows standard Bash best practices and shell conventions

## Import Organization

**Bash scripts:**
- No traditional imports; instead uses shell sourcing pattern
- User config sourcing pattern (optional): `[[ -f "${HOME}/.config/<app>/config" ]] && source "${HOME}/.config/<app>/config"`
- Environment PATH customization: `export PATH="/opt/homebrew/bin:$PATH"` (prepend for priority)
- Order: Set strict mode → Source config → Set up variables → Define functions → Execute logic

**Python scripts:**
- Standard library imports at top: `import os`, `import sys`
- Third-party imports: `from PIL import Image, ImageDraw, ImageFont`
- No relative imports; absolute imports only

## Error Handling

**Patterns:**

**Bash error handling:**
- Exit on error immediately: `set -euo pipefail` prevents silent failures
- Explicit error checks with `||` operator: `mkdir -p "$target" 2>/dev/null || die "message"`
- Error messages prefixed with `[ERROR]` in stdout/stderr context: `echo "[ERROR] message" >&2`
- Structured error output via `err()` function (with color): `err "Skill not found"`
- Fatal errors via `die()` function (calls `err()` then `exit 1`): `die "Invalid skill name"`
- Pre-flight check pattern: Validate all requirements silently before proceeding, with clear errors if checks fail

**Examples from codebase:**

```bash
# From install.sh — pre-flight validation
if [ ! -d "$source" ]; then
  err "Skill '${name}' not found in ${SKILLS_DIR}"
  info "Run ./install.sh --list to see available skills"
  return 1
fi

# From tmux-iterm-tabs.sh — error with context
if ! command -v tmux &>/dev/null; then
  echo "[ERROR] tmux not found in PATH." >&2
  exit 1
fi

# From install.sh — compound error check
if ! mkdir -p "$target" 2>/dev/null; then
  die "Cannot create ${target} — check permissions on ~/.claude/"
fi
```

**Bash-specific patterns:**
- Silent command execution with stderr suppression: `command &>/dev/null`
- Conditional execution with `&&` and `||` for implicit branching
- Explicit return codes checked: `if ! command; then ... fi`
- Process substitution for loop input: `while IFS= read -r line; do ... done <<< "$variable"`
- Trap for cleanup: `trap 'rm -f "$TMPSCRIPT"' EXIT`

**Python error handling:**
- Try/except for file operations: `try: ... except Exception: ...`
- Fallback patterns: `try: return ImageFont.truetype(...) except Exception: continue`
- sys.exit(1) for fatal errors with message to stderr: `print(..., file=sys.stderr); sys.exit(1)`

## Logging

**Framework:** Custom shell functions (not a library)

**Patterns:**
- Structured output via helper functions: `info()`, `ok()`, `warn()`, `err()`
- Color-coded output (disabled if `NO_COLOR` env var set or not a terminal): `[ -t 1 ] && [ "${NO_COLOR:-}" = "" ]`
- Timestamp not included; output is prefixed with status code: `[PASS]`, `[WARN]`, `[FAIL]`, `[ERROR]`
- Logging to stderr for errors: `>&2` redirection for `err()`, `warn()`
- Logging to stdout for info/success: `info()`, `ok()` use standard output

**Examples:**

```bash
# From install.sh
info()  { printf "${CYAN}info${RESET}  %s\n" "$*"; }
ok()    { printf "${GREEN}  ok${RESET}  %s\n" "$*"; }
warn()  { printf "${YELLOW}warn${RESET}  %s\n" "$*" >&2; }
err()   { printf "${RED} err${RESET}  %s\n" "$*" >&2; }
die()   { err "$@"; exit 1; }

# Usage examples
info "Installing chk1 from ${source}"
ok "Installed 'chk1' v1.1.0 -> ~/.claude/skills/chk1"
warn "Skipped 'chk1' — overwrite cancelled"
err "Skill 'chk1' is missing SKILL.md — broken skill definition"
```

## Comments

**When to Comment:**
- Comments are used sparingly; self-documenting code is preferred
- Comment section headers: `# --- Section Name ---` format used in install.sh
- Inline comments explain *why*, not *what* the code does
- Comments explain special handling or workarounds

**Examples from codebase:**

```bash
# From install.sh — section header
# --- Colors (disabled if not a terminal) ---

# From tmux-iterm-tabs.sh — explanatory comment
# Wait for external volume if needed (up to 10s)
for i in {1..10}; do
  [[ -d "$REPOS_DIR" ]] && break
  sleep 1
done

# From tmux-attach-session.sh — technical detail
# Set tab title (persists because tmux has set-titles off + allow-rename off)
printf '\033]0;%s\007' "$LABEL"
```

**Shebang lines:**
- Standard: `#!/usr/bin/env bash` (preferred for portability)
- Python: `#!/usr/bin/env python3`

**Docstrings (Python):**
- Triple-quoted docstring at module level: `"""Generate a subtle background image with the session name as a watermark."""`
- Function documentation via comments above function definition

## Function Design

**Size:**
- Small, single-responsibility functions (most < 30 lines)
- Examples: `sanitize_name()` is 6 lines, `lookup_label()` is 12 lines, `install_skill()` is 60 lines (large but comprehensive)

**Parameters:**
- Positional parameters with validation: `validate_name()` checks `[ -z "$name" ]` immediately
- Use of `${1:?error message}` for required positional args: `SESSION="${1:?session required}"`
- Default values via parameter expansion: `INDEX="${3:-0}"` (use 0 if not provided)

**Return Values:**
- Bash scripts use exit codes: `return 0` for success, `return 1` for failure
- Functions may also output to stdout which is captured by caller: `echo "$result"` then captured via `result=$(function_name)`
- Python functions return computed values or None

**Example pattern (from install.sh):**

```bash
# Function with parameter validation
get_skill_version() {
  local skill_file="$1"
  [ -f "$skill_file" ] || return 1
  local ver
  ver=$(grep -m1 '^version:' "$skill_file" 2>/dev/null | sed 's/^version: *//' || true)
  echo "${ver:-unknown}"
}

# Usage: capture return value via command substitution
src_ver=$(get_skill_version "${source}/SKILL.md")
```

## Module Design

**Exports:**
- No explicit module system in Bash; functions are available after definition
- Python modules use `if __name__ == "__main__":` guard for entry point

**Barrel Files:**
- Not applicable; no TypeScript/JavaScript in this codebase

**Script Organization Pattern:**
1. Shebang and strict mode
2. Configuration and environment setup
3. Helper function definitions
4. Main logic / argument parsing
5. Execution

**Example structure (install.sh):**
```bash
#!/usr/bin/env bash
set -euo pipefail
VERSION="1.1.0"  # Constants
# ... variable setup ...
# --- Colors --- (section)
# --- Output helpers --- (functions)
info() { ... }
ok() { ... }
# --- Flags --- (more setup)
# ... more function definitions ...
# --- Parse arguments ---
while [ $# -gt 0 ]; do ... done
# --- Execute ---
case "$ACTION" in ... esac
```

## Directory Structure Conventions

**Script organization:**
- Executable scripts in `bin/` subdirectories: `/skills/iterm2-tmux/bin/*.sh`
- Installer scripts at package root: `/skills/<name>/install.sh`, `./install.sh`
- Python utilities alongside related scripts: `/bin/gen-session-bg.py` with `/bin/tmux-attach-session.sh`

**Skill structure:**
- `SKILL.md` required for Claude Code skill discovery
- `README.md` for documentation
- Optional `install.sh` for per-skill installation logic

## Validation Patterns

**Input validation (Bash):**
- Pattern matching: `[[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]` for skill names
- Directory checks: `[ -d "$dir" ]` before operations
- File checks: `[ -f "$file" ]` before reading
- Writability checks: `[ ! -w "${HOME}/.claude" ]` before writing

**Example from install.sh:**

```bash
validate_name() {
  local name="$1"
  if [ -z "$name" ]; then
    die "Empty skill name"
  fi
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    die "Invalid skill name '${name}' — only letters, numbers, hyphens, and underscores allowed"
  fi
}
```

## Command Exit Pattern

**Consistent exit code strategy:**
- `exit 0` on success
- `exit 1` on error
- `exit $?` to propagate previous command's exit code
- `return` in functions (not `exit`) to allow caller to handle result

**Example from install.sh:**

```bash
case "$ACTION" in
  install)
    preflight
    # ... installation logic ...
    ok "${count} skill(s) installed"
    [ "$failed" -gt 0 ] && warn "${failed} skill(s) failed"
    ;;
esac
# (implicit exit 0 at end if no errors)
```

---

*Convention analysis: 2026-03-31*
