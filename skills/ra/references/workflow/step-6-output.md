# Step 6 — Output

Produce the final assessment and write all files.

---

## Incorporate Discussion

Apply all adjustments from Step 5:

1. Update findings with user-confirmed changes
2. Add new findings identified during discussion
3. Record deferred items and insufficient evidence flags
4. Track all changes in `changes_from_previous`

---

## Final Validation

Before writing final files, validate:

- [ ] All enum values are valid per enums.schema.json
- [ ] All ratings follow the rating matrix
- [ ] Epistemic basis is complete for every finding
- [ ] Every projected residual risk has a confidence level with justification
- [ ] Every `fact` classification cites a valid `source_id`
- [ ] Every `assumption` has a rationale
- [ ] Every `unknown` describes what is unknown and its impact
- [ ] At least one finding exists
- [ ] Scope statement matches the confirmed scope from Step 1

If any validation fails, correct the issue before proceeding. If correction requires user input, return to Step 5.

---

## Write Files

Write `assessment_final.json` conforming to `assessment.schema.json` with:
- `iteration`: 3 (draft=1, rectified=2, final=3)
- `status`: "final"

Write all files to the output directory:

```
${RA_OUTPUT_DIR:-~/ra-output}/<date>_<subject-slug>/
```

Where:
- `<date>` is the assessment date in `yyyy-mm-dd` format
- `<subject-slug>` is a lowercase, hyphenated slug of the subject (e.g., `vendor-contract-acme-corp`)

### Files Written

| File | Description |
|------|-------------|
| `01_interview.json` | Interview record and confirmed scope |
| `02_ingest.json` | Ingested materials with provenance |
| `03_assessment.json` | Assessment iterations (draft, adversarial reviewed, rectified) |
| `04_discussion.json` | Discussion record with user inputs |
| `assessment_final.json` | Final assessment incorporating all feedback |

---

## Present Summary

Show the user:

### Findings by Severity

| Rating | Count |
|--------|-------|
| 🔴 Critical | [N] |
| 🟠 High | [N] |
| 🟡 Medium | [N] |
| 🟢 Low | [N] |

### Overall Risk Profile

Brief narrative of the overall risk posture for the assessed subject.

### Key Recommendations

Top 3–5 mitigations by priority, with assigned owner roles.

### Files Created

List all files with their full paths.

---

## Next Steps

Inform the user:

1. **Review**: All files are available in the output directory for review
2. **Publish to Jira**: Use `/ra:publish` to create the Assessment Epic, Finding Tasks, and Mitigation Sub-tasks in Jira project RA
3. **Preview**: Use `/ra:publish --dry-run` to preview what would be created in Jira without actually creating anything

**Do not publish to Jira in this step.** Publication is a separate command invoked by the user.
