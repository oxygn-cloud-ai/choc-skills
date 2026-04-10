# ra — Bespoke Risk Assessment

Risk assessment skill for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Assesses arbitrary subjects — legal documents, initiative plans, concepts, incidents — through an interactive interview-driven workflow.

Part of the [choc-skills](https://github.com/oxygn-cloud-ai/choc-skills) monorepo.

## Features

- **Interview-first workflow** — Adaptive conversation to understand the subject before assessing
- **Multi-source ingestion** — Local files, URLs, Jira, Confluence, Slack with full provenance
- **Epistemic classification** — Every assertion classified as fact, user claim, assumption, or unknown
- **Adversarial self-review** — 11-criteria challenge of every assessment
- **Projected residual risk** — With confidence levels on every projection
- **Jira integration** — Publish to RA project: Assessment, Findings, Mitigations

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Jira credentials (JIRA_EMAIL, JIRA_API_KEY) for publication
- Atlassian MCP connection for Jira/Confluence source ingestion

## Installation

### From repo root

```bash
./install.sh --force ra
```

### Per-skill installer (recommended)

```bash
cd skills/ra && ./install.sh --force
```

### Verify

```bash
cd skills/ra && ./install.sh --check
```

## Usage

```
/ra                    Start interactive assessment
/ra:assess             Same as above
/ra:publish            Publish to Jira
/ra:publish --dry-run  Preview without creating tickets
/ra:status             List assessments
/ra:update             Update to latest
/ra:help               Usage guide
/ra:doctor             Health check
/ra:version            Show version
```

## Workflow

| Step | Phase | Output |
|------|-------|--------|
| 1 | Interview | 01_interview.json |
| 2 | Ingest | 02_ingest.json |
| 3 | Assess | 03_assessment.json |
| 4 | Adversarial | (updates 03_assessment.json) |
| 5 | Discuss | 04_discussion.json |
| 6 | Output | assessment_final.json |

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| RA_OUTPUT_DIR | ~/ra-output | Assessment output directory |
| JIRA_EMAIL | — | Required for Jira publication |
| JIRA_API_KEY | — | Required for Jira publication |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Reference files not found" | Run /ra:doctor, then reinstall: `cd skills/ra && ./install.sh --force` |
| "JIRA_EMAIL not set" | Export JIRA_EMAIL and JIRA_API_KEY in your shell profile |
| "Atlassian MCP not connected" | Ensure the Atlassian MCP server is configured in Claude Code |
| Publication fails | Check /ra:doctor for connectivity, verify JIRA_API_KEY is valid |

## Update

```
/ra:update
```

Or manually:

```bash
git -C /path/to/choc-skills pull
cd /path/to/choc-skills/skills/ra && ./install.sh --force
```

## Uninstall

```bash
cd skills/ra && ./install.sh --uninstall
```

## Version

1.0.0

## License

See repository root.
