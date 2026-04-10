# Design Spec: `/ra` — Bespoke Risk Assessment Skill

## Purpose

A conversational risk assessment tool for Chocolate Finance that interviews the user to understand a bespoke subject (legal document, initiative plan, concept, incident), gathers supporting materials from any source, produces a structured risk assessment with adversarial self-review, and publishes results to Jira project `RA`.

Unlike `/rr` which assesses existing risk register entries (Jira RR-NNN tickets), `/ra` assesses anything — a contract, a strategic plan, a regulatory change, a vendor proposal. The assessment is interview-driven, not ticket-driven.

---

## Assessment Types

| Type | Examples |
|------|----------|
| Document review | Contract, T&Cs, policy, legal opinion, regulatory guidance |
| Planned change | New initiative, product launch, process change, market entry |
| Issue / incident | Emerging risk, near-miss, reported problem, audit finding |
| Concept | Strategic idea, partnership evaluation, technology adoption |

The type is determined during the interview phase and recorded in the subject identity model.

---

## Workflow

### Phase 1: Interview

Adaptive conversation to understand the subject.

1. **Scope determination** — What is being assessed? What type? Why now?
2. **Detailed repeat-back** — Ra restates its understanding in detail. User corrects/refines.
3. **Iterate** — Continue until user explicitly confirms understanding.
4. **Scope statement** — Produce explicit "this assessment covers X and does NOT cover Y".
5. **Material gathering** — Request supporting documents, links, references.

**Accepted input sources:**
- Local files (PDF, DOCX, MD, TXT)
- Pasted text
- URLs (web pages)
- Jira tickets (via Atlassian MCP)
- Confluence pages (via Atlassian MCP)
- Slack message links (via Slack MCP)

**Output:** `01_interview.json` — full structured record of the interview.

### Phase 2: Ingest

Read and normalise all provided materials.

1. **Fetch** — Retrieve each source using appropriate tool (Read, WebFetch, Atlassian MCP, Slack MCP).
2. **Normalise** — Extract text content. Record format, length, extraction method.
3. **Provenance** — For each source record: `source_type`, `locator`, `retrieved_at`, `normalisation_method`, `excerpt_or_hash`, `access_limitations`, `reliability` (high/medium/low/unknown).
4. **Brief** — Synthesise a comprehensive subject brief from all materials.

**Output:** `02_ingest.json` — all ingested content with full source provenance.

### Phase 3: Assess

Produce the risk assessment.

For each identified risk:

1. **Categorise** — Assign one of the 12 risk categories (A, B, C, D, ER, F, I, L, O, OO, P, T).
2. **Epistemic classification** — Classify evidence as `fact`, `user_claim`, `assumption`, or `unknown`. Each finding must cite which it relies on.
3. **Rate inherent risk** — Likelihood × Impact using the standard rating matrix.
4. **Recommend mitigations** — For each: title, priority, owner_role, implementation_steps, implementation_assumptions, expected_effect, confidence (high/medium/low).
5. **Project residual risk** — What the residual risk WOULD BE if mitigations are adopted. Include confidence level (high/medium/low) in the projection.
6. **Adversarial self-review** — Challenge the assessment against 11 criteria:
   - rr's 8: unsupported_claim, speculative_assertion, outdated_reference, missing_evidence, unbounded_scope, rating_not_justified, control_assumed, regulatory_imprecision
   - 3 new: assumption_not_validated, scope_gap, stakeholder_not_consulted
7. **Rectify** — Address each challenge. Adjust ratings, add caveats, or justify with evidence.

**Output:** `03_assessment.json` — full assessment with all risks, ratings, adversarial challenges, and rectifications.

### Phase 4: Discuss

Present findings to the user for review.

1. **Walk through** each identified risk with the user.
2. **Accept challenges** — User may dispute ratings, add context, identify missing risks.
3. **Handle unresolved items** — If user cannot answer, record as `deferred` with reason.
4. **Out-of-scope / insufficient evidence** — Explicitly flag areas where evidence was insufficient.
5. **Finalise** — Incorporate all adjustments. Produce final assessment.

**Output:** `04_discussion.json` — structured record of discussion, adjustments, and deferred items.

### Phase 5: Output

1. **Write final** — `assessment_final.json` consolidating all phases.
2. **User review** — Present summary. User confirms or requests further changes.
3. **Publish** — Separate step via `/ra:publish`. Supports `--dry-run` for preview.

---

## Schema Family

New schema family for ra. Shares enums with rr (likelihood, impact, rating matrix, risk categories) but owns its structure.

### Shared Enums (duplicated from rr for v1)

- `likelihood`: Almost Certain, Likely, Possible, Unlikely, Rare
- `impact`: Catastrophic, Major, Moderate, Minor, Insignificant
- `risk_rating`: Critical, High, Medium, Low (derived from L×I matrix)
- `risk_category`: A, B, C, D, ER, F, I, L, O, OO, P, T

### New Schemas

| Schema | Purpose |
|--------|---------|
| `subject.schema.json` | Subject identity: id, type, description, scope, out_of_scope, assessment_question, version |
| `interview.schema.json` | Structured interview record: rounds[], confirmed_scope, source_requests[] |
| `ingest.schema.json` | Source materials with provenance: sources[], subject_brief |
| `assessment.schema.json` | Assessment: findings[], each with epistemic_basis, inherent_risk, recommended_mitigations[], projected_residual_risk (with confidence), adversarial_challenges[], rectifications[] |
| `discussion.schema.json` | Discussion record: turns[], adjustments[], deferred_items[], out_of_scope[], insufficient_evidence[] |
| `jira-publication.schema.json` | Publication receipt: epic_key, finding_keys[], mitigation_keys[], attachments[] |

