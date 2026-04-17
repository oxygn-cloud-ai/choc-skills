---
name: OPSvdd
version: 1.0.0
description: "MAS-aligned Vendor Due Diligence for Chocolate Finance. 9-step workflow, 4-tier materiality × criticality framework, OPS publication, APRVL sign-off for Tier 1/2, audit-grade override mirroring LEGtc. Phase 0 (scaffolding only) — /OPSvdd assess lands in 87.1+."
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(bash *), Bash(shasum *), Bash(cat *), Bash(ls *), Bash(grep *), Bash(sed *), Bash(awk *), Bash(mkdir *), Bash(basename *), Bash(dirname *), Bash(test *), Bash(which *), Bash(head *), Bash(tail *), Bash(wc *), Skill
argument-hint: [assess <vendor-slug> | approval <OPS-key> | duplicate <vendor-slug> | help | doctor | version | update]
---

# OPSvdd — MAS-aligned Vendor Due Diligence

`/OPSvdd` performs structured 9-step vendor due diligence assessments for Chocolate Finance, aligned with MAS Guidelines on Outsourcing, Notice SFA 04-N10, Technology Risk Management Guidelines, Business Continuity Management Guidelines, and PDPA. Material outsourcing (Tier 1/2) triggers APRVL sign-off with audit-grade override mechanism mirroring `/LEGtc`.

> **Phase 0 (v1.0.0) ships scaffolding only.** Domain subcommands (`assess`, `approval`, `duplicate`) return a `not yet implemented — see CPT-87.1 / 87.2 / 87.3` message. Structure, installer, router, doctor, version, help, and update are fully functional.

## Pre-flight Checks

Before executing, silently verify:

1. **Reference tree installed**: `test -d ~/.claude/skills/OPSvdd/references`. If missing:
   > **OPSvdd error**: Reference files not found at `~/.claude/skills/OPSvdd/references/`. Run `/OPSvdd:doctor` to diagnose.

2. **Sub-commands installed**: `ls ~/.claude/commands/OPSvdd/*.md` finds at least the four Phase 0 files (`help.md`, `doctor.md`, `version.md`, `update.md`). If not:
   > **OPSvdd warning**: Sub-command files not found in `~/.claude/commands/OPSvdd/`. Re-run `cd <repo>/skills/OPSvdd && ./install.sh --force`.

---

## Routing

Parse `$ARGUMENTS` and route to the matching colon-command. If the target `.md` file exists in `~/.claude/commands/OPSvdd/`, invoke it via the Skill tool. Otherwise, fall through to `/OPSvdd:help`.

| Argument | Action |
|----------|--------|
| (empty) | Invoke `/OPSvdd:help` |
| `help`, `--help`, `-h` | Invoke `/OPSvdd:help` |
| `doctor`, `--doctor`, `check` | Invoke `/OPSvdd:doctor` |
| `version`, `--version`, `-v` | Invoke `/OPSvdd:version` |
| `update`, `--update`, `upgrade` | Invoke `/OPSvdd:update` |
| `assess <vendor-slug> [...]` | Invoke `/OPSvdd:assess` (Phase 1 — CPT-87.1/87.2; returns `not yet implemented` in v1.0.0) |
| `approval <OPS-KEY>` | Invoke `/OPSvdd:approval` (Phase 3 — CPT-87.3; returns `not yet implemented` in v1.0.0) |
| `duplicate <vendor-slug>` | Invoke `/OPSvdd:duplicate` (Phase 2 — CPT-87.2; returns `not yet implemented` in v1.0.0) |
| anything else | Invoke `/OPSvdd:help` |

### Missing vendor slug on `assess`

If the user types `/OPSvdd assess` with no trailing slug, the assess command is responsible for erroring with:

```
Vendor slug required. Usage: /OPSvdd assess <vendor-slug> [--input <path>]. Slug is kebab-case, stable across re-reviews (e.g. "havenport", "adansonia-vcc").
```

(Phase 0 `assess.md` is a stub; the slug-missing error becomes load-bearing in Phase 1.)

---

## Configuration

| Environment Variable | Default | Purpose |
|---------------------|---------|---------|
| `OPSVDD_OUTPUT_DIR` | `~/opsvdd-output` | Assessment artefact directory (per-vendor subdir) |
| `JIRA_EMAIL` | (none) | Required for `:approval` Jira operations if MCP unavailable |
| `JIRA_API_KEY` | (none) | Required for `:approval` Jira operations if MCP unavailable |

