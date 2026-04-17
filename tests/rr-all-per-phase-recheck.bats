#!/usr/bin/env bats

# CPT-133: CPT-91's compaction re-check was single-file (only step-1-extract
# heading verified once per risk, at the start of the 6-step workflow).
# Three concerns from chk1/Codex:
#   (1) Single-file heuristic misses compaction that evicted step-2/3/5/6
#       while leaving step-1 retrievable.
#   (2) Check-at-start misses compaction that happens mid-workflow (between
#       Step 2 and Step 5, for example).
#   (3) Raw numbering bug: the "Process Each Risk" list has two `3.` items.
#
# Fix: per-phase re-check (Option A in the ticket). Before each of the five
# step-file-backed phases, quote the corresponding heading; re-read on miss.
# Log entry annotated with step name so drift is observable per-phase.

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ALL_MD="${REPO_DIR}/skills/rr/commands/all.md"

@test "rr/commands/all.md exists" {
  [ -f "$ALL_MD" ]
}

@test "Process Each Risk numbered list has no duplicate numbers (CPT-133 concern 3)" {
  # Extract the numbered list items at the top level inside "### Process Each Risk"
  # until the next `### ` heading, collecting only lines that start with
  # `^\d+\. ` (no indent).
  local numbers
  numbers=$(awk '/^### Process Each Risk/{inside=1; next} /^### Progress File Status Values/{inside=0} inside' "$ALL_MD" \
    | grep -E '^[0-9]+\. ' | sed -E 's/^([0-9]+)\. .*/\1/')
  [ -n "$numbers" ] || { echo "Process Each Risk block not found / empty list" >&2; return 1; }

  local dup_count
  dup_count=$(echo "$numbers" | sort | uniq -d | wc -l | tr -d ' ')
  if [ "$dup_count" -gt 0 ]; then
    echo "Process Each Risk numbered list has duplicate numbers: $(echo "$numbers" | tr '\n' ' ')" >&2
    echo "duplicates: $(echo "$numbers" | sort | uniq -d | tr '\n' ' ')" >&2
    return 1
  fi
}

@test "per-phase compaction re-check covers all 5 step-file-backed phases (CPT-133 concerns 1+2)" {
  # Each of step-1-extract, step-2-adversarial, step-3-rectify, step-5-finalise,
  # step-6-publish must be referenced in a re-check / verify / recall context
  # inside the per-phase workflow area (not just as a "use pre-loaded" bullet).
  local block
  block=$(awk '/^### Process Each Risk/{inside=1; next} /^### Progress File Status Values/{inside=0} inside' "$ALL_MD")
  [ -n "$block" ] || { echo "Process Each Risk block not found" >&2; return 1; }

  local step missing=0
  for step in step-1-extract step-2-adversarial step-3-rectify step-5-finalise step-6-publish; do
    # Must appear in a verification line (re-check / verify / retrievable /
    # recall / heading). A bare "use pre-loaded step-X content" reference is
    # NOT sufficient.
    if ! echo "$block" | grep -E "${step}" | grep -qiE 'recall|re-check|re.?read|verify|retriev|heading|still'; then
      echo "per-phase re-check missing for ${step}" >&2
      missing=$((missing + 1))
    fi
  done
  [ "$missing" -eq 0 ]
}

@test "compaction re-read log entry is annotated with step name (CPT-133)" {
  # CPT-91's log was "pre-load recovered by re-read" — generic, can't tell
  # which step drifted. CPT-133 requires a step annotation so observability
  # is useful.
  local block
  block=$(awk '/^### Process Each Risk/{inside=1; next} /^### Progress File Status Values/{inside=0} inside' "$ALL_MD")
  echo "$block" | grep -qE 'pre-load recovered by re-read:.*step' || {
    echo "re-read log entry is not step-annotated — use 'pre-load recovered by re-read: <step>' form so the step that drifted is visible in the log" >&2
    return 1
  }
}

