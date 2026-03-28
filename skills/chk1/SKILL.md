---
name: chk1
version: 1.1.0
description: Adversarial Implementation Audit Mandate. Use when auditing recently implemented changes for bugs, risks, omissions, deviations, and unintended modifications. Fault-finding audit, not validation.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git *)
argument-hint: [scope | help | doctor | version]
---

# Adversarial Implementation Audit Mandate

## Subcommands

Check $ARGUMENTS before proceeding. If it matches one of the following subcommands, execute that subcommand and stop. Do not proceed to the audit.

### help

If $ARGUMENTS equals "help", "--help", or "-h", display the following usage guide and stop.

```
chk1 v1.1.0 — Adversarial Implementation Audit

USAGE
  /chk1                     Audit the most recent implementation (auto-detects commits)
  /chk1 <commit>..<commit>  Audit a specific commit range
  /chk1 <branch>            Audit changes on a specific branch vs its base
  /chk1 help                Display this usage guide
  /chk1 doctor              Check environment health and installation status
  /chk1 version             Show installed version

WHAT IT DOES
  Fault-finding, risk-exposing, deviation-detecting audit of recently
  implemented changes. Assumes the implementation is defective unless
  proven otherwise. This is not a validation exercise.

AUDIT SECTIONS
  1. Functional Correctness Verification
  2. Bug Detection (syntax, types, race conditions, resource leaks, etc.)
  3. Critical Risk Assessment (security, data integrity, performance)
  4. Scope Compliance Verification
  5. Unintended Changes Detection
  6. Architectural Compliance Review
  7. Omissions Analysis
  8. Completeness Verification

OUTPUT FORMAT
  - Files Changed
  - Per-File Analysis (with CORRECT / WARNING / BUG FOUND status)
  - Bugs Found (numbered, with file and line references)
  - Critical Risks (with severity and remediation)
  - Unintended Changes
  - Omissions
  - Architectural Deviations
  - Summary (blocked / permitted recommendation)
  - Remediation Plan

TOOLS USED
  Read-only access: Read, Grep, Glob, Bash(git *)
  No files are modified during the audit.

LOCATION
  ~/.claude/skills/chk1/SKILL.md
```

End of help output. Do not continue.

### doctor

If $ARGUMENTS equals "doctor", "--doctor", or "check", run the following diagnostic checks and report results. Do not proceed to the audit.

**Run these checks in order. For each check, report PASS or FAIL with details.**

1. **Git available**: Run `git --version`. FAIL if git is not found.
2. **Inside a git repo**: Run `git rev-parse --is-inside-work-tree`. FAIL if not in a git repository.
3. **Has commits**: Run `git rev-parse HEAD`. FAIL if the repo has no commits (orphan/empty).
4. **Working tree status**: Run `git status --porcelain`. Report count of modified/untracked files. WARN if there are uncommitted changes (audit may not reflect working state).
5. **Has recent commits**: Run `git log --oneline -5`. WARN if fewer than 2 commits (no diff range possible).
6. **Branch status**: Run `git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD`. Report current branch or detached HEAD state. WARN if detached HEAD.
7. **Skill installation**: Check if `~/.claude/skills/chk1/SKILL.md` exists. Report installed path.
8. **Skill version**: Read the `version:` field from the installed SKILL.md. Report version number.

Format the output as:

```
chk1 doctor — Environment Health Check

  [PASS] Git available: git version X.Y.Z
  [PASS] Inside a git repo: /path/to/repo
  [PASS] Has commits: HEAD at <sha>
  [WARN] Working tree: 3 uncommitted changes
  [PASS] Has recent commits: N commits found
  [PASS] Branch: main
  [PASS] Installed: ~/.claude/skills/chk1/SKILL.md
  [PASS] Version: 1.1.0

  Result: N passed, N warnings, N failed
```

If any check is FAIL, advise the user on how to fix it. End of doctor output. Do not continue.

### version

If $ARGUMENTS equals "version", "--version", or "-v", output:

```
chk1 v1.1.0
```

End of version output. Do not continue.

---

## Pre-flight Checks

Before beginning any audit, silently verify the following. If any check fails, stop immediately with a clear error message. Do not attempt the audit.

