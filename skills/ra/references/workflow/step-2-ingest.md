# Step 2 — Ingest Materials

Read and normalise all provided materials with full provenance tracking.

---

## IMPORTANT: MCP call-spec variable substitution (CPT-103)

The MCP call specs below reference `$JIRA_CLOUD_ID` as a placeholder. **The MCP layer does not expand shell variables** — parameter strings are passed literally. Before calling any MCP tool, Claude MUST substitute the placeholder with the value from the `$JIRA_CLOUD_ID` environment variable (e.g. via `echo "$JIRA_CLOUD_ID"`). Do NOT pass the literal string `"$JIRA_CLOUD_ID"` as the `cloudId` parameter.

---

## Fetch

For each source identified in Step 1, retrieve the content:

| Source Type | Tool |
|-------------|------|
| Local files | Read tool |
| URLs | WebFetch tool |
| Jira tickets | `mcp__plugin_atlassian_atlassian__getJiraIssue` with `cloudId: "$JIRA_CLOUD_ID"` |
| Confluence pages | `mcp__plugin_atlassian_atlassian__getConfluencePage` with `cloudId: "$JIRA_CLOUD_ID"` |
| Slack messages | Slack MCP tools |
| Pasted text | Already available from conversation |

If a source cannot be retrieved:
- Record the failure in `access_limitations`
- Note the error and attempted retrieval method
- Continue with remaining sources — do not halt the assessment

---

## Normalise

For each successfully retrieved source, extract and record:

| Field | Description |
|-------|-------------|
| `source_id` | Sequential identifier (SRC001, SRC002, ...) |
| `source_type` | One of: `local_file`, `pasted_text`, `url`, `jira_ticket`, `confluence_page`, `slack_message`, `skill_context` |
| `locator` | File path, URL, ticket key, or page ID |
| `description` | What this source is and why it is relevant |
| `retrieved_at` | ISO 8601 timestamp of retrieval |
| `normalisation_method` | How content was extracted (e.g., "read_tool", "webfetch_markdown", "jira_api_markdown") |
| `content_hash` | SHA256 hash of the extracted text content |
| `content_length_chars` | Character count of extracted text |
| `reliability` | `high` (official/regulatory), `medium` (internal/user-provided), `low` (informal), `unknown` |
| `access_limitations` | Any restrictions noted (e.g., "PDF images not OCR'd", "partial page load") |

---

## Provenance

Assign reliability ratings using these criteria:

| Reliability | Criteria |
|-------------|----------|
| `high` | Official documents, regulatory publications, audited financial statements, signed contracts |
| `medium` | Internal company documents, user-provided information, internal policies, Confluence pages |
| `low` | Informal sources, chat messages, unattributed claims, blog posts |
| `unknown` | Cannot determine provenance or authority of the source |

---

## Subject Brief

Synthesise all ingested materials into a comprehensive narrative:

1. **subject_brief** — A narrative summary of the subject being assessed (minimum 200 characters). Should describe the subject, its context, and why it matters from a risk perspective.

2. **key_facts** — Extract at least one key fact from the materials. Each fact must:
   - Be directly supported by a source (cite `source_id`)
   - Be relevant to the risk assessment
   - Be stated precisely without embellishment

3. **open_questions** — Identify questions that the materials do not answer but that are relevant to the assessment. These will inform the assessment's `unknown` epistemic classifications.

---

## Output

Write `02_ingest.json` conforming to `ingest.schema.json`.

Present the subject brief to the user. Confirm:
1. All sources were ingested correctly
2. The subject brief accurately represents the materials
3. Any open questions are acknowledged

Proceed to Step 3 only after user confirmation.
