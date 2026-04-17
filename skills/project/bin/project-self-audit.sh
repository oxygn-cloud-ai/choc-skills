#!/usr/bin/env bash
set -uo pipefail

# project-self-audit — Recursive / meta audit of the /project skill itself.
#
# Implements: CPT-59 (skills/project/CLAUDE.md "Skill-is-product rule")
#
# 5 checks:
#   A  Install parity      skill source shasum vs ~/.claude/<target> byte-identical;
#                          orphan detection for hooks + settings-registration integrity.
#   B  Rules → Mechanisms  every enforcement rule in the standards docs has a
#                          mechanism in skill source that cites it via
#                          "# Implements: <doc>:§<section>".
#   C  Mechanisms → Rules  every mechanism citing "# Implements:" points at a
#                          rule that actually exists in the cited doc.
#   D  Install manifest    every source file under hooks/, bin/, commands/ is
#                          referenced by install.sh (by basename).
#   E  Standards           run scripts/validate-skills.sh + (when present)
#                          scripts/validate-config.sh as a proxy for /project:audit.
#
# Exit code contract:
#   0  All checks PASS
#   1  One or more checks FLAG
#   2  Invocation error (unknown flag, missing file, etc.)

# --------------------------------------------------------------------------
# Resolve skill source path. This script may live at either:
#   <repo>/skills/project/bin/project-self-audit.sh  (invoked from a checkout)
#   ~/.claude/skills/project/bin/project-self-audit.sh  (invoked from install)
#
# When invoked from the install target, we need to find the source repo via the
# .source-repo marker so we can compare source↔target.
# --------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Walk up: if we're under bin/, the skill dir is the parent.
if [ "$(basename "$SCRIPT_DIR")" = "bin" ]; then
  SKILL_DIR="$(dirname "$SCRIPT_DIR")"
else
  SKILL_DIR="$SCRIPT_DIR"
fi

# Determine source repo: prefer .source-repo marker, fall back to SKILL_DIR
# when we're already in a repo checkout.
SOURCE_REPO=""
if [ -f "${SKILL_DIR}/.source-repo" ]; then
  SOURCE_REPO="$(cat "${SKILL_DIR}/.source-repo")"
elif [ -d "${SKILL_DIR}/.." ] && [ -f "${SKILL_DIR}/../../install.sh" ]; then
  # Running from a repo checkout: skills/project/ → repo root is two levels up
  SOURCE_REPO="$(cd "${SKILL_DIR}/../.." && pwd)"
fi

# If we're running inside a repo checkout, $SKILL_DIR is already the source.
# Otherwise point at the source skill under the resolved repo.
if [ -n "$SOURCE_REPO" ] && [ -d "${SOURCE_REPO}/skills/project" ]; then
  SRC_SKILL="${SOURCE_REPO}/skills/project"
else
  SRC_SKILL="$SKILL_DIR"
fi

INSTALL_SKILL="${HOME}/.claude/skills/project"
INSTALL_COMMANDS="${HOME}/.claude/commands/project"
INSTALL_HOOKS="${HOME}/.claude/hooks"
INSTALL_SETTINGS="${HOME}/.claude/settings.json"

# --------------------------------------------------------------------------
# Output helpers
# --------------------------------------------------------------------------

FORMAT="human"
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

pass() { [ "$FORMAT" = "human" ] && printf "${GREEN}  PASS${RESET}  %s\n" "$*"; }
flag() { [ "$FORMAT" = "human" ] && printf "${YELLOW}  FLAG${RESET}  %s\n" "$*"; }
fail() { [ "$FORMAT" = "human" ] && printf "${RED}  FAIL${RESET}  %s\n" "$*" >&2; }
info() { [ "$FORMAT" = "human" ] && printf "${CYAN}  info${RESET}  %s\n" "$*"; }
header() { [ "$FORMAT" = "human" ] && printf "\n${BOLD}%s${RESET}\n" "$*"; }
die()  { fail "$@"; exit 2; }

# --------------------------------------------------------------------------
# Usage
# --------------------------------------------------------------------------