### Key Schema Differences from rr

| Aspect | rr | ra |
|--------|----|----|
| Identity | `ticket_key: RR-\d+` | `subject_id` (slug), `subject_type`, `assessment_scope` |
| Controls | `existing_controls[]` (observed) | `recommended_mitigations[]` (projected) |
| Residual risk | Actual (post-controls) | Projected (with confidence level) |
| Evidence model | `evidences.data_sources[]` | Epistemic: `facts[]`, `user_claims[]`, `assumptions[]`, `unknowns[]` |
| Adversarial | 8 challenge types | 11 challenge types (+3 bespoke) |
| Provenance | Jira ticket is the source | Multi-source with per-source provenance |

---

## Jira Integration

### Project: RA (Risk Assessments)

**Three-level hierarchy:**

| Level | Jira Type | Content |
|-------|-----------|---------|
| Assessment | Epic | Subject summary, scope, date, overall risk profile |
| Finding | Task | Individual risk: category, inherent rating, projected residual, rationale, epistemic basis |
| Recommended Mitigation | Sub-task | Title, priority, owner, implementation steps, assumptions, expected effect, confidence |

**Configuration:** Requires `references/jira-config.md` defining:
- Project key: RA
- Cloud ID
- Issue type IDs for Epic, Task, Sub-task
- Default assignee
- Labels convention
- Custom fields (if any)
- Idempotency rules (how to detect duplicate assessments)
- Required fields per issue type

**Attachments:** All 6 JSON files (01_interview through jira_publication) attached to the Assessment Epic on publish.

**Publish flow:**
1. `--dry-run` — Preview what will be created (Epic + N Tasks + M Sub-tasks)
2. Create Assessment Epic
3. For each finding: create Task linked to Epic
4. For each mitigation: create Sub-task under its Finding Task
5. Attach all JSON files to Epic
6. Write `jira_publication.json` receipt locally

---

## Sub-commands

| Command | Purpose | Key flags |
|---------|---------|-----------|
| `/ra:assess` | Full interactive assessment flow (phases 1–5) | None |
| `/ra:publish` | Push saved assessment to Jira RA project | `--dry-run` |
| `/ra:status` | List recent assessments, check publish state | None |
| `/ra:update` | Update skill to latest version | None |
| `/ra:help` | Usage guide | None |
| `/ra:doctor` | Environment health check | None |
| `/ra:version` | Show version | None |

All sub-commands are colon commands with their own command file and frontmatter.

---

## Local Storage

```
~/ra-output/
└── <YYYY-MM-DD>_<subject-slug>/
    ├── 01_interview.json
    ├── 02_ingest.json
    ├── 03_assessment.json
    ├── 04_discussion.json
    ├── assessment_final.json
    └── jira_publication.json    # Created by /ra:publish
```

Environment variable: `RA_OUTPUT_DIR` (default: `~/ra-output`).

---

## Pre-flight Checks

1. Reference files readable at `~/.claude/skills/ra/references/schemas/`
2. Sub-commands installed at `~/.claude/commands/ra/`
3. Jira credentials available (`JIRA_EMAIL`, `JIRA_API_KEY`) — required for publish only
4. Atlassian MCP connected — required for Jira/Confluence source ingestion

---

## Doctor Checks

1. Required tools: curl, jq
2. Environment variables: `JIRA_EMAIL`, `JIRA_API_KEY` (status only)
3. Reference files present (schemas, jira-config, quality-standards)
4. Sub-commands installed (7 files)
5. Output directory writable
6. Atlassian MCP connectivity
7. Slack MCP connectivity (non-blocking WARN)

---

## File Structure in Repo

```
skills/ra/
├── SKILL.md                  # Frontmatter + routing
├── CHANGELOG.md
├── README.md
├── install.sh                # Per-skill installer
├── commands/
│   ├── assess.md
│   ├── publish.md
│   ├── status.md
│   ├── update.md
│   ├── help.md
│   ├── doctor.md
│   └── version.md
└── references/
    ├── schemas/
    │   ├── enums.schema.json
    │   ├── subject.schema.json
    │   ├── interview.schema.json
    │   ├── ingest.schema.json
    │   ├── assessment.schema.json
    │   ├── discussion.schema.json
    │   └── jira-publication.schema.json
    ├── jira-config.md
    ├── quality-standards.md
    └── business-context.md       # Shared with rr (symlink or copy)
```

---

## Quality Standards

Inherit from rr's quality-standards.md with adaptations:
- All assertions must be grounded in ingested source material or explicitly classified as assumptions
- Regulatory references must be verified via web search
- British English throughout
- Schema compliance enforced for all JSON outputs
- No fabricated evidence or sources
- Epistemic classification mandatory for every finding
- Confidence level mandatory for every projected residual risk rating
- Out-of-scope boundaries must be explicit

---

## v1 Scope Boundaries

**In scope:**
- Single interactive assessment flow
- All input sources (files, text, URLs, Jira, Confluence, Slack)
- Full schema family with validation
- Jira publication with dry-run
- Adversarial self-review (11 criteria)
- Source provenance tracking
- Epistemic classification

**Out of scope (future):**
- Batch mode (assess multiple subjects)
- Assessment templates (pre-configured scopes for common assessment types)
- Periodic reassessment scheduling
- Cross-referencing with rr risk register
- Shared enum extraction to common location between rr and ra
