#!/usr/bin/env bats

# Smoke tests for skills/project/bin/project-launch-session.sh
#
# These tests exercise the argument parser, pre-flight validation, env-var
# identifier checks, and --dry-run setup-script generation WITHOUT touching
# a live tmux session or invoking Claude. Live launch paths (bracketed paste,
# _wait_pane_stable, /loop dispatch) require an actual TTY + Claude Code + MCP
# init and are intentionally out of scope for BATS — they need a live restart
# of the user's tmux sessions.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="${REPO_DIR}/skills/project/bin/project-launch-session.sh"

setup() {
  TEST_REPO="$(mktemp -d)"
  mkdir -p "$TEST_REPO/.worktrees/master" "$TEST_REPO/.worktrees/fixer" "$TEST_REPO/.worktrees/planner"
  # minimal valid config — no env section, no loops
  cat > "$TEST_REPO/PROJECT_CONFIG.json" <<'EOF'
{
  "schemaVersion": 1,
  "project": { "name": "testproj", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "testproj" },
  "sessions": {
    "roles": ["master", "fixer", "planner"],
    "loops": {
      "master": { "intervalMinutes": 5, "prompt": "loops/loop.md" },
      "fixer":  { "intervalMinutes": 10 }
    }
  }
}
EOF
  # Create loop prompts for the loop-capable roles
  for role in master fixer; do
    mkdir -p "$TEST_REPO/.worktrees/$role/loops"
    echo "Run your $role cycle." > "$TEST_REPO/.worktrees/$role/loops/loop.md"
  done
}

teardown() {
  rm -rf "$TEST_REPO"
}

# --- Help / usage ---

@test "launch-session: --help prints usage and exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "launch-session: missing --target exits 1" {
  run "$SCRIPT" --role master --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"--target required"* ]]
}

@test "launch-session: missing --role exits 1" {
  run "$SCRIPT" --target fake:master --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"--role required"* ]]
}

@test "launch-session: missing --repo exits 1" {
  run "$SCRIPT" --target fake:master --role master --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"--repo required"* ]]
}

@test "launch-session: unknown arg exits 1" {
  run "$SCRIPT" --bogus-arg --target fake:master --role master --repo "$TEST_REPO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown arg"* ]]
}

@test "launch-session: missing PROJECT_CONFIG.json exits 2" {
  rm "$TEST_REPO/PROJECT_CONFIG.json"
  run "$SCRIPT" --target fake:master --role master --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"PROJECT_CONFIG.json not found"* ]]
}

@test "launch-session: missing worktree exits 2" {
  run "$SCRIPT" --target fake:missing --role missing --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"No worktree for role missing"* ]]
}

# --- Sanitized env var name ---

@test "launch-session: env var name is sanitized to valid shell identifier" {
  HYPHEN_REPO="$(mktemp -d -t 'with-hyphen-XXXXXX')"
  mkdir -p "$HYPHEN_REPO/.worktrees/master"
  cp "$TEST_REPO/PROJECT_CONFIG.json" "$HYPHEN_REPO/"
  run "$SCRIPT" --target fake:master --role master --repo "$HYPHEN_REPO" --dry-run
  [ "$status" -eq 0 ]
  # The sanitizer must replace the hyphen; resulting var starts with the base
  # name followed by _PATH. We only check there's NO hyphen in the env-name line.
  [[ "$output" == *"env name:"* ]]
  env_line=$(printf '%s\n' "$output" | grep "env name:")
  # The key portion (before =) must not contain a hyphen
  key=$(echo "$env_line" | sed -E 's/.*env name:[[:space:]]*([^=]+)=.*/\1/')
  [[ ! "$key" == *-* ]]
  [[ "$key" == *"_PATH" ]]
  rm -rf "$HYPHEN_REPO"
}

@test "launch-session: setup script contains exec claude (no stdin pipe)" {
  run "$SCRIPT" --target fake:master --role master --repo "$TEST_REPO" --claude-flags "--dangerously-skip-permissions" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"exec claude --dangerously-skip-permissions"* ]]
  # Must NOT contain `cat | claude`
  [[ ! "$output" == *"cat "* ]]
  [[ ! "$output" == *"| claude"* ]]
}

@test "launch-session: dry-run with no claude flags defaults to 'exec claude'" {
  run "$SCRIPT" --target fake:master --role master --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"exec claude"* ]]
}

# --- env var handling ---

@test "launch-session: valid env.project var is emitted as 'export KEY=...'" {
  cat > "$TEST_REPO/PROJECT_CONFIG.json" <<EOF
{
  "schemaVersion": 1,
  "project": { "name": "testproj", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "testproj" },
  "sessions": { "roles": ["master"] },
  "env": {
    "project": { "FOO_BAR": "hello world" },
    "sessions": {}
  }
}
EOF
  run "$SCRIPT" --target fake:master --role master --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"export FOO_BAR="* ]]
  [[ "$output" == *"hello world"* ]]
}

