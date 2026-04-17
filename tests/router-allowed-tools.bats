#!/usr/bin/env bats
# Tests for CPT-32: Router-level allowed-tools should be minimal,
# with heavy tools moved to individual sub-command files.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# --- rr SKILL.md router ---

@test "rr/SKILL.md allowed-tools has 10 or fewer entries" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/SKILL.md")
  # Count comma-separated entries
  count=$(echo "$line" | tr ',' '\n' | wc -l | tr -d ' ')
  [ "$count" -le 10 ]
}

@test "rr/SKILL.md allowed-tools does not include Bash(python3 *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/SKILL.md")
  [[ "$line" != *"Bash(python3"* ]]
}

@test "rr/SKILL.md allowed-tools does not include Bash(bash *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/SKILL.md")
  [[ "$line" != *"Bash(bash"* ]]
}

@test "rr/SKILL.md allowed-tools does not include Bash(curl *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/SKILL.md")
  [[ "$line" != *"Bash(curl"* ]]
}

@test "rr/SKILL.md allowed-tools does not include WebSearch" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/SKILL.md")
  [[ "$line" != *"WebSearch"* ]]
}

# --- chk2 SKILL.md router ---

@test "chk2/SKILL.md allowed-tools has 10 or fewer entries" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/SKILL.md")
  count=$(echo "$line" | tr ',' '\n' | wc -l | tr -d ' ')
  [ "$count" -le 10 ]
}

@test "chk2/SKILL.md allowed-tools does not include Bash(python3 *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/SKILL.md")
  [[ "$line" != *"Bash(python3"* ]]
}

@test "chk2/SKILL.md allowed-tools does not include Bash(openssl *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/SKILL.md")
  [[ "$line" != *"Bash(openssl"* ]]
}

@test "chk2/SKILL.md allowed-tools does not include Bash(dig *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/SKILL.md")
  [[ "$line" != *"Bash(dig"* ]]
}

@test "chk2/SKILL.md allowed-tools does not include Bash(nmap *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/SKILL.md")
  [[ "$line" != *"Bash(nmap"* ]]
}

# --- rr sub-commands must have allowed-tools frontmatter ---

