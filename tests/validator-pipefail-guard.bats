#!/usr/bin/env bats

# CPT-145: scripts/validate-skills.sh runs under `set -euo pipefail` at
# the script top. The CPT-134 README-drift blocks use
#   var=$(grep ... | grep ... | head -1 | sed ...)
# When the first grep finds nothing it exits 1, pipefail propagates, the
# command substitution returns 1, the assignment inherits, and set -e
# aborts the whole validator — before the downstream `if [ -z "$var" ]`
# warn branch can run. The validator dies in exactly the scenario its
# new branches were added to warn about.
#
# Fix: append `|| true` so the pipeline can legitimately produce empty
# output without tripping set -e.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
VALIDATOR="$REPO_DIR/scripts/validate-skills.sh"

setup() {
  [ -f "$VALIDATOR" ]
  TMPREPO="$(mktemp -d)"
  # Copy validator into the fixture tree so its REPO_DIR resolution
  # (via BASH_SOURCE) points at TMPREPO, not the real repo.
  mkdir -p "$TMPREPO/scripts" "$TMPREPO/skills/fakeskill"
  cp "$VALIDATOR" "$TMPREPO/scripts/validate-skills.sh"
  chmod +x "$TMPREPO/scripts/validate-skills.sh"
  FIXTURE_VALIDATOR="$TMPREPO/scripts/validate-skills.sh"
}

teardown() {
  rm -rf "$TMPREPO"
}

# Helper: run the validator against a synthetic repo with a single fake
# skill and a controlled root README / per-skill README setup. The
# validator itself is sourced from the real repo, but REPO_DIR inside
# the subshell is the fixture path.
_run_validator_on_fixture() {
  run bash -c "cd '$TMPREPO' && bash '$FIXTURE_VALIDATOR' 2>&1"
}

# --- Fixture 1: skill is NOT listed in root README skills table ---
#   Pre-fix: first grep exits 1 → pipefail → set -e abort → non-zero exit
#   with no "not listed in root README skills table" warning.
#   Post-fix: warn branch runs, validator continues, summary reports the
#   warning, exits cleanly.

@test "CPT-145: validator survives a skill missing from root README skills table" {
  cat > "$TMPREPO/skills/fakeskill/SKILL.md" <<'EOF'
---
name: fakeskill
version: 1.0.0
description: "Fake skill for the CPT-145 test fixture"
user-invocable: true
disable-model-invocation: true
allowed-tools: Read
---

# fakeskill v1.0.0

### help
test
### doctor
test
### version
1.0.0
EOF

  cat > "$TMPREPO/skills/fakeskill/README.md" <<'EOF'
# fakeskill
Test readme — no Version section at all.
EOF

  # Root README missing the fakeskill row entirely
  cat > "$TMPREPO/README.md" <<'EOF'
# choc-skills
## Skills
| Skill | Version |
|-------|---------|
EOF

  _run_validator_on_fixture

  # With the pre-CPT-145 script, set -e aborts BEFORE this warn is emitted;
  # output never contains the warn line and status is the grep's failure
  # code (abort path). With the CPT-145 fix, the warn fires and the
  # script either exits 0 with warnings or exits 1 only if a downstream
  # check flagged a real error — but NOT because grep returned empty.
  echo "--- validator output ---"
  echo "$output"
  echo "--- exit status: $status ---"

  # The warn string must appear (it runs only after the grep pipeline
  # returns without aborting).
  [[ "$output" == *"not listed in root README skills table"* ]]
}

# --- Fixture 2: README exists but uses only the legacy bare form ---
#   Pre-fix: first grep for `Current: **X**` form exits 1, pipefail aborts
#   the validator before the awk fallback (the exact reason the fallback
#   was added) can run.
#   Post-fix: the grep returns empty, the awk fallback runs, the validator
#   either matches or cleanly warns.

@test "CPT-145: validator survives legacy bare '## Version' README form" {
  cat > "$TMPREPO/skills/fakeskill/SKILL.md" <<'EOF'
---
name: fakeskill
version: 1.0.0
description: "Fake skill for the CPT-145 test fixture"
user-invocable: true
disable-model-invocation: true
allowed-tools: Read
---

# fakeskill v1.0.0

### help
test
### doctor
test
### version
1.0.0
EOF

  # Legacy bare ## Version form — CPT-134's awk fallback should pick it up.
  cat > "$TMPREPO/skills/fakeskill/README.md" <<'EOF'
# fakeskill

Test readme.

## Version

1.0.0
EOF

  # Root README with matching row so block 1 doesn't also warn
  cat > "$TMPREPO/README.md" <<'EOF'
# choc-skills
## Skills
| Skill | Version |
|-------|---------|
| **fakeskill** | v1.0.0 | /fake | test | [README](skills/fakeskill/README.md) |
EOF

  _run_validator_on_fixture

  echo "--- validator output ---"
  echo "$output"
  echo "--- exit status: $status ---"

  # The awk fallback should fire — the "Per-skill README version matches
  # frontmatter" pass line must appear, which means the fallback found
  # 1.0.0 and matched the frontmatter without aborting.
  [[ "$output" == *"Per-skill README version matches frontmatter"* ]]
}

# --- Static check: both CPT-134 pipelines now carry || true ---

@test "CPT-145: root README skills-table pipeline has || true guard" {
  grep -qE "grep -oE 'v\[0-9\].* \| head -1 \| sed 's/\^v//' \|\| true" "$VALIDATOR" || \
    grep -qE "sed 's/\^v//' \|\| true" "$VALIDATOR" || {
    echo "root_row_ver pipeline missing '|| true' — pipefail will abort on skills missing from root README" >&2
    grep -nE 'root_row_ver=' "$VALIDATOR" >&2
    return 1
  }
}

@test "CPT-145: Current:-form readme_ver pipeline has || true guard" {
  # The Current:-form readme_ver assignment spans two lines (continuation
  # with \). Check that on the line containing `head -1` followed by the
  # closing paren, there's a `|| true` guard.
  grep -qE 'head -1 \|\| true' "$VALIDATOR" || {
    echo "readme_ver Current:-form pipeline missing '|| true'" >&2
    grep -nE 'readme_ver=' "$VALIDATOR" >&2
    return 1
  }
}
