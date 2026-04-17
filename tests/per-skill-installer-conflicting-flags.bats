#!/usr/bin/env bats

# CPT-123: CPT-76's order-independent argparse in the 5 per-skill installers
# (chk1, chk2, project, ra, rr) silently overwrites ACTION each time it
# sees another mode flag — so `./install.sh --help --uninstall` runs
# uninstall, `--uninstall --check` runs check (skipping the uninstall the
# user intended), etc. A wrapper script that composes flags to go "verify
# then uninstall" gets unpredictable behaviour and can turn a read-only
# probe into an unexpected destructive action.
#
# Fix: conflicting action flags die with a clear error at parse time.
# Same flag twice is fine (idempotent). --force is orthogonal and still
# combines freely.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# Discover the 5 per-skill installers the ticket lists.
INSTALLERS=(
  "${REPO_DIR}/skills/chk1/install.sh"
  "${REPO_DIR}/skills/chk2/install.sh"
  "${REPO_DIR}/skills/project/install.sh"
  "${REPO_DIR}/skills/ra/install.sh"
  "${REPO_DIR}/skills/rr/install.sh"
)

setup() {
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] || return 0
  rm -rf "$HOME"
}

# Per the ticket, exercise each of the three concrete hazardous combinations
# on every affected installer.

@test "per-skill installers die on --help + --uninstall conflict (CPT-123)" {
  local failures=0
  for inst in "${INSTALLERS[@]}"; do
    [ -f "$inst" ] || continue
    run bash "$inst" --help --uninstall
    if [ "$status" -eq 0 ]; then
      echo "$inst: --help --uninstall did not die — silent last-wins regression" >&2
      failures=$((failures + 1))
      continue
    fi
    if ! echo "$output" | grep -qiE 'conflict|cannot combine|mutually exclusive'; then
      echo "$inst: --help --uninstall failed without a conflict message: $output" >&2
      failures=$((failures + 1))
    fi
  done
  [ "$failures" -eq 0 ]
}

@test "per-skill installers die on --version + --uninstall conflict (CPT-123)" {
  local failures=0
  for inst in "${INSTALLERS[@]}"; do
    [ -f "$inst" ] || continue
    run bash "$inst" --version --uninstall
    if [ "$status" -eq 0 ]; then
      echo "$inst: --version --uninstall did not die" >&2
      failures=$((failures + 1))
      continue
    fi
    if ! echo "$output" | grep -qiE 'conflict|cannot combine|mutually exclusive'; then
      echo "$inst: --version --uninstall failed without a conflict message: $output" >&2
      failures=$((failures + 1))
    fi
  done
  [ "$failures" -eq 0 ]
}

@test "per-skill installers die on --uninstall + --check conflict (CPT-123)" {
  local failures=0
  for inst in "${INSTALLERS[@]}"; do
    [ -f "$inst" ] || continue
    run bash "$inst" --uninstall --check
    if [ "$status" -eq 0 ]; then
      echo "$inst: --uninstall --check did not die — silent last-wins regression" >&2
      failures=$((failures + 1))
      continue
    fi
    if ! echo "$output" | grep -qiE 'conflict|cannot combine|mutually exclusive'; then
      echo "$inst: --uninstall --check failed without a conflict message: $output" >&2
      failures=$((failures + 1))
    fi
  done
  [ "$failures" -eq 0 ]
}

@test "per-skill installers still accept the same action flag twice (CPT-123)" {
  # Idempotency: passing --help twice is a wrapper-script convenience,
  # not a conflict. Must succeed (same as a single --help).
  local failures=0
  for inst in "${INSTALLERS[@]}"; do
    [ -f "$inst" ] || continue
    run bash "$inst" --help --help
    if [ "$status" -ne 0 ]; then
      echo "$inst: --help --help incorrectly failed: $output" >&2
      failures=$((failures + 1))
    fi
  done
  [ "$failures" -eq 0 ]
}

@test "per-skill installers still accept --check + --force combination (CPT-123 non-conflict)" {
  # --force is orthogonal to the action flags and must still combine
  # freely with any of them. Using --check because it's read-only and
  # doesn't need skill files to exist in $HOME for the test.
  local failures=0
  for inst in "${INSTALLERS[@]}"; do
    [ -f "$inst" ] || continue
    run bash "$inst" --check --force
    # Exit code may be non-zero (check can legitimately fail on a freshly
    # mktemp'd HOME with no skills installed). What matters is that the
    # parser did NOT die with "conflict" — --force is orthogonal.
    if echo "$output" | grep -qiE 'conflicting action flags|cannot combine.*force'; then
      echo "$inst: --check --force incorrectly flagged as conflict: $output" >&2
      failures=$((failures + 1))
    fi
  done
  [ "$failures" -eq 0 ]
}
