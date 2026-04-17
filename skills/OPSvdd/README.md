# OPSvdd — MAS-aligned Vendor Due Diligence

`/OPSvdd` is a Claude Code skill for Chocolate Finance that runs structured 9-step vendor due diligence assessments, publishes to the OPS Jira project under a yearly `Vendor Due Diligence <year>` Epic, and — for material outsourcing (Tier 1/2) — triggers APRVL sign-off with an audit-grade override mechanism that mirrors `/LEGtc`.

**Status — v1.0.0 (CPT-87 Phase 0): scaffolding only.** Domain subcommands (`assess`, `approval`, `duplicate`) emit `not yet implemented` and exit. The installer, router, `help`, `doctor`, `version`, and `update` are fully functional.

---

## Install

```bash
cd <repo>/skills/OPSvdd
./install.sh --force
```

The root installer also picks it up via glob auto-discovery:

```bash
./install.sh --force OPSvdd
```

Either way, files land in:

- `~/.claude/skills/OPSvdd/SKILL.md`
- `~/.claude/skills/OPSvdd/references/...` (recursive)
- `~/.claude/skills/OPSvdd/.source-repo` (pointer for `/OPSvdd update`)
- `~/.claude/commands/OPSvdd.md` (router)
- `~/.claude/commands/OPSvdd/*.md` (subcommands)

### Verify

```bash
./install.sh --check    # from the skill directory
/OPSvdd doctor          # from a Claude Code session
```

### Uninstall

```bash
./install.sh --uninstall
```

Removes every install-time artefact with zero orphans. Idempotent.

---

## Phase roadmap

| Phase | Jira | Scope |
|-------|------|-------|
| **0 — shipping in v1.0.0** | CPT-87 | Skill structure, per-skill installer, router, `help`/`doctor`/`version`/`update`, empty `references/` tree with placeholders, bats coverage of scaffolding |
| 1 | CPT-87.1 (to file) | Tier framework (8 materiality + 4 criticality questions → rule table), `assess` Step 1 + Step 2, `references/tiering/mas-materiality-test.md`, slug-mandatory guard |
| 2 | CPT-87.2 (to file) | Steps 3–9, OPS publication, yearly Epic auto-creation, `Vendor Review Status` custom-field schema, `duplicate` subcommand |
| 3 | CPT-87.3 (to file) | `approval` subcommand, override gate (50-byte reason, 8-unique tokens, 10-string blocklist, SHA-256 artefact hash, `⚠️ OVERRIDE:` label/banner), APRVL parent + 2 sub-tasks, dry-run mode |

All domain ACs (AC-5, 6, 7.1–7.12, 8, 9, 10, 11, 13, 14, 15, 17) are deferred to their respective phases. Phase 0 covers AC-1, 2, 3, 4, 12, 16. AC-0 (Vendor Review Status custom field) is a human Jira-admin prerequisite that gates Phase 2, not Phase 0.

---

## Architecture

### Skill layout

```
skills/OPSvdd/
├── SKILL.md              Router + phase roadmap + tier framework reference
├── CHANGELOG.md          Per-version entries
├── README.md             This file
├── install.sh            Per-skill installer (matches rr pattern)
├── commands/             Colon-subcommand source (help, doctor, version, update; + assess/approval/duplicate stubs)
└── references/           Deployed to ~/.claude/skills/OPSvdd/references/
    ├── jurisdictions/    sg active; hk/jp/uae stubs
    ├── regulatory/       Per-jurisdiction MAS/PDPA content (populated in Phase 2)
    ├── tiering/          Deterministic tier questionnaire (Phase 1)
    ├── schemas/          JSON Schemas for each workflow step (Phase 2)
    └── workflow/         Step-by-step instructions 1–9 (Phases 1+2)
```

### 9-step workflow (Phase 2)

| Step | Action |
|------|--------|
| 1 | Vendor intake (legal name, scope, business owner) |
| 2 | Tier determination (deterministic rule table) |
| 3 | Document collection (per-tier requirements) |
| 4 | Entity / regulatory check (ACRA UEN, ownership, licences, sanctions, adverse media) |
| 5 | Financial / operational assessment |
| 6 | Security / BCP / sub-outsourcing |
| 7 | Adversarial review |
| 8 | User discussion gate (hybrid-D) |
| 9 | Finalise + user confirmation + publish to OPS |

### Tier framework

| Tier | Materiality | Criticality | APRVL required |
|------|-------------|-------------|----------------|
| 1 | Material | Critical | Yes (2-stage) |
| 2 | Material | Not critical | Yes (2-stage) |
| 3 | Non-material | (any) | No |
| 4 | Commodity | (any) | No |

Tier is rule-based (BATS-testable), never LLM-judged. Every question-and-answer is recorded in `02_tier.json` for audit.

### Override audit contract (Phase 3)

Mirrors `/LEGtc` AC-7 verbatim:

- **Trigger**: literal case-sensitive `Override` — no synonyms
- **Reason validation**: ≥50 UTF-8 bytes trimmed, ≥8 unique alphanumeric tokens, not one of the 10 blocklisted strings (`approved`, `ok`, `proceed`, `go ahead`, `n/a`, `none`, `see above`, `trust me`, `override`, `no reason`)
- **Artefact hash** (reproducible):
  ```bash
  jq -S -c 'del(.content_hash) | del(.aprvl_parent_key)' <artefact> | shasum -a 256 | cut -d' ' -f1
  ```
- **Artefact keys** (alphabetical): `aprvl_parent_key`, `content_hash`, `ops_ticket`, `override_reason`, `timestamp_utc`, `unresolved_gaps`, `user`, `vendor_slug`
- **Posted to**: both OPS and APRVL parent, inside a fenced `json` code block
- **Label**: `override-applied` on the APRVL parent
- **Summary prefix**: `⚠️ OVERRIDE:` on the APRVL parent
- **Banner**: `**OVERRIDE INVOKED**` with reason, user, UTC timestamp, `content_hash`
- **Immutability**: skill never edits or deletes the artefact; tamper detection via (a) SHA-256 in artefact, (b) Jira comment edit-history, (c) hash embedded in APRVL banner, (d) Jira description edit-history.

---

## Regulatory reference

`/OPSvdd` is authored against:

- **MAS Guidelines on Outsourcing** (2018 reissue) — materiality test, outsourcing register, notification requirements
- **MAS Notice SFA 04-N10** — Technology Risk Management
- **MAS Notice 634** — notification of material outsourcing arrangements
- **MAS Business Continuity Management Guidelines** — BCP test evidence
- **PDPA Part VIA** — data processor obligations and transfers
- **MAS Guidelines on Cyber Hygiene** — vendor security baseline

Regulatory content is authored into `references/regulatory/sg/<instrument>.md` in Phase 2. Phase 0 ships the directory skeleton only.

---

## Dependencies

- **OPS custom field** — `Vendor Review Status` (textarea, OPS Task scope) MUST exist before Phase 2 install. AC-0 prerequisite. Human Jira-admin step. Field creation is not possible via MCP. Doctor in Phase 2+ probes and FAILs if missing.
- **APRVL project access** — read/write. Needed for Phase 3.
- **OPS project access** — read/write. Needed for Phase 2.

---

## License & audit trail

This skill is internal to Chocolate Finance. All override artefacts are audit-grade artefacts produced for MAS inspection support; they are written once and never modified. Reviewers can reproduce `content_hash` locally with the one-liner above.
