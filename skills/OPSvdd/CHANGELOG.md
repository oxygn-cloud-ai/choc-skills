# Changelog — OPSvdd

All notable changes to `/OPSvdd` are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); version numbers follow [SemVer](https://semver.org/).

## [1.0.0] — 2026-04-17

**Phase 0 scaffolding (CPT-87).** Ships the skill structure, installer, router, and trivial lifecycle commands. No domain logic — `assess`, `approval`, `duplicate` return `not yet implemented` stubs. Domain phases land in CPT-87.1 (tier framework), CPT-87.2 (workflow + OPS publication), CPT-87.3 (APRVL + override audit).

### Added

- `skills/OPSvdd/SKILL.md` — v1.0.0 frontmatter (`user-invocable: true`, `disable-model-invocation: true`, minimal `allowed-tools`), router table, tier framework reference, 9-step workflow reference, Jira quick-reference, MAS Notice 634 warning spec, phase roadmap.
- `skills/OPSvdd/install.sh` — per-skill installer matching `skills/rr/install.sh` pattern. `--force`, `--check`, `--uninstall`, `--version`, `--help`. Writes `.source-repo` marker. SHA-256 verification on SKILL.md copy. Recursive references/ tree copy preserving structure.
- `skills/OPSvdd/commands/{help,doctor,version,update}.md` — four Phase 0 colon-commands (router targets).
- `skills/OPSvdd/commands/{assess,approval,duplicate}.md` — Phase 1/2/3 stubs that emit `not yet implemented — see CPT-87.1 / 87.2 / 87.3` and exit. Stubs exist so `/OPSvdd assess` resolves to a file rather than falling through to help, keeping the router table honest.
- `skills/OPSvdd/references/` — empty tree with placeholders:
  - `jurisdictions/{sg,hk,jp,uae}.yaml` — sg active, others stubs
  - `regulatory/{sg,hk,jp,uae}/` — sg populated in Phase 2; others empty
  - `tiering/.gitkeep` — `mas-materiality-test.md` lands in Phase 1
  - `schemas/.gitkeep` — schemas land alongside their workflow steps in Phase 2
  - `workflow/.gitkeep` — step-1 through step-9 land in Phases 1+2
- `skills/OPSvdd/README.md` — usage, install, phase roadmap, design contract.
- `tests/opsvdd-scaffolding.bats` — structure + frontmatter + install round-trip + root-installer discovery + validator compliance + AC-16 code hygiene. 24 tests.
- Root `README.md` — skills table entry.

### Phase-0 ACs covered

- AC-0 (Vendor Review Status field) — **DEFERRED** to Phase 2. Doctor will probe once Phase 2 lands; Phase 0 doctor only verifies structural installation.
- AC-1 — structure.
- AC-2 — install.
- AC-3 — root-installer discovery.
- AC-4 — uninstall round-trip.
- AC-12 — CI green.
- AC-16 — code hygiene (forbidden strings enumerated in `tests/opsvdd-scaffolding.bats`: none of them appear in the skill source).

All other ACs (5, 6, 7.1–7.12, 8, 9, 10, 11, 13, 14, 15, 17) are deferred to Phase 1/2/3 per the split proposed on the parent ticket on 2026-04-17.
