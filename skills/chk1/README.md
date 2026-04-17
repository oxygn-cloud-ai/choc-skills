# chk1 — Adversarial Implementation Audit

A Claude Code skill that performs fault-finding, risk-exposing, deviation-detecting audits of recently implemented code changes. Assumes the implementation is defective unless proven otherwise.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- `git` installed and available in PATH
- Must be run inside a git repository with at least one commit

## Installation

### From repo root (recommended)

```bash
git clone https://github.com/oxygn-cloud-ai/choc-skills.git
cd choc-skills
./install.sh chk1
```

### Standalone (from this directory)

```bash
./install.sh
```

### Manual (no clone needed)

```bash
mkdir -p ~/.claude/skills/chk1
curl -sL https://raw.githubusercontent.com/oxygn-cloud-ai/choc-skills/main/skills/chk1/SKILL.md \
  -o ~/.claude/skills/chk1/SKILL.md
```

### Verify installation

```bash
./install.sh --check
```

## Usage

In Claude Code:

```
/chk1                       Audit the most recent implementation (auto-detects commits)
/chk1 abc123..def456        Audit a specific commit range
/chk1 feature-branch        Audit changes on a branch vs main
/chk1 abc123                Audit a single commit
/chk1 doctor                Check environment health
/chk1 version               Show installed version
/chk1 help                  Display full usage guide
```

## What it audits

1. **Functional Correctness** — runtime errors, logic vs plan, edge cases, data flow
2. **Bug Detection** — syntax, types, race conditions, resource leaks, off-by-one errors
3. **Critical Risks** — security (XSS, injection, secrets), data integrity, performance
4. **Scope Compliance** — unintended file changes, dependency mutations
5. **Unintended Changes** — out-of-scope features, unauthorised refactors
6. **Architectural Compliance** — boundary erosion, new patterns/coupling
7. **Omissions** — missing steps, skipped validations
8. **Completeness** — partial or deferred work

## Output format

The audit produces a structured report:

- **Audit Metadata** — scope, files, lines, author, plan reference
- **Files Changed** — complete list
- **Per-File Analysis** — CORRECT / WARNING / BUG FOUND status per file
- **Bugs Found** — numbered with file:line references
- **Critical Risks** — severity + remediation
- **Unintended Changes** — or "None detected"
- **Omissions** — missing plan steps
- **Architectural Deviations** — boundary violations
- **Summary** — BLOCKED / PERMITTED / PERMITTED WITH WARNINGS verdict
- **Remediation Plan** — step-by-step fix plan

## Scope auto-detection

When no arguments are given, chk1 examines `git log` and identifies the boundary of the most recent implementation session by looking for:

- Merge commits
- Author changes
- Time gaps (>4 hours between commits)
- Different task indicators in commit messages

If the boundary is ambiguous, it defaults to the latest commit and tells you to narrow the scope.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Not inside a git repository" | `cd` into your project repo before running |
| "This repository has no commits" | Make at least one commit first |
| "No changes found in the specified range" | Check your commit range with `git log --oneline` |
| "Could not auto-detect implementation boundary" | Specify a range: `/chk1 abc..def` |
| "Very large diff" warning | Narrow scope: `/chk1 abc..def` or target specific commits |
| Skill not appearing in Claude Code | Verify: `ls ~/.claude/skills/chk1/SKILL.md` |
| Skill is outdated | Run `./install.sh --force chk1` or `./install.sh --check` |

## Update

```bash
cd choc-skills && git pull && ./install.sh --force chk1
```

## Uninstall

### Via installer

```bash
./install.sh --uninstall chk1
```

### Manual

```bash
rm -rf ~/.claude/skills/chk1
```

## Version

Current: **2.4.6**

## License

MIT
