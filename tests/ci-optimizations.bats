#!/usr/bin/env bats
# Tests for CPT-34: CI workflow optimizations
# Red-green TDD — FAIL before, PASS after.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
CI_YML="$REPO_ROOT/.github/workflows/ci.yml"
RELEASE_YML="$REPO_ROOT/.github/workflows/release.yml"
RELEASE_SKILL_YML="$REPO_ROOT/.github/workflows/release-skill.yml"

# --- Finding 1: paths-ignore on ci.yml ---

@test "ci.yml has paths-ignore for markdown files" {
  grep -q 'paths-ignore' "$CI_YML"
}

@test "ci.yml paths-ignore includes *.md pattern" {
  grep -A5 'paths-ignore' "$CI_YML" | grep -q '\.md'
}

# --- Finding 2: BATS caching ---

@test "ci.yml uses setup-bats action or caches BATS" {
  # Should use bats-core/bats-action or actions/cache, not raw apt-get
  grep -q 'bats-action\|actions/cache\|setup-bats\|bats-core/bats-core' "$CI_YML"
}

# --- Finding 3: no runtime chmod needed ---

@test "ci.yml validate-skills job does not chmod scripts" {
  # The validate-skills job should not need chmod +x if files are committed executable
  ! sed -n '/validate-skills:/,/^  [a-z]/p' "$CI_YML" | grep -q 'chmod +x scripts'
}

@test "ci.yml verify-checksums job does not chmod scripts" {
  ! sed -n '/verify-checksums:/,/^  [a-z]/p' "$CI_YML" | grep -q 'chmod +x scripts'
}

# --- Finding 4: release.yml does not re-run validation ---

@test "release.yml does not re-run validate-skills.sh" {
  ! grep -q 'validate-skills' "$RELEASE_YML"
}

@test "release.yml does not re-run install.sh --force" {
  ! grep -q 'install.sh --force' "$RELEASE_YML"
}

# --- Finding 5: release-skill.yml validates only the tagged skill ---

@test "release-skill.yml validates only the tagged skill, not all" {
  # Should validate just the specific skill, not run validate-skills.sh (which checks ALL)
  ! grep -q 'validate-skills\.sh' "$RELEASE_SKILL_YML"
}
