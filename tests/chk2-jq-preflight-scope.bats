#!/usr/bin/env bats

# CPT-135: CPT-98 added a global jq pre-flight to skills/chk2/SKILL.md
# that aborts every /chk2 invocation when jq is missing. Only /chk2 auth
# (AU3 concurrent-session pipeline) and /chk2 all (which dispatches
# auth) actually use jq. Other categories — /chk2 headers, /chk2 tls,
# /chk2 dns, /chk2 fix, /chk2 update, etc. — don't touch jq, but
# CPT-98's broad check blocks them all on any machine without jq.
#
# Fix: scope the jq pre-flight to auth/all only. Doctor can still warn
# globally about missing jq (diagnostic usefulness preserved), but the
# abort-before-execution path must not fire for non-auth categories.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SKILL_MD="${REPO_DIR}/skills/chk2/SKILL.md"

# Extract the global "## Pre-flight Checks" block up to the next `## ` heading
# (exclusive of the next heading line).
_preflight_block() {
  awk '/^## Pre-flight Checks/{inside=1; next} /^## /{inside=0} inside' "$SKILL_MD"
}

@test "chk2 SKILL.md exists (sanity)" {
  [ -f "$SKILL_MD" ]
}

@test "chk2 global pre-flight does not FATAL on missing jq for non-auth categories (CPT-135)" {
  local block
  block=$(_preflight_block)
  [ -n "$block" ] || { echo "could not locate Pre-flight block" >&2; return 1; }

  # The pre-fix shape had an unconditional numbered item like:
  #   2. **jq available**: `which jq`. If not found: <error>
  # which aborts every /chk2 invocation. Refuse that shape outright —
  # the jq check must either be pushed to auth.md/all.md OR the pre-flight
  # line that invokes `which jq` must be gated on $ARGUMENTS.
  local jq_item
  jq_item=$(echo "$block" | grep -E '\*\*jq|which jq' || true)

  if [ -z "$jq_item" ]; then
    # No jq mention in pre-flight — pushed elsewhere; accept.
    return 0
  fi

  # If jq IS mentioned, the surrounding line must contain a conditional
  # anchor — `if $ARGUMENTS`, `only for`, `when`, `unless`, or `skip`. A
  # bare mention of "/chk2 auth" inside the error message does NOT count
  # as gating (the error message existing doesn't make the imperative
  # conditional).
  if ! echo "$jq_item" | grep -qiE 'if \$ARGUMENTS|only (for|when)|unless|skip unless|only if|\(only for|when the command'; then
    echo "chk2 SKILL.md pre-flight jq check is not gated on \$ARGUMENTS — still blocks every category (CPT-135)" >&2
    echo "jq_item: $jq_item" >&2
    return 1
  fi
}

@test "chk2 doctor section still verifies jq globally (diagnostic preserved)" {
  # The doctor path is explicitly diagnostic — users should still see jq
  # status even when they're running a non-auth category. Fix must not
  # remove the doctor check, only the blocking pre-flight.
  awk '/^### doctor$/,/^### version$/' "$SKILL_MD" | grep -qE 'which jq|\[PASS.*jq|\[FAIL.*jq' || {
    echo "chk2 doctor no longer mentions jq — diagnostic coverage lost (CPT-135 fix must preserve doctor's jq check)" >&2
    return 1
  }
}

@test "jq dependency is enforced for /chk2 auth code path on the ACTUAL execution path (CPT-135, CPT-144)" {
  # CPT-144: the installed router (~/.claude/commands/chk2.md) routes
  # `(empty)` and `all` DIRECTLY to /chk2:all. SKILL.md is only loaded for
  # help/doctor/version. A jq guard living ONLY in SKILL.md pre-flight is
  # therefore bypassed on the primary invocation. The guard must live on
  # the execution path — commands/all.md or commands/auth.md.
  local auth_md="${REPO_DIR}/skills/chk2/commands/auth.md"
  local all_md="${REPO_DIR}/skills/chk2/commands/all.md"

  local guarded=0
  [ -f "$auth_md" ] && grep -qE 'which jq|jq.*not.*installed|jq.*missing|jq.*available' "$auth_md" && guarded=1
  [ -f "$all_md" ] && grep -qE 'which jq|jq.*not.*installed|jq.*missing|jq.*available' "$all_md" && guarded=1
  # Deliberately NOT accepting SKILL.md pre-flight as coverage — the router
  # bypasses it (CPT-144).

  [ "$guarded" -eq 1 ] || {
    echo "jq guard is missing from commands/auth.md AND commands/all.md — SKILL.md pre-flight is bypassed by the router on /chk2 and /chk2 all, so the CPT-98 silent-evidence-loss protection is gone (CPT-144)" >&2
    return 1
  }
}

@test "chk2:all frontmatter whitelists Bash(which *) when its body uses 'which jq' (CPT-144)" {
  # If commands/all.md carries the jq guard via `which jq`, its per-command
  # allowed-tools frontmatter must whitelist Bash(which *) — otherwise the
  # guard itself will be tool-denied under CPT-32 enforcement and silently
  # skip, restoring the original CPT-98 failure mode.
  local all_md="${REPO_DIR}/skills/chk2/commands/all.md"
  [ -f "$all_md" ] || skip "all.md not present"
  if grep -qE 'which jq' "$all_md"; then
    grep -E '^allowed-tools:' "$all_md" | grep -qE 'Bash\(which' || {
      echo "commands/all.md uses 'which jq' but frontmatter lacks Bash(which *) — guard will be tool-denied (CPT-144)" >&2
      return 1
    }
  fi
}
