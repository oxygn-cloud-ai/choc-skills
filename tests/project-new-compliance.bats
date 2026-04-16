#!/usr/bin/env bats

# Source-level compliance tests for skills/project/commands/new.md.
#
# /project:new is an LLM-prompt-driven skill — we can't run it in bats to
# scaffold a real project and inspect the output. Instead we assert that the
# *skill prompt itself* embeds the required templates and instructions, so
# when Claude executes the prompt the generated files inherit the standards.
#
# Each test maps 1:1 to a Gap in CPT-56's acceptance criteria. Gap 5 (CI
# templates) is blocked on CPT-52/CPT-53 — we assert only that the prompt
# acknowledges the pending decision rather than promising a templated fix.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
NEW_MD="${REPO_DIR}/skills/project/commands/new.md"

@test "new.md: Step 10 session-prompt template includes Worktree rule (Gap 1)" {
  [ -f "$NEW_MD" ]
  # The worktree rule phrase + the hard-block reference must be present in
  # the prompt template or its quick-reference append instructions.
  grep -q 'Worktree rule' "$NEW_MD"
  grep -q 'git worktree add' "$NEW_MD"
  grep -q 'PreToolUse' "$NEW_MD"
  grep -q 'GIT_WORKTREE_OVERRIDE' "$NEW_MD"
}

@test "new.md: Step 5 generated CLAUDE.md includes verification-discipline block or reference (Gap 2)" {
  # Either the block is inlined in the CLAUDE.md template instructions OR
  # there is an explicit pointer to ~/.claude/CLAUDE.md as the source of
  # truth. The phrase "verification discipline" must appear at least once
  # in the Step 5 area of the prompt.
  grep -q 'verification discipline\|Verification discipline' "$NEW_MD"
}

@test "new.md: Step 5 generated CLAUDE.md includes Jira-first coordination / no-PR policy (Gap 3)" {
  # The template must instruct Claude to include coordination guidance in
  # the generated CLAUDE.md. Match phrases the skill should embed.
  grep -q 'Coordination' "$NEW_MD"
  grep -qE 'no[[:space:]]*PR|gh pr create|Jira.*coordination|coordination.*Jira' "$NEW_MD"
}

@test "new.md: Step 5 .gitignore template appends .worktrees/ (Gap 4)" {
  # The prompt must instruct the skill to add .worktrees/ to the project's
  # generated .gitignore regardless of language. We need a phrase that ties
  # .worktrees/ to .gitignore — `.worktrees/` alone is insufficient (the
  # prompt mentions `.worktrees/<role>/` paths in unrelated contexts).
  grep -qE '\.gitignore[^\n]*\.worktrees/|\.worktrees/[^\n]*\.gitignore' "$NEW_MD" \
    || grep -B2 -A2 '\.gitignore' "$NEW_MD" | grep -q '\.worktrees/'
}

@test "new.md: Step 11 CI promise acknowledges CPT-52/CPT-53 pending decision (Gap 5)" {
  # Until CPT-52/CPT-53 resolve the CI-vs-Master-session design decision,
  # the /project:new CI step must flag the pending state explicitly rather
  # than promising a non-existent reference implementation.
  grep -qE 'CPT-52|CPT-53' "$NEW_MD"
}

@test "new.md: Step 4 PHILOSOPHY.md interview is mandatory for every project (Gap 6)" {
  # The old prompt said "For Software projects (and Non-Software if user
  # opts in)". The fix removes the opt-in conditional so PHILOSOPHY.md is
  # mandatory for every project.
  run grep -qE 'if (the )?user opts in' "$NEW_MD"
  [ "$status" -ne 0 ] || { echo "opt-in conditional still present in new.md" >&2; return 1; }
  # Must still instruct writing PHILOSOPHY.md
  grep -q 'PHILOSOPHY.md' "$NEW_MD"
}

@test "new.md: includes preflight check for worktree PreToolUse hook (Gap 7)" {
  # A new step or addition must check that the hook file is installed AND
  # that settings.json has it registered. WARN not STOP.
  grep -q 'block-worktree-add.sh' "$NEW_MD"
  grep -qE 'settings\.json.*PreToolUse|PreToolUse.*settings\.json|hooks\.PreToolUse' "$NEW_MD"
}
