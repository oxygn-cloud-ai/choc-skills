# project:self-audit — Recursive / meta audit of the /project skill

Audits the `/project` skill against its own standards — the recursive check that closes the cave-inversion class of errors where the skill drifts from the rules it defines.

Positioning:

| Command | Audits what? | Against what? |
|---------|--------------|---------------|
| `/project:audit` | Other projects | `~/.claude/MULTI_SESSION_ARCHITECTURE.md` + `PROJECT_STANDARDS.md` |
| `install.sh --check` | Install targets | Skill source (one-way source → target) |
| **`/project:self-audit`** | **The `/project` skill itself** | **Bidirectional: rules ↔ mechanisms, source ↔ target, manifest ↔ reality** |

## Execution

Run the self-audit via the bundled script. It takes care of every check.

```bash
~/.claude/skills/project/bin/project-self-audit.sh         # Run all 5 checks
~/.claude/skills/project/bin/project-self-audit.sh --parity
~/.claude/skills/project/bin/project-self-audit.sh --rules
~/.claude/skills/project/bin/project-self-audit.sh --manifest
~/.claude/skills/project/bin/project-self-audit.sh --standards
~/.claude/skills/project/bin/project-self-audit.sh --format=json
```

If the bin script is not yet installed (`test -x ~/.claude/skills/project/bin/project-self-audit.sh` fails), run `./install.sh --force` from the skill source first, or invoke the script directly from the repo checkout at `skills/project/bin/project-self-audit.sh`.

## Checks

### A — Install parity

For every file under `skills/project/{hooks,bin,commands}/`, `shasum -a 256` the source and compare to the install target under `~/.claude/`:

- **DRIFT** — installed copy differs from source (run `./install.sh --force`)
- **MISSING** — source exists but no install target
- **ORPHAN** — hook present in `~/.claude/hooks/` with no source in `skills/project/hooks/`
- **NOT-REGISTERED** — hook source is installed but not registered in `~/.claude/settings.json` `hooks.PreToolUse[]`

### B — Rules → Mechanisms

Parse `~/.claude/MULTI_SESSION_ARCHITECTURE.md` and `~/.claude/PROJECT_STANDARDS.md` for numbered `§N.N` sections whose bodies contain enforcement verbs (`must`, `forbidden`, `hard-block`, `non-negotiable`, `blocks`, `rejected`, `never`). For each rule, search the skill source for `# Implements: <doc>:§<section>`. Rules with zero matching citations are FLAGGED — either the rule is missing an enforcement mechanism, or it is documentation-only and should be marked as such.

### C — Mechanisms → Rules

Grep `skills/project/{hooks,bin,commands}/*` for `# Implements:` lines. For each citation, verify the referenced `§<section>` actually exists in the cited doc. Mechanisms with no citation OR unresolvable citations are FLAGGED — either the rule is missing from the docs, or the mechanism is dead code.

### D — Install manifest

For every file under `skills/project/{hooks,bin,commands}/`, grep `install.sh` for the basename. Missing basenames are FLAGGED — the installer has no code path that deploys the file. Supersets byte-parity: parity catches "installed but differs", manifest catches "installer doesn't know about this file at all".

### E — Standards compliance (proxy)

Run `scripts/validate-skills.sh` and `scripts/validate-config.sh` from the source repo. Both exit zero = PASS. Non-zero = FLAG. `/project:audit` itself is an interactive user-invocable command; this check is a non-interactive proxy. The operator still runs `/project:audit` manually for a full audit including the human-level checks (docs, branch protection, CI, etc.).

## Cite convention

Every enforcement mechanism in `skills/project/{hooks,bin,commands}/` MUST include a header comment of the form:

```
# Implements: <doc-basename>:§<section-number>
```

Example:

```bash
#!/bin/bash
# block-worktree-add.sh — Claude Code PreToolUse hook
# Implements: MULTI_SESSION_ARCHITECTURE.md:§7.1
```

Multiple citations are allowed on separate lines. Documentation-only files (no enforcement logic) do not need citations. The convention is documented in `skills/project/CLAUDE.md`.

## Exit codes

- `0` — all checks PASS
- `1` — one or more checks FLAG
- `2` — invocation error (unknown flag, missing source, etc.)

## JSON output

`--format=json` emits a top-level object:

```json
{
  "version": "1.0.0",
  "totals": {"pass": 10, "flag": 0},
  "results": [
    {"check": "A", "verdict": "pass", "detail": "8 file(s) byte-identical, no orphans"},
    {"check": "B", "verdict": "pass", "detail": "every enforcement rule has a citing mechanism"},
    ...
  ]
}
```

Valid JSON regardless of pass/flag count. CI / automation can parse `.totals.flag` and gate on zero.
