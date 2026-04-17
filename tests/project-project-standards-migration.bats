#!/usr/bin/env bats

# CPT-124: GITHUB_CONFIG.md has been retired and replaced by
# PROJECT_STANDARDS.md (narrative standards) + PROJECT_CONFIG.json
# (per-project machine-readable config). The project skill still
# references the retired file in several places — including a required
# check in install.sh, which under CPT-77's exit-nonzero contract now
# fails every modern install. Fix: migrate all GITHUB_CONFIG.md refs
# to PROJECT_STANDARDS.md across install.sh, SKILL.md, README.md,
# and commands/new.md.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# Files in the project skill that must no longer reference GITHUB_CONFIG.md.
# Listed explicitly so adding a new file doesn't silently slip a new ref in.
PROJECT_FILES=(
  "${REPO_DIR}/skills/project/install.sh"
  "${REPO_DIR}/skills/project/SKILL.md"
  "${REPO_DIR}/skills/project/README.md"
  "${REPO_DIR}/skills/project/commands/new.md"
)

@test "no project skill file uses GITHUB_CONFIG.md as a live requirement (CPT-124)" {
  # "Retired GITHUB_CONFIG.md" migration-nudge references are legitimate
  # documentation (tell users the file is safe to remove). What we must
  # NOT see is any reference that treats GITHUB_CONFIG.md as a LIVE runtime
  # requirement — phrases that imply the file is still needed for the
  # skill to work.
  local failures=0
  for f in "${PROJECT_FILES[@]}"; do
    [ -f "$f" ] || continue
    # Flag lines that mention GITHUB_CONFIG.md but NOT "retired"/"replaces"/"supersed"
    while IFS= read -r line; do
      if echo "$line" | grep -qiE 'retired|replaces|supersed|stale'; then
        continue  # migration-nudge language — allowed
      fi
      echo "$f: live GITHUB_CONFIG.md reference without retirement annotation: $line" >&2
      failures=$((failures + 1))
    done < <(grep -nF 'GITHUB_CONFIG.md' "$f" || true)
  done
  [ "$failures" -eq 0 ]
}

@test "project skill files reference PROJECT_STANDARDS.md as runtime reference (CPT-124)" {
  # Positive assertion: install.sh + SKILL.md must reference the new file,
  # so we don't accidentally drop the reference entirely.
  for f in "${REPO_DIR}/skills/project/install.sh" "${REPO_DIR}/skills/project/SKILL.md"; do
    [ -f "$f" ] || { echo "$f not found" >&2; return 1; }
    grep -qF 'PROJECT_STANDARDS.md' "$f" || {
      echo "$f does not reference PROJECT_STANDARDS.md (CPT-124)" >&2
      return 1
    }
  done
}

setup_fake_home() {
  # Fresh HOME with the new authoritative files (MSA + PROJECT_STANDARDS.md)
  # but no retired GITHUB_CONFIG.md. This is the exact state CPT-124
  # calls "valid modern install".
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
  touch "${HOME}/.claude/MULTI_SESSION_ARCHITECTURE.md"
  touch "${HOME}/.claude/PROJECT_STANDARDS.md"
}

teardown_fake_home() {
  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] || return 0
  rm -rf "$HOME"
}

@test "project install.sh --check does NOT flag missing GITHUB_CONFIG.md on modern install (CPT-124)" {
  setup_fake_home
  local installer="${REPO_DIR}/skills/project/install.sh"

  run bash "$installer" --check

  # Regardless of exit code (install-not-present issues are legitimate),
  # the specific "GITHUB_CONFIG.md missing" message must not appear.
  if echo "$output" | grep -qF 'GITHUB_CONFIG.md missing'; then
    echo "--check still complains about GITHUB_CONFIG.md missing:" >&2
    echo "$output" >&2
    teardown_fake_home
    return 1
  fi
  teardown_fake_home
}

@test "project install.sh --check flags missing PROJECT_STANDARDS.md (CPT-124)" {
  # Opposite direction: on a HOME without PROJECT_STANDARDS.md but WITH
  # MSA, --check must now say PROJECT_STANDARDS.md is missing (replacing
  # the old GITHUB_CONFIG.md complaint with the authoritative one).
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude"
  touch "${HOME}/.claude/MULTI_SESSION_ARCHITECTURE.md"
  # deliberately no PROJECT_STANDARDS.md

  local installer="${REPO_DIR}/skills/project/install.sh"
  run bash "$installer" --check

  [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* || "$HOME" == /private/tmp/* || "$HOME" == /private/var/* ]] && rm -rf "$HOME"

  echo "$output" | grep -qF 'PROJECT_STANDARDS.md' || {
    echo "--check does not mention PROJECT_STANDARDS.md at all: $output" >&2
    return 1
  }
}
