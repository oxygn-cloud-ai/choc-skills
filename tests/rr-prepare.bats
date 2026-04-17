#!/usr/bin/env bats

# Tests for rr-prepare.sh — symlink resolution and path validation.
#
# CPT-26: Verify that WORK_DIR symlinks are resolved before the case guard,
# preventing symlink traversal attacks on rm -rf.
#
# Each test uses a temporary HOME so it never touches the real environment.
#
# PARALLEL-UNSAFE: This test suite reassigns HOME in setup().

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
RR_PREPARE="${REPO_DIR}/skills/rr/bin/rr-prepare.sh"
RR_FINALIZE="${REPO_DIR}/skills/rr/bin/rr-finalize.sh"

setup() {
  export HOME="$(mktemp -d)"
  # Create a fake target directory that looks like a valid rr-work dir
  FAKE_TARGET="$(mktemp -d)"
  touch "$FAKE_TARGET/batch.log"
  touch "$FAKE_TARGET/discovery.json"
  # Suppress Jira credentials check — we're only testing path validation
  export JIRA_EMAIL="test@example.com"
  export JIRA_API_KEY="fake-key"
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] || return 0
  rm -rf "$HOME"
  [ -d "$FAKE_TARGET" ] && rm -rf "$FAKE_TARGET"
}

# --- rr-prepare.sh: symlink resolution ---

