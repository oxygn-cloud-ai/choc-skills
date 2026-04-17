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

# --- CPT-136: CPT-101 fix introduced printf in reporting.md body without
#     extending allowed-tools. Under per-command enforcement RC4 is denied
#     → silent evidence loss (same fix-introduces-new-silent-failure pattern
#     as CPT-88/98). Guard:

@test "chk2:reporting frontmatter whitelists printf (CPT-136)" {
  line=$(grep '^allowed-tools:' "$REPO_ROOT/skills/chk2/commands/reporting.md")
  [[ "$line" == *"Bash(printf"* ]]
}

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

@test "no update command has the narrow Bash(bash install.sh *) pattern ALONE (CPT-119, CPT-150 refined)" {
  # Pre-CPT-119: frontmatter carried ONLY the bare `Bash(bash install.sh *)`
  # form — that did not cover absolute-path invocations (`bash /abs/path/
  # install.sh --force`) which the body instructs. The offender is the
  # bare form WITHOUT any other install.sh-anchored pattern alongside it.
  #
  # CPT-150 adds `Bash(bash ./install.sh *)` and `Bash(bash */install.sh *)`
  # alongside the bare form — the triplet together covers all invocation
  # shapes safely. An update.md that carries the bare form AND at least
  # one path-anchored form is NOT an offender.
  offenders=""
  for f in "$REPO_ROOT"/skills/*/commands/update.md; do
    [ -f "$f" ] || continue
    allow=$(head -20 "$f" | grep '^allowed-tools:' || true)
    if printf '%s' "$allow" | grep -qE 'Bash\(bash install\.sh \*\)'; then
      # Bare form present — require a path-anchored companion.
      if ! printf '%s' "$allow" | grep -qE 'Bash\(bash (\./install\.sh \*|\*/install\.sh \*)\)'; then
        offenders="$offenders ${f#$REPO_ROOT/}"
      fi
    fi
  done
  echo "offenders (bare form present without path-anchored companion):$offenders"
  [ -z "$offenders" ]
}

@test "every update command has a pattern covering absolute-path bash invocation (CPT-119)" {
  # For every update.md that instructs the model to run `bash <path>/install.sh`,
  # the allowed-tools frontmatter MUST contain a pattern that will match such
  # calls. Acceptable anchored forms (CPT-150 hardened — pre-CPT-150 the
  # regex also accepted `Bash(bash *install.sh *)` which matches
  # uninstall.sh/reinstall.sh substrings and weakened CPT-25 least-privilege):
  #   - Bash(bash install.sh *)      ← bare same-directory
  #   - Bash(bash ./install.sh *)    ← explicit same-directory
  #   - Bash(bash */install.sh *)    ← any path ending in /install.sh
  #   - Bash(bash *)                 ← wide bash-only catch-all (still acceptable)
  #   - Bash                         ← fully unrestricted Bash
  offenders=""
  for f in "$REPO_ROOT"/skills/*/commands/update.md; do
    [ -f "$f" ] || continue
    body=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2' "$f")
    # Extract the whole frontmatter block for allowed-tools inspection
    fm=$(awk 'BEGIN{fm=0} /^---$/{fm++; if(fm==2)exit; next} fm==1' "$f")
    if printf '%s' "$body" | grep -qE 'bash [^ ]*/install\.sh'; then
      if ! printf '%s' "$fm" | grep -qE '(Bash\(bash (install\.sh \*|\./install\.sh \*|\*/install\.sh \*|\*)\)|(^|[[:space:],-])Bash([[:space:],]|$))'; then
        offenders="$offenders ${f#$REPO_ROOT/}"
      fi
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}

# --- CPT-150: CPT-119's canonical widening `Bash(bash *install.sh *)` uses a
#     leading-glob that substring-matches `uninstall.sh`, `reinstall.sh`, and
#     any `*install.sh.bak`-shape path. CPT-25's least-privilege rationale is
#     weakened even when the body instructions don't currently invoke those.
#     Fix: anchor the pattern so `install.sh` must be either bare, `./install.sh`,
#     or `*/install.sh` — all forms require a path-separator (or start) before
#     `install.sh`.

