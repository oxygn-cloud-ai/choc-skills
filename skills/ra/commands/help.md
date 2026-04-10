---
name: ra:help
description: "Display usage guide for ra"
allowed-tools: Read
---

# ra:help — Usage Guide

Read version from `~/.claude/skills/ra/SKILL.md` frontmatter.

Display:
```
ra v{version} — Bespoke Risk Assessment

USAGE
  /ra                  Start interactive assessment (alias for /ra:assess)
  /ra:assess           Interactive 6-step assessment workflow
  /ra:publish           Publish assessment to Jira RA project
  /ra:publish --dry-run Preview Jira publication without creating tickets
  /ra:status           List recent assessments and their state
  /ra:update           Update ra to latest version
  /ra:help             Display this usage guide
  /ra:doctor           Check environment health
  /ra:version          Show installed version

WORKFLOW
  Step 1: Interview         Understand subject through adaptive conversation
  Step 2: Ingest            Fetch and normalise supporting materials
  Step 3: Assess            Identify risks, rate, recommend mitigations
  Step 4: Adversarial       Self-challenge against 11 criteria
  Step 5: Discuss           Walk through findings with user
  Step 6: Output            Produce final assessment files

INPUT SOURCES
  Local files (PDF, DOCX, MD, TXT)
  Pasted text
  URLs (web pages)
  Jira tickets (via Atlassian MCP)
  Confluence pages (via Atlassian MCP)
  Slack messages (via Slack MCP)

ENVIRONMENT VARIABLES
  RA_OUTPUT_DIR         Output directory (default: ~/ra-output)
  JIRA_EMAIL            Required for Jira publication
  JIRA_API_KEY          Required for Jira publication

LOCATION
  ~/.claude/skills/ra/SKILL.md
  ~/.claude/commands/ra/*.md (sub-commands)
  ~/.claude/skills/ra/references/ (schemas, workflow, context)
```

End of help output. Do not continue.
