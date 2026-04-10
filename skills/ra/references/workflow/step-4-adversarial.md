# Step 4 — Adversarial Review

Self-challenge the draft assessment against 11 criteria. Assume the assessment is wrong, unsupported, or speculative.

---

## Adversarial Criteria

Apply each of the following 11 challenges to every finding in the assessment:

### 1. Factual Accuracy
Are assertions verifiable from confirmed sources? Cross-check each `fact` classification against its cited `source_id`. Flag any assertion classified as `fact` that cannot be traced to a source.

### 2. Regulatory Precision
Are cited instruments current, correctly titled, and directly relevant? Search the web to verify each regulatory citation. Flag outdated, misnamed, or tangentially relevant instruments.

### 3. Evidential Basis for Ratings
Are ratings supported by specific, grounded justifications? Challenge any rating where the rationale is generic, circular, or could apply to any firm. Rationales must be specific to Chocolate Finance's circumstances.

### 4. Scope Discipline
Does the assessment stay within the declared scope boundaries from Step 1? Flag any finding that addresses risks outside the confirmed scope. Flag any in-scope area that has no corresponding finding.

### 5. Actionability of Mitigations
Could an owner act on each mitigation without further interpretation? Challenge vague mitigations (e.g., "improve governance", "enhance monitoring"). Each mitigation must specify concrete steps.

### 6. Completeness of Evidences
Does the evidences section honestly disclose what was unavailable? Are there obvious sources that should have been consulted but were not? Flag missing evidence that would materially change the assessment.

### 7. Logical Coherence
Do ratings flow consistently? If inherent risk is High but projected residual is Low, are the mitigations genuinely sufficient to achieve that reduction? Does the confidence level reflect the certainty of the reduction?

### 8. Epistemic Rigour
Are `fact`/`user_claim`/`assumption`/`unknown` classifications accurate and complete? Challenge any assertion that is classified as `fact` without a source, or `assumption` without rationale.

### 9. Assumption Validation
Are assumptions reasonable? Could they be verified with available resources? Are alternative assumptions considered? Flag assumptions that are optimistic without justification.

### 10. Scope Gap
Are there risks within the declared scope that the assessment missed entirely? Consider each risk category and whether it applies to the subject. Flag categories that should have been considered.

### 11. Stakeholder Consultation
Were relevant stakeholders consulted during the interview? Should additional stakeholders be involved before finalising? Flag if the assessment would benefit from input not yet obtained.

---

## Regulatory Verification

For every regulatory instrument cited in the assessment:

1. Search the web for the instrument title
2. Verify it is current (not repealed or superseded)
3. Verify the title is exact
4. Verify it is directly relevant to the finding (not tangentially related)
5. Record the verification result

If an instrument cannot be verified, downgrade its reliability and note this in caveats.

---

## Challenge Recording

Record each challenge conforming to the `adversarial_review.challenges[]` structure in `assessment.schema.json`:

| Field | Description |
|-------|-------------|
| `id` | Sequential: CH001, CH002, ... |
| `section` | Which section: `subject`, `context`, `regulatory_framework`, `inherent_risk`, `recommended_mitigations`, `projected_residual_risk`, `evidences` |
| `challenge_type` | One of the 12 enum values from `enums.schema.json#/definitions/challenge_type` |
| `original_claim` | The specific claim or assertion being challenged |
| `challenge` | Why this claim is problematic (min 20 chars) |
| `evidence_for_challenge` | Supporting evidence (e.g., web search result) |
| `resolution_required` | `correction_required`, `evidence_required`, `clarification_required`, `removal_required`, `user_verification_required` |
| `suggested_resolution` | How to fix this issue |
| `severity` | `critical`, `major`, `minor` |

---

## Rectification

Address every challenge:

- **corrected**: Fix the issue (change rating, add source, revise classification)
- **caveat_added**: Add a caveat to the finding acknowledging the limitation
- **justified**: Provide evidence or reasoning that the original assessment is correct
- **deferred**: Cannot be resolved without additional information — record for Step 5 discussion

Track all changes in the assessment's `changes_from_previous` field.

---

## Output

Update `03_assessment.json`:
1. Set `iteration`: 2, `status`: "adversarial_reviewed"
2. Apply all corrections and caveats
3. Set `iteration`: 2, `status`: "rectified" after all rectifications applied

### Presentation

Present the adversarial summary to the user:

| Metric | Value |
|--------|-------|
| Total challenges | [N] |
| Critical | [N] |
| Major | [N] |
| Minor | [N] |
| Corrected | [N] |
| Caveats added | [N] |
| Justified | [N] |
| Deferred to discussion | [N] |

Highlight the key issues addressed and any material changes to ratings.

Proceed to Step 5 (Discuss with User).
