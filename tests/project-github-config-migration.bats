#!/usr/bin/env bats

# CPT-141: CPT-124 (v1.2.6) migrated project/install.sh, SKILL.md,
# README.md, and commands/new.md from GITHUB_CONFIG.md to PROJECT_STANDARDS.md
# + PROJECT_CONFIG.json, but left four command files hard-depending on the
# retired filename:
#   commands/audit.md   — STOPs if ~/.claude/GITHUB_CONFIG.md is missing
#   commands/config.md  — STOPs if ~/.claude/GITHUB_CONFIG.md is missing
#   commands/status.md  — marks GITHUB_CONFIG.md as required doc, reads it
#   commands/launch.md  — reads GITHUB_CONFIG.md for type detection
#
# A freshly-scaffolded repo per CPT-124's /project:new can't run
# /project:audit or /project:config. The CPT-124 --check "healthy"
# verdict is a lie for 4 of 5 project commands.
#
# Fix: finish the migration. Each file must no longer HARD-FAIL on a
# missing GITHUB_CONFIG.md, and must reference PROJECT_STANDARDS.md
# and/or PROJECT_CONFIG.json for the information it used to read from
# the retired file.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# --- audit.md ---

@test "audit.md does not hard-STOP on missing ~/.claude/GITHUB_CONFIG.md (CPT-141)" {
  # Refuse the STOP pattern that blocks /project:audit on fresh modern repos.
  file="$REPO_DIR/skills/project/commands/audit.md"
  # Look for the distinctive STOP line introduced pre-migration.
  if grep -qE 'test -f ~/\.claude/GITHUB_CONFIG\.md.*STOP|~/\.claude/GITHUB_CONFIG\.md not found.*required' "$file"; then
    echo "audit.md still hard-STOPs on missing ~/.claude/GITHUB_CONFIG.md (CPT-141)" >&2
    return 1
  fi
}

@test "audit.md references PROJECT_STANDARDS.md or PROJECT_CONFIG.json (CPT-141)" {
  file="$REPO_DIR/skills/project/commands/audit.md"
  grep -qE 'PROJECT_STANDARDS\.md|PROJECT_CONFIG\.json' "$file" || {
    echo "audit.md does not reference PROJECT_STANDARDS.md or PROJECT_CONFIG.json" >&2
    return 1
  }
}

# --- config.md ---

@test "config.md does not hard-STOP on missing ~/.claude/GITHUB_CONFIG.md (CPT-141)" {
  file="$REPO_DIR/skills/project/commands/config.md"
  if grep -qE 'test -f ~/\.claude/GITHUB_CONFIG\.md.*STOP|~/\.claude/GITHUB_CONFIG\.md not found' "$file"; then
    echo "config.md still hard-STOPs on missing ~/.claude/GITHUB_CONFIG.md (CPT-141)" >&2
    return 1
  fi
}

@test "config.md references PROJECT_STANDARDS.md or PROJECT_CONFIG.json (CPT-141)" {
  file="$REPO_DIR/skills/project/commands/config.md"
  grep -qE 'PROJECT_STANDARDS\.md|PROJECT_CONFIG\.json' "$file" || {
    echo "config.md does not reference PROJECT_STANDARDS.md or PROJECT_CONFIG.json" >&2
    return 1
  }
}

# --- status.md ---

@test "status.md does not report GITHUB_CONFIG.md as a required doc (CPT-141)" {
  file="$REPO_DIR/skills/project/commands/status.md"
  # The "required docs" loop must not include GITHUB_CONFIG.md as a doc
  # whose absence is a MISSING finding.
  if grep -qE 'for doc in.*GITHUB_CONFIG\.md' "$file"; then
    echo "status.md still lists GITHUB_CONFIG.md in the required-docs loop (CPT-141)" >&2
    return 1
  fi
}

@test "status.md references PROJECT_STANDARDS.md or PROJECT_CONFIG.json (CPT-141)" {
  file="$REPO_DIR/skills/project/commands/status.md"
  grep -qE 'PROJECT_STANDARDS\.md|PROJECT_CONFIG\.json' "$file" || {
    echo "status.md does not reference PROJECT_STANDARDS.md or PROJECT_CONFIG.json" >&2
    return 1
  }
}

# --- launch.md ---

@test "launch.md detects project type without GITHUB_CONFIG.md (CPT-141)" {
  file="$REPO_DIR/skills/project/commands/launch.md"
  # The pre-migration shape was "Detect project type from GITHUB_CONFIG.md".
  # Post-migration should use PROJECT_CONFIG.json (machine-readable type) or
  # fall through to auto-detection without hard-requiring GITHUB_CONFIG.md.
  if grep -qE 'from `GITHUB_CONFIG\.md`' "$file"; then
    echo "launch.md still uses GITHUB_CONFIG.md for project-type detection (CPT-141)" >&2
    return 1
  fi
}

# --- Cross-file: migration annotations permitted, live references forbidden ---

@test "no command file HARD-requires ~/.claude/GITHUB_CONFIG.md (CPT-141)" {
  # The pre-migration shape was:
  #   test -f ~/.claude/GITHUB_CONFIG.md — if missing: **STOP** ...
  # Match the file-existence-check-then-STOP construct specifically. Accept
  # descriptive mentions like "(replaces retired GITHUB_CONFIG.md)" inside
  # error messages for OTHER files — those are migration annotations.
  offenders=""
  for f in "$REPO_DIR"/skills/project/commands/*.md; do
    name=$(basename "$f")
    if grep -qE 'test -f ~/\.claude/GITHUB_CONFIG\.md' "$f"; then
      offenders="$offenders $name"
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}
