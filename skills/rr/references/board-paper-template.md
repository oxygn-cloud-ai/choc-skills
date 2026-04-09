# Board Risk Oversight Paper — Template

This template defines the structure, content, tone, and formatting rules for the quarterly Board Risk Oversight Paper. The agent follows this template exactly, populating data from `board-statistics.json` and generating narrative from reference files.

## Formatting Rules

- **Markdown throughout** — renders in Jira ADF
- **Blockquotes** (`>`) for formal resolutions
- **Tables** for all quantitative data
- **Bold** for risk ratings and statuses
- **British English** exclusively
- **Formal board-paper tone** — concise, evidence-based, no conversational language
- **No emojis** — this is a formal regulatory document
- All statistics MUST come from `board-statistics.json` — do not recompute
- All business assertions MUST be grounded in `business-context.md`
- All regulatory references MUST be from `regulatory-framework.md`

## Data Inputs

The agent reads these files before generating:

1. `board-statistics.json` — aggregated statistics (from rr-board-aggregate.py)
2. `~/.claude/skills/rr/references/business-context.md` — firm facts
3. `~/.claude/skills/rr/references/regulatory-framework.md` — regulatory instruments
4. `~/.claude/skills/rr/references/quality-standards.md` — assessment methodology
5. Individual assessment files for Critical/High residual risks (from `critical_high_residual_risks[]` in statistics)

---

## Section Structure

### Section 0: Document Control

A table with:
- Document Reference: `BRD-RISK-[YYYY]-[QN]-001`
- Classification: `BOARD CONFIDENTIAL`
- Prepared by: `Chief Risk Officer, Chocolate Finance Pte. Ltd.`
- Reviewed by: `Head of Compliance; Chief Operating Officer`
- Board Meeting Date: 14 days from paper date
- Paper Deadline: today's date
- Version: `1.0 — Final`
- Distribution: `Board of Directors; Company Secretary; External Auditor (for information)`
- Regulatory Nexus: `MAS Guidelines on Risk Management Practices (MAS 649); SFC Management, Supervision and Internal Control Guidelines (GL-6)`

### Section 1: Purpose and Requested Board Resolutions

**1.1 Purpose** — 2-3 sentences stating the paper's objective and regulatory basis.

**1.2 Requested Resolutions** — Four blockquoted resolutions:

> **Resolution 1 — NOTE**
> Board NOTES the Q[N] review outcomes, citing: number of Critical/High residual risks, control uncertainty percentage.

> **Resolution 2 — APPROVE**
> Board APPROVES the risk appetite alignment assessment, acknowledging any breaches and management remediation timelines.

> **Resolution 3 — DIRECT**
> Board DIRECTS management on specific actions derived from the Critical/High risk analysis. Typically 3-5 concrete directions with deadlines.

> **Resolution 4 — ACCEPT**
> Board ACCEPTS the next quarter's Risk Management Plan.

**Content source:** Derived from `critical_high_residual_risks[]` and `control_analysis` in statistics.

### Section 2: Executive Summary

- **Overall Risk Posture** statement (one line: ELEVATED / STABLE / IMPROVING / DETERIORATING)
- 2-3 paragraph narrative summarising key findings
- **Key metrics table**: total risks, Critical/High inherent and residual counts, controls Uncertain %, appetite breaches
- **Five matters requiring Board attention** — numbered list, each 2-3 sentences linking to specific risk IDs

**Content source:** `metadata`, `rating_distributions`, `control_analysis`, `critical_high_residual_risks[]`

### Section 3: Risk Register Overview

**3.1 Distribution by Category** — table from `categories` in statistics:

| Category | Code | Risks | Critical (R) | High (R) | Medium (R) | Low (R) |

Sorted by risk count descending.

**3.2 Residual Risk Heatmap** — 3x3 table from `heatmaps.residual`:

| | Low Impact | Medium Impact | High Impact |
|--|-----------|---------------|-------------|
| High Likelihood | | | |
| Medium Likelihood | | | |
| Low Likelihood | | | |

Cell contents: count, plus specific risk IDs for Critical/High cells.

**Content source:** `categories`, `heatmaps`

### Section 4: Critical and High Residual Risks — Detailed Analysis

One sub-section per risk from `critical_high_residual_risks[]`, split into:

