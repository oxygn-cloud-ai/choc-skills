#!/usr/bin/env bats

# CPT-114: /project:status previously derived its expected role list from
# `.worktrees/*/` (which is the thing it was supposed to validate), making
# the comparison tautological — missing roles silently dropped from the
# "expected" set, stray worktrees implicitly accepted. The fix is to derive
# ROLES from MULTI_SESSION_ARCHITECTURE.md (the authoritative source of
# session roles) and explicitly compare observed worktrees against it.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
STATUS_MD="${REPO_DIR}/skills/project/commands/status.md"

@test "project/commands/status.md exists" {
  [ -f "$STATUS_MD" ]
}

@test "status.md does NOT derive ROLES tautologically from .worktrees/ (CPT-114)" {
  # The CPT-19 shape was:
  #   ROLES=()
  #   for wt in .worktrees/*/; do
  #     [ -d "$wt" ] && ROLES+=("$(basename "$wt")")
  #   done
  # Refuse that shape outright so a future refactor can't silently reintroduce it.
  if grep -qE 'for wt in \.worktrees/\*/;' "$STATUS_MD"; then
    if grep -qE 'ROLES\+=\("\$\(basename "\$wt"\)"\)' "$STATUS_MD"; then
      echo "status.md still populates ROLES by walking .worktrees/*/ — comparison is tautological (CPT-114)" >&2
      return 1
    fi
  fi
}

@test "status.md derives ROLES from MULTI_SESSION_ARCHITECTURE.md (CPT-114)" {
  # Post-fix must source the authoritative role list from MSA. The exact
  # parse expression is flexible — awk, grep, or sed — but it must mention
  # the MSA path AND populate ROLES.
  grep -qE 'MULTI_SESSION_ARCHITECTURE\.md' "$STATUS_MD" || {
    echo "status.md does not reference MULTI_SESSION_ARCHITECTURE.md for ROLES" >&2
    return 1
  }
  # Extraction must look at the worktree-branch column tokens (`session/<role>`)
  # OR the role-name column — either is acceptable as an authoritative source.
  grep -qE 'session/|Session Roles|role table' "$STATUS_MD" || {
    echo "status.md does not parse the role table from MSA" >&2
    return 1
  }
}

@test "status.md compares observed worktrees against ROLES (CPT-114)" {
  # Without an explicit missing/stray comparison, restoring the authoritative
  # ROLES list is only half the fix. The display block must contain a
  # dedicated marker the auditor will print when state is degraded —
  # "[missing role]" OR "[unexpected worktree]" (or equivalent in the
  # Worktrees: output section).
  #
  # Inspect the display block (from Step 4 onward) rather than the
  # pre-flight text, so we don't accept the incidental "skip worktree
  # role comparison" WARN message as "coverage".
  local display
  display=$(awk '/^## Step 4/,EOF' "$STATUS_MD")
  [ -n "$display" ] || { echo "could not locate Step 4 display block" >&2; return 1; }
  echo "$display" | grep -qiE '\[missing\]|\[stray\]|\[unexpected\]|missing role|unexpected worktree|stray worktree' || {
    echo "Step 4 display spec does not surface missing/stray worktree markers" >&2
    return 1
  }
}

# --- CPT-139: expected-role set must be scoped to THIS project's configured
#     roles, not the full MSA catalog. Otherwise non-software projects (which
#     skip chk1/chk2/playtester) see false [missing role] warnings.

@test "status.md consults PROJECT_CONFIG.json for the expected role set (CPT-139)" {
  grep -qE 'PROJECT_CONFIG\.json' "$STATUS_MD" || {
    echo "status.md does not reference PROJECT_CONFIG.json for role scoping" >&2
    return 1
  }
}

@test "status.md honours PROJECT_CONFIG.json .sessions.roles explicit list (CPT-139)" {
  # When PROJECT_CONFIG.json carries an explicit .sessions.roles array, the
  # parser must use it as the expected-role set rather than the full MSA
  # catalog.
  grep -qE '(sessions\.roles|"sessions".*"roles"|\.sessions\.roles)' "$STATUS_MD" || {
    echo "status.md does not read PROJECT_CONFIG.json .sessions.roles" >&2
    return 1
  }
}

@test "status.md honours PROJECT_CONFIG.json project type → role subset (CPT-139)" {
  # When PROJECT_CONFIG.json has .project.type (or equivalent) set to
  # non-software, the parser must drop chk1/chk2/playtester from the expected
  # role set (per MSA "Non-software projects may skip: chk1, chk2, Playtester").
  grep -qE '(non-software|project\.type|project_type|projectType)' "$STATUS_MD" || {
    echo "status.md does not map project type to role subset" >&2
    return 1
  }
}

@test "status.md documents the MSA fallback when PROJECT_CONFIG is absent (CPT-139)" {
  # The existing behaviour (derive from MSA) must remain as a safe fallback
  # for projects that don't yet have PROJECT_CONFIG.json or have it without
  # the role-narrowing fields.
  grep -qE '(fallback|if PROJECT_CONFIG.*absent|MSA)' "$STATUS_MD" || {
    echo "status.md does not document MSA fallback for missing PROJECT_CONFIG" >&2
    return 1
  }
}