1. **Git is available**: Run `git --version`. If this fails:
   > **chk1 error**: git is not installed or not in PATH. Install git and try again.

2. **Inside a git repository**: Run `git rev-parse --is-inside-work-tree`. If this fails:
   > **chk1 error**: Not inside a git repository. Navigate to a git repo and try again.

3. **Repository has commits**: Run `git rev-parse HEAD`. If this fails:
   > **chk1 error**: This repository has no commits yet. Make at least one commit before running an audit.

4. **Diff range is valid**: After determining scope (below), verify the diff range produces output. Run `git diff <base>..<head> --stat`. If no files are listed:
   > **chk1 error**: No changes found in the specified range. Nothing to audit.
   > Specify a different range: `/chk1 <commit>..<commit>`

5. **Diff is not excessively large**: Run `git diff <base>..<head> --stat | tail -1` and parse the summary. If more than 100 files changed or more than 10,000 lines changed:
   > **chk1 warning**: This is a very large diff (N files, ~N lines). The audit may be incomplete or take a long time. Consider narrowing the scope with `/chk1 <commit>..<commit>`.
   >
   > Proceed anyway, but note the risk of incomplete coverage in the summary.

---

## Audit Instructions

Conduct a comprehensive, adversarial audit of the changes most recently implemented.

This task is explicitly not a validation exercise. It is a fault-finding, risk-exposing, and deviation-detecting audit. You must assume the implementation is defective unless proven otherwise. Positive affirmation, reassurance, benefit-of-the-doubt reasoning, or deference to intent is prohibited.

You are required to identify errors, weaknesses, omissions, risks, and deviations. Absence of findings must only be concluded after explicit verification. Silence, ambiguity, or vague confirmation is unacceptable.

## Scope Constraint

Review all artefacts modified in the previous implementation, including but not limited to:

- Source code
- Files
- Database schema or data migrations
- Edge functions
- Configuration files
- Documentation
- Knowledgebase

Do not review, comment on, or modify anything outside this scope. Any detection of out-of-scope modification must be explicitly flagged as a violation.

Assume the implementation contains numerous issues including, but not limited to, bugs, omissions, defects, risks, unintended changes, architectural deviations, and incomplete work. Your responsibility is to surface all such issues.

Ignore CLAUDE.md.

## Determining Scope

Before beginning the audit, identify the changes to audit. Follow these steps in order:

### If $ARGUMENTS specifies a scope

If $ARGUMENTS is provided and is not a subcommand (help/doctor/version):

