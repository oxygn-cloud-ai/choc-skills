#!/usr/bin/env bats

# CPT-80: iterm2-tmux lives under skills/ and has its own install.sh,
# but it is NOT a Claude skill (no SKILL.md, no slash commands — macOS-
# only terminal tooling). The root installer's install_skill() skips
# dirs without SKILL.md, so iterm2-tmux was invisible to every root CLI
# path (--list, --help, --dry-run, positional install) even though
# README.md documents it as a first-class entry.
#
# Fix: extend list_skills() with a second section that enumerates
# standalone companion tools — directories under skills/ with install.sh
# but NO SKILL.md — and advertise with a [standalone] marker pointing
# users to run skills/<name>/install.sh directly.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALLER="$REPO_DIR/install.sh"

setup() {
  [ -f "$INSTALLER" ]
  # Use a fake HOME so --list's [installed] marker logic doesn't touch real installs.
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
}

teardown() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/* ]] && rm -rf "$HOME"
}

# --- --list output includes every directory under skills/ that ships
#     install.sh, either as a regular skill (SKILL.md present) or a
#     standalone companion tool (install.sh but no SKILL.md).

@test "CPT-80: ./install.sh --list includes iterm2-tmux" {
  run bash "$INSTALLER" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"iterm2-tmux"* ]]
}

@test "CPT-80: --list marks iterm2-tmux as standalone" {
  run bash "$INSTALLER" --list
  [ "$status" -eq 0 ]
  # Must appear WITH the [standalone] marker so users know the root
  # installer won't install it.
  echo "$output" | grep -E 'iterm2-tmux.*\[standalone\]' >/dev/null || {
    echo "iterm2-tmux listed but NOT marked [standalone]" >&2
    echo "$output" >&2
    return 1
  }
}

@test "CPT-80: --list mentions running skills/<name>/install.sh directly" {
  run bash "$INSTALLER" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"skills/<name>/install.sh"* ]] || [[ "$output" == *"skills/"*"/install.sh"* ]]
}

# --- Generic invariant: every directory under skills/ that carries an
#     install.sh must appear in --list output, either as a regular skill
#     (implicitly, with its own name) or as a companion tool.

@test "CPT-80: every skills/*/install.sh directory is discoverable via --list" {
  run bash "$INSTALLER" --list
  [ "$status" -eq 0 ]
  local missing=""
  for dir in "$REPO_DIR"/skills/*/; do
    [ -d "$dir" ] || continue
    [ -f "${dir}install.sh" ] || continue
    local name
    name="$(basename "$dir")"
    [[ "$name" == _* ]] && continue
    if ! echo "$output" | grep -qE "(^|[[:space:]])${name}([[:space:]]|$)"; then
      missing="$missing $name"
    fi
  done
  if [ -n "$missing" ]; then
    echo "--list missing these installable directories:$missing" >&2
    echo "$output" >&2
    return 1
  fi
}

# --- Static: --help text mentions --list covers standalone tools too ---

@test "CPT-80: --help mentions --list covers standalone companion tools" {
  run bash "$INSTALLER" --help
  [ "$status" -eq 0 ]
  echo "$output" | grep -iE 'standalone|companion' >/dev/null || {
    echo "--help does not mention standalone/companion tools" >&2
    return 1
  }
}

# --- CPT-163: exec-bit-stripped safety — the advertised install command
#     must be `bash skills/<name>/install.sh`, not `skills/<name>/install.sh`
#     directly. Users downloading via GitHub zip, Windows file shares, or
#     some corporate shared filesystems lose the exec bit; a direct
#     invocation then fails with "Permission denied". The bash wrapper
#     runs regardless of exec bit. CPT-80's `[ -f ... ]` guard only checks
#     existence, not executability, so the hint must be robust by shape.

@test "CPT-163: --list advertises bash-prefix install command (exec-bit-stripped safety)" {
  run bash "$INSTALLER" --list
  [ "$status" -eq 0 ]
  # The Companion tools header must advertise `bash skills/<name>/install.sh`
  # so the printed command works even when the install.sh exec bit is absent.
  if ! echo "$output" | grep -qE 'bash[[:space:]]+skills/[^[:space:]]+install\.sh'; then
    echo "--list companion-tools header does not advertise bash-prefix invocation" >&2
    echo "Expected pattern: 'bash skills/<name>/install.sh'" >&2
    echo "Actual output:" >&2
    echo "$output" >&2
    return 1
  fi
}

# --- Static: list_skills() has a standalone-tool enumeration block ---

@test "CPT-80: install.sh list_skills() enumerates install.sh-without-SKILL.md directories" {
  # Structural check that the second loop in list_skills() filters on
  # [ -f install.sh ] AND [ ! -f SKILL.md ].
  awk '/^list_skills\(\)/{flag=1} flag; /^\}$/{if(flag){print "---end---"; flag=0}}' "$INSTALLER" \
    | grep -qE '\[ -f .*install\.sh.* \] \|\| continue' || {
    echo "list_skills() lacks the install.sh existence guard for standalone tools" >&2
    return 1
  }
  awk '/^list_skills\(\)/{flag=1} flag; /^\}$/{if(flag){print "---end---"; flag=0}}' "$INSTALLER" \
    | grep -qE '\[ -f .*SKILL\.md.* \] && continue' || {
    echo "list_skills() lacks the SKILL.md absence guard for standalone tools" >&2
    return 1
  }
}