usage() {
  cat <<EOF
${BOLD}project self-audit${RESET} — recursive audit of the /project skill

${BOLD}USAGE${RESET}
  project-self-audit              Run all 5 checks (A-E)
  project-self-audit --parity     Check A only (install byte-parity + orphans)
  project-self-audit --rules      Checks B + C (rules ↔ mechanisms)
  project-self-audit --manifest   Check D (install.sh coverage)
  project-self-audit --standards  Check E (validate-skills + validate-config)
  project-self-audit --format=json   Machine-readable output
  project-self-audit --version    Show version
  project-self-audit --help       Show this help

${BOLD}EXIT CODES${RESET}
  0  all checks passed
  1  one or more checks flagged
  2  invocation error

${BOLD}IMPLEMENTS${RESET}
  skills/project/CLAUDE.md "Skill-is-product rule"
EOF
}

# --------------------------------------------------------------------------
# JSON accumulator (only populated when FORMAT=json)
# --------------------------------------------------------------------------

JSON_RESULTS=""   # comma-separated list of {check, verdict, detail} objects

json_add() {
  local check="$1" verdict="$2" detail="$3"
  local esc_detail
  esc_detail=$(printf '%s' "$detail" | python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))")
  local entry="{\"check\":\"${check}\",\"verdict\":\"${verdict}\",\"detail\":${esc_detail}}"
  if [ -z "$JSON_RESULTS" ]; then
    JSON_RESULTS="$entry"
  else
    JSON_RESULTS="${JSON_RESULTS},${entry}"
  fi
}

# --------------------------------------------------------------------------
# Record per-check verdicts
# --------------------------------------------------------------------------

A_PASS=0; A_FLAG=0
B_PASS=0; B_FLAG=0
C_PASS=0; C_FLAG=0
D_PASS=0; D_FLAG=0
E_PASS=0; E_FLAG=0

flag_a() { A_FLAG=$((A_FLAG+1)); flag "A — $*"; json_add "A" "flag" "$*"; }
pass_a() { A_PASS=$((A_PASS+1)); pass "A — $*"; json_add "A" "pass" "$*"; }
flag_b() { B_FLAG=$((B_FLAG+1)); flag "B — $*"; json_add "B" "flag" "$*"; }
pass_b() { B_PASS=$((B_PASS+1)); pass "B — $*"; json_add "B" "pass" "$*"; }
flag_c() { C_FLAG=$((C_FLAG+1)); flag "C — $*"; json_add "C" "flag" "$*"; }
pass_c() { C_PASS=$((C_PASS+1)); pass "C — $*"; json_add "C" "pass" "$*"; }
flag_d() { D_FLAG=$((D_FLAG+1)); flag "D — $*"; json_add "D" "flag" "$*"; }
pass_d() { D_PASS=$((D_PASS+1)); pass "D — $*"; json_add "D" "pass" "$*"; }
flag_e() { E_FLAG=$((E_FLAG+1)); flag "E — $*"; json_add "E" "flag" "$*"; }
pass_e() { E_PASS=$((E_PASS+1)); pass "E — $*"; json_add "E" "pass" "$*"; }

# --------------------------------------------------------------------------
# Check A — Install parity
# --------------------------------------------------------------------------