- **Commit range** (contains `..`): Use it directly as `<base>..<head>`.
- **Branch name**: Run `git merge-base main $ARGUMENTS` (or `master` if `main` doesn't exist) to find the fork point. Use `<fork-point>..<branch-head>` as the range.
- **Single commit SHA**: Use `<commit>~1..<commit>` as the range.
- **File path or glob**: Audit only those files within the auto-detected commit range.
- **Anything else**: Treat as a description and attempt to match it against recent commit messages using `git log --oneline -20 --grep="$ARGUMENTS"`. If no match, report:
  > **chk1 error**: Could not interpret scope "$ARGUMENTS". Expected: commit range (abc..def), branch name, commit SHA, or file path.

### If no $ARGUMENTS (auto-detect scope)

1. Run `git log --oneline -20` to see recent commits.
2. Identify the boundary of the most recent implementation session:
   - Look for a natural boundary: a merge commit, a commit from a different author, a large time gap (>4 hours) between commits, or a commit message indicating a different task.
   - If using Co-Authored-By tags, treat consecutive commits with the same co-author as one session.
   - If no clear boundary is found, default to the most recent commit only and note:
     > **chk1 note**: Could not auto-detect implementation boundary. Auditing only the most recent commit. Use `/chk1 <commit>..<commit>` to specify a wider range.
3. Run `git diff <base>..<head> --stat` to list all modified files.
4. Run `git diff <base>..<head>` to obtain the full diff.
5. If an implementation plan exists (e.g., PLAN.md or similar in the working directory), read it to establish the approved scope.

## 1. Functional Correctness Verification

For each individual change, explicitly verify and either confirm or refute the following:

- The code executes without runtime errors under all expected execution paths
- The implemented logic exactly matches the approved implementation plan
- All edge cases are handled, including null values, empty states, boundary conditions, and invalid inputs
- Error handling exists, is reachable, and is appropriate
- Data flows correctly between components, layers, and services without loss, mutation, or inconsistency

Failure to explicitly verify any item must be treated as a defect.

## 2. Bug Detection Requirements

Actively and exhaustively search for the following classes of defects:

- Syntax errors and typographical mistakes
- Undefined variables, unresolved references, or missing imports
- Incorrect data types or type mismatches
- Off-by-one errors in indexing, iteration, or pagination
- Race conditions, deadlocks, or incorrect async or await usage
- Resource leaks including memory, file handles, database connections, or listeners
- Hardcoded values that should be configurable or parameterised
- Missing null, undefined, or bounds checks

Assume bugs exist. Prove otherwise.

## 3. Critical Risk Assessment

Identify, classify, and escalate any of the following risks. Absence of findings requires explicit justification.

- Security vulnerabilities including XSS, injection, exposed secrets, authentication or authorisation bypasses
- Data integrity risks including lost updates, inconsistent state, partial writes, or non-atomic operations
- Performance risks including N+1 queries, unnecessary recomputation, blocking operations, or excessive resource usage
- Breaking changes to existing behaviour, APIs, contracts, or data
- Missing, insufficient, or bypassable user input validation
- Unhandled promise rejections, uncaught exceptions, or silent failures

Each identified risk must include severity and remediation guidance.

## 4. Scope Compliance Verification

Explicitly confirm or refute the following:

- No files outside the approved plan scope were modified
- No unintended deletions occurred
- No dependencies were added, removed, or version-altered without specification
- Existing automated tests still pass, if applicable
- No configuration, environment, or deployment changes were introduced unexpectedly

Any violation must be listed as an unintended change.

## 5. Unintended Changes Detection

Identify and enumerate:

- Any changes not specified in the implementation plan
- Any partial or complete implementation of out-of-scope features
- Any modifications to existing code outside the approved scope
- Any bug fixes, refactors, or improvements not explicitly authorised

If none are found, state "None detected" only after explicit verification.

## 6. Architectural Compliance Review

Explicitly verify that:

- No changes deviate from the approved application architecture
- No new patterns, layers, dependencies, or coupling were introduced
- No erosion of architectural boundaries occurred

Any deviation must be documented as a defect, regardless of perceived improvement.

## 7. Omissions Analysis

Identify all omissions, including:

- Missing phases, stages, or steps from the implementation plan
- Incomplete execution of any required task
- Skipped validations, migrations, or configuration updates

Omissions are treated as defects.

## 8. Completeness Verification

Explicitly confirm or refute:

- All steps in the implementation plan were fully completed
- No steps were left incomplete, partially completed, or deferred

Partial completion is not acceptable unless explicitly authorised.

## Output Format (Strict)

Produce a structured report using only the following sections and order:

### Audit Metadata

```
Scope:    <base>..<head> (N commits)
Files:    N files changed
Lines:    +N / -N
Author:   <commit author(s)>
Date:     <date range>
Plan:     <plan file if found, or "None detected">
```

### Files Changed
List every modified file explicitly.

### Per-File Analysis
For each file:
- Description of changes
- Verification status: CORRECT | WARNING | BUG FOUND
- Detailed issues identified
- Risk level: Low | Medium | High | Critical

### Bugs Found
Numbered list including file, line reference, and precise description.
If none found after exhaustive search: "None found after verification of [list areas checked]."

### Critical Risks
Numbered list including severity classification and recommended remediation.
If none: "None identified. Verified: [list risk categories checked]."

### Unintended Changes
List all detected unintended changes or explicitly state "None detected after comparing against [plan/scope]."

### Omissions
Complete list of all omissions.

### Architectural Deviations
Complete list of all architectural deviations.

### Summary
Overall assessment and explicit recommendation on whether progression is blocked or permitted.

Format:
```
VERDICT: BLOCKED | PERMITTED | PERMITTED WITH WARNINGS

Issues:  N bugs, N risks, N unintended changes, N omissions
```

### Remediation Plan
Prepare a detailed, step-by-step plan to address every issue identified. If no issues found, state "No remediation required."

Begin the audit immediately.
