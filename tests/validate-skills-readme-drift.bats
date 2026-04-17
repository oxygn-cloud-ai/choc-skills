#!/usr/bin/env bats

# CPT-134: CPT-92 landed validate-skills.sh drift detection for SKILL.md
# internal `<name> v<semver>` strings, but the validator didn't cover
# root README.md skills-table entries or per-skill README "Current:"
# lines. Result: a version bump that forgets either README location
# still exits 0 — the class of drift keeps leaking.
#
# Also: version-sync.bats hardcoded SKILL_NAMES=(chk1 chk2 project ra rr)
# so a new skill would silently lose coverage.
#
# And: ra/README.md used a different heading style (`## Version\n\nX.Y.Z`
# vs the `Current: **X.Y.Z**` form used elsewhere), so the bats test 3
# skipped ra silently — ra/README.md was left stale at 1.0.0 while
# frontmatter said 1.0.5.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# Dynamically discover installable skills (same filter as install.sh).
discover_skills() {
  local dir name
  for dir in "${REPO_DIR}"/skills/*/; do
    name="$(basename "$dir")"
    [[ "$name" == _* ]] && continue
    [ -f "${dir}/SKILL.md" ] || continue
    printf '%s\n' "$name"
  done
}

fm_version() {
  grep -m1 '^version:' "${REPO_DIR}/skills/$1/SKILL.md" | sed 's/^version: *//'
}

@test "no per-skill README is skipped by the version-sync check (CPT-134 concern 2)" {
  # Every skill that ships a README.md must have a detectable version
  # declaration — `Current: **X.Y.Z**` OR a bare `X.Y.Z` after a
  # `## Version` heading. If none matches, ra-style stale drift sneaks
  # back in.
  local drift=()
  local name readme cur
  while IFS= read -r name; do
    readme="${REPO_DIR}/skills/$name/README.md"
    [ -f "$readme" ] || continue

    cur=$(grep -oE 'Current: \*\*[0-9]+\.[0-9]+\.[0-9]+\*\*' "$readme" \
          | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -z "$cur" ]; then
      cur=$(awk '/^## Version/{hit=1; next} hit && /^[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+[[:space:]]*$/{print; exit}' "$readme" | tr -d '[:space:]')
    fi
    if [ -z "$cur" ]; then
      drift+=("$name/README.md: no version declaration found (expected 'Current: **X.Y.Z**' or 'X.Y.Z' after '## Version')")
      continue
    fi

    local fm
    fm="$(fm_version "$name")"
    if [ "$cur" != "$fm" ]; then
      drift+=("$name/README.md: says $cur, frontmatter says $fm")
    fi
  done < <(discover_skills)

  if [ ${#drift[@]} -gt 0 ]; then
    printf '%s\n' "${drift[@]}" >&2
    return 1
  fi
}

@test "validate-skills.sh flags root README.md skills-table drift (CPT-134 concern 1)" {
  # Scaffold a temp repo with one complete skill whose root README disagrees
  # with frontmatter. Every OTHER validator check must pass so the non-zero
  # exit can only come from the README drift — otherwise the test passes
  # spuriously on unrelated errors (missing subcommand, etc.).
  local tmproot
  tmproot="$(mktemp -d)"
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

### help
placeholder

### doctor
placeholder

### version
placeholder
EOF

  # Root README says v1.0.0 — mismatch with frontmatter 9.9.9
  cat > "$tmproot/README.md" <<'EOF'
# choc-skills
| Skill | Version | Command |
|-------|---------|---------|
| **testskill** | v1.0.0 | `/testskill` |
EOF

  cp "$REPO_DIR/scripts/validate-skills.sh" "$tmproot/validate-skills.sh"
  run env REPO_DIR_OVERRIDE="$tmproot" bash -c "cd '$tmproot' && bash validate-skills.sh 2>&1"

  [ "$status" -ne 0 ] || {
    echo "validate-skills.sh did not flag root README drift (exit $status)" >&2
    echo "$output" >&2
    return 1
  }
  # Must mention README + at least one of the version values so the failure
  # is clearly the drift, not an unrelated check.
  echo "$output" | grep -qiE 'README.*(9\.9\.9|1\.0\.0)|(9\.9\.9|1\.0\.0).*README' || {
    echo "validate-skills.sh failed but without a recognisable README drift message" >&2
    echo "$output" >&2
    return 1
  }
}

@test "validate-skills.sh flags per-skill README Current drift (CPT-134 concern 1)" {
  local tmproot
  tmproot="$(mktemp -d)"
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

### help
placeholder

### doctor
placeholder

### version
placeholder
EOF
  cat > "$tmproot/skills/testskill/README.md" <<'EOF'
# testskill

## Version

Current: **1.0.0**
EOF

  # Root README fine, per-skill README drifted
  cat > "$tmproot/README.md" <<'EOF'
# choc-skills
| Skill | Version | Command |
|-------|---------|---------|
| **testskill** | v9.9.9 | `/testskill` |
EOF

  cp "$REPO_DIR/scripts/validate-skills.sh" "$tmproot/validate-skills.sh"
  run env REPO_DIR_OVERRIDE="$tmproot" bash -c "cd '$tmproot' && bash validate-skills.sh 2>&1"

  [ "$status" -ne 0 ] || {
    echo "validate-skills.sh did not flag per-skill README Current drift (exit $status)" >&2
    echo "$output" >&2
    return 1
  }
  # Must mention README + the mismatching version
  echo "$output" | grep -qiE 'README.*(9\.9\.9|1\.0\.0)|(9\.9\.9|1\.0\.0).*README' || {
    echo "validate-skills.sh failed but without a recognisable per-skill README drift message" >&2
    echo "$output" >&2
    return 1
  }
}

@test "version-sync.bats discovers skills dynamically, not from a hardcoded array (CPT-134 concern 3)" {
  # The test file must not pin the skill list; it should loop over the
  # same discovery glob install.sh uses (skills/*/SKILL.md).
  local version_sync="${REPO_DIR}/tests/version-sync.bats"
  [ -f "$version_sync" ] || { echo "tests/version-sync.bats missing" >&2; return 1; }

  if grep -qE '^SKILL_NAMES=\(.*[a-z]' "$version_sync"; then
    echo "version-sync.bats still has a hardcoded SKILL_NAMES=(...) array — adding a new skill would silently lose coverage" >&2
    grep -n 'SKILL_NAMES=(' "$version_sync" >&2
    return 1
  fi

  # Positive: must loop over skills/ directories
  grep -qE 'skills/\*|SKILLS_DIR|discover_skills' "$version_sync" || {
    echo "version-sync.bats has no dynamic skill discovery (looking for skills/* glob or discover_skills helper)" >&2
    return 1
  }
}
