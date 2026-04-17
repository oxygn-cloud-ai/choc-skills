#!/usr/bin/env bats

# CPT-92 (+ CPT-116 + CPT-130): Version-sync invariants.
#
# A skill's version lives in multiple places: YAML frontmatter, internal
# "<skill> v<semver>" strings in SKILL.md (help banner, version output,
# doctor example), "Current: **X.Y.Z**" in per-skill README, and the root
# README.md skills table. These drift silently whenever an author bumps
# one and forgets the others.
#
# Tests below assert all locations stay in sync with the frontmatter
# (single source of truth). Also asserts validate-skills.sh catches
# SKILL.md internal drift so the class of bug can't recur.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

SKILL_NAMES=(chk1 chk2 project ra rr)

# Extract frontmatter version for a skill.
fm_version() {
  local name="$1"
  grep -m1 '^version:' "$REPO_DIR/skills/$name/SKILL.md" | sed 's/^version: *//'
}

@test "SKILL.md internal <skill> v<semver> strings match frontmatter version" {
  local drift=()
  for name in "${SKILL_NAMES[@]}"; do
    local fm sk_file
    fm="$(fm_version "$name")"
    sk_file="$REPO_DIR/skills/$name/SKILL.md"
    # Extract every "<name> v<semver>" token
    while IFS= read -r ver; do
      [ -n "$ver" ] || continue
      if [ "$ver" != "$fm" ]; then
        drift+=("$name: internal '$name v$ver' does not match frontmatter $fm")
      fi
    done < <(grep -oE "${name} v[0-9]+\.[0-9]+\.[0-9]+" "$sk_file" | sed "s/^${name} v//" | sort -u)
  done
  if [ ${#drift[@]} -gt 0 ]; then
    printf '%s\n' "${drift[@]}" >&2
    return 1
  fi
}

@test "root README.md skills table versions match SKILL.md frontmatter" {
  local drift=()
  for name in "${SKILL_NAMES[@]}"; do
    local fm readme_ver
    fm="$(fm_version "$name")"
    # Match the row: | **<name>** | v<X.Y.Z> | ... |
    readme_ver=$(grep -E "\\| \\*\\*${name}\\*\\*" "$REPO_DIR/README.md" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | sed 's/^v//')
    if [ -z "$readme_ver" ]; then
      drift+=("$name: not listed in root README skills table")
      continue
    fi
    if [ "$readme_ver" != "$fm" ]; then
      drift+=("$name: root README says v$readme_ver, frontmatter says $fm")
    fi
  done
  if [ ${#drift[@]} -gt 0 ]; then
    printf '%s\n' "${drift[@]}" >&2
    return 1
  fi
}

@test "per-skill README.md Current version matches SKILL.md frontmatter (when present)" {
  local drift=()
  for name in "${SKILL_NAMES[@]}"; do
    local readme="$REPO_DIR/skills/$name/README.md"
    [ -f "$readme" ] || continue
    # Find "Current: **X.Y.Z**" if present
    local cur
    cur=$(grep -Eo 'Current: \*\*[0-9]+\.[0-9]+\.[0-9]+\*\*' "$readme" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -n "$cur" ] || continue  # no "Current:" line — that's fine
    local fm
    fm="$(fm_version "$name")"
    if [ "$cur" != "$fm" ]; then
      drift+=("$name/README.md: Current **$cur** does not match frontmatter $fm")
    fi
  done
  if [ ${#drift[@]} -gt 0 ]; then
    printf '%s\n' "${drift[@]}" >&2
    return 1
  fi
}

@test "validate-skills.sh flags SKILL.md internal version drift" {
  # Craft a temp SKILL.md with frontmatter 9.9.9 but internal "testskill v1.0.0"
  local tmproot
  tmproot=$(mktemp -d)
  trap "rm -rf '$tmproot'" RETURN
  mkdir -p "$tmproot/skills/testskill"
  cat > "$tmproot/skills/testskill/SKILL.md" <<'EOF'
---
name: testskill
version: 9.9.9
description: test
user-invocable: true
disable-model-invocation: true
allowed-tools: Read
---

# testskill

Running testskill v1.0.0 — oops, wrong version.
EOF
  # Run a copy of validate-skills.sh against the temp tree
  cp "$REPO_DIR/scripts/validate-skills.sh" "$tmproot/validate-skills.sh"
  # Point the script at the temp SKILLS_DIR
  run env REPO_DIR_OVERRIDE="$tmproot" bash -c "cd '$tmproot' && bash validate-skills.sh 2>&1"
  # The validator must exit non-zero AND the output must mention the drift
  [ "$status" -ne 0 ] || {
    echo "validate-skills.sh did not flag internal version drift (exited $status)" >&2
    echo "$output" >&2
    return 1
  }
  [[ "$output" == *"version"* ]] || {
    echo "validate-skills.sh output did not mention version drift" >&2
    return 1
  }
}
