# Multi-Session Architecture

This is the **authoritative global standard** for how Claude sessions collaborate on any project. Every project must follow this architecture unless explicitly overridden in the project's CLAUDE.md (with documented justification).

Referenced by (paths resolved from `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/`):
- `CLAUDE.md` (global rules)
- `PROJECT_STANDARDS.md` (branch protection, CI, documentation standards)
- Each project's `CLAUDE.md` and `.claude/sessions/*.md` startup prompts
- The `/project` skill (reads this file to understand session structure)

---

## 1. Roles

Every software project has these sessions, each in its own git worktree:

| # | Role | Writes code? | Files issues? | Worktree branch |
|---|------|-------------|---------------|-----------------|
| 1 | **Master** | Yes (docs, config, architecture) | Yes | `session/master` |
| 2 | **Planner** | No | Yes (feature requests only) | `session/planner` |
| 3 | **Implementer** | Yes | No (picks up existing issues) | `session/implementer` |
| 4 | **Fixer** | Yes | No (picks up existing issues) | `session/fixer` |
| 5 | **Merger** | No (merges only) | Yes (CI/merge failures) | `session/merger` |
| 6 | **chk1 Auditor** | No | Yes (code quality) | `session/chk1` |
| 7 | **chk2 Auditor** | No | Yes (security) | `session/chk2` |
| 8 | **PerformanceReviewer** | No | Yes (PI-labeled) | `session/performance` |
| 9 | **Playtester** | No | Yes (bugs, UX) | `session/playtester` |
| 10 | **Reviewer** | No | Yes (review comments) | `session/reviewer` |
| 11 | **Triager** | No | Yes (triage updates) | `session/triager` |

**Non-software projects** may skip: chk1, chk2, Playtester.

### Code-writing permissions

Only these roles may modify source code:
- **Fixer** — bug fixes, one issue per branch (`fix/PROJ-<n>`)
- **Implementer** — features, one issue per branch (`feature/PROJ-<n>-<slug>`)
- **Master** — documentation, config, architecture files only (README.md, ARCHITECTURE.md, CLAUDE.md, PROJECT_CONFIG.json, session prompts). NOT PHILOSOPHY.md in projects where it is human-owned.
- **Merger** — squash-merges only, no direct code changes

All other roles are **read-only on source**. They interact via Jira issues and review comments.

---

## 2. Master

The Master session serves two functions:

**Automated monitoring (via sub-agents):**
- Monitors all other sessions for health, progress, and stalls
- Monitors Jira for issues stuck in workflow, missing fields, priority drift
- Monitors CI status, sandbox health, release readiness
- Raises concerns to the human with specific recommendations
- May recommend improvements to the multi-session architecture itself

**Human interaction:**
- The human's primary Claude session (like a direct conversation)
- Handles ad-hoc requests, architecture decisions, planning discussions
- Owns PHILOSOPHY.md edits (with human approval)
- Coordinates releases

---

## 3. Planner

The **only** session that can create issues labeled as feature requests.

Protocol:
1. Engage the human in deep discussion — explore the request holistically
2. Research extensively: codebase impact, architecture implications, alternatives
3. Present a wide variety of options and recommendations (not limited to 3)
4. Iterate with the human until the feature is fully understood
5. Search Jira for duplicates
6. Verify alignment with PHILOSOPHY.md and ROADMAP.md
7. Draft issue with: Goal, Motivation, Acceptance Criteria, Out of Scope, Notes, Options Considered
8. On human approval: create Jira issue with type `Feature Request` + priority

**Never writes code. Never files bugs.** Only feature requests, and only after deep human engagement.

---

## 4. Fixer

Works through Jira issues labeled as bugs/errors, one at a time.

Protocol:
1. **Check for rework first:** Scan Jira for issues in `Changes Requested` state with a `fix/PROJ-<n>` branch that this session owns. Rework takes priority over new issues.
2. If no rework: pick the highest-priority bug in `Ready for Coding` state
3. Create branch: `fix/PROJ-<n>` (where PROJ-<n> is the Jira issue key). If reworking, check out the existing branch.
4. **Plan first** (new issues only — skip for rework): Write a comprehensive fix plan covering:
   - Root cause analysis (go deep — trace every caller and side effect)
   - Test specification (file, describe block, test name, assertion)
   - Implementation approach
   - Files to modify (exhaustive list)
   - Risk assessment
