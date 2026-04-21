#!/bin/bash
# block-worktree-add.sh — Claude Code PreToolUse hook
#
# Blocks `git worktree add` unless the command inlines GIT_WORKTREE_OVERRIDE=1.
# Exit 0 = allow the tool call; exit 2 = block (stderr is shown to Claude).
#
# Rationale: MULTI_SESSION_ARCHITECTURE.md §7.1 fixes the 11 role worktrees.
# Feature/fix work is a branch inside the existing role worktree, never a new
# or re-pointed worktree. See the global doc for the full rule.
#
# Bypass: prefix the command with GIT_WORKTREE_OVERRIDE=1 inline. The inline
# form is deliberate — it forces the human to consciously authorise each
# bypass rather than setting a long-lived env var and forgetting about it.

set -u

# Read tool call payload from stdin. Empty / malformed input → allow (fail open;
# this hook must never hard-break unrelated tool calls).
input=$(cat 2>/dev/null || true)
[ -z "$input" ] && exit 0

# Extract the Bash command, if this is a Bash tool call.
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -z "$cmd" ] && exit 0

# Match `git worktree add` anywhere the token boundary is at the start,
# after `;`, `&`, `|`, or whitespace — covers inline env prefix,
# compound commands, and newlines.
pattern_add='(^|[;&|[:space:]])git[[:space:]]+worktree[[:space:]]+add([[:space:]]|$)'
if ! printf '%s' "$cmd" | grep -qE "$pattern_add"; then
  exit 0
fi

# Check for inline override. Same token-boundary rules apply.
pattern_override='(^|[;&|[:space:]])GIT_WORKTREE_OVERRIDE=1([[:space:]]|$)'
if printf '%s' "$cmd" | grep -qE "$pattern_override"; then
  # Human override authorised — allow through.
  exit 0
fi

# Block with a clear message. Stderr is surfaced back to the calling agent.
# CPT-175: print the actual running-hook path via ${BASH_SOURCE[0]} so the
# banner matches reality on CLAUDE_CONFIG_DIR machines (was hardcoded to
# ~/.claude/hooks/... which misdirects debugging under a relocated config dir).
cat >&2 <<EOF
BLOCKED by ${BASH_SOURCE[0]}

\`git worktree add\` is forbidden by MULTI_SESSION_ARCHITECTURE.md §7.1.

The 11 role worktrees are fixed. Feature/fix work is a branch CREATED INSIDE
the existing role worktree, never a new worktree:

    # From inside the role worktree (e.g. .worktrees/fixer):
    git checkout -b fix/CPT-<n>
    # …work, commit, push…
    git checkout session/<role>          # return to parked state

To bypass this check (human-authorised only), prefix inline:

    GIT_WORKTREE_OVERRIDE=1 git worktree add <path> <args...>

The override must be inline on every invocation — by design, so each bypass
is a conscious action rather than a forgotten long-lived env var.
EOF
exit 2
