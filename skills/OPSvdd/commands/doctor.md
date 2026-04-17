# OPSvdd:doctor — Environment Health Check

Run these checks and report results as a pass/warn/fail summary. Do not proceed to any other action after.

## Structural checks (Phase 0)

1. Verify `bash` is available: `which bash`
2. Verify `shasum` is available (macOS ships it; Linux may need `coreutils`): `which shasum`
3. Verify `git` is available (required by `update`): `which git`
4. Verify `jq` is available (required for Phase 3 override hash): `which jq` — **WARN only in v1.0.0**.
5. Check installed files exist:
   - `ls ~/.claude/skills/OPSvdd/SKILL.md`
   - `ls ~/.claude/skills/OPSvdd/.source-repo`
   - `ls ~/.claude/commands/OPSvdd.md`
   - `ls ~/.claude/commands/OPSvdd/help.md`
   - `ls ~/.claude/commands/OPSvdd/doctor.md`
   - `ls ~/.claude/commands/OPSvdd/version.md`
   - `ls ~/.claude/commands/OPSvdd/update.md`
6. Check reference tree exists (empty dirs are OK in Phase 0):
   - `ls -d ~/.claude/skills/OPSvdd/references/jurisdictions`
   - `ls -d ~/.claude/skills/OPSvdd/references/regulatory`
   - `ls -d ~/.claude/skills/OPSvdd/references/regulatory/sg`
   - `ls -d ~/.claude/skills/OPSvdd/references/tiering`
   - `ls -d ~/.claude/skills/OPSvdd/references/schemas`
   - `ls -d ~/.claude/skills/OPSvdd/references/workflow`
7. Check SKILL.md version matches source (if `.source-repo` present and accessible): read `version:` from both, compare.
8. Check env vars (report set/not set, **never display values**):
   - `OPSVDD_OUTPUT_DIR` (optional in Phase 0; required in Phase 2)
   - `JIRA_EMAIL` (optional in Phase 0; required for `:approval` in Phase 3 if MCP unavailable)
   - `JIRA_API_KEY` (optional in Phase 0; required for `:approval` in Phase 3 if MCP unavailable)
9. Check `OPSVDD_OUTPUT_DIR` is writable if set (`test -w "$OPSVDD_OUTPUT_DIR"`); WARN if set but not writable.

## Domain checks (deferred)

These are reported as `deferred` in Phase 0 and become active in later phases:

- **Atlassian MCP connectivity** (probes OPS + APRVL) — activated in Phase 2+
- **OPS `Vendor Review Status` custom field present and writable** (AC-0 prerequisite) — activated in Phase 2
- **Yearly parent Epic `Vendor Due Diligence <current-year>`** exists — activated in Phase 2 (warn-only; skill auto-creates)

## Output format

```
OPSvdd doctor — Phase 0 (v1.0.0)

Structural
  PASS  bash: /bin/bash
  PASS  shasum: /usr/bin/shasum
  PASS  git: /usr/bin/git
  WARN  jq: not found (required for Phase 3 override hash)
  PASS  SKILL.md installed
  PASS  Router installed
  PASS  Subcommands: 4/4 installed (help, doctor, version, update)
  PASS  References tree: 6/6 directories present
  PASS  Version match: v1.0.0 (source == installed)
  INFO  OPSVDD_OUTPUT_DIR: not set (default ~/opsvdd-output, Phase 2+)
  INFO  JIRA_EMAIL: not set (Phase 3+ requirement)
  INFO  JIRA_API_KEY: not set (Phase 3+ requirement)

Domain (deferred to later phases)
  DEFER Atlassian MCP connectivity (Phase 2+)
  DEFER OPS Vendor Review Status field (Phase 2, AC-0)
  DEFER Yearly parent Epic (Phase 2)

All structural checks passed.
```

Exit non-zero if ANY of the structural PASS checks fails. WARNs and DEFERs do not cause a non-zero exit in Phase 0.