---

## Tier Framework (MAS-aligned)

| Tier | Materiality | Criticality | Example | DD depth | APRVL required |
|------|-------------|-------------|---------|----------|----------------|
| 1 | Material | Critical | Custodian, core banking, KYC | Full 9 steps | Yes (2-stage) |
| 2 | Material | Not critical | Licensed data provider | Full 9 steps | Yes (2-stage) |
| 3 | Non-material | (any) | SaaS tooling, analytics | Abbreviated (steps 1–4, 7–9; 5/6 light-touch) | No |
| 4 | Commodity | (any) | Office services, stock photos | Entity check only (step 1, 4, 9) | No |

Determination is rule-based (deterministic) — 8 materiality questions + 4 criticality questions. See `references/tiering/mas-materiality-test.md` (Phase 1, CPT-87.1).

---

## 9-step workflow (Phase 2, CPT-87.2)

| Step | Action | Output |
|------|--------|--------|
| 1 | Vendor intake | `01_intake.json` |
| 2 | Tier determination | `02_tier.json` |
| 3 | Document collection | `03_documents.json` |
| 4 | Entity / regulatory check | `04_entity.json` |
| 5 | Financial / operational assessment | `05_financial_ops.json` |
| 6 | Security / BCP / sub-outsourcing | `06_security_bcp.json` |
| 7 | Adversarial review | `07_adversarial.json` |
| 8 | User discussion gate (hybrid-D) | `08_discussion.json` |
| 9 | Finalise + user confirmation + publish to OPS | `final_report.md` + OPS ticket |

---

## Jira quick reference

| Field | Value |
|-------|-------|
| OPS Project | OPS |
| APRVL Project | APRVL |
| Cloud ID | `81a55da4-28c8-4a49-8a47-03a98a73f152` |
| Parent Epic pattern | `Vendor Due Diligence <current-year>` (auto-created if absent at Step 9 publish) |
| Custom field (load-bearing) | `Vendor Review Status` (textarea, OPS Task scope) — MUST exist before install per AC-0 |

---

## Override audit mechanism (Phase 3 — CPT-87.3)

Mirrors `/LEGtc` AC-7 verbatim (once LEGtc ships):

- Literal `Override` trigger (case-sensitive)
- Deterministic reason validation — ≥50 UTF-8 bytes, ≥8 unique alphanumeric tokens, 10-string blocklist
- SHA-256 content hash via `jq -S -c 'del(.content_hash) | del(.aprvl_parent_key)' <artefact> | shasum -a 256 | cut -d' ' -f1`
- Artefact posted verbatim to OPS + APRVL parent, `override-applied` label, `⚠️ OVERRIDE:` summary prefix, banner in APRVL description
- Skill never edits post-hoc; tamper-detection via SHA-256 + Jira edit-history

Phase 3 bats tests cover blocklist enforcement, length/token boundary, hash stability, canonicalization idempotence, label/banner application, artefact immutability.

---

## MAS Notice 634 warning

When `tier == 1` OR (`tier == 2` AND `material == true`), every output includes:

```
⚠️ MATERIAL OUTSOURCING — MAS Notice 634 notification may be required. This skill does not file with MAS; confirm with Compliance.
```

Skill detects and warns; humans file via the MAS portal.

---

## Phase roadmap

| Phase | Jira | Delivers |
|-------|------|----------|
| **0 (this release)** | CPT-87 | Scaffolding, installer, router, help/doctor/version/update, empty references tree |
| 1 | CPT-87.1 (to be filed) | Tier framework, `assess` Step 1 + Step 2, deterministic tier questionnaire, `references/tiering/mas-materiality-test.md`, slug-mandatory guard |
| 2 | CPT-87.2 (to be filed) | Steps 3–9, OPS publication, yearly Epic auto-creation, Vendor Review Status schema, `duplicate` subcommand |
| 3 | CPT-87.3 (to be filed) | `approval` subcommand, override gate + validation + hash + artefact + label + banner, APRVL parent + sub-tasks, dry-run mode |

---

## Fallback Behaviour

This file is only reached when Claude self-invokes the skill without a matching subcommand argument. In that case, invoke `/OPSvdd:help` via the Skill tool and stop. Do not attempt to infer intent or execute any destructive action. All operational subcommands live as explicit command files under `~/.claude/commands/OPSvdd/` and are routed by `~/.claude/commands/OPSvdd.md`.
