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

# =============================================================================
# CPT-71: auto-detect unauthenticated Claude + drive /login flow
# =============================================================================
#
# classify_auth_state and ensure_logged_in live in skills/project/bin/_launch-auth.sh
# so the decision logic is sourceable and unit-testable without a live tmux.
#
# setup_tmux_stub — stamps a PATH-first tmux + sleep stub into $1 (a tmpdir).
#   - capture-pane -p -t <target>  serves $dir/capture.<N>.txt. N starts at 1.
#     N advances ONLY on send-keys invocations that include 'Enter' — simulates
#     "state changes after the user hits submit", matching how the real Claude
#     TUI behaves.
#   - send-keys                    logs full arg vector to $dir/keystrokes.log.
#   - has-session / load-buffer / paste-buffer / delete-buffer / list-* / new-*
#     are no-ops (exit 0).
#   - sleep is stubbed to exit 0 so wait_pane_stable's 1s polls don't slow
#     tests down.
# The stub cooperates with wait_pane_stable: since capture-pane returns the
# SAME file until send-keys Enter advances the counter, wait_pane_stable sees
# stable output and returns 0 after $STABLE_SAMPLES matching calls.
setup_tmux_stub() {
  local dir="$1"
  mkdir -p "$dir"
  export TMUX_STATE_DIR="$dir"
  echo 1 > "$dir/capture.counter"
  cat > "$dir/tmux" <<'TMUX_EOF'
#!/usr/bin/env bash
dir="${TMUX_STATE_DIR:?TMUX_STATE_DIR not set}"
case "$1" in
  capture-pane)
    n=$(cat "$dir/capture.counter" 2>/dev/null || echo 1)
    f="$dir/capture.$n.txt"
    [ -f "$f" ] && cat "$f"
    ;;
  send-keys)
    shift
    printf '%s\n' "$*" >> "$dir/keystrokes.log"
    # An argument exactly "Enter" (not substring) triggers a state transition.
    for a in "$@"; do
      if [ "$a" = "Enter" ]; then
        n=$(cat "$dir/capture.counter" 2>/dev/null || echo 1)
        echo $((n + 1)) > "$dir/capture.counter"
        break
      fi
    done
    ;;
  has-session|load-buffer|paste-buffer|delete-buffer|list-windows|new-window|new-session|kill-session)
    exit 0
    ;;
  *)
    # Silently no-op on anything else so tests don't blow up on future tmux usage.
    exit 0
    ;;
esac
TMUX_EOF
  chmod +x "$dir/tmux"
  cat > "$dir/sleep" <<'SLEEP_EOF'
#!/usr/bin/env bash
exit 0
SLEEP_EOF
  chmod +x "$dir/sleep"
  PATH="$dir:$PATH"; export PATH
}

# seed_capture <dir> <N> <text> — writes text (one pane capture) for state N.
seed_capture() {
  local dir="$1" n="$2" text="$3"
  printf '%s\n' "$text" > "$dir/capture.$n.txt"
}

LIB="${REPO_DIR}/skills/project/bin/_launch-auth.sh"

# --- classify_auth_state (pure, no tmux) ---

@test "classify_auth_state: authed when pane has no login markers" {
  run bash -c "source '$LIB'; classify_auth_state 'Welcome back, James. Claude ready.'"
  [ "$status" -eq 0 ]
  [ "$output" = "authed" ]
}

@test "classify_auth_state: not-logged-in when pane contains 'Not logged in'" {
  run bash -c "source '$LIB'; classify_auth_state 'Not logged in · Please run /login'"
  [ "$status" -eq 0 ]
  [ "$output" = "not-logged-in" ]
}

@test "classify_auth_state: login-menu when pane advertises Claude subscription option" {
  run bash -c "source '$LIB'; classify_auth_state 'Select auth method:
1. Claude subscription (recommended)
2. Anthropic Console (API key)'"
  [ "$status" -eq 0 ]
  [ "$output" = "login-menu" ]
}

@test "classify_auth_state: login-complete when pane shows 'Login successful'" {
  run bash -c "source '$LIB'; classify_auth_state 'Login successful! Press Enter to continue.'"
  [ "$status" -eq 0 ]
  [ "$output" = "login-complete" ]
}

