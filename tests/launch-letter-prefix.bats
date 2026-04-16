#!/usr/bin/env bats

# CPT-72: tmux windows use letter-prefix names ("a master" ... "k triager")
# with <prefix> a..k bound to select the corresponding window.
#
# Live-tmux behaviour (the actual window rename + bind-key install) is verified
# by operator smoke-test during `/project:launch` — these bats tests are static
# checks on the skill source itself (launch.md + project-launch-session.sh)
# to make sure the canonical role→letter mapping, the letter-prefixed name
# format, the bind-key loop, and the index-based targeting pattern are all
# present and consistent. If someone renames a role or drops the bindings
# in future, these tests fail.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
LAUNCH_MD="${REPO_DIR}/skills/project/commands/launch.md"

# --- Canonical mapping present ---

@test "launch.md declares ROLE_LETTER associative array" {
  [ -f "$LAUNCH_MD" ]
  grep -qE 'declare -A ROLE_LETTER=' "$LAUNCH_MD"
}

@test "launch.md ROLE_LETTER maps each of the 11 canonical roles to a..k" {
  for role in master planner implementer fixer merger chk1 chk2 performance playtester reviewer triager; do
    grep -qE "\[${role}\]=[a-k]" "$LAUNCH_MD" \
      || { echo "info: ROLE_LETTER missing entry for $role"; return 1; }
  done
}

@test "launch.md ROLE_LETTER assigns master=a" {
  grep -qE '\[master\]=a' "$LAUNCH_MD"
}

@test "launch.md ROLE_LETTER assigns triager=k" {
  grep -qE '\[triager\]=k' "$LAUNCH_MD"
}

@test "launch.md ROLE_LETTER letters are unique (no two roles share a letter)" {
  local letters
  letters=$(grep -oE '\[[a-z]+\]=[a-k]' "$LAUNCH_MD" | awk -F= '{print $2}' | sort)
  local dups
  dups=$(printf '%s\n' "$letters" | uniq -d)
  [ -z "$dups" ] || { echo "info: duplicate letter(s) in ROLE_LETTER: $dups"; return 1; }
}

# --- Window creation uses the letter-prefixed name ---

@test "launch.md Step 6 new-session uses '\$first_letter \$first_role' format" {
  # Must be the letter-prefixed form; naked "-n master" would mean the rename
  # never happened.
  grep -q 'tmux new-session.*-n "\$first_letter \$first_role"' "$LAUNCH_MD"
}

@test "launch.md Step 6 new-window loop uses '\$letter \$role' format" {
  grep -q 'tmux new-window.*-n "\$letter \$role"' "$LAUNCH_MD"
}

# --- Step 6.1 bind-key loop present ---

@test "launch.md has Step 6.1 with bind-key loop for a..k" {
  grep -q '## Step 6.1' "$LAUNCH_MD"
  grep -q 'tmux bind-key "\$letter" select-window' "$LAUNCH_MD"
}

@test "launch.md Step 6.1 targets windows by INDEX (not name) in bind" {
  # After the rename windows have spaces in their names; targeting by index
  # is unambiguous. Binding should point at "$PROJECT_SLUG:$i" not "$ROLE".
  grep -qE 'select-window -t "\$PROJECT_SLUG:\$i"' "$LAUNCH_MD"
}

# --- Invocation loop targets by index too ---

@test "launch.md Step 7 invocation targets '\$PROJECT_SLUG:\$i' (index), not ':\$ROLE'" {
  # There should be NO remaining naked `--target "$PROJECT_SLUG:$ROLE"` — the
  # index-based loop replaces it.
  if grep -qE 'target="\$PROJECT_SLUG:\$ROLE"' "$LAUNCH_MD"; then
    echo "info: Step 7 still targets by role-name; windows with spaces need index targeting"
    return 1
  fi
  grep -qE 'target="\$PROJECT_SLUG:\$i"' "$LAUNCH_MD" \
    || { echo "info: Step 7 missing index-based target"; return 1; }
}

# --- Navigation hint in Step 8 report updated ---

@test "launch.md Step 8 report hints at <prefix> a..k navigation" {
  grep -qiE '<prefix>[[:space:]]*a\.\.k' "$LAUNCH_MD" \
    || { echo "info: Step 8 report doesn't mention a..k navigation"; return 1; }
}

# --- Idempotency note present ---

@test "launch.md Step 6.1 notes bindings are idempotent (tmux bind-key replaces)" {
  grep -qi 'idempoten' "$LAUNCH_MD"
}

# --- Non-Software (8-role) mapping note present ---

@test "launch.md documents Non-Software project letter mapping" {
  # Non-Software drops chk1/chk2/playtester; documentation should call out the
  # gap so operators know why f/g/i are missing in those projects.
  grep -qi 'non-software' "$LAUNCH_MD"
}
