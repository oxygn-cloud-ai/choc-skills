# OPSvdd:help — Usage Guide

First, read the `version:` field from `~/.claude/skills/OPSvdd/SKILL.md` frontmatter to get the current version number.

Display the following and stop. Do not proceed to any other action. Replace `{version}` with the actual version read above.

```
OPSvdd v{version} — MAS-aligned Vendor Due Diligence

USAGE
  /OPSvdd assess <vendor-slug>       Run 9-step vendor DD assessment (Phase 1+2 — stub in v1.0.0)
  /OPSvdd approval <OPS-KEY>         Create APRVL package for Tier 1/2 vendor (Phase 3 — stub in v1.0.0)
  /OPSvdd duplicate <vendor-slug>    Force new OPS ticket even if same-day exists (Phase 2 — stub in v1.0.0)
  /OPSvdd help                       Display this usage guide
  /OPSvdd doctor                     Check environment health
  /OPSvdd version                    Show installed version
  /OPSvdd update                     Update skill to latest version

PHASE 0 STATUS (v1.0.0 — CPT-87)
  Scaffolding only. The structural commands (help, doctor, version, update) and
  installer are fully functional. Domain subcommands (assess, approval, duplicate)
  emit a "not yet implemented" message and exit until their respective phases land:

    * Phase 1 (CPT-87.1): tier framework + assess Step 1/2
    * Phase 2 (CPT-87.2): full workflow + OPS publication + duplicate
    * Phase 3 (CPT-87.3): APRVL integration + override audit

TIER FRAMEWORK
  Tier 1  Material + Critical           Full 9 steps + APRVL required (2-stage)
  Tier 2  Material + Not critical        Full 9 steps + APRVL required (2-stage)
  Tier 3  Non-material                   Abbreviated (steps 1-4, 7-9; 5/6 light)
  Tier 4  Commodity                      Entity check only (steps 1, 4, 9)

ENVIRONMENT VARIABLES
  OPSVDD_OUTPUT_DIR    Assessment output directory (default: ~/opsvdd-output)
  JIRA_EMAIL           Required for :approval if MCP unavailable
  JIRA_API_KEY         Required for :approval if MCP unavailable

JIRA QUICK REFERENCE
  Cloud ID       81a55da4-28c8-4a49-8a47-03a98a73f152
  OPS project    Vendor assessment Tasks
  APRVL project  Sign-off parent + sub-tasks (Tier 1/2 only)
  Parent Epic    Vendor Due Diligence <current-year> (auto-created Phase 2+)
  Custom field   Vendor Review Status (textarea; must exist before Phase 2 install)

MAS ALIGNMENT
  MAS Guidelines on Outsourcing, MAS Notice SFA 04-N10, Notice 634, TRM, BCM, PDPA.
  Tier 1 outsourcing MAY require MAS Notice 634 notification — skill warns, does not file.

DOCS
  cat ~/.claude/skills/OPSvdd/SKILL.md       Full routing spec + phase roadmap
  ~/.claude/skills/OPSvdd/references/        Reference tree (populated in Phase 1+2)
```
