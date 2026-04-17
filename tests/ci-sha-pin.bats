#!/usr/bin/env bats

# CPT-108: Every third-party GitHub Action referenced from .github/workflows/
# must be SHA-pinned (40-char hex), not tag-pinned, to harden against
# upstream tag-retargeting attacks. First-party actions under actions/ and
# github/ are allowed to use tag refs (they're managed by GitHub itself).

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "every third-party action in .github/workflows/ is SHA-pinned (40-char hex)" {
  local offenders=()
  while IFS= read -r line; do
    # Extract the "owner/repo@ref" token after `uses: `
    local spec ref
    spec=$(echo "$line" | sed -E 's/.*uses:[[:space:]]*//' | awk '{print $1}')
    case "$spec" in
      actions/*|github/*) continue ;;      # first-party — tag pins allowed
    esac
    ref="${spec#*@}"
    if ! [[ "$ref" =~ ^[a-f0-9]{40}$ ]]; then
      offenders+=("$line")
    fi
  done < <(grep -Eh '^\s*[- ]*uses:' "$REPO_DIR"/.github/workflows/*.yml)
  if [ ${#offenders[@]} -gt 0 ]; then
    printf '%s\n' "Third-party action not SHA-pinned:" "${offenders[@]}" >&2
    return 1
  fi
}
