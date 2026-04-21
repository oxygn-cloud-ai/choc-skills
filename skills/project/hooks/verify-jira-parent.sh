#!/bin/bash
# verify-jira-parent.sh — Claude Code PreToolUse hook
#
# Blocks Jira createJiraIssue / editJiraIssue calls when the proposed parent
# epic does NOT match the current project's PROJECT_CONFIG.json jira.epicKey.
#
# Rationale: projects declare their canonical Jira epic in PROJECT_CONFIG.json.
# Filing tickets under any other epic is a mistake in 99% of cases — pattern-
# extension from a prior cross-cutting filing is the specific failure mode that
# led to CPT-43/44/45/50/51/52/53/54 being filed under CPT-5 when they should
# have been under CPT-3 (the Choc-Skills epic per PROJECT_CONFIG.json).
#
# Bypass: export JIRA_PARENT_OVERRIDE=1 before invoking. Required for deliberate
# cross-cutting tickets (e.g., BWS/secrets hygiene affecting multiple projects —
# CPT-49 is the canonical example; its parent CPT-5 is correct by design).
#
# Exit 0 = allow the tool call; exit 2 = block (stderr shown to Claude).
#
# Fails OPEN (allows the call) on any parse error, missing config, or malformed
# input. This hook must never hard-break unrelated work.

set -u

input=$(cat 2>/dev/null || true)
[ -z "$input" ] && exit 0

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)
case "$tool_name" in
  mcp__claude_ai_Atlassian__createJiraIssue)
    # In createJiraIssue the parent field is a plain string (per schema)
    proposed=$(printf '%s' "$input" | jq -r '.tool_input.parent // empty' 2>/dev/null || true)
    ;;
  mcp__claude_ai_Atlassian__editJiraIssue)
    # In editJiraIssue the parent field is nested under fields as an object {key: ...}
    proposed=$(printf '%s' "$input" | jq -r '.tool_input.fields.parent.key // empty' 2>/dev/null || true)
    ;;
  *)
    # Not a Jira create/edit — let through
    exit 0
    ;;
esac

# No parent in the tool call — nothing to check
[ -z "$proposed" ] && exit 0

# Honour the inline override. Env var is inherited from the Claude Code process;
# `JIRA_PARENT_OVERRIDE=1` must be exported before the session (or via the
# session's shell) for the hook to see it.
if [ "${JIRA_PARENT_OVERRIDE:-}" = "1" ]; then
  exit 0
fi

# Locate PROJECT_CONFIG.json — try cwd, then git toplevel, then main repo
# (git-common-dir's parent handles the case where Claude is cd'd into a worktree)
config_path=""
for candidate in \
  "./PROJECT_CONFIG.json" \
  "$(git rev-parse --show-toplevel 2>/dev/null)/PROJECT_CONFIG.json" \
  "$(git rev-parse --git-common-dir 2>/dev/null)/../PROJECT_CONFIG.json"; do
  [ -f "$candidate" ] && { config_path="$candidate"; break; }
done

# No project config found — no canonical epic to check against; let through
[ -z "$config_path" ] && exit 0

expected=$(jq -r '.jira.epicKey // empty' "$config_path" 2>/dev/null || true)
[ -z "$expected" ] && exit 0

# Match — allow
[ "$proposed" = "$expected" ] && exit 0

# Mismatch — block with a clear message.
# CPT-175: print the actual running-hook path via ${BASH_SOURCE[0]} so the
# banner matches reality on CLAUDE_CONFIG_DIR machines.
cat >&2 <<EOF
BLOCKED by ${BASH_SOURCE[0]}

Proposed Jira parent: $proposed
PROJECT_CONFIG.json jira.epicKey (from $config_path): $expected

These do not match. The canonical epic for this project is $expected; filing
under $proposed is likely a mistake (pattern-extension from a prior session's
cross-cutting filing is the usual cause).

To file deliberately under a different epic (cross-cutting work that spans
multiple projects — e.g., BWS hygiene, global-policy changes), bypass this
check by exporting JIRA_PARENT_OVERRIDE=1 in the session's shell before
retrying the tool call.
EOF
exit 2
