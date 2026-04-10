# Step 5 — Discuss with User

Present findings and walk through with the user for validation and refinement.

---

## Present Findings

For each finding, present:

1. **Title** and **Finding ID**
2. **Category** with prefix
3. **Inherent risk** with rating badge
4. **Key epistemic basis items** — what is fact, what is assumed, what is unknown
5. **Recommended mitigations** with priorities
6. **Projected residual risk** with confidence level
7. **Any deferred challenges** from Step 4

Use the rating badges consistently:
- 🔴 Critical
- 🟠 High
- 🟡 Medium
- 🟢 Low

---

## Walk Through

Discuss each finding one at a time with the user. **Do NOT wait passively** — ask the first question immediately after presenting the first finding.

For each finding, ask:
1. Does this accurately represent the risk?
2. Is the inherent risk rating appropriate?
3. Are the mitigations practical and complete?
4. Is the projected residual risk reasonable?
5. Is there additional context that would change this assessment?

---

## Accept Challenges

The user may:
- **Dispute ratings** — provide their reasoning and adjust if justified
- **Add context** — new information that changes the epistemic basis (reclassify from `assumption` to `fact` or `user_claim`)
- **Identify missing risks** — add as new findings (see New Risks below)
- **Challenge assumptions** — provide evidence that an assumption is incorrect
- **Reject mitigations** — remove or replace mitigations they consider impractical
- **Adjust scope** — narrow or expand (requires re-confirmation of scope statement)

Record every user input with timestamp and the resulting change to the assessment.

---

## Handle Deferred Items

For challenges deferred from Step 4:
- Present each to the user
- Ask if they can provide the missing information
- If yes: incorporate and resolve the challenge
- If no: record as deferred with:
  - `reason`: Why it cannot be resolved
  - `impact_on_assessment`: How this gap affects the assessment's reliability
  - `follow_up_action`: What would be needed to resolve it in future

---

## Insufficient Evidence

Flag areas where evidence was insufficient to make a confident assessment:

| Field | Description |
|-------|-------------|
| `area` | Which aspect of the assessment |
| `description` | What evidence was lacking |
| `impact` | How this affects the reliability of the finding |
| `recommendation` | What additional evidence would strengthen the assessment |

---

## New Risks

If the user identifies new risks during discussion:

1. Create a new finding (next sequential Finding ID)
2. Apply the full assessment process (categorise, epistemic classification, rating, mitigations, projected residual)
3. Apply adversarial review to the new finding
4. Present back to user for confirmation

---

## Finalise

Once all findings have been discussed:

1. Summarise all changes made during discussion
2. Present the updated assessment summary table
3. Ask the user to confirm they are satisfied with the assessment

**The user must explicitly confirm satisfaction before proceeding to Step 6.** Do not proceed on ambiguous responses.

---

## Output

Write `04_discussion.json` conforming to `discussion.schema.json`.

The discussion record must include:
- All user inputs with timestamps
- All changes made to findings
- All deferred items with reasons
- All insufficient evidence flags
- Any new findings added
- Final confirmation status