@test "CPT-150: no update command keeps the unanchored Bash(bash *install.sh *) pattern" {
  offenders=""
  for f in "$REPO_ROOT"/skills/*/commands/update.md; do
    [ -f "$f" ] || continue
    allow=$(head -20 "$f" | grep '^allowed-tools:' || true)
    # The unanchored form `Bash(bash *install.sh *)` (leading glob before
    # `install.sh` with no required path-separator) MUST NOT appear.
    if printf '%s' "$allow" | grep -qE 'Bash\(bash \*install\.sh \*\)'; then
      offenders="$offenders ${f#$REPO_ROOT/}"
    fi
  done
  echo "offenders (still carry Bash(bash *install.sh *)): $offenders"
  [ -z "$offenders" ]
}

@test "CPT-150: update commands carrying any bash-install.sh pattern use an anchored form" {
  # If the frontmatter mentions `install.sh` inside a `Bash(bash ...)`
  # pattern AT ALL, at least one of the anchored forms must be present.
  # Files that rely on the wider `Bash(bash *)` catch-all, or that don't
  # mention install.sh under `bash`, are out of scope for this assertion.
  offenders=""
  for f in "$REPO_ROOT"/skills/*/commands/update.md; do
    [ -f "$f" ] || continue
    allow=$(head -20 "$f" | grep '^allowed-tools:' || true)
    # Does the frontmatter carry any `Bash(bash ... install.sh ...)` pattern?
    if printf '%s' "$allow" | grep -qE 'Bash\(bash [^)]*install\.sh[^)]*\)'; then
      # Yes — require at least one anchored form.
      if ! printf '%s' "$allow" | grep -qE 'Bash\(bash (install\.sh \*|\./install\.sh \*|\*/install\.sh \*)\)'; then
        offenders="$offenders ${f#$REPO_ROOT/}"
      fi
    fi
  done
  echo "offenders (bash-install.sh pattern present but none anchored): $offenders"
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

@test "chk2 category sub-skills reference the correct SECURITY_CHECK.parts path in the Output block (CPT-125, scope-fixed CPT-151)" {
  # Each category sub-skill's `## Output` block must mention `SECURITY_CHECK.parts/`,
  # which is where the sub-skill actually writes (orchestrators merge later).
  #
  # CPT-151: the grep below is deliberately scoped to just the `## Output`
  # block (awk extracts from `## Output` up to the next `## ` heading).
  # A whole-file grep would also match the CPT-125 intro line and the
  # CPT-126 `## After` / `## Status signal` sections, so it would silently
  # miss an accidental removal from the actual Output block. The new regression
  # meta-test below proves the scope is load-bearing.
  offenders=""
  for f in "$REPO_ROOT"/skills/chk2/commands/*.md; do
    name=$(basename "$f")
    case "$name" in all.md|quick.md|fix.md|github.md|update.md|help.md|doctor.md|version.md) continue ;; esac
    output_block=$(awk '/^## Output/{flag=1; next} /^## /{flag=0} flag' "$f")
    if ! printf '%s\n' "$output_block" | grep -q 'SECURITY_CHECK\.parts/'; then
      offenders="$offenders $name"
    fi
  done
  echo "offenders:$offenders"
  [ -z "$offenders" ]
}

@test "CPT-151: Output-block scope is load-bearing — whole-file grep would miss an Output-block removal" {
  # Synthetic category file where the `## Output` block does NOT mention
  # SECURITY_CHECK.parts/ (simulating an accidental removal) but the
  # `## After` block DOES (via the CPT-126 `.orchestrated` marker path).
  #
  # Assert:
  #   1. The old whole-file grep "passes" this file (bug: misses the removal).
  #   2. The new awk-scoped grep correctly flags it.
  #
  # If this test ever fails, the CPT-125 production test above is no longer
  # scope-protected and CPT-151's fix has regressed.
  local tmpfile
  tmpfile=$(mktemp)
  cat > "$tmpfile" <<'EOF'
---
name: chk2:synthetic
---

# chk2:synthetic

Intro mentioning `SECURITY_CHECK.parts/synthetic.md`.

## Tests

Some tests here.

## Output

Write to `SECURITY_CHECK.md` (deliberately scrubbed — no .parts path).

## After — standalone only

Check `SECURITY_CHECK.parts/.orchestrated`; if absent, also write `SECURITY_CHECK.md`.
EOF

  # Old logic (whole-file grep) — incorrectly "passes"
  run grep -q 'SECURITY_CHECK\.parts/' "$tmpfile"
  [ "$status" -eq 0 ]

  # New logic (awk-scoped to `## Output` block) — correctly flags
  local output_block
  output_block=$(awk '/^## Output/{flag=1; next} /^## /{flag=0} flag' "$tmpfile")
  run bash -c 'printf "%s\n" "$1" | grep -q "SECURITY_CHECK\.parts/"' _ "$output_block"
  [ "$status" -ne 0 ]

  rm -f "$tmpfile"
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

# --- CPT-152: the CPT-126 orchestrator marker is created via `touch` in body,
#     but neither orchestrator's frontmatter lists Bash(touch *). Under per-command
#     enforcement, the touch is denied → marker never created → sub-skills see
#     no marker → they execute the standalone-merge path under /chk2:all, which
#     reintroduces the CPT-88 race the marker was designed to close.
#
#     Fix: use the Write tool (already in both orchestrators' allowed-tools) to
#     create the marker file, instead of shell touch. Keeps the allowed-tools
#     surface minimal (triager-approved Option B in ticket comment 60301).

@test "CPT-152: chk2 orchestrators do NOT use 'touch' to create the .orchestrated marker" {
  offenders=""
  for f in "$REPO_ROOT"/skills/chk2/commands/all.md \
           "$REPO_ROOT"/skills/chk2/commands/quick.md; do
    [ -f "$f" ] || continue
    if grep -qE 'touch[[:space:]]+SECURITY_CHECK\.parts/\.orchestrated' "$f"; then
      offenders="$offenders ${f#$REPO_ROOT/}"
    fi
  done
  echo "offenders (still using touch): $offenders"
  [ -z "$offenders" ]
}

@test "CPT-152: chk2 orchestrators instruct the Write tool for the .orchestrated marker" {
  offenders=""
  for f in "$REPO_ROOT"/skills/chk2/commands/all.md \
           "$REPO_ROOT"/skills/chk2/commands/quick.md; do
    [ -f "$f" ] || continue
    # Within ~200 chars of a `.orchestrated` reference, the body must name the
    # Write tool. Cross-line match allowed; case-sensitive on "Write" to avoid
    # matching prose like "write the marker".
    if ! awk '/\.orchestrated/{found=1} found{buf=buf $0 "\n"} END{print buf}' "$f" \
         | grep -qE 'Write tool'; then
      offenders="$offenders ${f#$REPO_ROOT/}"
    fi
  done
  echo "offenders (no Write tool near .orchestrated): $offenders"
  [ -z "$offenders" ]
}
