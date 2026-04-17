#!/usr/bin/env bats

# CPT-89: chk2:all circuit-breaker had no wire protocol between sub-agents
# and the orchestrator. Fix = each sub-skill emits a final-line status
# signal (CHK2-STATUS: OK|RATE_LIMITED|ERROR); orchestrator parses only
# that line and tracks consecutive RATE_LIMITED waves.
#
# These tests are structural: they assert the design contract is present
# in both the sub-skills (emit the signal) and the orchestrator (parse +
# reset counter on OK).

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
CMD_DIR="$REPO_DIR/skills/chk2/commands"

CATEGORY_NAMES=(
  api auth backend brute business cache compression cookies cors
  disclosure dns fingerprint graphql hardening headers infra ipv6 jwt
  negotiation proxy redirect reporting scale smuggling sse timing tls
  transport waf ws
)

@test "every category sub-skill instructs emission of CHK2-STATUS signal" {
  local failed=()
  for name in "${CATEGORY_NAMES[@]}"; do
    local f="$CMD_DIR/$name.md"
    [ -f "$f" ] || { failed+=("$name: missing"); continue; }
    if ! grep -qE "CHK2-STATUS" "$f"; then
      failed+=("$name")
    fi
  done
  if [ ${#failed[@]} -gt 0 ]; then
    echo "Missing CHK2-STATUS instruction: ${failed[*]}" >&2
    return 1
  fi
}

@test "every category sub-skill enumerates OK and RATE_LIMITED states" {
  local failed=()
  for name in "${CATEGORY_NAMES[@]}"; do
    local f="$CMD_DIR/$name.md"
    grep -q "OK" "$f" && grep -q "RATE_LIMITED" "$f" || failed+=("$name")
  done
  if [ ${#failed[@]} -gt 0 ]; then
    echo "Missing OK/RATE_LIMITED state enumeration: ${failed[*]}" >&2
    return 1
  fi
}

@test "chk2:all orchestrator parses CHK2-STATUS from sub-agent returns" {
  grep -qE "CHK2-STATUS" "$CMD_DIR/all.md"
}

@test "chk2:all orchestrator resets rate-limit counter on OK wave" {
  # The counter-reset semantics must be explicit, not implied.
  grep -qiE "reset.*counter|counter.*reset|reset.*OK|OK.*reset" "$CMD_DIR/all.md"
}

@test "chk2:all orchestrator still aborts after 3 consecutive RATE_LIMITED waves" {
  grep -qE "3 consecutive" "$CMD_DIR/all.md"
  grep -qE "abort" "$CMD_DIR/all.md"
}

@test "chk2 SKILL.md documents the CHK2-STATUS contract" {
  grep -qE "CHK2-STATUS" "$REPO_DIR/skills/chk2/SKILL.md"
}
