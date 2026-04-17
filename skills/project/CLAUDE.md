# CLAUDE.md — /project skill-local instructions

This file is loaded when a session is operating inside `skills/project/`. It supplements the repo-level `CLAUDE.md` at the choc-skills root with rules specific to the `/project` skill's internal invariants.

## Cite convention (CPT-59)

Every enforcement mechanism in this skill MUST declare which standards-doc rule it implements, via a header comment:

```
# Implements: <doc-basename>:§<section-number>
```

- Targets `~/.claude/MULTI_SESSION_ARCHITECTURE.md` and `~/.claude/PROJECT_STANDARDS.md` use their basename.
- Section anchors use the `§N.N` form (e.g., `§7.1`).
- Project-local references (e.g., `project CLAUDE.md "Skill-is-product rule"`) are accepted as documentation cites.
- Multiple citations on separate lines are allowed (mechanism implements more than one rule).

### Why

`/project:self-audit` (B-check and C-check) parses these citations to verify:

- **B** — every enforcement rule in the standards docs has at least one mechanism that cites it (no orphan rule).
- **C** — every mechanism that declares a citation actually points at a real section (no dead code, no stale pointer).

Without a grep-friendly convention, the audit can't distinguish "this hook has a rationale comment" from "this hook implements §7.1". The `# Implements:` prefix is machine-readable.

### Where to put it

- **Shell hooks** (`skills/project/hooks/*.sh`): header block near the top, typically line 2-5.
- **Bin scripts** (`skills/project/bin/*.sh`): header block near the top.
- **Command files** (`skills/project/commands/*.md`): as an HTML comment or code-fence comment near the relevant check, or in a `## Implements` section.

### Examples

```bash
#!/bin/bash
# block-worktree-add.sh — Claude Code PreToolUse hook
# Implements: MULTI_SESSION_ARCHITECTURE.md:§7.1
```

```bash
#!/bin/bash
# verify-jira-parent.sh — Claude Code PreToolUse hook
# Implements: MULTI_SESSION_ARCHITECTURE.md:§5
```

```markdown
16. **No unauthorised worktrees** <!-- Implements: MULTI_SESSION_ARCHITECTURE.md:§7.1 -->
```

### Documentation-only files

Files with no enforcement logic (help text, changelog, README, etc.) don't need citations. The self-audit only flags enforcement mechanisms — hooks, audit-checks, session-prompt clauses — that lack them.

### Running the audit

```
/project:self-audit                # all checks (A-E)
/project:self-audit --rules        # B + C only
/project:self-audit --format=json  # machine-readable
```

See `skills/project/commands/self-audit.md` for the full contract.