check_a() {
  header "A. Install parity (source ↔ ~/.claude/)"

  if [ ! -d "$INSTALL_SKILL" ]; then
    flag_a "skill not installed at $INSTALL_SKILL — run ./install.sh --force"
    return
  fi

  local mismatches=0 checked=0

  # 1. Commands byte-parity
  if [ -d "${SRC_SKILL}/commands" ]; then
    for src in "${SRC_SKILL}/commands"/*.md; do
      [ -f "$src" ] || continue
      local name
      name=$(basename "$src")
      local target="${INSTALL_COMMANDS}/${name}"
      checked=$((checked+1))
      if [ ! -f "$target" ]; then
        flag_a "MISSING commands/${name} — source exists but not installed"
        mismatches=$((mismatches+1))
        continue
      fi
      local ssha tsha
      ssha=$(shasum -a 256 "$src" | cut -d' ' -f1)
      tsha=$(shasum -a 256 "$target" | cut -d' ' -f1)
      if [ "$ssha" != "$tsha" ]; then
        flag_a "DRIFT commands/${name} — installed copy differs from source"
        mismatches=$((mismatches+1))
      fi
    done
  fi

  # 2. Hooks byte-parity (install location: ~/.claude/hooks/<basename>)
  if [ -d "${SRC_SKILL}/hooks" ]; then
    for src in "${SRC_SKILL}/hooks"/*.sh; do
      [ -f "$src" ] || continue
      local name
      name=$(basename "$src")
      local target="${INSTALL_HOOKS}/${name}"
      checked=$((checked+1))
      if [ ! -f "$target" ]; then
        flag_a "MISSING hooks/${name} — source exists but not installed"
        mismatches=$((mismatches+1))
        continue
      fi
      local ssha tsha
      ssha=$(shasum -a 256 "$src" | cut -d' ' -f1)
      tsha=$(shasum -a 256 "$target" | cut -d' ' -f1)
      if [ "$ssha" != "$tsha" ]; then
        flag_a "DRIFT hooks/${name} — installed copy differs from source"
        mismatches=$((mismatches+1))
      fi
    done
  fi

  # 3. Bin byte-parity (install location: ~/.local/bin/<basename>)
  local local_bin="${HOME}/.local/bin"
  if [ -d "${SRC_SKILL}/bin" ]; then
    for src in "${SRC_SKILL}/bin"/*.sh; do
      [ -f "$src" ] || continue
      local name
      name=$(basename "$src")
      local target="${local_bin}/${name}"
      checked=$((checked+1))
      if [ ! -f "$target" ]; then
        # Not all bin scripts ship to ~/.local/bin — some live under ~/.claude/skills/project/bin/
        # Accept either location as the install target.
        local alt="${INSTALL_SKILL}/bin/${name}"
        if [ -f "$alt" ]; then
          target="$alt"
        else
          flag_a "MISSING bin/${name} — source exists but not installed"
          mismatches=$((mismatches+1))
          continue
        fi
      fi
      local ssha tsha
      ssha=$(shasum -a 256 "$src" | cut -d' ' -f1)
      tsha=$(shasum -a 256 "$target" | cut -d' ' -f1)
      if [ "$ssha" != "$tsha" ]; then
        flag_a "DRIFT bin/${name} — installed copy differs from source"
        mismatches=$((mismatches+1))
      fi
    done
  fi

  # 4. Orphan hook detection — hooks under ~/.claude/hooks/ named like project-skill hooks
  #    but with no source under skills/project/hooks/
  if [ -d "$INSTALL_HOOKS" ]; then
    for target in "${INSTALL_HOOKS}"/*.sh; do
      [ -f "$target" ] || continue
      local name
      name=$(basename "$target")
      # Heuristic: project-skill hooks either match known names or match project-* prefix
      case "$name" in
        block-worktree-add.sh|verify-jira-parent.sh|project-*)
          if [ ! -f "${SRC_SKILL}/hooks/${name}" ]; then
            flag_a "ORPHAN hooks/${name} — installed but no source in skills/project/hooks/"
            mismatches=$((mismatches+1))
          fi
          ;;
      esac
    done
  fi

  # 5. Settings-registration integrity — verify each hook source is registered
  if [ -f "$INSTALL_SETTINGS" ] && command -v jq >/dev/null 2>&1; then
    for src in "${SRC_SKILL}/hooks"/*.sh; do
      [ -f "$src" ] || continue
      local name
      name=$(basename "$src")
      local reg_count
      reg_count=$(jq -r --arg name "$name" \
        '[.hooks.PreToolUse // [] | .[] | .hooks[]? | select(.command // "" | test($name))] | length' \
        "$INSTALL_SETTINGS" 2>/dev/null || echo 0)
      if [ "$reg_count" -lt 1 ]; then
        flag_a "NOT-REGISTERED hooks/${name} — source installed but not in settings.json PreToolUse"
        mismatches=$((mismatches+1))
      fi
    done
  fi

  if [ "$mismatches" -eq 0 ]; then
    pass_a "${checked} file(s) byte-identical, no orphans"
  fi
}

# --------------------------------------------------------------------------
# Check B — Rules → Mechanisms
# --------------------------------------------------------------------------

# For each §N.N section in standards docs whose heading or first paragraph
# contains an enforcement verb, look for a mechanism in skill source that cites
# it via "# Implements: <doc>:§<section>".

check_b() {
  header "B. Rules → Mechanisms (rule has enforcing mechanism)"

  local docs=(
    "${HOME}/.claude/MULTI_SESSION_ARCHITECTURE.md"
    "${HOME}/.claude/PROJECT_STANDARDS.md"
  )

  for doc in "${docs[@]}"; do
    if [ ! -f "$doc" ]; then
      flag_b "standards doc missing: $doc"
      continue
    fi

    local docname
    docname=$(basename "$doc")

    # Extract numbered section headings like "## 7.1 ..." or "### §7.1 ..."
    # Combined with any line containing enforcement verbs.
    local rules
    rules=$(grep -nE "^#+ *(§)?[0-9]+(\.[0-9]+)* " "$doc" | head -40)

    [ -z "$rules" ] && continue

    while IFS= read -r line; do
      [ -z "$line" ] && continue
      # Extract the section number (first N.N or §N.N after the leading ##s)
      local section
      section=$(printf '%s' "$line" | sed -E 's/^[0-9]+:#+ *§?([0-9]+(\.[0-9]+)*) .*/\1/')
      [ -z "$section" ] && continue

      # Look at the next ~15 lines for enforcement verbs
      local lineno
      lineno=$(printf '%s' "$line" | cut -d: -f1)
      local body
      body=$(awk -v start="$lineno" 'NR>=start && NR<start+20' "$doc")

      # Enforcement keywords
      if printf '%s' "$body" | grep -iqE "(forbidden|must not|hard[- ]?block|non-negotiable|blocks|rejected|never)"; then
        # A rule with enforcement language. Look for a mechanism that cites it.
        local citation_target="${docname}:§${section}"
        local found
        found=$(grep -rE "# Implements:.*${citation_target}" \
          "${SRC_SKILL}/hooks" "${SRC_SKILL}/bin" "${SRC_SKILL}/commands" 2>/dev/null | head -1)

        if [ -z "$found" ]; then
          flag_b "${docname} §${section}: enforcement rule has no mechanism citing it"
        fi
      fi
    done <<< "$rules"
  done

  if [ "$B_FLAG" -eq 0 ]; then
    pass_b "every enforcement rule in standards docs has a citing mechanism"
  fi
}