# --- CPT-143: CPT-133's per-phase re-check only covered Sequential Mode
#     (commands/all.md). Agent Orchestrator Mode — the DEFAULT batch path
#     when bin/ is available and JIRA_EMAIL/JIRA_API_KEY are set — is driven
#     by bin/sub-agent-prompt.md, which was not touched by CPT-133. The
#     compaction-protection invariants must hold on BOTH files.

SUB_AGENT_PROMPT="${REPO_DIR}/skills/rr/bin/sub-agent-prompt.md"

@test "sub-agent-prompt.md exists (sanity) (CPT-143)" {
  [ -f "$SUB_AGENT_PROMPT" ]
}

@test "sub-agent-prompt.md carries per-phase compaction re-check for all 5 step files (CPT-143)" {
  # Same invariant as CPT-133's concerns 1+2 but enforced on the sub-agent
  # prompt used by the Agent Orchestrator default path.
  local step missing=0
  for step in step-1-extract step-2-adversarial step-3-rectify step-5-finalise step-6-publish; do
    if ! grep -E "${step}" "$SUB_AGENT_PROMPT" | grep -qiE 'recall|re-check|re.?read|verify|retriev|heading|still'; then
      echo "per-phase re-check missing for ${step} in sub-agent-prompt.md" >&2
      missing=$((missing + 1))
    fi
  done
  [ "$missing" -eq 0 ]
}

@test "sub-agent-prompt.md re-read log entry is step-annotated (CPT-143)" {
  # Same observability contract as CPT-133: the log line must identify which
  # step was recovered, not just say something drifted.
  grep -qE 'pre-load recovered by re-read:.*step' "$SUB_AGENT_PROMPT" || {
    echo "sub-agent-prompt.md re-read log line is not step-annotated (use 'pre-load recovered by re-read: <step>' form)" >&2
    return 1
  }
}

# --- CPT-157: the per-phase re-checks (CPT-143) assume each step file was
#     pre-loaded before the per-risk loop began. Without that pre-load the
#     re-check is a no-op — Claude either re-reads per phase (defeating the
#     optimization CPT-9/CPT-91 were building toward) or improvises from the
#     one-line phase description (lossy). Mirror commands/all.md Sequential
#     Mode's "### Pre-Load Workflow Steps" block into sub-agent-prompt.md
#     BEFORE "## Task — For Each Risk".

@test "CPT-157: sub-agent-prompt.md pre-loads all 5 step files before the per-risk Task section" {
  # Extract the pre-task slice (everything up to but NOT including the
  # "## Task — For Each Risk" heading).
  local pre_task
  pre_task=$(awk '/^## Task — For Each Risk/{exit} {print}' "$SUB_AGENT_PROMPT")
  [ -n "$pre_task" ] || { echo "pre-Task section empty" >&2; return 1; }

  local step missing=0
  for step in step-1-extract step-2-adversarial step-3-rectify step-5-finalise step-6-publish; do
    if ! printf '%s\n' "$pre_task" | grep -qE "workflow/${step}\.md"; then
      echo "CPT-157: ${step}.md not pre-loaded before Task section in sub-agent-prompt.md" >&2
      missing=$((missing + 1))
    fi
  done
  [ "$missing" -eq 0 ]
}

@test "CPT-157: sub-agent-prompt.md pre-load section appears before the per-phase re-check text" {
  # Order matters: the pre-load must precede the re-check text, otherwise
  # the "verify X is still retrievable" text would reference a file that
  # hasn't been loaded yet.
  local preload_line recheck_line
  preload_line=$(grep -nE '^### Pre-Load Workflow Steps' "$SUB_AGENT_PROMPT" | head -1 | cut -d: -f1)
  recheck_line=$(grep -niE 'verify.*step-1-extract.*heading' "$SUB_AGENT_PROMPT" | head -1 | cut -d: -f1)
  [ -n "$preload_line" ] || { echo "### Pre-Load Workflow Steps heading missing" >&2; return 1; }
  [ -n "$recheck_line" ] || { echo "per-phase re-check text missing (CPT-143 regression?)" >&2; return 1; }
  [ "$preload_line" -lt "$recheck_line" ] || {
    echo "Pre-Load block (line $preload_line) must precede per-phase re-check (line $recheck_line)" >&2
    return 1
  }
}
