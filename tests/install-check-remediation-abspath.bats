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
  # Positive: must anchor via REPO_DIR in the same neighbourhood. Accept
  # either the pre-CPT-142 unquoted form or the CPT-142 quoted form
  # (run "${REPO_DIR}/..." — escaped \" in bash double-quoted string).
  grep -qE 'run (\\")?\$\{REPO_DIR\}/skills/\$\{name\}/install\.sh' "$INSTALLER" || {
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

# --- CPT-142: CPT-132's remediation string works from outside the repo, but
#     (1) unquoted $REPO_DIR breaks when the repo lives under a path with
#         spaces (e.g. /Volumes/Team Drive/choc-skills) — shell splits the
#         copy-pasted command into separate words;
#     (2) the summary-line uses literal `<name>` as a placeholder — POSIX
#         shells parse `< name` as input redirection, so users who follow
#         the hint verbatim hit `name: No such file or directory`.

@test "CPT-142: per-skill remediation quotes the \${REPO_DIR} path" {
  # The per-skill ok() line at ~346 must wrap ${REPO_DIR}/skills/${name}/install.sh
  # in double quotes so shells treat it as one argument even when the path
  # contains spaces. The source uses escaped quotes (\") inside a bash
  # double-quoted string — the regex must match those literal \" bytes.
  grep -qE '\\"\$\{REPO_DIR\}/skills/\$\{name\}/install\.sh\\"' "$INSTALLER" || {
    echo 'per-skill remediation string does not quote "${REPO_DIR}/skills/${name}/install.sh" — breaks on paths with spaces' >&2
    grep -nE 'REPO_DIR\}/skills/\$\{name\}/install\.sh' "$INSTALLER" >&2
    return 1
  }
}

@test "CPT-142: summary-line remediation does not use a raw '<name>' placeholder" {
  # `<name>` triggers POSIX shell input-redirection. The summary-line must
  # use a copy-safe placeholder form. Accept uppercase NAME or any braces/
  # angle-bracket alternative that doesn't trigger shell parsing when the
  # user copy-pastes the command verbatim.
  local summary_block
  summary_block=$(awk '/All.*skill.*SKILL\.md verified/,/^\}$/' "$INSTALLER")
  [ -n "$summary_block" ] || { echo "could not locate summary-line block" >&2; return 1; }

  if echo "$summary_block" | grep -qE 'skills/<name>/install\.sh'; then
    echo 'summary-line uses literal <name> — shells parse that as input redirection from a file named "name"' >&2
    echo "$summary_block" >&2
    return 1
  fi
}

@test "CPT-142: summary-line remediation quotes the \${REPO_DIR} path" {
  # Same quoting requirement as the per-skill line — the summary hint's
  # ${REPO_DIR}/skills/NAME/install.sh must be wrapped in double quotes.
  # The source uses escaped quotes (\") inside a bash double-quoted string.
  local summary_block
  summary_block=$(awk '/All.*skill.*SKILL\.md verified/,/^\}$/' "$INSTALLER")
  [ -n "$summary_block" ] || { echo "could not locate summary-line block" >&2; return 1; }

  echo "$summary_block" | grep -qE '\\"\$\{REPO_DIR\}/skills/[^\\]+/install\.sh\\"' || {
    echo "summary-line remediation does not quote \"\${REPO_DIR}/skills/.../install.sh\" — breaks on paths with spaces" >&2
    echo "$summary_block" >&2
    return 1
  }
}

@test "CPT-142: --check output on spaces-in-path repo emits quoted remediation" {
  # End-to-end: copy the installer into a worktree under a path containing
  # a space, run --check, assert the output contains a quoted
  # ${REPO_DIR}/.../install.sh reference that would survive copy-paste.
  local spaced_dir
  spaced_dir="$(mktemp -d)/repo with space"
  mkdir -p "$spaced_dir/skills" "$spaced_dir/scripts"
  cp "$INSTALLER" "$spaced_dir/install.sh"
  chmod +x "$spaced_dir/install.sh"

  # Copy validate-skills.sh if it exists (optional — --check only needs install.sh)
  if [ -f "${REPO_DIR}/scripts/generate-checksums.sh" ]; then
    cp "${REPO_DIR}/scripts/generate-checksums.sh" "$spaced_dir/scripts/" || true
  fi

  # Copy at least one skill so the per-skill line fires
  if [ -d "${REPO_DIR}/skills/rr" ]; then
    cp -r "${REPO_DIR}/skills/rr" "$spaced_dir/skills/" || true
  fi

  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude/skills/rr"
  # Seed a matching install so --check finds the skill "installed"
  if [ -f "${spaced_dir}/skills/rr/SKILL.md" ]; then
    cp "${spaced_dir}/skills/rr/SKILL.md" "${HOME}/.claude/skills/rr/SKILL.md"
  fi

  run bash -c "cd / && bash '$spaced_dir/install.sh' --check 2>&1"

  # Clean up
  [[ "$spaced_dir" == /tmp/* || "$spaced_dir" == /var/folders/* || "$spaced_dir" == /private/* ]] && \
    rm -rf "$(dirname "$spaced_dir")"
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/* ]] && rm -rf "$HOME"

  # If the output references the spaced path, it must be quoted. Accept
  # either the per-skill "verified" hint or the summary hint; we're looking
  # for evidence that at least one emission escaped the quoting issue.
  if echo "$output" | grep -qE 'repo with space'; then
    echo "$output" | grep -qE '"[^"]*repo with space[^"]*/install\.sh"' || {
      echo "--check output references the spaced path without quoting — copy-paste will break" >&2
      echo "$output" >&2
      return 1
    }
  fi
  # If the test env couldn't reproduce the spaced path in the output (skill
  # not installed, etc.), the structural tests above still enforce the
  # quoting invariant statically.
}