5. **Check the plan:** Review recursively for correctness. Send to Codex for second opinion. Improve based on feedback.
6. **Attach plan to Jira issue** as a comment
7. **Wait for Triager** to review the plan and mark the issue as `Plan Approved` (new issues only — rework already has approval)
8. **RED:** Write failing regression test first
9. **GREEN:** Implement the minimum fix to pass
10. Run full test suite — must be 100% green
11. **Update docs:** If the fix changes documented behavior, update README.md and ARCHITECTURE.md in the same branch. Do NOT touch PHILOSOPHY.md.
12. Push branch, update Jira issue status to `In Review`
13. Exit. Never merge.

**May use sub-agents** for investigation, but not by default — only when the fixer decides a task warrants it or is instructed to.

**3-strikes rule:** If the same issue fails tests or review 3 times across separate fix attempts, escalate to the human via Master with full context of all 3 attempts.

---

## 5. Implementer

Works through Jira issues labeled as feature requests, one at a time.

Protocol:
1. **Check for rework first:** Scan Jira for issues in `Changes Requested` state with a `feature/PROJ-<n>-*` branch that this session owns. Rework takes priority over new issues.
2. If no rework: pick the highest-priority feature in `Ready for Coding` state
3. Create branch: `feature/PROJ-<n>-<slug>`. If reworking, check out the existing branch.
4. Read the Reviewer's comments on the Jira issue (for rework) to understand what needs to change
5. Follow strict red-green TDD
6. Atomic commits referencing the Jira issue key
7. Full test suite must pass before push
8. **Update docs:** If the change affects documented features, endpoints, config, or architecture, update README.md and ARCHITECTURE.md in the same branch. Do NOT touch PHILOSOPHY.md.
9. Push branch, update Jira status to `In Review`
10. Exit. Never merge.

**May use sub-agents** when beneficial, but not by default.

---

## 6. Merger

Merges completed work into main. Never writes code directly.

Protocol:
1. Scan for Jira issues in `In Review` state with:
   - Reviewer approval (structured comment or label)
   - CI green on the branch
   - All tests passing (100% — no exceptions)
2. If all gates pass: squash-merge the branch into main, delete branch, update Jira to `Done`
3. If tests are NOT 100% passing: send back as a new Jira issue (type: Bug/CI Issue) with details of the failure. Link to the original issue.
4. **3-strikes rule:** If a branch fails merger's check 3 times, escalate to human.
5. Post-merge: verify main CI stays green. If it breaks, file a Jira issue immediately.
6. 5-minute cooldown between merges (allows human override window)

---

## 7. chk1 Auditor

Runs the `/chk1:all` skill against new commits on main.

Protocol:
1. Track last-audited commit SHA (via git ref `refs/audit/chk1-last-seen`)
2. On each iteration: check for new commits since last audit
3. Run `/chk1:all` against each new diff
4. File findings as Jira issues with type `Code Quality`, priority P1-P4, comprehensive detail
5. Deduplicate: search Jira before filing. Update existing issues if the finding matches.
6. Update last-seen SHA

**Does not write code. Does not fix issues.** Only audits and files.

---

## 8. chk2 Auditor

Runs the `/chk2:all` skill against test/staging/production servers.

Protocol:
1. If the project has a test, staging, or production server URL: run `/chk2:all` against it
2. If no server is available: **wait patiently**. Do not attempt to create or start servers.
3. File findings as Jira issues with type `Security`, priority based on severity:
   - P1: credential exposure, RCE, authentication bypass
   - P2: information disclosure, injection vectors
   - P3: missing best-practice headers, configuration weaknesses
   - P4: informational findings
4. Deduplicate before filing

**Does not write code.** Only scans and files.

---

## 9. PerformanceReviewer

Assesses performance before releases.

Protocol:
1. **Trigger:** Runs when Master signals a release candidate (not per-commit)
2. Review all commits since the last release tag
3. Assess for: regressions, N+1 queries, unbounded loops, memory leaks, unnecessary allocations, missing caching, slow algorithms
4. File findings as Jira issues with type `Performance Improvement` (label: `PI`), priority P1-P4
5. If any PI issue is P1 or P2: the release is blocked until addressed

**Does not write code.** Files issues only.

---

## 10. Playtester

Runs the actual code — install, uninstall, operate every feature, stress test, check UI, check everything.

Protocol:
1. **Must operate in a sandboxed environment** so the current machine is not impacted
   - Options: Docker container, dedicated VM, RunPod pod, or any isolated environment
   - Work with the human to configure the sandbox if the Playtester cannot set it up itself
