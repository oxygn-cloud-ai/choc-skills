#!/usr/bin/env bash
set -euo pipefail

# Validates all skill definitions in the repository.
# Used by CI and can be run locally before submitting PRs.

# Override for testing: REPO_DIR_OVERRIDE lets tests point at a fixture tree
# without mutating the real one.
if [ -n "${REPO_DIR_OVERRIDE:-}" ]; then
  REPO_DIR="$REPO_DIR_OVERRIDE"
else
  REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
SKILLS_DIR="${REPO_DIR}/skills"

# --- Colors ---
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
  BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BOLD=''; RESET=''
fi

pass() { printf "${GREEN}  PASS${RESET}  %s\n" "$*"; }
warn() { printf "${YELLOW}  WARN${RESET}  %s\n" "$*"; }
fail() { printf "${RED}  FAIL${RESET}  %s\n" "$*"; }

errors=0
warnings=0
checked=0

printf "\n${BOLD}Validating skill definitions${RESET}\n\n"

for dir in "${SKILLS_DIR}"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"

  # Skip template and non-skill directories
  [[ "$name" == _* ]] && continue
  [ -f "${dir}/SKILL.md" ] || continue

  checked=$((checked + 1))
  skill_errors=0
  printf "${BOLD}%s${RESET}\n" "$name"

  skill_file="${dir}/SKILL.md"

  # --- Check: YAML frontmatter exists ---
  if head -1 "$skill_file" | grep -q '^---$'; then
    pass "Has YAML frontmatter"
  else
    fail "Missing YAML frontmatter (must start with ---)"
    skill_errors=$((skill_errors + 1))
  fi

  # --- Check: Required frontmatter fields ---
  # Extract frontmatter (between first and second ---).
  # awk stops at the second --- explicitly, so horizontal rules in the
  # SKILL.md body don't leak into the captured frontmatter.
  frontmatter=$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$skill_file")

  for field in name version description; do
    if echo "$frontmatter" | grep -q "^${field}:"; then
      pass "Has '${field}' field"
    else
      fail "Missing required field: ${field}"
      skill_errors=$((skill_errors + 1))
    fi
  done

  # --- Check: user-invocable field ---
  if echo "$frontmatter" | grep -q "^user-invocable:"; then
    pass "Has 'user-invocable' field"
  else
    warn "Missing 'user-invocable' field (recommended: true)"
    warnings=$((warnings + 1))
  fi

  # --- Check: name matches directory ---
  fm_name=$(echo "$frontmatter" | grep '^name:' | sed 's/^name: *//' | tr -d '[:space:]')
  if [ "$fm_name" = "$name" ]; then
    pass "Name matches directory (${name})"
  else
    fail "Name mismatch: frontmatter says '${fm_name}', directory is '${name}'"
    skill_errors=$((skill_errors + 1))
  fi

  # --- Check: version is semver-like ---
  fm_version=$(echo "$frontmatter" | grep '^version:' | sed 's/^version: *//' | tr -d '[:space:]')
  if echo "$fm_version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    pass "Version is semver (${fm_version})"
  else
    fail "Version '${fm_version}' is not valid semver (expected X.Y.Z)"
    skill_errors=$((skill_errors + 1))
  fi

  # --- Check: internal <name> v<semver> strings match frontmatter version (CPT-92) ---
  # Skills frequently drift: author bumps frontmatter but forgets the help
  # banner, version-output, and doctor-example strings. This catches those
  # silent mismatches. Use `X.Y.Z` as a placeholder in doctor-example blocks
  # to opt out of this check for cases where the literal represents a
  # template rather than the real version.
  internal_drift=0
  while IFS= read -r internal_ver; do
    [ -n "$internal_ver" ] || continue
    if [ "$internal_ver" != "$fm_version" ]; then
      fail "Internal '${name} v${internal_ver}' does not match frontmatter ${fm_version}"
      internal_drift=$((internal_drift + 1))
    fi
  done < <(grep -oE "${name} v[0-9]+\.[0-9]+\.[0-9]+" "$skill_file" | sed "s/^${name} v//" | sort -u)
  if [ "$internal_drift" -eq 0 ]; then
    pass "Internal '${name} v<ver>' strings match frontmatter"
  else
    skill_errors=$((skill_errors + internal_drift))
  fi

  # --- Check: required subcommands ---
  # Skills can define subcommands either inline (### help) or via command files (commands/help.md)
  for subcmd in help doctor version; do
    if grep -q "^### ${subcmd}$" "$skill_file"; then
      pass "Has '${subcmd}' subcommand (inline section)"
    elif [ -f "${dir}/commands/${subcmd}.md" ]; then
      pass "Has '${subcmd}' subcommand (command file)"
    else
      fail "Missing '${subcmd}' subcommand (need inline ### ${subcmd} section or commands/${subcmd}.md)"
      skill_errors=$((skill_errors + 1))
    fi
  done

  # --- Check: routing table matches commands/ directory ---
  if [ -d "${dir}/commands" ]; then
    skill_md_content=$(< "$skill_file")
    cmd_warnings=0
    for cmd_file in "${dir}/commands"/*.md; do
      [ -f "$cmd_file" ] || continue
      cmd_name=$(basename "$cmd_file" .md)
      # Skip standard subcommands that may be defined inline rather than routed
      case "$cmd_name" in help|doctor|version) continue ;; esac
      if echo "$skill_md_content" | grep -qi "${cmd_name}"; then
        : # found a reference
      else
        warn "${name}: command file '${cmd_name}.md' has no routing entry in SKILL.md"
        cmd_warnings=$((cmd_warnings + 1))
        warnings=$((warnings + 1))
      fi
    done
    if [ "$cmd_warnings" -eq 0 ]; then
      pass "All command files have routing entries in SKILL.md"
    fi
  fi

  # --- Check: install.sh is executable (if present) ---
  if [ -f "${dir}/install.sh" ]; then
    if [ -x "${dir}/install.sh" ]; then
      pass "install.sh is executable"
    else
      fail "install.sh exists but is not executable (run: chmod +x ${dir}/install.sh)"
      skill_errors=$((skill_errors + 1))
    fi
  fi

  # --- Check: README.md exists ---
  if [ -f "${dir}/README.md" ]; then
    pass "Has README.md"
  else
    warn "Missing README.md (recommended for documentation)"
    warnings=$((warnings + 1))
  fi

  # --- Check: no unwanted files ---
  for unwanted in node_modules .env .env.local .DS_Store; do
    if [ -e "${dir}/${unwanted}" ]; then
      fail "Contains unwanted file/directory: ${unwanted}"
      skill_errors=$((skill_errors + 1))
    fi
  done

  # --- Check: disable-model-invocation recommended ---
  if echo "$frontmatter" | grep -q "^disable-model-invocation: *true"; then
    pass "Has 'disable-model-invocation: true'"
  else
    warn "Missing 'disable-model-invocation: true' (recommended for security)"
    warnings=$((warnings + 1))
  fi

  errors=$((errors + skill_errors))
  echo ""
done

# --- Summary ---
printf "${BOLD}Validation summary${RESET}\n\n"
printf "  Skills checked: %d\n" "$checked"
printf "  Errors:         %d\n" "$errors"
printf "  Warnings:       %d\n" "$warnings"
echo ""

if [ "$errors" -gt 0 ]; then
  fail "${errors} error(s) found — fix before merging"
  exit 1
elif [ "$warnings" -gt 0 ]; then
  warn "${warnings} warning(s) — consider addressing"
  exit 0
else
  pass "All skills valid"
  exit 0
fi
