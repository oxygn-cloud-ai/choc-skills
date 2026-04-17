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
