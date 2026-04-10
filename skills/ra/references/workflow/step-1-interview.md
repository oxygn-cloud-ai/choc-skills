# Step 1 — Interview

Adaptive conversation to understand the subject being assessed.

---

## Scope Determination

Ask what is being assessed and why. Determine:

- **Subject**: What is the thing being assessed? (A contract, initiative, concept, incident, regulation, vendor, etc.)
- **Subject type**: Classify as one of: `document_review`, `planned_change`, `issue_incident`, `concept`
- **Trigger**: Why is this assessment being requested now? What prompted it?
- **Urgency**: Is there a deadline or decision date this assessment must inform?

Begin with open-ended questions. Do not assume the subject type — let the user describe it in their own words, then classify.

---

## Detailed Repeat-Back

Once you have enough context, restate your understanding in detail. Include:

1. **What** is being assessed
2. **Why** — the trigger and business context
3. **Subject type** — your classification and why
4. **In scope** — what the assessment will cover
5. **Out of scope** — what the assessment will explicitly NOT cover
6. **Key stakeholders** — who is affected or involved

Present this as a structured summary and ask the user to confirm or correct.

---

## Iterate

Continue rounds of clarification until the user explicitly confirms understanding. Each round:

1. Ask one or two targeted clarifying questions
2. Incorporate the answers into your understanding
3. Present the updated understanding

**Do NOT proceed without explicit user confirmation.** Phrases like "sounds about right" or "yeah" are sufficient. Silence or ambiguity is not.

Limit to 5 rounds. If understanding is not confirmed after 5 rounds, summarise what remains unclear and ask the user to resolve those specific points.

---

## Scope Statement

Produce an explicit scope statement:

> **This assessment covers:** [enumerated list of what is in scope]
>
> **This assessment does NOT cover:** [enumerated list of what is out of scope]

The user must confirm this scope statement before proceeding.

---

## Material Gathering

Request supporting documents, links, and references. Accepted source types:

| Source Type | Retrieval Method |
|-------------|-----------------|
| Local files (PDF, DOCX, MD, TXT) | Read tool |
| Pasted text | Direct from conversation |
| URLs | WebFetch tool |
| Jira tickets | `mcp__plugin_atlassian_atlassian__getJiraIssue` |
| Confluence pages | `mcp__plugin_atlassian_atlassian__getConfluencePage` |
| Slack message links | Slack MCP tools |

For each source, ask:
1. What is this document/link?
2. Why is it relevant to this assessment?

Record each source with a provisional `source_id` (SRC001, SRC002, ...).

If the user has no materials to provide, that is acceptable — note this as an access limitation.

---

## Output

Write `01_interview.json` conforming to `interview.schema.json`.

Present the confirmed scope and source list to the user before proceeding to Step 2.
