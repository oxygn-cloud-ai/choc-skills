# Testing Patterns

**Analysis Date:** 2026-03-31

## Test Framework

**Runner:**
- Not detected — No automated test framework configured
- Testing approach: Manual verification and health check scripts

**Assertion Library:**
- Not applicable — No test framework in place

**Run Commands:**
```bash
# Manual health check (part of install.sh functionality)
./install.sh --check              # Verify installation health across all skills

# Per-skill diagnostics (via SKILL.md pattern)
/chk1 doctor                       # Run environment health check for chk1 skill
/chk1 help                         # Display usage guide
/chk1 version                      # Show installed version
```

## Test File Organization

**Location:**
- Not applicable — No dedicated test files exist
- Health checks embedded in main scripts: `check_health()` function in `install.sh`
- Diagnostic patterns defined in `SKILL.md` files (doctor subcommand)

**Naming:**
- Not applicable — No test files

**Structure:**
```
No test directory structure
```

## Testing Strategy

**Health Check Pattern (from install.sh):**

The codebase uses an embedded health check function rather than automated tests. This is the primary verification mechanism:

```bash
# From install.sh — check_health() function
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

    ok "'${name}' v${src_ver} is healthy"
  done

  echo ""
  if [ "$issues" -gt 0 ]; then
    warn "${issues} issue(s) found across ${checked} skill(s)"
    info "Run ./install.sh --update to fix outdated/missing skills"
    return 1
  else
    ok "All ${checked} skill(s) healthy"
    return 0
  fi
}
```

## Verification Patterns in Code

**Installation Verification Pattern (from install.sh):**

Each installation step includes post-action verification:

```bash
# Copy SKILL.md
if ! cp "${source}/SKILL.md" "${target}/SKILL.md" 2>/dev/null; then
  die "Failed to copy SKILL.md to ${target} — check disk space and permissions"
fi

# Verify copy with byte-by-byte comparison
if ! cmp -s "${source}/SKILL.md" "${target}/SKILL.md"; then
  err "Verification failed — source and installed SKILL.md differ"
  err "Source: ${source}/SKILL.md"
  err "Target: ${target}/SKILL.md"
  die "Installation may be corrupt. Try again with --force"
fi
```

**Pre-flight Checks Pattern:**

All scripts implement pre-flight validation before main execution:

```bash
# From tmux-iterm-tabs.sh
if ! command -v tmux &>/dev/null; then
  echo "[ERROR] tmux not found in PATH." >&2
  exit 1
fi

if [[ ! -x "$ATTACH_SCRIPT" ]]; then
  echo "[ERROR] Attach script not found: $ATTACH_SCRIPT" >&2
  exit 1
fi

# Wait for external volume if needed (up to 10s)
for i in {1..10}; do
  [[ -d "$REPOS_DIR" ]] && break
  sleep 1
done
[[ -d "$REPOS_DIR" ]] || { echo "[ERROR] Repos dir not found: $REPOS_DIR" >&2; exit 1; }

if ! pgrep -qf "iTerm"; then
  echo "[ERROR] iTerm2 is not running. Cannot open tabs." >&2
  exit 1
fi
```

## Doctor/Diagnostic Pattern

**Skill Diagnostics (from SKILL.md template):**

Every skill implements a standardized `doctor` subcommand for environment verification:

```
USAGE
  /chk1 doctor              Run environment health check
  /chk1 version             Show installed version
  /chk1 help                Display usage guide
```

**Doctor subcommand requirements (from chk1/SKILL.md):**
1. Git available: Run `git --version`
2. Inside a git repo: Run `git rev-parse --is-inside-work-tree`
3. Has commits: Run `git rev-parse HEAD`
4. Working tree status: Run `git status --porcelain`
5. Has recent commits: Run `git log --oneline -5`
6. Branch status: Run `git symbolic-ref --short HEAD`
7. Skill installation: Check if `~/.claude/skills/<name>/SKILL.md` exists
8. Skill version: Read version from installed SKILL.md

**Output format:**

