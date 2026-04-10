# Quality Standards

Rules, constraints, and operational requirements for all risk assessments.

---

## Mandatory Requirements

1. **Grounded assertions.** Every assertion about Chocolate Finance's business must be grounded in confirmed facts (from business-context.md, ingested materials, web search, or user-provided information). Do not fabricate internal details.

2. **Verified regulatory citations.** Every regulatory reference must cite the correct instrument title and date. If uncertain, search the web to verify before including.

3. **Explicit uncertainty.** Where internal controls cannot be confirmed, state this explicitly. Do not infer effectiveness without evidence.

4. **Epistemic classification mandatory.** Every finding must classify each assertion as `fact`, `user_claim`, `assumption`, or `unknown`. No finding may omit this classification.

5. **Confidence levels mandatory.** Every projected residual risk must include a confidence level (`high`, `medium`, or `low`) with justification.

6. **British English.** Use British English exclusively.

7. **Schema compliance.** All JSON outputs must validate against their respective schemas. Non-conforming values for enum fields must be rejected.

---

## Prohibited Actions

1. **Do not fabricate** regulatory citations, enforcement actions, or penalties.

2. **Do not use a risk rating** that does not follow the matrix defined below.

3. **Do not proceed past Step 5** (Discuss with User) without user confirmation of findings.

4. **Do not assign Jira tickets** unless explicitly instructed by the user.

5. **Do not invent** internal controls, policies, or procedures that have not been evidenced.

6. **Do not silently duplicate** assessments — always check for existing assessments on the same subject before creating.

---

## Risk Rating Matrix

| | **Low Impact** | **Medium Impact** | **High Impact** |
|---|---|---|---|
| **High Likelihood** | Medium | High | Critical |
| **Medium Likelihood** | Low | Medium | High |
| **Low Likelihood** | Low | Low | Medium |

Use this matrix consistently. Do not introduce alternative rating scales.

**Validation rule:** If `inherent_risk.rating` or `projected_residual_risk.rating` does not match the matrix derivation from the stated likelihood and impact, the assessment is invalid.

---

## Epistemic Classification Rules

Every assertion within a finding must be classified using one of four categories:

| Classification | Requirements |
|----------------|-------------|
| **fact** | Must cite a `source_id` from the ingested materials. Verifiable from the source. |
| **user_claim** | Must note when claimed and by whom. Not independently verified. |
| **assumption** | Must include rationale for why this assumption is reasonable. |
| **unknown** | Must describe what is unknown and the impact of this gap on the assessment. |

**Rules:**
- A finding with only `assumption` and `unknown` classifications must have its confidence level set to `low`
- Facts take precedence — if a source confirms an assertion, classify as `fact` even if the user also claimed it
- When an assumption can be verified, note this in the mitigation recommendations

---

## Projected Residual Risk Rules

Projected residual risk represents what the risk level WOULD BE if recommended mitigations were fully adopted.

1. Must include a confidence level: `high`, `medium`, or `low`
2. Confidence must be justified with rationale
3. If confidence is `low`, caveats must note this prominently and explain why
4. Impact typically does not reduce through mitigations — likelihood reduction is the primary mechanism
5. Where mitigations are speculative or untested, confidence must not be `high`

---

## Evidence Standards

### Source Types

| Type | Description |
|------|-------------|
| `local_file` | File read from the local filesystem |
| `pasted_text` | Text pasted directly by the user |
| `url` | Content retrieved from a URL |
| `jira_ticket` | Information from a Jira ticket |
| `confluence_page` | Information from a Confluence page |
| `slack_message` | Information from a Slack message |
| `skill_context` | Information from business-context.md |

### Required Fields

| Field | Required |
|-------|----------|
| source_id | Yes |
| source_type | Yes |
| locator | Yes (path, URL, or key) |
| description | Yes |
| retrieved_at | Yes |
| reliability | Yes |
| content_hash | Yes (SHA256) |

### Provenance Requirements

- Every source must have a unique `source_id` (SRC001, SRC002, ...)
- Reliability must be assessed: `high` (official/regulatory), `medium` (internal/user-provided), `low` (informal), `unknown`
- Access limitations must be recorded for any source that could not be fully retrieved

---

## File Inventory

Each completed assessment produces the following JSON files:

| Step | Filename | Schema |
|------|----------|--------|
| 1 | `01_interview.json` | interview.schema.json |
| 2 | `02_ingest.json` | ingest.schema.json |
| 3–4 | `03_assessment.json` | assessment.schema.json |
| 5 | `04_discussion.json` | discussion.schema.json |
| 6 | `assessment_final.json` | assessment.schema.json |
| Publish | `jira_publication.json` | jira-publication.schema.json |

All files are saved to the output directory (`$RA_OUTPUT_DIR`, default: `~/ra-output/<date>_<subject-slug>/`).

---

## Validation Checkpoints

| Checkpoint | Validation |
|------------|------------|
| Before Step 2 | Interview JSON validates against interview.schema.json |
| Before Step 3 | Ingest JSON validates against ingest.schema.json |
| Before Step 4 | Assessment JSON validates against assessment.schema.json (iteration 1) |
| Before Step 5 | Assessment JSON validates against assessment.schema.json (iteration 2, adversarial reviewed) |
| Before Step 6 | Discussion JSON validates against discussion.schema.json |
| Before Publish | Final assessment JSON validates against assessment.schema.json (status: "final") |

If validation fails, halt and report the validation error to the user.

---

## Markdown Rendering

Markdown is rendered on-demand from JSON for:
- User presentation (during workflow)
- Jira ticket descriptions (during publication)

### Rendering Rules

1. **Header section** renders as H2 with metadata table
2. **Subject brief** renders as narrative prose
3. **Regulatory framework** renders as numbered list with instrument details
4. **Risk assessments** render as definition lists (Likelihood: X, Impact: Y, Rating: Z)
5. **Epistemic basis** renders as classified list with source citations
6. **Mitigations** render as numbered action items with priority indicators and confidence levels
7. **Evidences** render as three subsections: Sources Used, Unavailable, Caveats

### Rating Badges

| Rating | Badge |
|--------|-------|
| Critical | 🔴 Critical |
| High | 🟠 High |
| Medium | 🟡 Medium |
| Low | 🟢 Low |