# --------------------------------------------------------------------------
# Check C — Mechanisms → Rules
# --------------------------------------------------------------------------

check_c() {
  header "C. Mechanisms → Rules (every cite resolves to a real rule)"

  # Shell files (hooks/ + bin/): cite starts with '# Implements: '.
  # Markdown files (commands/): cite uses HTML-comment form '<!-- Implements: ... -->'.
  # Excludes .md files from the shell-style grep so fenced code-block examples
  # in CLAUDE.md / docs don't get picked up as real citations.
  local cites_shell cites_md
  cites_shell=$(grep -rhE "^# Implements: " \
    "${SRC_SKILL}/hooks" "${SRC_SKILL}/bin" 2>/dev/null \
    | grep -v '<doc-basename>' | sort -u)
  cites_md=$(grep -rhE "<!-- Implements: .*-->" \
    "${SRC_SKILL}/commands" 2>/dev/null \
    | sed -E 's|^.*<!-- (Implements: [^>]*) -->.*$|# \1|' | sort -u)
  local cites="${cites_shell}"
  if [ -n "$cites_md" ]; then
    if [ -n "$cites" ]; then
      cites="${cites}"$'\n'"${cites_md}"
    else
      cites="$cites_md"
    fi
  fi

  if [ -z "$cites" ]; then
    flag_c "no mechanism in skill source declares '# Implements:' — establish the cite convention"
    return
  fi

  local cite_count=0 unresolved=0
  while IFS= read -r cite; do
    [ -z "$cite" ] && continue
    cite_count=$((cite_count+1))
    # Expected form: "# Implements: <doc>:§<section>" or "# Implements: <doc> §<section>"
    # Extract the doc basename (before the first ':' or ' ' after the prefix).
    local target doc_name section
    target=$(printf '%s' "$cite" | sed -E 's/^# Implements: *//' | awk -F'[: ]' '{print $1}')
    doc_name="$target"
    section=$(printf '%s' "$cite" | sed -nE 's/.*§([0-9]+(\.[0-9]+)*).*/\1/p' | head -1)

    # Map free-form doc references → canonical ~/.claude paths
    local doc_path=""
    case "$doc_name" in
      MULTI_SESSION_ARCHITECTURE.md) doc_path="${HOME}/.claude/MULTI_SESSION_ARCHITECTURE.md" ;;
      PROJECT_STANDARDS.md) doc_path="${HOME}/.claude/PROJECT_STANDARDS.md" ;;
      *CLAUDE.md*|CPT-*)
        # Project-local CLAUDE.md reference or ticket reference — accept as documentation cite
        pass_c "${cite#\# Implements: } (documentation cite)"
        continue
        ;;
      *)
        # Unknown doc — flag
        flag_c "unknown target doc: ${cite}"
        unresolved=$((unresolved+1))
        continue
        ;;
    esac

    if [ ! -f "$doc_path" ]; then
      flag_c "cite references missing doc: ${doc_path}"
      unresolved=$((unresolved+1))
      continue
    fi

    # Verify section heading exists in the doc. Docs use several conventions:
    #   "## 7.1 Worktree creation ..."  (number-space-title)
    #   "## 1. Branch Protection"       (number-period-space-title)
    #   "### §7.1 ..."                   (literal § prefix)
    # Accept any of these: the number followed by space, period, or end of line.
    if [ -n "$section" ]; then
      if ! grep -qE "^#+ *§?${section//./\\.}([ .]|$)" "$doc_path"; then
        flag_c "${cite#\# Implements: } — §${section} not found in ${doc_name}"
        unresolved=$((unresolved+1))
        continue
      fi
    fi

    pass_c "${cite#\# Implements: }"
  done <<< "$cites"

  if [ "$cite_count" -eq 0 ]; then
    flag_c "no citations found"
  fi
}