@test "every rr sub-command has allowed-tools in frontmatter" {
  missing=""
  for f in "$REPO_ROOT"/skills/rr/commands/*.md; do
    name=$(basename "$f")
    if ! head -20 "$f" | grep -q '^allowed-tools:'; then
      missing="$missing $name"
    fi
  done
  echo "missing:$missing"
  [ -z "$missing" ]
}

@test "rr sub-commands have YAML frontmatter delimiters" {
  missing=""
  for f in "$REPO_ROOT"/skills/rr/commands/*.md; do
    name=$(basename "$f")
    first_line=$(head -1 "$f")
    if [ "$first_line" != "---" ]; then
      missing="$missing $name"
    fi
  done
  echo "missing:$missing"
  [ -z "$missing" ]
}

# --- chk2 sub-commands must have allowed-tools frontmatter ---

@test "every chk2 sub-command has allowed-tools in frontmatter" {
  missing=""
  for f in "$REPO_ROOT"/skills/chk2/commands/*.md; do
    name=$(basename "$f")
    if ! head -20 "$f" | grep -q '^allowed-tools:'; then
      missing="$missing $name"
    fi
  done
  echo "missing:$missing"
  [ -z "$missing" ]
}

@test "chk2 sub-commands have YAML frontmatter delimiters" {
  missing=""
  for f in "$REPO_ROOT"/skills/chk2/commands/*.md; do
    name=$(basename "$f")
    first_line=$(head -1 "$f")
    if [ "$first_line" != "---" ]; then
      missing="$missing $name"
    fi
  done
  echo "missing:$missing"
  [ -z "$missing" ]
}

# --- Sub-command tools must be sufficient for their job ---

@test "rr review sub-command has WebSearch (needs regulatory lookups)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/commands/review.md")
  [[ "$line" == *"WebSearch"* ]]
}

@test "rr review sub-command has Write (creates JSON artifacts)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/commands/review.md")
  [[ "$line" == *"Write"* ]]
}

@test "rr all sub-command has Agent (spawns sub-agents)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/commands/all.md")
  [[ "$line" == *"Agent"* ]]
}

@test "chk2 all sub-command has Agent (parallel category dispatch) — CPT-110" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/commands/all.md")
  [[ "$line" == *"Agent"* ]]
}

# --- Body→frontmatter cross-check: any command that tells the model to use the
#     Agent tool MUST list Agent in allowed-tools. Catches the CPT-110 class of
#     defect at CI time.

@test "every command that invokes Agent in body declares Agent in allowed-tools (CPT-110)" {
  offenders=""
  # Check both router SKILL.md files and per-command files
  for f in "$REPO_ROOT"/skills/*/commands/*.md "$REPO_ROOT"/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    # Extract body (everything after the second '---' fence)
    body=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2' "$f")
    # Does the body IMPERATIVELY instruct the model to use the Agent tool?
    # An imperative is one of: Launch/Spawn/Dispatch/using within ~40 chars of
    # "Agent tool"/"Agent call"/"parallel Agent", OR the code keyword
    # "subagent_type". Descriptive mentions like "runs under X (via the Agent
    # tool)" are intentionally NOT matched — they describe external behavior
    # rather than instruct the current command.
    if printf '%s' "$body" | grep -qE '([Ll]aunch|[Ss]pawn|[Dd]ispatch|[Uu]sing|[Uu]se).{0,40}(Agent tool|Agent call|parallel Agent)|subagent_type'; then
      # Frontmatter allowed-tools must list Agent as a distinct entry
      allow=$(head -30 "$f" | grep '^allowed-tools:' || true)
      if ! printf '%s' "$allow" | grep -qE '(^|[[:space:],])Agent([[:space:],]|$)'; then
        offenders="$offenders ${f#$REPO_ROOT/}"
      fi
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}

@test "chk2 tls sub-command has Bash(openssl *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/commands/tls.md")
  [[ "$line" == *"Bash(openssl"* ]]
}

@test "chk2 dns sub-command has Bash(dig *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/commands/dns.md")
  [[ "$line" == *"Bash(dig"* ]]
}

@test "chk2 timing sub-command has Bash(python3 *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/commands/timing.md")
  [[ "$line" == *"Bash(python3"* ]]
}

@test "chk2 github sub-command has Bash(gh *)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/commands/github.md")
  [[ "$line" == *"Bash(gh"* ]]
}

# --- chk2 sub-commands should not have Bash(bash *) catch-all ---
# (rr sub-commands may need it for shell script invocation)

@test "no chk2 sub-command has Bash(bash *) catch-all" {
  offenders=""
  for f in "$REPO_ROOT"/skills/chk2/commands/*.md; do
    name=$(basename "$f")
    if head -20 "$f" | grep '^allowed-tools:' | grep -q 'Bash(bash \*)'; then
      offenders="$offenders $name"
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}

# --- CPT-128: rr:all invokes _update_cpt.sh from the body but frontmatter
#     doesn't whitelist the path. The invocations have `|| true` suffix so
#     failures hide as "silent observability degradation" — CPT-1 progress
#     tracking simply stops reporting with no visible error.

@test "rr:all frontmatter whitelists _update_cpt.sh (CPT-128)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/rr/commands/all.md")
  [[ "$line" == *"_update_cpt.sh"* ]]
}

@test "every rr sub-command that invokes an rr/bin/ script in the body declares it in allowed-tools (CPT-128)" {
  # Body→frontmatter cross-check. Any `~/.claude/skills/rr/bin/<name>.sh`
  # invocation in the body must be matched by a corresponding
  # `Bash(~/.claude/skills/rr/bin/<name>.sh *)` in the frontmatter.
  # Excluded: `ls <path>` existence checks (covered by `Bash(ls *)`).
  offenders=""
  for f in "$REPO_ROOT"/skills/rr/commands/*.md; do
    name=$(basename "$f")
    body=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2' "$f")
    allow=$(head -30 "$f" | grep '^allowed-tools:' || true)
    # Drop lines where the script path is a `ls <path>` existence check.
    real_invocations=$(printf '%s' "$body" | grep -E '~/\.claude/skills/rr/bin/[A-Za-z0-9_.-]+\.sh' | grep -v 'ls ~/\.claude/skills/rr/bin/' || true)
    scripts=$(printf '%s' "$real_invocations" | grep -oE '~/\.claude/skills/rr/bin/[A-Za-z0-9_.-]+\.sh' | sort -u || true)
    for script in $scripts; do
      if ! printf '%s' "$allow" | grep -qF "Bash($script *)"; then
        offenders="$offenders ${name}:$(basename "$script")"
      fi
    done
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}

# --- CPT-119: narrow Bash(bash install.sh *) pattern blocks absolute-path invocation ---
#
# `bash <repo-path>/skills/<skill>/install.sh --force` (the documented primary
# update flow when .source-repo is set) does NOT match the literal
# `bash install.sh *` pattern because the command starts with
# `bash /Volumes/…` not `bash install.sh`. Under per-command tool enforcement,
# the sandbox blocks the invocation and the update silently fails. The fix is
# to widen to `Bash(bash *install.sh *)` which matches both the absolute-path
# and bare forms while still constraining to install.sh invocations.

@test "no update command has the narrow Bash(bash install.sh *) pattern (CPT-119)" {
  offenders=""
  for f in "$REPO_ROOT"/skills/*/commands/update.md; do
    [ -f "$f" ] || continue
    allow=$(head -20 "$f" | grep '^allowed-tools:' || true)
    # The literal narrow pattern is `Bash(bash install.sh *)` — NOT widened.
    # The widened form is `Bash(bash *install.sh *)` (note the leading `*`).
    # If the narrow form appears in the allowed-tools line, that's an offender.
    if printf '%s' "$allow" | grep -qE 'Bash\(bash install\.sh \*\)'; then
      offenders="$offenders ${f#$REPO_ROOT/}"
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}

