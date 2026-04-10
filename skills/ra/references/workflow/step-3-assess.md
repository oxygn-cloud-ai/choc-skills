# Step 3 — Assess

Produce the risk assessment based on ingested materials.

---

## Preparation

Before assessing, read and internalise:
- `references/business-context.md` — firm context and standing risk dimensions
- `references/schemas/enums.schema.json` — valid enum values for all fields
- `references/quality-standards.md` — mandatory requirements and prohibited actions

---

## Finding Identification

Identify all distinct risks within the declared scope. Create one Finding per discrete risk. Do not combine unrelated risks into a single finding. Do not split a single risk artificially to inflate the count.

For each finding:

### 1. Finding ID

Sequential identifier: F001, F002, F003, ...

### 2. Categorise

Assign one of the 12 risk categories:

| Prefix | Category |
|--------|----------|
| `A` | Audit |
| `B` | Business Continuity Management |
| `C` | Compliance |
| `D` | Product / Design |
| `ER` | Expansion Risk |
| `F` | Financial |
| `I` | Investment |
| `L` | Legal |
| `O` | Operational |
| `OO` | Other Operational |
| `P` | People |
| `T` | Technology |

### 3. Epistemic Classification

For each assertion within the finding, classify as:

| Classification | Requirement |
|----------------|-------------|
| **fact** | Must cite `source_id`. Verifiable from the referenced source. |
| **user_claim** | Must note when claimed and the source. Not independently verified. |
| **assumption** | Must state rationale for why this assumption is reasonable. |
| **unknown** | Must describe what is unknown and the impact of this gap on the finding. |

Every finding must have at least one epistemic classification entry. Findings composed entirely of assumptions and unknowns must flag this prominently.

### 4. Inherent Risk

Rate likelihood and impact using the rating matrix from quality-standards.md.

- **Likelihood rationale**: Minimum 50 characters. Must be grounded in the firm's specific circumstances, not generic industry observations.
- **Impact rationale**: Minimum 50 characters. Must describe the specific consequences for Chocolate Finance.
- **Rating**: Derived strictly from the matrix. Do not override.

### 5. Regulatory Framework

Identify applicable regulatory instruments for each finding:

- **Instrument**: Full title and reference number
- **Jurisdiction**: SG, HK, UAE, JP, or international
- **Status**: Current, proposed, or repealed
- **Relevance**: How this instrument applies to the finding

**Verification**: Search the web to verify each cited instrument is current, correctly titled, and directly relevant. Record the verification in the finding.

### 6. Recommended Mitigations

For each finding, recommend one or more mitigations:

| Field | Requirement |
|-------|-------------|
| `mitigation_id` | Sequential: M001, M002, ... |
| `title` | Concise action title |
| `priority` | Critical, High, Medium, or Low |
| `owner_role` | Use role titles from business-context.md (e.g., "Head of Compliance", "CTO") |
| `implementation_steps` | At least one concrete step. Must be actionable without further interpretation. |
| `implementation_assumptions` | What must be true for this mitigation to work |
| `expected_effect` | What risk reduction this mitigation provides |
| `confidence` | `high`, `medium`, or `low` — confidence that this mitigation will achieve the expected effect |

### 7. Projected Residual Risk

What the residual risk WOULD BE if all recommended mitigations for this finding were fully adopted:

- **Likelihood**: May reduce from inherent if mitigations address root causes
- **Impact**: Typically does NOT reduce — mitigations rarely eliminate consequences entirely
- **Rating**: Derived from the matrix
- **Confidence**: `high`, `medium`, or `low` with justification
- **Caveats**: If confidence is `low`, this must be noted prominently

---

## Output

Write `03_assessment.json` conforming to `assessment.schema.json` with:
- `iteration`: 1
- `status`: "draft"

### Validation Before Proceeding

- All enum values are valid per enums.schema.json
- All ratings follow the matrix
- At least one finding exists
- Epistemic basis is complete for each finding
- Every projected residual risk has a confidence level

### Presentation

Present the assessment summary to the user as a table:

| Finding | Category | Inherent Risk | Projected Residual | Confidence |
|---------|----------|---------------|-------------------|------------|
| F001: [title] | [category] | [badge] [rating] | [badge] [rating] | [level] |
| ... | ... | ... | ... | ... |

Proceed to Step 4 (Adversarial Review).
