---
name: chk1:fix
description: Deep resolution helper — apply fixes for audit findings
allowed-tools: Read, Grep, Glob, Edit, Write, Bash(git *), AskUserQuestion
---

# chk1:fix — Deep Resolution Helper

Read the most recent audit output and provide specific, implementable fixes for every issue found.

## Instructions

1. Find the most recent audit output. Check in order:
   - The current conversation (if an audit was just run)
   - `AUDIT.md` in the repo root
   - The most recent `/chk1` output in conversation history

2. For each bug, risk, unintended change, omission, or architectural deviation found:

### For Each Bug
- Show the exact file and line
- Show the current (buggy) code
- Show the corrected code as a complete, copy-pasteable replacement
- Explain what was wrong and why the fix works
- If the bug could have tests, suggest a test case

### For Each Security Risk
- Show the vulnerable code
- Explain the attack vector (how it could be exploited)
- Show the secure replacement code
- Reference OWASP category if applicable
- Suggest additional hardening if relevant

### For Each Unintended Change
- Show what was changed and what it should be
- Provide a revert command or corrected code
- If the change was actually beneficial, note that but still flag it

### For Each Omission
- Describe what's missing
- Provide implementation code or steps
- Reference the plan item if a plan exists

### For Each Architectural Deviation
- Show the deviation
- Show what the pattern should be (with example from existing code)
- Provide refactored code that follows the pattern

3. Group fixes by effort:

#### Immediate Fixes (< 5 minutes each)
One-line changes, missing checks, typo fixes

#### Quick Fixes (5-15 minutes each)
Small refactors, adding validation, fixing error handling

#### Deeper Fixes (30+ minutes)
Architectural changes, missing features, test additions

4. For each fix, provide a verification step:
```
# Verify: {what we're checking}
{command or manual check}
# Expected: {expected result}
```

5. After presenting all fixes, ask:

> **Want me to implement these fixes now?** I can apply them directly to the codebase. I'll make one commit per fix category (immediate/quick/deeper) so they're easy to review and revert individually.

If the user says yes, implement the fixes using Edit/Write tools, then run `/chk1 quick` on the changes to verify the fixes don't introduce new issues.

**Iteration cap:** If `/chk1 quick` finds new issues introduced by the fixes, you may attempt one additional fix round (maximum of 2 rounds total). After the second round, do not continue looping — instead, present any remaining findings as a summary list of still-open issues for the user to review manually. This prevents unbounded fix→audit→fix cycles.