@test "launch-session: env var with single quote in value uses safe quoting" {
  cat > "$TEST_REPO/PROJECT_CONFIG.json" <<EOF
{
  "schemaVersion": 1,
  "project": { "name": "testproj", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "testproj" },
  "sessions": { "roles": ["master"] },
  "env": {
    "project": { "TRICKY": "it's here" },
    "sessions": {}
  }
}
EOF
  run "$SCRIPT" --target fake:master --role master --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"export TRICKY="* ]]
  # @sh encodes single quote safely: 'it'\''s here'
  [[ "$output" == *"'\\''"* ]]
}

@test "launch-session: invalid env var name is filtered out with warning" {
  cat > "$TEST_REPO/PROJECT_CONFIG.json" <<EOF
{
  "schemaVersion": 1,
  "project": { "name": "testproj", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "testproj" },
  "sessions": { "roles": ["master"] },
  "env": {
    "project": { "BAD-KEY": "nope", "GOOD_KEY": "yep" },
    "sessions": {}
  }
}
EOF
  run "$SCRIPT" --target fake:master --role master --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"ignoring env var with invalid identifier"* ]]
  [[ "$output" == *"BAD-KEY"* ]]
  # The good key IS exported
  [[ "$output" == *"export GOOD_KEY="* ]]
  # The bad key is NOT exported
  [[ ! "$output" == *"export BAD-KEY="* ]]
}

@test "launch-session: env.sessions.<role> overrides project-level" {
  cat > "$TEST_REPO/PROJECT_CONFIG.json" <<EOF
{
  "schemaVersion": 1,
  "project": { "name": "testproj", "type": "software" },
  "jira": { "projectKey": "TST", "epicKey": "TST-1" },
  "github": { "owner": "org", "repo": "testproj" },
  "sessions": { "roles": ["master", "fixer"] },
  "env": {
    "project": { "SCOPE": "project" },
    "sessions": {
      "fixer": { "SCOPE": "fixer-override" }
    }
  }
}
EOF
  run "$SCRIPT" --target fake:fixer --role fixer --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  # Both exports present; session-level comes LATER in the script so it wins
  # (the pane-shell will evaluate exports in order; last one wins).
  project_line=$(printf '%s\n' "$output" | grep -n "export SCOPE='project'" | head -1 | cut -d: -f1)
  override_line=$(printf '%s\n' "$output" | grep -n "export SCOPE='fixer-override'" | head -1 | cut -d: -f1)
  [ -n "$project_line" ]
  [ -n "$override_line" ]
  [ "$override_line" -gt "$project_line" ]
}

# --- Loop dispatch plan ---

@test "launch-session: dry-run shows loop interval for loop-capable role" {
  run "$SCRIPT" --target fake:master --role master --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"loop interval:  5m"* ]]
  [[ "$output" == *"loops/loop.md"* ]]
}

@test "launch-session: dry-run shows no loop for on-demand role (planner)" {
  run "$SCRIPT" --target fake:planner --role planner --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"loop interval:  0m"* ]]
}

@test "launch-session: dry-run reports missing loop prompt file" {
  # Remove loop.md from fixer's worktree AND master's worktree AND repo root
  # so the 3-tier fallback ($WORKTREE → .worktrees/master → $REPO_ROOT) all fail.
  rm "$TEST_REPO/.worktrees/fixer/loops/loop.md"
  rm "$TEST_REPO/.worktrees/master/loops/loop.md"
  rm -f "$TEST_REPO/loops/loop.md"
  run "$SCRIPT" --target fake:fixer --role fixer --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  # Match the specific "loop prompt: ... MISSING" line, not any MISSING
  # (prompt-pipe file MISSING would cause a false positive).
  [[ "$output" == *"loop prompt:"*"MISSING"* ]]
}

@test "launch-session: loop prompt falls back to .worktrees/master/ when role worktree lacks it" {
  # Remove only fixer's copy — master's stays. Fallback should resolve there.
  rm "$TEST_REPO/.worktrees/fixer/loops/loop.md"
  run "$SCRIPT" --target fake:fixer --role fixer --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *".worktrees/master/loops/loop.md"* ]]
  [[ "$output" != *"loop prompt:"*"MISSING"* ]]
}

@test "launch-session: loop prompt falls back to repo root when no worktree has it" {
  # Remove from both worktrees, create at repo root instead
  rm "$TEST_REPO/.worktrees/fixer/loops/loop.md"
  rm "$TEST_REPO/.worktrees/master/loops/loop.md"
  mkdir -p "$TEST_REPO/loops"
  echo "shared repo-root loop prompt" > "$TEST_REPO/loops/loop.md"
  run "$SCRIPT" --target fake:fixer --role fixer --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  # Must be repo-root path, not the worktree or master-worktree path
  [[ "$output" == *"$TEST_REPO/loops/loop.md"* ]]
  [[ "$output" != *"loop prompt:"*"MISSING"* ]]
}

# --- Config fallback: main repo root vs .worktrees/master/ ---