2. Install the project from scratch (following README.md instructions)
3. Exercise every feature systematically
4. Stress/performance test where applicable
5. Check UI rendering, accessibility, edge cases
6. Uninstall and verify clean removal
7. File any problems as Jira issues with type `Bug` or `UX`, priority P1-P4, comprehensive detail including reproduction steps
8. Deduplicate: search Jira before filing

**Does not write code.** Only tests and files.

---

## 11. Reviewer

Reviews every branch from Implementer or Fixer.

Protocol:
1. Scan for branches in `In Review` state (via Jira)
2. For each: read the diff, run tests, run `/chk1:all` against the diff, read linked Jira issue
3. Post a structured review comment ending with:
   ```
   reviewed-sha: <full HEAD SHA>
   Recommendation: {APPROVE | CHANGES REQUESTED | HOLD} — <reason>
   ```
4. Update Jira issue with review outcome
5. **Never approves, never merges.** Posts comments only. Merger handles the merge.

---

## 12. Triager

Quality gate between issue filing and code writing. **No issue may move to coding until the Triager releases it.**

Protocol:
1. Scan Jira for issues in `New` or `Needs Triage` state
2. For each issue, verify:
   - Has a priority (P1-P4) and it's correct
   - Has a type (Bug, Feature, PI, Security, Code Quality, CI, UX)
   - Has comprehensive detail — the issue creator went deep and understood the problem holistically
   - For bugs: reproduction steps are clear
   - For features: acceptance criteria are specific
   - For Fixer issues: a plan is attached (Fixer posts plan before coding)
3. If incomplete: comment asking for more detail, leave in `Needs Triage`
4. If the plan (for bugs) is inadequate: reject with specific feedback
5. If complete: move to `Ready for Coding`
6. Check for duplicates — mark and link
7. Verify priority is accurate (re-prioritize if needed with justification)

**The `Ready for Coding` state is the Triager's exclusive gate.** Fixer and Implementer may only pick up issues in this state.

---

## 3. Issue Lifecycle (Jira Workflow)

```
New → Needs Triage → Ready for Coding → In Progress → In Review → Done
                 ↑                                         |
                 └─── Changes Requested ←──────────────────┘
```

| State | Who sets it | Meaning |
|-------|------------|---------|
| New | Any session that files an issue | Just created |
| Needs Triage | Triager (or auto on create) | Awaiting triager review |
| Ready for Coding | Triager only | Plan reviewed (if bug), detail sufficient, priority confirmed |
| In Progress | Fixer or Implementer | Claimed, branch created, work started |
| In Review | Fixer or Implementer | Branch pushed, awaiting Reviewer + Merger |
| Changes Requested | Reviewer | Review found issues — original Fixer/Implementer reworks and resubmits to In Review |
| Done | Merger | Merged to main, tests green |

### Required Jira fields

Every issue must have:
- **Priority:** P1 (critical/blocker), P2 (high), P3 (medium), P4 (low)
- **Type:** Bug, Feature Request, Performance Improvement (PI), Security, Code Quality, CI Issue, UX
- **Status:** per workflow above
- **Description:** comprehensive, holistic, deep. Must include:
  - For bugs: severity, file:line, reproduction steps, expected vs actual, root cause if known
  - For features: goal, motivation, acceptance criteria, out of scope
  - For PI/Security/Quality: location, impact, recommended fix
- **Linked branch:** `fix/PROJ-<n>` or `feature/PROJ-<n>-<slug>` (set by Fixer/Implementer)
- **Plan:** (bugs only) attached as comment before coding begins

---

## 4. Release Model

A release is a tagged version on main representing a deployable checkpoint.

### Release gates (ALL must be true)

1. **Zero open P1 or P2 issues** in Jira
2. **PerformanceReviewer pass** — has run against current main since last release, no P1/P2 PI issues open
3. **Playtester regression pass** — full end-to-end in sandbox
4. **CI green on main** — no open CI failure issues
5. **No `In Progress` issues** — all active work either completed or cleanly parked

### Who monitors release readiness

**Master.** Periodically checks all gates. When all are met, notifies the human:

> Release candidate: vX.Y.Z — N merges since last release, 0 P1/P2 open, CI green, PerformanceReviewer clear. Cut release?

### Release mechanics

```bash
# Bump version (minor for features, patch for fixes-only)
# Tag and create GitHub release
gh release create vX.Y.Z --title "vX.Y.Z" --generate-notes --target main
# Deploy per project (manual or scripted)
```

### Version numbering

- **Patch** (0.5.X → 0.5.Y): bug fixes only
- **Minor** (0.X.0 → 0.Y.0): new features
- **Major** (X.0.0): breaking changes or milestone releases