```
chk1 doctor — Environment Health Check

  [PASS] Git available: git version X.Y.Z
  [PASS] Inside a git repo: /path/to/repo
  [PASS] Has commits: HEAD at <sha>
  [WARN] Working tree: 3 uncommitted changes
  [PASS] Has recent commits: N commits found
  [PASS] Branch: main
  [PASS] Installed: ~/.claude/skills/chk1/SKILL.md
  [PASS] Version: 1.1.0

  Result: N passed, N warnings, N failed
```

## Test Coverage Patterns

**Approach:** Health checks rather than unit tests

The codebase relies on:
1. **Installation verification** — byte-for-byte comparison of copied files
2. **Version consistency checks** — compare installed vs. available versions
3. **State validation** — verify directory structure, file existence, permissions
4. **Pre-flight checks** — validate dependencies and environment before execution
5. **Health check runs** — `./install.sh --check` verifies all installations

**Coverage characteristics:**
- Full coverage of happy path for installation (copy, verify, version check)
- Comprehensive error path coverage (permission checks, missing files, invalid names)
- End-to-end verification (health check traverses all skills and validates each)

**No coverage for:**
- Unit tests for individual functions
- Mocking of external commands (tmux, git, etc.)
- Integration tests for multi-step workflows
- Performance/stress testing
- Error recovery scenarios not explicitly coded

## Error Testing Pattern

**From install.sh — Validation with expected errors:**

```bash
# Test: Empty skill name
validate_name "" || { echo "Correctly rejected empty name"; }

# Test: Invalid characters in skill name
validate_name "my/skill" || { echo "Correctly rejected path traversal"; }

# Test: Valid skill name
validate_name "chk1" && echo "Valid name accepted"
```

**From tmux scripts — Command availability testing:**

```bash
# Test: tmux not found
if ! command -v tmux &>/dev/null; then
  echo "[ERROR] tmux not found in PATH." >&2
  exit 1
fi
```

## What Gets Verified

**Installation process:**
- Skill directory existence
- SKILL.md file presence
- Version consistency
- Content integrity (byte comparison)
- Permission checks
- Disk space implicitly (cp will fail if no space)

**Runtime checks:**
- External command availability (git, tmux, python3)
- Directory accessibility
- File readability
- Process status (pgrep for iTerm2)

**Configuration:**
- User config files sourced if present: `[[ -f "${HOME}/.config/iterm2-tmux/config" ]] && source ...`
- Environment variable overrides: `${TMUX_REPOS_DIR:-$HOME/Repos}`
- Fallback patterns for missing optional tools

## What Is NOT Tested

**Missing test coverage:**
- Unit tests for core functions
- Integration tests for multi-step workflows
- Failure scenarios not explicitly handled in code
- Concurrent execution safety
- Large-scale performance (e.g., hundreds of skills)
- Platform-specific behavior (tested manually on macOS)
- Python image generation (gen-session-bg.py) — no tests, relies on PIL library
- AppleScript execution in tmux-iterm-tabs.sh — no test verification

**Why minimal testing:**
- Small, focused scripts with simple logic
- External command-heavy (tmux, git, osascript) — hard to test without mocks
- Installation scripts require manual verification anyway
- Health checks provide sufficient runtime validation
- Team prefers manual testing for release verification

## Testing Recommendations

**To add automated tests:**

1. **Bash unit tests** — Use `bats` (Bash Automated Testing System):
   ```bash
   # Example test file: tests/install.bats
   @test "validate_name rejects empty string" {
     run validate_name ""
     [ "$status" -eq 1 ]
   }

   @test "validate_name accepts valid names" {
     run validate_name "my-skill"
     [ "$status" -eq 0 ]
   }
   ```

2. **Health check validation** — Expand `check_health()` with specific test cases

3. **Mock external commands** — Use `shunit2` or create isolated test environment

4. **Python unit tests** — Add `pytest` for `gen-session-bg.py`:
   ```python
   import pytest
   from gen_session_bg import generate

   def test_generate_creates_image(tmp_path):
       output = tmp_path / "test.png"
       generate("TestLabel", str(output), 0)
       assert output.exists()
   ```

---

*Testing analysis: 2026-03-31*