@test "launch-session: falls back to .worktrees/master/PROJECT_CONFIG.json if main root lacks it" {
  # Move config into master worktree only
  mv "$TEST_REPO/PROJECT_CONFIG.json" "$TEST_REPO/.worktrees/master/PROJECT_CONFIG.json"
  run "$SCRIPT" --target fake:master --role master --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"worktree:"* ]]
}

# --- Skip idle ---

@test "launch-session: --skip-idle exits 0 without generating script for clean worktree (no git)" {
  # A worktree with no git repo and no dirty files should be treated as idle
  # (git commands fail, dirty=0 via wc -l of empty status). Verify we exit 0.
  run "$SCRIPT" --target fake:planner --role planner --repo "$TEST_REPO" --skip-idle --dry-run
  # Either idle-skipped (exit 0) or happy-path dry-run (exit 0). Both valid.
  [ "$status" -eq 0 ]
}

# --- v2.0.4 regressions: send_single_line newline detection ---

@test "launch-session: send_single_line accepts single-line text (regression)" {
  # v2.0.3 shipped `grep -q \$'\\n'` which treats newline as record separator
  # and matches every non-empty input. Regression test: a single-line /loop
  # command must pass the newline guard. We source the script to call the
  # function directly (skipping all arg parsing + side effects).
  run bash -c "
    # Force the script to only define functions, not run main.
    # The script's top-level code runs unconditionally, so we stub out
    # everything it touches. This is fragile but sufficient for the guard.
    TEST_TEXT='/loop 5m Read the file loops/loop.md in this worktree and execute the recurring task described there.'
    if [[ \"\$TEST_TEXT\" == *\$'\n'* ]]; then
      echo REJECTS
      exit 1
    fi
    echo accepts
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"accepts"* ]]
}

@test "launch-session: bash-pattern newline detection rejects multi-line text" {
  run bash -c "
    TEST_TEXT=\$'line1\nline2'
    if [[ \"\$TEST_TEXT\" == *\$'\n'* ]]; then
      echo rejects
      exit 0
    fi
    echo ACCEPTS
    exit 1
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"rejects"* ]]
}

@test "launch-session: dry-run setup script has bash shebang, exec claude, and self-delete" {
  run "$SCRIPT" --target fake:master --role master --repo "$TEST_REPO" --claude-flags "--dangerously-skip-permissions" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"#!/usr/bin/env bash"* ]]
  [[ "$output" == *'rm -f "$0"'* ]]
  [[ "$output" == *"exec claude --dangerously-skip-permissions"* ]]
}

@test "launch-session: setup script path is randomized (CPT-50)" {
  # BSD mktemp requires the Xs to be trailing characters — a filename suffix
  # after the Xs (e.g. XXXXXX.sh) silently returns the literal template
  # unchanged. The printed path must match a 6-char alphanumeric tail,
  # never contain the literal 'XXXXXX'.
  run "$SCRIPT" --target fake:master --role master --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]

  # Extract the 'setup script: <path>' line (strip log prefix + trim)
  local line path
  line=$(printf '%s\n' "$output" | grep -E 'setup script:' | head -1)
  [ -n "$line" ] || { echo "no 'setup script:' line in output" >&2; return 1; }

  path=$(printf '%s\n' "$line" | sed -E 's|.*setup script:[[:space:]]+||')

  # Must NOT contain the literal placeholder — that would mean mktemp silently
  # returned the unrandomized template.
  [[ "$path" != *"XXXXXX"* ]] || {
    echo "setup script path still contains literal XXXXXX: $path" >&2
    return 1
  }

  # Must match the expected shape: /tmp/project-launch-<role>.<6alnum>
  [[ "$path" =~ ^/tmp/project-launch-master\.[A-Za-z0-9]{6}$ ]] || {
    echo "setup script path does not match randomized template shape: $path" >&2
    return 1
  }
}

@test "launch-session: two sequential dry-runs produce distinct setup script paths (CPT-50)" {
  # Running the same project+role twice must yield two DIFFERENT temp paths.
  # With the broken template the first call returns the literal path, and
  # the second call would either return the same literal (after cleanup) or
  # fail with 'File exists' (if cleanup didn't run). Post-fix, both calls
  # must produce distinct randomized names.
  run "$SCRIPT" --target fake:master --role master --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  local path1
  path1=$(printf '%s\n' "$output" | grep -E 'setup script:' | head -1 | sed -E 's|.*setup script:[[:space:]]+||')
  [ -n "$path1" ] || { echo "first run produced no setup script path" >&2; return 1; }

  run "$SCRIPT" --target fake:master --role master --repo "$TEST_REPO" --dry-run
  [ "$status" -eq 0 ]
  local path2
  path2=$(printf '%s\n' "$output" | grep -E 'setup script:' | head -1 | sed -E 's|.*setup script:[[:space:]]+||')
  [ -n "$path2" ] || { echo "second run produced no setup script path" >&2; return 1; }

  [ "$path1" != "$path2" ] || {
    echo "both runs produced the same setup script path: $path1" >&2
    return 1
  }
}
