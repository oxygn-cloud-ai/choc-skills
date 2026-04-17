# CPT Project — Jira Configuration

## Connection Details

| Parameter | Value |
|-----------|-------|
| **Cloud ID** | `$JIRA_CLOUD_ID` |
| **Project Key** | `CPT` |
| **Project Name** | CPT: Claude Progress Tracker |
| **Target Ticket** | `CPT-1` |

## Issue Types

| Issue Type | ID | Purpose |
|------------|-----|---------|
| Task | `13146` | Top-level tracking items |
| Sub-task | `13147` | Child items |

## Integration (v1)

- **Comments only** — no Jira status transitions
- **Non-blocking** — CPT failures never block the main workflow
- **Kill switch** — `export RR_CPT_DISABLED=true` to skip all CPT activity
- **Local audit** — all events logged to `$WORK_DIR/cpt-events.jsonl`

## API

### Post Comment

```
POST /rest/api/3/issue/CPT-1/comment
Authorization: Basic <base64(JIRA_EMAIL:JIRA_API_KEY)>
Content-Type: application/json

{
  "body": {
    "type": "doc",
    "version": 1,
    "content": [{"type": "paragraph", "content": [{"type": "text", "text": "..."}]}]
  }
}
```

## Revert Instructions

To remove CPT integration entirely:

1. Remove all lines containing `_update_cpt.sh` from `rr-prepare.sh` and `rr-finalize.sh`
2. Remove CPT-related instructions from `all.md`, `board.md`, `doctor.md`
3. Delete `_update_cpt.sh` and this file
4. No other files depend on CPT
