---
name: ra:status
description: "List recent assessments and their publication state"
allowed-tools: Read, Bash(ls *), Bash(cat *), Bash(date *), Glob
---

# ra:status — Assessment Status

List assessments in `${RA_OUTPUT_DIR:-~/ra-output}/`:

1. List all subdirectories matching `<date>_<slug>/` pattern
2. For each, check which JSON files exist (01_interview through jira_publication)
3. Determine state: interview_only, ingested, assessed, discussed, finalised, published
4. Display table:

```
ra assessments — ${RA_OUTPUT_DIR}

| # | Date | Subject | State | Findings |
|---|------|---------|-------|----------|
| 1 | 2026-04-11 | vendor-contract | published (RA-4) | 3 |
| 2 | 2026-04-10 | expansion-plan | finalised | 5 |
```

If no assessments found: "No assessments found in ${RA_OUTPUT_DIR}."
