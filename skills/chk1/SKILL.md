---
name: chk1
version: 2.4.1
description: Adversarial Implementation Audit Mandate. Use when auditing recently implemented changes for bugs, risks, omissions, deviations, and unintended modifications. Fault-finding audit, not validation.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(gh *), Bash(curl *), Write, Edit, AskUserQuestion
argument-hint: [all | quick | security | scope | architecture | fix | github | update | help | doctor | version]
---

# Adversarial Implementation Audit Mandate

## Subcommands

Check $ARGUMENTS before proceeding. If it matches one of the following subcommands, execute that subcommand and stop. Do not proceed to the audit.

### help

If $ARGUMENTS equals "help", "--help", or "-h", display the following usage guide and stop.

```
chk1 v2.4.0 — Adversarial Implementation Audit

USAGE
  /chk1                     Full audit (auto-detects recent changes)
  /chk1 all                 Same as above
  /chk1 quick               Bugs + risks only (fast pre-commit check)
  /chk1 security            Deep security-focused audit (OWASP categories)
  /chk1 scope               Scope compliance + omissions + unintended changes
  /chk1 architecture        Pattern, boundary, coupling, consistency checks
  /chk1 fix                 Deep resolution for issues found
  /chk1 github              Log audit findings as GitHub Issues with P1-P4 priority
  /chk1 update              Update chk1 to the latest version
  /chk1 <commit>..<commit>  Full audit on a specific commit range
  /chk1 <branch>            Full audit on branch changes vs base
  /chk1 help                Display this usage guide
  /chk1 doctor              Check environment health
  /chk1 version             Show installed version

MODES
  all            Full 8-section audit (default)
  quick          Sections 2-3 only: bugs + risks
  security       Deep security: injection, auth, data exposure, crypto
  scope          Sections 4-5, 7-8: compliance, unintended, omissions
  architecture   Section 6 expanded: patterns, boundaries, coupling
  fix            Guided remediation for all findings
  github         Log all findings to GitHub Issues with priority labels
  update         Update chk1 from the GitHub repo

AUDIT SECTIONS (full mode)
  1. Functional Correctness Verification
  2. Bug Detection (syntax, types, race conditions, resource leaks)
  3. Critical Risk Assessment (security, data integrity, performance)
  4. Scope Compliance Verification
  5. Unintended Changes Detection
  6. Architectural Compliance Review
  7. Omissions Analysis
  8. Completeness Verification

TOOLS USED
  Audit: Read, Grep, Glob, Bash(git *)
  Fix mode: + Write, Edit (to apply fixes)

LOCATION
  ~/.claude/skills/chk1/SKILL.md
  ~/.claude/commands/chk1/*.md (sub-commands)
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
chk1 v2.4.0
```

End of version output. Do not continue.

---

## Routing

If $ARGUMENTS matches a mode keyword, route to the corresponding sub-command:

| Argument | Action |
|----------|--------|
| (empty) or `all` | Run full audit (all 8 sections below) |
| `quick` | Run `/chk1:quick` — bugs + risks only |
| `security` | Run `/chk1:security` — deep security audit |
| `scope` | Run `/chk1:scope` — scope compliance + omissions |
| `architecture` | Run `/chk1:architecture` — pattern + boundary audit |
| `fix` | Run `/chk1:fix` — remediation for previous findings |
| `github` | Run `/chk1:github` — log findings to GitHub Issues |
| `update` | Run `/chk1:update` — update chk1 to the latest version |

If $ARGUMENTS doesn't match a mode keyword, treat it as a scope specifier (commit range, branch, SHA) and run the full audit on that scope.

If sub-command files exist in `~/.claude/commands/chk1/`, invoke them via the Skill tool. Otherwise execute inline.

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
- Cross-component data format compatibility: where one component writes output that another reads, verify the exact format matches (JSON field names, nesting structure, wrapper vs raw objects). Trace jq paths, JSON.parse expectations, and struct field accesses across the boundary.
- Environment variable chain completeness: where a parent process spawns child processes, verify every variable the child reads (via `$VAR`, `${VAR}`, `${VAR:-default}`, `${VAR:?error}`) is explicitly exported by the parent. Unexported variables silently disappear across process boundaries.
- Re-run safety: verify that re-executing the same operation (re-running a script, re-deploying, re-installing) does not leave stale artefacts from the previous run. Scripts that create files must clean previous outputs first, or use atomic replacement. Install scripts that copy files to a target must remove the target directory first if files were deleted from the source.

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
- Dangling references to deleted or renamed files (grep for old filenames across all modified and adjacent files, including README, docs, comments, install scripts, and health checks)
- Stale directory contents: if files were deleted from a source directory, verify that install/deploy scripts clean the target before copying (additive copy leaves orphaned files from previous versions)
- Dead code from status/priority chain analysis: for any if-elif chain or priority ordering, verify every branch is reachable under realistic runtime conditions (a state that is always shadowed by an earlier condition is dead code)

Assume bugs exist. Prove otherwise.

## 3. Critical Risk Assessment

Identify, classify, and escalate any of the following risks. Absence of findings requires explicit justification.

- Security vulnerabilities including XSS, injection, exposed secrets, authentication or authorisation bypasses
- Data integrity risks including lost updates, inconsistent state, partial writes, or non-atomic operations
- Performance risks including N+1 queries, unnecessary recomputation, blocking operations, or excessive resource usage
- Breaking changes to existing behaviour, APIs, contracts, or data
- Missing, insufficient, or bypassable user input validation
- Unhandled promise rejections, uncaught exceptions, or silent failures
- Feature nullification through architectural change: when a feature depends on timing assumptions (e.g., a status is visible because file A is written minutes before file B), verify those timing assumptions still hold after the changes. A refactor that moves both writes into the same synchronous path can silently make the feature unobservable.
- Observability gaps: for any monitoring, dashboard, or status system, verify that every state it displays is actually reachable in the current architecture. Walk through the poll interval vs write timing to confirm users can actually see transient states.

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

---

## After Every Run

After producing the audit report (any mode), ask the user:

> **Do you want help fixing the issues found?** If yes, I'll walk through each bug, risk, and deviation with specific code fixes you can apply directly.

If the user says yes, invoke `/chk1:fix`.