# --------------------------------------------------------------------------
# Check D — Install manifest
# --------------------------------------------------------------------------

check_d() {
  header "D. Install manifest (every source is installed by install.sh)"

  local install_sh="${SRC_SKILL}/install.sh"
  if [ ! -f "$install_sh" ]; then
    flag_d "install.sh missing at ${install_sh}"
    return
  fi

  local src_files=0 uncovered=0
  for dir in hooks bin commands; do
    [ -d "${SRC_SKILL}/${dir}" ] || continue
    for src in "${SRC_SKILL}/${dir}"/*; do
      [ -f "$src" ] || continue
      local name
      name=$(basename "$src")
      src_files=$((src_files+1))
      # install.sh should reference either the basename or the parent dir
      # (some installers iterate the whole dir without listing files by name)
      if ! grep -qF "$name" "$install_sh" && ! grep -qE "(${dir}_SOURCE|${dir}/)" "$install_sh"; then
        flag_d "${dir}/${name}: install.sh has no reference to this file"
        uncovered=$((uncovered+1))
      fi
    done
  done

  if [ "$uncovered" -eq 0 ]; then
    pass_d "all ${src_files} source file(s) covered by install.sh"
  fi
}

# --------------------------------------------------------------------------
# Check E — Standards compliance (validator proxy for /project:audit)
# --------------------------------------------------------------------------

check_e() {
  header "E. Standards compliance (validate-skills + validate-config)"

  local vs="${SOURCE_REPO}/scripts/validate-skills.sh"
  local vc="${SOURCE_REPO}/scripts/validate-config.sh"

  if [ -z "$SOURCE_REPO" ]; then
    flag_e "no source repo path (.source-repo missing) — cannot run validators"
    return
  fi

  if [ -x "$vs" ]; then
    if bash "$vs" >/dev/null 2>&1; then
      pass_e "validate-skills.sh: PASS"
    else
      flag_e "validate-skills.sh: FAIL"
    fi
  else
    flag_e "validate-skills.sh not found or not executable at ${vs}"
  fi

  if [ -x "$vc" ]; then
    # validate-config.sh depends on python3 jsonschema being importable;
    # in some environments (e.g. bats with HOME overridden) the user-site
    # path differs and the module is not visible. Probe first and skip
    # with an info note if so — a missing python package is not a reason
    # to fail the skill's self-audit.
    if ! python3 -c "import jsonschema" >/dev/null 2>&1; then
      info "validate-config.sh skipped — python3 jsonschema not importable in this environment"
    elif bash "$vc" "${SOURCE_REPO}/PROJECT_CONFIG.json" >/dev/null 2>&1; then
      pass_e "validate-config.sh: PASS"
    else
      flag_e "validate-config.sh: FAIL"
    fi
  else
    info "validate-config.sh not available — skipped"
  fi
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

RUN_A=false; RUN_B=false; RUN_C=false; RUN_D=false; RUN_E=false
RUN_ANY=false

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --version|-v) echo "project-self-audit 1.0.0"; exit 0 ;;
    --parity) RUN_A=true; RUN_ANY=true ;;
    --rules) RUN_B=true; RUN_C=true; RUN_ANY=true ;;
    --rules-to-mech) RUN_B=true; RUN_ANY=true ;;
    --mech-to-rules) RUN_C=true; RUN_ANY=true ;;
    --manifest) RUN_D=true; RUN_ANY=true ;;
    --standards) RUN_E=true; RUN_ANY=true ;;
    --format=json) FORMAT="json" ;;
    --format=*) die "unsupported format: ${1#*=}" ;;
    *) die "unknown flag: $1" ;;
  esac
  shift
done

# No explicit check selected → run all
if ! "$RUN_ANY"; then
  RUN_A=true; RUN_B=true; RUN_C=true; RUN_D=true; RUN_E=true
fi

"$RUN_A" && check_a
"$RUN_B" && check_b
"$RUN_C" && check_c
"$RUN_D" && check_d
"$RUN_E" && check_e

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------

TOTAL_FLAG=$((A_FLAG + B_FLAG + C_FLAG + D_FLAG + E_FLAG))
TOTAL_PASS=$((A_PASS + B_PASS + C_PASS + D_PASS + E_PASS))

if [ "$FORMAT" = "json" ]; then
  python3 - <<PYJSON "$JSON_RESULTS" "$TOTAL_PASS" "$TOTAL_FLAG"
import json, sys
raw, tp, tf = sys.argv[1:]
results = json.loads("[" + raw + "]") if raw else []
print(json.dumps({
    "version": "1.0.0",
    "totals": {"pass": int(tp), "flag": int(tf)},
    "results": results,
}, indent=2))
PYJSON
else
  header "Summary"
  printf "  A. Install parity       : %d pass / %d flag\n" "$A_PASS" "$A_FLAG"
  printf "  B. Rules → Mechanisms   : %d pass / %d flag\n" "$B_PASS" "$B_FLAG"
  printf "  C. Mechanisms → Rules   : %d pass / %d flag\n" "$C_PASS" "$C_FLAG"
  printf "  D. Install manifest     : %d pass / %d flag\n" "$D_PASS" "$D_FLAG"
  printf "  E. Standards compliance : %d pass / %d flag\n" "$E_PASS" "$E_FLAG"
  echo ""
  if [ "$TOTAL_FLAG" -eq 0 ]; then
    printf "  ${GREEN}All %d check(s) passed${RESET}\n\n" "$TOTAL_PASS"
  else
    printf "  ${YELLOW}%d flag(s) across %d pass(es)${RESET}\n\n" "$TOTAL_FLAG" "$TOTAL_PASS"
  fi
fi

[ "$TOTAL_FLAG" -eq 0 ] && exit 0 || exit 1