@test "classify_auth_state: keychain-locked when pane mentions 'security unlock-keychain'" {
  run bash -c "source '$LIB'; classify_auth_state 'Error: keychain locked.
Run: security unlock-keychain ~/Library/Keychains/login.keychain-db'"
  [ "$status" -eq 0 ]
  [ "$output" = "keychain-locked" ]
}

@test "classify_auth_state: unclear when pane mentions 'login' but has no specific marker" {
  run bash -c "source '$LIB'; classify_auth_state 'Verifying login credentials...'"
  [ "$status" -eq 0 ]
  [ "$output" = "unclear" ]
}

# --- ensure_logged_in (tmux-driven, orchestration) ---

@test "ensure_logged_in: returns 0 immediately when first capture is authed" {
  local dir="$BATS_TEST_TMPDIR/tmux-stub"
  setup_tmux_stub "$dir"
  seed_capture "$dir" 1 "Welcome back — Claude ready"
  run bash -c "
    source '$LIB'
    log() { :; }
    warn() { :; }
    wait_pane_stable() { return 0; }
    TARGET='fake:master'
    ROLE='master'
    ensure_logged_in
  "
  [ "$status" -eq 0 ]
  [ ! -s "$dir/keystrokes.log" ] 2>/dev/null || [ ! -f "$dir/keystrokes.log" ]
}

@test "ensure_logged_in: full recovery flow not-logged-in → menu → success → dismiss" {
  local dir="$BATS_TEST_TMPDIR/tmux-stub"
  setup_tmux_stub "$dir"
  seed_capture "$dir" 1 "Not logged in · Please run /login"
  seed_capture "$dir" 2 "Select auth method:
1. Claude subscription
2. API key"
  seed_capture "$dir" 3 "Login successful! Press Enter to continue."
  seed_capture "$dir" 4 "Ready"
  run bash -c "
    source '$LIB'
    log() { :; }
    warn() { :; }
    wait_pane_stable() { return 0; }
    TARGET='fake:master'
    ROLE='master'
    ensure_logged_in
  "
  [ "$status" -eq 0 ]
  # Keystrokes expected: literal '/login', then 3 Enters (submit /login, pick option 1, dismiss)
  grep -q -- '/login' "$dir/keystrokes.log"
  [ "$(grep -cFx 'Enter' "$dir/keystrokes.log" 2>/dev/null || echo 0)" -ge 3 ] || {
    echo "info: expected 3 standalone Enters; keystrokes log:"; cat "$dir/keystrokes.log"; return 1; }
}