**4.1 Critical Residual Risks**
**4.2 High Residual Risks**

Each risk rendered as a table:

| Attribute | Detail |
|-----------|--------|
| Category | [code] ([name]) |
| Inherent Rating | [rating] (Likelihood: [L]; Impact: [I]) |
| Residual Rating | **[rating]** (Likelihood: [L]; Impact: [I]) |
| Risk Owner | [suggested_owner from top recommendation] |
| Description | [risk_statement or narrative] |
| Current Controls | Numbered list from controls[] |
| Control Effectiveness | [effectiveness summary with rationale] |
| Risk Appetite Position | [Within appetite / Near-breach / **BREACHED**] |
| Management Action Plan | Numbered list from recommendations[] with deadlines |
| Target Residual Rating | [target, derived from recommendations] |
| Board Attention | [Required / For noting] |

**Content source:** `critical_high_residual_risks[]` — use the full details including controls, recommendations, narratives.

### Section 5: Control Effectiveness Assessment

**5.1 Aggregate table** from `control_analysis`:

| Rating | Count | % |
|--------|-------|---|
| Effective | N | X% |
| Partially Effective | N | X% |
| Uncertain | N | X% |
| Ineffective | N | X% |

**5.2 Analysis** — 3-4 paragraphs explaining:
- The concentration of Uncertain ratings and its cause
- Regulatory risk from undocumented controls
- Board assurance gap
- Recommended phased documentation programme with deadlines

**Content source:** `control_analysis`

### Section 6: Risk Appetite Alignment

Map Critical/High residual risks against Board risk appetite statements. The agent should infer reasonable appetite statements from the risk profile:

- Zero tolerance for material regulatory breaches
- No single point of failure in regulatory-facing functions
- BCP tested annually
- New products reviewed through documented compliance process
- Succession plans documented for critical roles

Present as table:

| # | Appetite Statement | Status | Relevant Risk(s) |

Status values: **BREACHED** / Near-breach / Within appetite

**Content source:** `critical_high_residual_risks[]` + LLM synthesis

### Section 7: Thematic Analysis — Multi-Jurisdictional Expansion

- Identify all risks in categories ER (Expansion Risk) plus any Critical/High risks amplified by expansion
- Present as a table of expansion-related risks
- Cumulative exposure assessment (narrative)
- Recommendation for dedicated governance workstream

**Content source:** `categories.ER`, `critical_high_residual_risks[]` where expansion is mentioned

### Section 8: Incidents and Lessons Learnt

- Miles programme incident (Q1 2025) — from business-context.md
- Remediation status table (actions, status, due dates)
- Other material events in the quarter

**Content source:** `business-context.md`

### Section 9: Emerging and Horizon Risks

5-7 emerging risks NOT in the register, presented as table:

| # | Emerging Risk | Horizon | Potential Impact | Recommended Action |

Sources: regulatory pipeline from `regulatory-framework.md`, macroeconomic, technology, geopolitical factors.

**Content source:** `regulatory-framework.md` + LLM forward-looking analysis

### Section 10: Q2 Risk Management Plan

Prioritised deliverables table:

| Priority | Deliverable | Owner | Deadline | Resolution Link |

Typically 10-15 items derived from:
- Resolution 3 directions
- Top recommendations from `recommendation_analysis.top_20`
- Overdue remediation items from Section 8
- Register maintenance activities

**Content source:** `recommendation_analysis.top_20` + Sections 1, 4, 8

### Appendix A: Full Risk Register Summary

Table of ALL risks from `all_risks_summary[]`:

| # | Key | Category | Risk Name | Inherent | Residual | Recs |

Sorted by residual rating (Critical first), then category, then key.

### Appendix B: Rating Methodology

Static content:
- Rating matrix (3x3)
- Likelihood definitions (Low, Medium, High)
- Impact definitions
- Control effectiveness definitions
- Assessment process description (3-iteration adversarial review)

### Appendix C: Regulatory Framework Cross-Reference

Table from `regulatory-framework.md`:

| Jurisdiction | Regulator | Key Frameworks | Applicable Entity |

### Appendix D: Glossary

Standard abbreviations: AUM, BCP, CRO, MAS, SFC, SFO, VARA, JFSA, etc.