@test "rr-prepare --reset rejects symlink under HOME pointing outside HOME" {
  # Test premise: the resolved symlink target must be outside $HOME AND /tmp,
  # which is what the case guard in rr-prepare.sh rejects.
  #
  # CPT-96: previous version used /var/tmp/* as the attack path, but on some
  # Linux distros (including GitHub Actions ubuntu-latest) /var/tmp resolves
  # into /tmp via symlink or bind mount, making that path match the allowed
  # /tmp/* case. We probe at runtime for a writable location that provably
  # resolves outside /tmp and outside $HOME.
  local attack_dir=""
  local candidate resolved_home resolved_candidate
  resolved_home="$(realpath "$HOME" 2>/dev/null)" || resolved_home="$HOME"
  for candidate in /dev/shm /var/tmp /opt; do
    if [ -d "$candidate" ] && [ -w "$candidate" ]; then
      # Verify this candidate does not resolve into /tmp, /private/tmp, or $HOME
      resolved_candidate="$(realpath "$candidate" 2>/dev/null)" || resolved_candidate="$candidate"
      case "$resolved_candidate" in
        /tmp|/tmp/*|"$resolved_home"|"$resolved_home"/*|/private/tmp|/private/tmp/*) continue ;;
        *) attack_dir="$candidate/rr-test-attack-$$"; break ;;
      esac
    fi
  done

  [ -n "$attack_dir" ] || skip "no writable location outside /tmp and \$HOME available on this system"

  mkdir -p "$attack_dir"
  touch "$attack_dir/batch.log"
  ln -sf "$attack_dir" "$HOME/rr-work"
  export RR_WORK_DIR="$HOME/rr-work"

  run "$RR_PREPARE" --reset
  rm -rf "$attack_dir"

  [ "$status" -ne 0 ]
  [[ "$output" == *"FATAL"* ]] || [[ "$output" == *"symlink"* ]] || [[ "$output" == *"Refusing"* ]]
}

@test "rr-prepare --reset works with normal (non-symlink) path under HOME" {
  mkdir -p "$HOME/rr-work"
  touch "$HOME/rr-work/batch.log"
  touch "$HOME/rr-work/discovery.json"
  export RR_WORK_DIR="$HOME/rr-work"

  run "$RR_PREPARE" --reset

  [ "$status" -eq 0 ]
  [[ "$output" == *"reset"* ]]
  # Directory should be deleted
  [ ! -d "$HOME/rr-work" ]
}

@test "rr-prepare rejects WORK_DIR that is a symlink resolving outside allowed paths" {
  local attack_dir="/var/tmp/rr-test-attack2-$$"
  mkdir -p "$attack_dir"
  ln -sf "$attack_dir" "$HOME/rr-work"
  export RR_WORK_DIR="$HOME/rr-work"

  run "$RR_PREPARE"
  rm -rf "$attack_dir"

  [ "$status" -ne 0 ]
  [[ "$output" == *"FATAL"* ]]
}

@test "rr-prepare accepts normal path under /tmp" {
  local tmp_work="/tmp/rr-test-work-$$"
  mkdir -p "$tmp_work"
  touch "$tmp_work/batch.log"
  touch "$tmp_work/discovery.json"
  export RR_WORK_DIR="$tmp_work"

  run "$RR_PREPARE" --reset

  rm -rf "$tmp_work" 2>/dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"reset"* ]]
}

# --- rr-finalize.sh: path validation ---

@test "rr-finalize rejects WORK_DIR that is a symlink resolving outside allowed paths" {
  local attack_dir="/var/tmp/rr-test-attack3-$$"
  mkdir -p "$attack_dir"
  ln -sf "$attack_dir" "$HOME/rr-work"
  export RR_WORK_DIR="$HOME/rr-work"

  run "$RR_FINALIZE"
  rm -rf "$attack_dir"

  [ "$status" -ne 0 ]
  [[ "$output" == *"FATAL"* ]]
}

# --- CPT-100: first-run on symlinked HOME must not FATAL on path allowlist ---
#
# When HOME has a distinct canonical form (e.g. macOS `/var/folders/...` →
# `/private/var/folders/...`, autofs mounts, firmlinked network homes) and
# WORK_DIR doesn't exist yet (first run), CPT-26's realpath gate stays
# disengaged (`[ -e "$WORK_DIR" ]` false) and the case guard compares an
# unresolved `$HOME/rr-work` against a canonicalized `$RESOLVED_HOME/*`.
# They don't match, and the script FATALs before ever creating the dir.
# The fix is to canonicalize the parent of WORK_DIR when WORK_DIR itself
# doesn't exist.
#
# This test requires a HOME whose realpath differs AND whose path is not
# under /tmp (the /tmp/* allow-arm would hide the bug otherwise). macOS's
# `/var/folders/...` default mktemp location satisfies both conditions.
# On Linux, mktemp gives `/tmp/...` with no symlink indirection, so the
# scenario is not reachable — skip.

_cpt100_setup_symlinked_home() {
  # Returns 0 with HOME set to a symlinked home outside /tmp, or 1 if not possible.
  local real_home="$1"
  local resolved
  resolved="$(realpath "$real_home" 2>/dev/null)" || resolved="$real_home"
  # Must have a distinct canonical form
  [ "$resolved" != "$real_home" ] || return 1
  # Must not be under /tmp (would match /tmp/* allow-arm and mask the bug)
  case "$real_home" in
    /tmp|/tmp/*|/private/tmp|/private/tmp/*) return 1 ;;
  esac
  case "$resolved" in
    /tmp|/tmp/*|/private/tmp|/private/tmp/*) return 1 ;;
  esac
  return 0
}

@test "rr-prepare succeeds on first run when HOME is symlinked (CPT-100)" {
  if ! _cpt100_setup_symlinked_home "$HOME"; then
    skip "this platform's HOME has no distinct-canonical-form outside /tmp (typical on Linux)"
  fi

  # WORK_DIR does not exist yet. Under the CPT-26 bug, the case guard fails
  # because WORK_DIR stays unresolved while RESOLVED_HOME is canonicalized.
  export RR_WORK_DIR="$HOME/rr-work"
  [ ! -e "$RR_WORK_DIR" ]

  run "$RR_PREPARE" --reset

  # --reset may fail for other reasons (no Jira session, etc.), but it MUST NOT
  # fail with the path-allowlist FATAL message. That's the CPT-100 contract.
  echo "status=$status" >&2
  echo "output=$output" >&2
  [[ "$output" != *"FATAL: RR_WORK_DIR must be under"* ]]
}

@test "rr-finalize first run on symlinked HOME does not FATAL on path allowlist (CPT-100)" {
  if ! _cpt100_setup_symlinked_home "$HOME"; then
    skip "this platform's HOME has no distinct-canonical-form outside /tmp (typical on Linux)"
  fi

  export RR_WORK_DIR="$HOME/rr-work"
  [ ! -e "$RR_WORK_DIR" ]

  run "$RR_FINALIZE"

  echo "status=$status" >&2
  echo "output=$output" >&2
  [[ "$output" != *"FATAL: RR_WORK_DIR must be under"* ]]
}

@test "rr-prepare.sh canonicalizes WORK_DIR parent when WORK_DIR does not exist (CPT-100)" {
  # Source-level assertion: the fix must canonicalize the parent directory
  # of WORK_DIR when WORK_DIR itself doesn't exist yet. Expected patterns:
  # - `$(dirname "$WORK_DIR")` paired with `realpath ... basename ...`
  # - OR an equivalent `if [ -e "$WORK_DIR" ]; then ... else parent realpath`
  # Refuse the known-buggy form outright.
  local src="$RR_PREPARE"

  # Must NOT contain the bare gated realpath without a parent-dir fallback.
  # Detect the buggy shape: a single `[ -e "$WORK_DIR" ] && WORK_DIR=` line
  # not followed shortly by a dirname/parent canonicalization.
  if grep -qE '^[[:space:]]*\[ -e "\$WORK_DIR" \] && WORK_DIR="\$\(realpath "\$WORK_DIR"\)"[[:space:]]*$' "$src"; then
    if ! grep -qE 'dirname "\$WORK_DIR"' "$src"; then
      echo "rr-prepare.sh still uses the CPT-26 bare gated realpath without a parent-dir fallback" >&2
      return 1
    fi
  fi

  # Must contain a dirname-based canonicalization
  grep -qE 'dirname "\$WORK_DIR"' "$src"
}

@test "rr-finalize.sh canonicalizes WORK_DIR parent when WORK_DIR does not exist (CPT-100)" {
  local src="$RR_FINALIZE"
  if grep -qE '^[[:space:]]*\[ -e "\$WORK_DIR" \] && WORK_DIR="\$\(realpath "\$WORK_DIR"\)"[[:space:]]*$' "$src"; then
    if ! grep -qE 'dirname "\$WORK_DIR"' "$src"; then
      echo "rr-finalize.sh still uses the CPT-26 bare gated realpath without a parent-dir fallback" >&2
      return 1
    fi
  fi
  grep -qE 'dirname "\$WORK_DIR"' "$src"
}