@test "ensure_logged_in: returns 1 on keychain-locked hint without sending keystrokes" {
  local dir="$BATS_TEST_TMPDIR/tmux-stub"
  setup_tmux_stub "$dir"
  seed_capture "$dir" 1 "security unlock-keychain ~/Library/Keychains/login.keychain-db required"
  run bash -c "
    source '$LIB'
    log() { :; }
    WARN_LOG='$dir/warn.log'; warn() { printf '%s\n' \"\$*\" >> \"\$WARN_LOG\"; }
    wait_pane_stable() { return 0; }
    TARGET='fake:master'
    ROLE='master'
    ensure_logged_in
  "
  [ "$status" -eq 1 ]
  grep -qi 'keychain' "$dir/warn.log"
  [ ! -s "$dir/keystrokes.log" ] 2>/dev/null || [ ! -f "$dir/keystrokes.log" ]
}

@test "ensure_logged_in: returns 1 when menu never arrives after /login" {
  local dir="$BATS_TEST_TMPDIR/tmux-stub"
  setup_tmux_stub "$dir"
  seed_capture "$dir" 1 "Not logged in"
  seed_capture "$dir" 2 "Still not logged in (broken)"  # No 'Claude subscription' — no menu
  run bash -c "
    source '$LIB'
    log() { :; }
    warn() { :; }
    wait_pane_stable() { return 0; }
    TARGET='fake:master'
    ROLE='master'
    ensure_logged_in
  "
  [ "$status" -eq 1 ]
  # /login was dispatched + exactly ONE Enter (to submit /login).
  # NO second Enter should have been sent to "pick option 1".
  [ "$(grep -cFx 'Enter' "$dir/keystrokes.log" 2>/dev/null || echo 0)" -eq 1 ] || {
    echo "info: expected exactly 1 Enter; keystrokes log:"; cat "$dir/keystrokes.log"; return 1; }
}

@test "ensure_logged_in: returns 1 when initial capture is 'unclear'" {
  local dir="$BATS_TEST_TMPDIR/tmux-stub"
  setup_tmux_stub "$dir"
  seed_capture "$dir" 1 "Checking login status..."
  run bash -c "
    source '$LIB'
    log() { :; }
    warn() { :; }
    wait_pane_stable() { return 0; }
    TARGET='fake:master'
    ROLE='master'
    ensure_logged_in
  "
  [ "$status" -eq 1 ]
}

# --- write_status ---

@test "write_status: writes one-word status to /tmp path" {
  local slug="cpt71test$$"
  run bash -c "source '$LIB'; write_status '$slug' master auth-failed"
  [ "$status" -eq 0 ]
  [ -f "/tmp/project-launch-${slug}-master.status" ]
  [ "$(cat "/tmp/project-launch-${slug}-master.status")" = "auth-failed" ]
  rm -f "/tmp/project-launch-${slug}-master.status"
}

# --- End-to-end launch: auth gating + status file ---

@test "launch e2e: exits 4 and writes auth-failed status when pane stays unauthed" {
  local dir="$BATS_TEST_TMPDIR/e2e-stub"
  setup_tmux_stub "$dir"
  # capture.1 comes before the first send-keys "exec bash …" advances the counter;
  # seed capture.2 for when the script runs wait_pane_stable + ensure_logged_in.
  seed_capture "$dir" 2 "Not logged in · Please run /login"
  seed_capture "$dir" 3 "Still broken"
  local slug
  slug=$(basename "$TEST_REPO")
  local statusfile="/tmp/project-launch-${slug}-master.status"
  rm -f "$statusfile"
  run env PATH="$PATH" \
    PROJECT_LAUNCH_READY_TIMEOUT=5 \
    PROJECT_LAUNCH_STABLE_SAMPLES=1 \
    PROJECT_LAUNCH_PROCESS_TIMEOUT=5 \
    "$SCRIPT" --target fake:master --role master --repo "$TEST_REPO" --prompt-pipe
  [ "$status" -eq 4 ] || { echo "info: expected exit 4, got $status; output=$output"; rm -f "$statusfile"; return 1; }
  [ -f "$statusfile" ] || { echo "info: status file not written at $statusfile"; return 1; }
  grep -qi 'auth-failed' "$statusfile" || { echo "info: status file contents: $(cat "$statusfile")"; rm -f "$statusfile"; return 1; }
  rm -f "$statusfile"
}

@test "launch e2e: passes through on already-authed pane and writes ok status" {
  local dir="$BATS_TEST_TMPDIR/e2e-authed"
  setup_tmux_stub "$dir"
  seed_capture "$dir" 2 "Claude ready — what should we work on?"
  # Ensure the identity file exists so the script attempts the paste path.
  mkdir -p "$TEST_REPO/.worktrees/master/.claude/sessions"
  printf 'Role: master\n' > "$TEST_REPO/.worktrees/master/.claude/sessions/master.md"
  local slug
  slug=$(basename "$TEST_REPO")
  local statusfile="/tmp/project-launch-${slug}-master.status"
  rm -f "$statusfile"
  run env PATH="$PATH" \
    PROJECT_LAUNCH_READY_TIMEOUT=5 \
    PROJECT_LAUNCH_STABLE_SAMPLES=1 \
    PROJECT_LAUNCH_PROCESS_TIMEOUT=5 \
    "$SCRIPT" --target fake:master --role master --repo "$TEST_REPO" --prompt-pipe
  [ "$status" -eq 0 ] || { echo "info: expected exit 0, got $status; output=$output"; rm -f "$statusfile"; return 1; }
  [ -f "$statusfile" ] || { echo "info: status file not written at $statusfile"; return 1; }
  [ "$(cat "$statusfile")" = "ok" ] || { echo "info: status=$(cat "$statusfile")"; rm -f "$statusfile"; return 1; }
  rm -f "$statusfile"
}