@test "every update command has a pattern covering absolute-path bash invocation (CPT-119)" {
  # For every update.md that instructs the model to run `bash <path>/install.sh`,
  # the allowed-tools frontmatter MUST contain a pattern that will match such
  # calls. Acceptable forms (both inline `allowed-tools: a, b, c` and YAML
  # list syntax are handled):
  #   - Bash(bash *install.sh *)  ← the canonical widening
  #   - Bash(bash *)              ← wide bash-only catch-all
  #   - Bash                      ← fully unrestricted Bash
  offenders=""
  for f in "$REPO_ROOT"/skills/*/commands/update.md; do
    [ -f "$f" ] || continue
    body=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2' "$f")
    # Extract the whole frontmatter block for allowed-tools inspection
    fm=$(awk 'BEGIN{fm=0} /^---$/{fm++; if(fm==2)exit; next} fm==1' "$f")
    if printf '%s' "$body" | grep -qE 'bash [^ ]*/install\.sh'; then
      if ! printf '%s' "$fm" | grep -qE '(Bash\(bash \*(install\.sh \*)?\)|(^|[[:space:],-])Bash([[:space:],]|$))'; then
        offenders="$offenders ${f#$REPO_ROOT/}"
      fi
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}

# --- CPT-125: opening paragraph of each category sub-skill must not contradict
#     the Output block. CPT-88 switched sub-skills to write per-category part
#     files (SECURITY_CHECK.parts/<cat>.md) but left the opening paragraph of
#     every category file still saying "Append results to SECURITY_CHECK.md" —
#     an agent reading top-to-bottom may follow either instruction, leaving the
#     concurrent-write race CPT-88 was meant to close reachable.
#
#     The fix here narrowly removes the contradictory opening sentence. The
#     authoritative output-path instruction stays in the `## Output` block.

