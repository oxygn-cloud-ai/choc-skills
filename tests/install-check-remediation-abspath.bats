#!/usr/bin/env bats

# CPT-132: CPT-78 added scoped remediation text to install.sh --check
# that suggests `skills/<name>/install.sh --check` for full health.
# The root installer resolves absolute paths for its own operations
# (REPO_DIR at line 12), so it runs fine from any CWD — but the
# remediation string it prints is a bare relative path. Users who
# invoked `/abs/path/to/choc-skills/install.sh --check` from elsewhere
# follow the guidance verbatim and hit `No such file or directory`.
#
# Fix: anchor the remediation path to $REPO_DIR (absolute) so the
# suggested command works from any CWD.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALLER="${REPO_DIR}/install.sh"

@test "install.sh exists (sanity)" {
  [ -f "$INSTALLER" ]
}

@test "install.sh --check remediation string uses REPO_DIR-anchored path (CPT-132)" {
  # Refuse the broken shape outright (bare relative `skills/X/install.sh`
  # inside a user-facing message). Allow the same substring in comments.
  #
  # Pattern we reject: the exact CPT-78 string with a bare relative
  # skills/ path inside the remediation-text parenthetical.
  if grep -qE 'run skills/\$\{name\}/install\.sh --check' "$INSTALLER"; then
    echo "install.sh --check still suggests a relative 'skills/\${name}/install.sh' path that breaks when invoked from outside the repo root" >&2
    grep -nE 'run skills/\$\{name\}/install\.sh' "$INSTALLER" >&2
    return 1
  fi
  # Positive: must anchor via REPO_DIR in the same neighbourhood
  grep -qE 'run \$\{REPO_DIR\}/skills/\$\{name\}/install\.sh' "$INSTALLER" || {
    echo "install.sh --check per-skill remediation no longer anchors via \${REPO_DIR}/skills/\${name}/install.sh" >&2
    return 1
  }
}

@test "install.sh --check runtime remediation is absolute when invoked from outside repo (CPT-132)" {
  # Simulate the ticket's reproducing case: invoke via absolute path from
  # a different CWD. The --check output's remediation text must contain
  # the absolute repo path so a user can copy-paste the command.
  local tmp_cwd
  tmp_cwd="$(mktemp -d)"

  # Use a fake HOME so --check doesn't muck with real installs. Every
  # skill will report missing and won't hit the per-skill "verified" line;
  # but the summary-line hint (line 348) ALSO uses the path phrasing and
  # should also be absolute.
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"

  # Run from tmp_cwd, installer via absolute path
  run bash -c "cd '$tmp_cwd' && bash '$INSTALLER' --check 2>&1"

  # Clean up
  rm -rf "$tmp_cwd"
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] && rm -rf "$HOME"

  # Refuse any remediation line that suggests `skills/<name>/install.sh`
  # as a command to run — even if multiple skills are missing, the hint
  # would be false guidance. Allowlist the summary form that anchors via
  # the absolute repo path.
  if echo "$output" | grep -qE 'run skills/[A-Za-z0-9_-]+/install\.sh --check'; then
    echo "--check output still tells the user to 'run skills/<name>/install.sh --check' (relative path) — broken from non-repo CWDs" >&2
    echo "$output" >&2
    return 1
  fi
}

@test "install.sh summary-line remediation hint mentions absolute per-skill install.sh path (CPT-132)" {
  # Line ~348 summary-line hint on the all-OK path: also pointed users
  # at "per-skill install.sh" abstractly. Anchor to concrete absolute
  # paths so users have something copy-pasteable.
  local summary_block
  summary_block=$(awk '/All.*skill.*SKILL\.md verified/,/^\}$/' "$INSTALLER")
  [ -n "$summary_block" ] || { echo "could not locate summary-line block" >&2; return 1; }

  # Require the absolute-path phrasing in that block. Accept either a
  # \$REPO_DIR anchor or an actual absolute path placeholder.
  echo "$summary_block" | grep -qE '\$\{REPO_DIR\}/skills/' || {
    echo "summary-line hint does not anchor per-skill install.sh path via \${REPO_DIR}/skills/" >&2
    echo "$summary_block" >&2
    return 1
  }
}
