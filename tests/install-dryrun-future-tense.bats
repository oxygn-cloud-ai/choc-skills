#!/usr/bin/env bats

# CPT-79: `./install.sh --dry-run` printed "ok N skill(s) installed" at
# the end of its install-all loop. install_skill() returns 0 cleanly in
# dry-run mode (short-circuits before the cp), so the enclosing counter
# increments, and the shared summary line uses past-tense "installed"
# even though nothing was copied. Log-scrapers and quick-glance readers
# can misread as confirmation of actual install.
#
# Fix: branch the final summary line on $DRY_RUN — use future-tense
# "would be installed" in dry-run mode, leave past-tense as-is for real
# installs.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALLER="$REPO_DIR/install.sh"

setup() {
  [ -f "$INSTALLER" ]
  # Use a fake HOME so we don't touch the real installs.
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/* ]] && rm -rf "$HOME"
}

@test "CPT-79: ./install.sh --dry-run summary uses future-tense 'would be installed'" {
  run bash "$INSTALLER" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"would be installed"* ]]
}

@test "CPT-79: ./install.sh --dry-run summary does NOT use past-tense 'skill(s) installed'" {
  # Capture output — strip the dry-run future-tense line if present, then
  # assert no past-tense "skill(s) installed" remains anywhere in the rest.
  # (The per-skill "Would install 'X' vY.Z to ..." lines use a distinct
  # phrase "Would install" so they don't false-match.)
  run bash "$INSTALLER" --dry-run
  [ "$status" -eq 0 ]
  # Strip future-tense form via bash parameter expansion to avoid grep -v
  local filtered="${output//would be installed*/}"
  if echo "$filtered" | grep -qE 'skill\(s\) installed'; then
    echo "--dry-run still emits past-tense 'skill(s) installed' summary" >&2
    echo "$output" >&2
    return 1
  fi
}

@test "CPT-79: ./install.sh --dry-run clearly marks output as dry-run (no mutation)" {
  run bash "$INSTALLER" --dry-run
  [ "$status" -eq 0 ]
  # Accept either "(dry run)" parenthetical or "[dry-run]" bracketed form
  # as an explicit dry-run marker on the summary line.
  local filtered
  filtered=$(echo "$output" | grep -E 'skill\(s\) would be installed|\[dry-run\]')
  [ -n "$filtered" ] || {
    echo "--dry-run output lacks an explicit dry-run marker near the summary" >&2
    echo "$output" >&2
    return 1
  }
}

# --- Static: install.sh summary line actually branches on $DRY_RUN ---

@test "CPT-79: install.sh install-all summary branches on \$DRY_RUN" {
  # The summary block that previously hardcoded "${count} skill(s) installed"
  # must now test $DRY_RUN and emit a distinct future-tense variant.
  grep -qE '\$\{count\} skill\(s\) would be installed' "$INSTALLER" || {
    echo "install.sh lacks the future-tense summary branch" >&2
    return 1
  }
  # The original past-tense string must still exist (for real installs).
  grep -qE '\$\{count\} skill\(s\) installed' "$INSTALLER" || {
    echo "install.sh no longer has the past-tense summary for real installs" >&2
    return 1
  }
}