@test "no chk2 category sub-skill instructs 'Append results to SECURITY_CHECK.md' in the intro (CPT-125)" {
  offenders=""
  for f in "$REPO_ROOT"/skills/chk2/commands/*.md; do
    name=$(basename "$f")
    # Orchestrators (all.md, quick.md) legitimately own SECURITY_CHECK.md via
    # the merge step — skip them.
    case "$name" in all.md|quick.md) continue ;; esac
    if grep -qE 'Append results to `SECURITY_CHECK\.md`' "$f"; then
      offenders="$offenders $name"
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}

@test "chk2 category sub-skills reference the correct SECURITY_CHECK.parts path in the Output block (CPT-125)" {
  # Each category sub-skill's Output block must mention `SECURITY_CHECK.parts/`,
  # which is where the sub-skill actually writes (orchestrators merge later).
  offenders=""
  for f in "$REPO_ROOT"/skills/chk2/commands/*.md; do
    name=$(basename "$f")
    case "$name" in all.md|quick.md|fix.md|github.md|update.md|help.md|doctor.md|version.md) continue ;; esac
    if ! grep -q 'SECURITY_CHECK\.parts/' "$f"; then
      offenders="$offenders $name"
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}

# --- CPT-126: standalone /chk2 category runs must still produce SECURITY_CHECK.md ---
#
# Post-CPT-88, category sub-skills write only to SECURITY_CHECK.parts/<cat>.md.
# The merge into SECURITY_CHECK.md happens only inside /chk2:all and /chk2:quick
# orchestrators. Direct invocations like `/chk2 tls` bypass the orchestrator, so
# SECURITY_CHECK.md is never produced and downstream /chk2:fix / /chk2 github
# (which read SECURITY_CHECK.md) fail.
#
# Fix: each orchestrator creates a .orchestrated marker at start and removes it
# after the merge step. Each sub-skill Output block conditionally copies its
# part file to SECURITY_CHECK.md when the marker is absent (standalone mode).

@test "chk2:all orchestrator creates the .orchestrated marker in step 1 (CPT-126)" {
  grep -q 'SECURITY_CHECK\.parts/\.orchestrated' "$REPO_ROOT/skills/chk2/commands/all.md"
}

@test "chk2:all orchestrator removes the .orchestrated marker after merge (CPT-126)" {
  grep -qE 'rm [^#]*SECURITY_CHECK\.parts/\.orchestrated' "$REPO_ROOT/skills/chk2/commands/all.md"
}

@test "chk2:quick orchestrator creates the .orchestrated marker in step 1 (CPT-126)" {
  grep -q 'SECURITY_CHECK\.parts/\.orchestrated' "$REPO_ROOT/skills/chk2/commands/quick.md"
}

@test "chk2:quick orchestrator removes the .orchestrated marker after merge (CPT-126)" {
  grep -qE 'rm [^#]*SECURITY_CHECK\.parts/\.orchestrated' "$REPO_ROOT/skills/chk2/commands/quick.md"
}

@test "every chk2 category sub-skill has a standalone-merge step gated on .orchestrated (CPT-126)" {
  offenders=""
  for f in "$REPO_ROOT"/skills/chk2/commands/*.md; do
    name=$(basename "$f")
    # Orchestrators / utilities do not need the standalone-merge block.
    case "$name" in all.md|quick.md|fix.md|github.md|update.md|help.md|doctor.md|version.md) continue ;; esac
    # The Output block must contain the marker-existence check AND an
    # instruction to write to SECURITY_CHECK.md in the standalone case.
    if ! grep -q 'SECURITY_CHECK\.parts/\.orchestrated' "$f"; then
      offenders="$offenders $name"
      continue
    fi
    # "Standalone merge" anchor phrase MUST appear — it's the literal marker
    # the fix adds to every sub-skill's Output block.
    if ! grep -q 'Standalone merge' "$f"; then
      offenders="$offenders $name"
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}

# --- CPT-127: sub-skill sections must be gated on .orchestrated so
#     CHK2-STATUS is the final line under orchestration and `Ask the user`
#     fires cleanly only under standalone invocation. Anchor phrase convention:
#       After    → `standalone only`  (header suffix)
#       Status   → `orchestrated only` (header suffix)

@test "chk2 category sub-skills: '## After' header carries the 'standalone only' anchor (CPT-127)" {
  offenders=""
  for f in "$REPO_ROOT"/skills/chk2/commands/*.md; do
    name=$(basename "$f")
    case "$name" in all.md|quick.md|fix.md|github.md|update.md|help.md|doctor.md|version.md) continue ;; esac
    if ! grep -qE '^## After.*standalone only' "$f"; then
      offenders="$offenders $name"
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}

@test "chk2 category sub-skills: '## Status signal' header carries the 'orchestrated only' anchor (CPT-127)" {
  offenders=""
  for f in "$REPO_ROOT"/skills/chk2/commands/*.md; do
    name=$(basename "$f")
    case "$name" in all.md|quick.md|fix.md|github.md|update.md|help.md|doctor.md|version.md) continue ;; esac
    if ! grep -qE '^## Status signal.*orchestrated only' "$f"; then
      offenders="$offenders $name"
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}

@test "chk2 category sub-skills: Status block explicitly gates on .orchestrated absence (CPT-127)" {
  offenders=""
  for f in "$REPO_ROOT"/skills/chk2/commands/*.md; do
    name=$(basename "$f")
    case "$name" in all.md|quick.md|fix.md|github.md|update.md|help.md|doctor.md|version.md) continue ;; esac
    status_block=$(awk '/^## Status signal/{flag=1} flag' "$f")
    if ! printf '%s' "$status_block" | grep -qE '[Ss]kip.*\.orchestrated|\.orchestrated.*does NOT exist'; then
      offenders="$offenders $name"
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}