Each merge bumps the patch. Releases may bump minor or major.

---

## 5. Issue Tracking: Jira

**Jira is the single source of truth for all issue tracking.** This applies to ALL issues including CI failures.

### Jira structure

- **Project:** `CPT` (Claude Progress Tracking) — single project for all work
- **Epics:** one per repo/project (e.g., "myzr" epic, "uam" epic). The epic is the top-level container for all work in that project.
- **Tasks:** every issue (bug, feature, PI, security, code quality, CI, UX) is a task under the project's epic
- **Sub-tasks:** breakdowns of tasks when needed (e.g., a feature broken into implementation steps)

When filing any issue, every session must:
1. File it as a task under the correct epic
2. Set Priority (P1/P2/P3/P4), Type, and Status
3. Include comprehensive detail in the description

### CI failure auto-filing to Jira

The **Master session** monitors CI status on the local machine via `gh run list` and files failures as Jira tasks under the project's epic. Jira credentials are injected into the shell environment from AWS Secrets Manager by `~/.bashrc` (see `$CLAUDE_DIR/PROJECT_STANDARDS.md` §9). GitHub Actions workflows do not file to Jira directly — they only run tests and report pass/fail.

### No GitHub Issues for tracking

GitHub Issues are not used for issue tracking. If a project has legacy GitHub Issues, migrate them to Jira (as tasks under the project's epic) and close the GitHub copies.

### Per-project configuration

Each project documents its Jira epic name/key in its CLAUDE.md or PROJECT_CONFIG.json.

---

## 6. Sub-Agents Policy

- Sessions **may** use sub-agents when they decide a task warrants it or when instructed by the human
- Sessions **do not** use sub-agents by default
- Common sub-agent use cases:
  - Fixer: investigation of complex root causes
  - Implementer: parallel implementation of independent components
  - Master: monitoring multiple sessions simultaneously
  - Playtester: parallel testing of independent features
- Sub-agents inherit the permissions of their parent session (a Fixer sub-agent can write code; a chk1 sub-agent cannot)

---

## 7. Worktree Layout

Each session runs in its own git worktree inside the repo:

```
.worktrees/
  master/        chk1/          chk2/          performance/
  planner/       implementer/   fixer/         playtester/
  reviewer/      triager/       merger/
```

Each worktree is on branch `session/<role>` (parked at main between tasks).

### Setup (one-time per repo)

```bash
mkdir -p .worktrees
for name in master planner implementer fixer merger chk1 chk2 performance playtester reviewer triager; do
  if ! git worktree list | grep -q ".worktrees/$name "; then
    git worktree add ".worktrees/$name" -b "session/$name" main
  fi
done
```

### Starting a session

```bash
cd .worktrees/<role>
claude
# Paste startup prompt from .claude/sessions/<role>.md
```

---

## 7.1 Worktree creation is forbidden

**The 11 role worktrees listed in §7 are the ONLY worktrees permitted in any project. No session — including the human — may create additional worktrees in the normal flow of work.**

Feature/fix work is always a **branch created inside the existing role worktree**. Never a new worktree, never a re-pointed worktree.

### Correct

```bash
# Implementer picks up a feature; stays in its own worktree.
cd .worktrees/implementer             # already on session/implementer (parked)
git checkout -b feature/CPT-<n>-<slug>
# …red-green TDD, commits…
git push -u origin feature/CPT-<n>-<slug>
git checkout session/implementer      # return to parked state when work ships
```

### Incorrect

```bash
git worktree add .worktrees/my-feature -b feature/foo   # ❌ forbidden
git worktree add ../feature-CPT-42  -b feature/CPT-42    # ❌ forbidden
```

### Enforcement

Three layers, in order of strength:

1. **Tool-layer hook (hard block):** `$CLAUDE_DIR/hooks/block-worktree-add.sh` is registered as a `PreToolUse` hook in `$CLAUDE_DIR/settings.json`. Any Bash tool call matching `git worktree add` is rejected with exit code 2 unless the command inlines `GIT_WORKTREE_OVERRIDE=1` as a prefix. The inline requirement forces each bypass to be a conscious human action.
2. **Audit detection (soft block):** `/project:audit` check #16 FAILs on any `.worktrees/<name>/` whose `<name>` is not in `PROJECT_CONFIG.json` `sessions.roles`. It also validates each role worktree's HEAD branch against a role-aware rule — **fixer** may be on `session/fixer` or a branch matching `^fix/<JIRA_KEY>-[0-9]+` (active-work pattern per §7.1); **implementer** may be on `session/implementer` or `^feature/<JIRA_KEY>-[0-9]+`; **all other roles** (master, planner, merger, chk1, chk2, performance, playtester, reviewer, triager) must be on `session/<role>` because they are read-only on source per §1. Any other HEAD value FAILs (indicates a re-pointed worktree, forbidden).
3. **Session-prompt guidance:** every `.claude/sessions/<role>.md` includes a "Worktree rule" reminder that feature/fix work is a branch inside the existing worktree, never a new worktree.

### Human override

When the human genuinely needs a new worktree (rare — examples: reviewing a hostile branch in isolation, running a second independent experiment), they bypass the hook with the inline prefix:

```bash
GIT_WORKTREE_OVERRIDE=1 git worktree add <path> <args...>
```

No long-lived env var. No `unset` at the end. Every bypass is explicit.

---

## 8. Sandbox Requirements (Playtester)

The Playtester must operate in an isolated environment. Acceptable options:

- Docker container on the local machine
- Dedicated VM (local or cloud)
- RunPod pod or similar cloud compute
- Any environment isolated from the development machine

The sandbox must:
- Be disposable (can be destroyed and recreated)
- Have network access to test servers if applicable
- Not share filesystem, credentials, or state with the development machine
- Be configured with the human's help if the Playtester cannot set it up alone

The specific sandbox type is project-dependent and documented in the project's CLAUDE.md.

---

## 9. Plan-Before-Code Discipline

**Every bug fix requires a plan before coding begins.**

The plan must include:
1. Root cause analysis — go deep, trace every caller and side effect
2. Test specification — exact file, describe block, test name, assertion
3. Implementation approach — not just "fix it" but HOW
4. Files to modify — exhaustive list
5. Risk assessment — what could break

The plan must be:
- Checked recursively by the Fixer for correctness
- Sent to Codex for a second opinion
- Improved based on Codex feedback
- Attached to the Jira issue as a comment

**The Triager must review and approve the plan** before the Fixer may begin coding. This applies to ALL priorities including P4 — a P4 may be re-prioritized once the plan reveals deeper issues.

---

## 10. Quality Standards

### Testing
- Red-green TDD. No exceptions unless the human expressly says to skip.
- Tests must be comprehensive: edge cases, error paths, boundary conditions.
- 100% of tests must pass before any branch can be merged.
- All tests committed to the repo.

### Issue filing
- Every issue filed by any session must include comprehensive, holistic detail.
- The session must go deep and investigate before filing — shallow "I noticed X" issues are not acceptable.
- Every issue must have a priority (P1-P4) regardless of type.
- Deduplicate before filing: search Jira for existing matches.

### Documentation
- Fixer and Implementer update README.md and ARCHITECTURE.md in the same branch if their change affects documented behavior.
- PHILOSOPHY.md is owned by the Master session (with human approval). No other session touches it.

---

## 11. Escalation Rules

| Trigger | Escalate to |
|---------|-------------|
| Same issue fails 3 fix attempts | Human (via Master) |
| Branch fails merger's check 3 times | Human (via Master) |
| Session stalls for >60 minutes with no heartbeat | Master removes claim, notifies human |
| P1 issue filed | Master immediately notifies human |
| Architecture concern identified | Master raises with recommendation |
| Multi-session architecture improvement identified | Master proposes change to human |

---

## 12. Per-Project Configuration

Each project documents in its CLAUDE.md or PROJECT_CONFIG.json:

- Jira project key and board URL
- Sandbox type and setup instructions for Playtester
- Test/staging/production server URLs for chk2
- Deployment procedure
- Any role overrides or additions
- PHILOSOPHY.md ownership model
- Branch naming conventions if non-standard

---

## Finding this document

This file ships as part of the `/project` skill (skill product). At runtime it is installed to `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md` — i.e. under `$CLAUDE_CONFIG_DIR` when that env var is set, otherwise `$HOME/.claude/`. Source of truth lives in `skills/project/global/MULTI_SESSION_ARCHITECTURE.md` in the choc-skills repo; the installer copies it into the Claude config dir on every `--force` run.

For the `/project` skill or any tool that needs to understand the session structure:
- **Path:** resolved via `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/MULTI_SESSION_ARCHITECTURE.md`
- **What it contains:** role definitions, workflow rules, Jira integration, release model, code permissions, escalation rules
- **How to use it:** read this file at session start to understand the multi-session architecture. When creating a new project, use this as the template for setting up worktrees and session prompts. When auditing a project, verify it conforms to this standard.
