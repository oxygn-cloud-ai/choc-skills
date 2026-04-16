#!/usr/bin/env bash
# _launch-auth.sh — auth detection + /login orchestration for project-launch-session.sh.
#
# Sourced by project-launch-session.sh after log/warn/wait_pane_stable are
# defined. Split out into its own file so classify_auth_state is unit-testable
# without a live tmux (bats sources this lib directly, stubs tmux via PATH,
# stubs wait_pane_stable as a shell function).
#
# Ticket: CPT-71.
#
# Caller-scope dependencies (lookup occurs at call time, not at source time):
#   log()               — role-prefixed stdout logger
#   warn()              — role-prefixed stderr warner
#   wait_pane_stable()  — polls tmux capture-pane for stable output
#   $TARGET             — tmux pane target (session:window)
#   $ROLE               — current role name (for logging only)
#   tmux on PATH
#
# This file is intentionally NOT executable as a standalone script — it exits
# with an error if run directly so someone doesn't mistake it for a CLI tool.

# Guard against direct execution.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "_launch-auth.sh: this file is a library — source it, don't run it." >&2
  exit 2
fi

# classify_auth_state — pure classifier for Claude-Code TUI pane captures.
# Echoes exactly one of:
#   authed          — pane shows a ready Claude prompt (no login markers)
#   not-logged-in   — pane shows "Not logged in · Please run /login"
#   login-menu      — pane shows the /login method picker (Claude subscription option)
#   login-complete  — pane shows "Login successful! Press Enter to continue."
#   keychain-locked — pane references `security unlock-keychain` (macOS keychain locked)
#   unclear         — pane mentions login but none of the specific markers match
# Returns 0 regardless of outcome (errors surface via the echoed value).
#
# Priority order is most-specific first: keychain > login-complete > login-menu
# > not-logged-in > authed > unclear. This matters because "Login successful"
# is shown in a keychain-locked error pane too — but we prefer the more-specific
# keychain-locked verdict so the caller can warn instead of treating it as success.
# Usage: classify_auth_state "<pane capture text>"
classify_auth_state() {
  local cap="$1"
  if [[ "$cap" == *"security unlock-keychain"* ]]; then
    printf 'keychain-locked\n'; return 0
  fi
  if [[ "$cap" == *"Login successful"* ]]; then
    printf 'login-complete\n'; return 0
  fi
  if [[ "$cap" == *"Claude subscription"* ]]; then
    printf 'login-menu\n'; return 0
  fi
  if [[ "$cap" == *"Not logged in"* ]]; then
    printf 'not-logged-in\n'; return 0
  fi
  if [[ "$cap" != *"login"* ]] && [[ "$cap" != *"Login"* ]] && [[ "$cap" != *"/login"* ]]; then
    printf 'authed\n'; return 0
  fi
  printf 'unclear\n'
}

# ensure_logged_in — drive Claude TUI through the /login flow when the pane
# isn't authenticated. Returns 0 if the pane is (or becomes) ready; returns 1
# if authentication couldn't be completed automatically (operator intervention
# required).
#
# Flow for a not-logged-in pane:
#   1. send "/login" (literal) + Enter
#   2. wait for stability, re-capture, expect login-menu
#   3. send Enter (selects default option 1 — Claude subscription)
#   4. wait for stability, re-capture, expect login-complete
#   5. send Enter to dismiss "Press Enter to continue"
#
# Any step mismatching its expected state logs a warn and returns 1. Keychain-
# locked panes return 1 immediately without sending any keystrokes (the user
# must run `security unlock-keychain` manually; auto-unlock is security-hostile
# and out of scope per CPT-71 §"Out of scope").
ensure_logged_in() {
  local cap state
  cap=$(tmux capture-pane -p -t "$TARGET" 2>/dev/null || true)
  state=$(classify_auth_state "$cap")
  case "$state" in
    authed)
      return 0
      ;;
    keychain-locked)
      warn "keychain locked — run 'security unlock-keychain ~/Library/Keychains/login.keychain-db' then re-launch this role"
      return 1
      ;;
    unclear)
      warn "initial pane capture is ambiguous (no login marker, but contains the word 'login'). Pane tail: $(printf '%s' "$cap" | tail -n 3 | tr '\n' ' ')"
      return 1
      ;;
    login-menu|login-complete)
      warn "pane is mid-login (state=$state) — operator must resolve before re-launching"
      return 1
      ;;
    not-logged-in)
      log "not logged in — dispatching /login"
      tmux send-keys -t "$TARGET" -l "/login"
      tmux send-keys -t "$TARGET" Enter
      if ! wait_pane_stable 15; then
        warn "login menu did not appear within 15s of /login"
        return 1
      fi
      cap=$(tmux capture-pane -p -t "$TARGET" 2>/dev/null || true)
      state=$(classify_auth_state "$cap")
      if [[ "$state" != "login-menu" ]]; then
        warn "expected login menu after /login, got state=$state"
        return 1
      fi
      # Select default option 1 (Claude subscription)
      tmux send-keys -t "$TARGET" Enter
      if ! wait_pane_stable 30; then
        warn "login did not complete within 30s"
        return 1
      fi
      cap=$(tmux capture-pane -p -t "$TARGET" 2>/dev/null || true)
      state=$(classify_auth_state "$cap")
      case "$state" in
        login-complete)
          tmux send-keys -t "$TARGET" Enter
          wait_pane_stable 10 || true
          log "login successful"
          return 0
          ;;
        keychain-locked)
          warn "keychain locked mid-login — run 'security unlock-keychain' then re-launch"
          return 1
          ;;
        *)
          warn "login outcome unclear (state=$state). Pane tail: $(printf '%s' "$cap" | tail -n 3 | tr '\n' ' ')"
          return 1
          ;;
      esac
      ;;
  esac
}

# write_status — persist a one-word outcome for the launch-report aggregator.
# /project:launch Step 8 reads /tmp/project-launch-<slug>-<role>.status to
# populate the auth column.
# Valid statuses: ok | auth-failed | auth-recovered | timeout | idle-skipped | dry-run
# Usage: write_status <project-slug> <role> <status>
write_status() {
  local slug="$1" role="$2" status="$3"
  local file="/tmp/project-launch-${slug}-${role}.status"
  printf '%s\n' "$status" > "$file"
  chmod 600 "$file" 2>/dev/null || true
}
