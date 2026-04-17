# rr — Risk Register Assessment

A Claude Code CLI skill for structured risk assessment of a Jira-based risk register (project RR). Single-risk interactive mode or fully autonomous batch mode with parallel sub-agents.

## Prerequisites

- [Claude Code](https://claude.ai/claude-code) installed
- Atlassian MCP integration connected with access to the RR project
- For batch mode: `curl`, `jq`, and environment variables (see below)

## Installation

**Important:** Use the per-skill installer. The root `./install.sh rr` only copies SKILL.md and will produce a broken install.

```bash
cd skills/rr && ./install.sh
```

### Verify

```bash
./install.sh --check
```

Or in Claude Code:

```
/rr doctor
```

### Uninstall

```bash
cd skills/rr && ./install.sh --uninstall
```

## Usage

```
/rr RR-220              Review a specific risk (interactive 6-step workflow)
/rr all                 Batch review all risks (parallel sub-agents)
/rr all --force         Batch all risks, ignore quarterly filter
/rr all T               Batch Technology risks only
/rr all --reset         Clear batch work directory
/rr status              Check batch progress (snapshot)
/rr monitor             Real-time batch progress monitor (live refresh)
/rr fix                 Re-run failed assessments
/rr update              Update to latest version
/rr doctor              Environment health check
/rr help                Usage guide
/rr version             Show version
```

Natural language also works:

```
Review RR-220
Assess all technology risks
Do a risk review of RR-315
```

## How It Works

### Single Risk Mode (`/rr RR-220`)

Interactive 6-step workflow:

1. **Extract & Draft** — Retrieve risk from Jira, draft initial assessment
2. **Adversarial Review** — Challenge the draft against 8 criteria, verify regulatory citations
3. **Rectified Assessment** — Address every challenge, correct or justify
4. **Discussion** — Resolve uncertainties with the user interactively
5. **Final Assessment** — Incorporate discussion outcomes (user confirms before publishing)
6. **Publish to Jira** — Create Review child ticket with full assessment

### Batch Mode (`/rr all`)

Fully autonomous parallel processing:

| Phase | Duration | Action |
|-------|----------|--------|
| 1 | ~30s | Query Jira for all risks |
| 2 | ~10s | Filter out quarterly-reviewed |
| 3 | ~30s | Chunk into batches of 10 |
| 4 | ~15min | Dispatch 20 sub-agents in parallel |
| 5 | ~2min | Collect and validate results |
| 6 | ~10min | Create Review tickets in Jira |
| 7 | ~5s | Slack notification |

**Total: ~30 minutes for 200 risks**

Requires `JIRA_EMAIL` and `JIRA_API_KEY`. Falls back to sequential mode if these are not set. Sub-agents run via Claude Code Agent tool (no API key needed).

## Environment Variables

| Variable | Default | Required For |
|----------|---------|-------------|
| `RR_OUTPUT_DIR` | `~/rr-output` | All modes |
| `RR_WORK_DIR` | `~/rr-work` | Batch mode |
| `JIRA_EMAIL` | — | Batch mode Jira API |
| `JIRA_API_KEY` | — | Batch mode Jira API |
| `SLACK_WEBHOOK_URL` | — | Optional: completion notification |

## Output Files

Each completed review produces 7 JSON files in `$RR_OUTPUT_DIR` (default: `~/rr-output/`):

| File | Step |
|------|------|
| `<key>_export.json` | 1 — Jira data export |
| `<key>_<date>_assessment_1.json` | 1 — Draft assessment |
| `<key>_<date>_adversarial_review.json` | 2 — Challenges |
| `<key>_<date>_assessment_2.json` | 3 — Rectified assessment |
| `<key>_<date>_discussion.json` | 4 — Discussion log |
| `<key>_<date>_assessment_final.json` | 5 — Final assessment |
| `<key>_<date>_jira_ticket.json` | 6 — Jira ticket record |

## File Structure

```
~/.claude/skills/rr/
  SKILL.md                           Main skill definition
  .source-repo                       Repo path (for /rr update)
  bin/
    rr-prepare.sh                    Phases 1-3: discovery, filter, extraction
    rr-finalize.sh                   Phases 5-7: collection, publication, completion
    sub-agent-prompt.md              Sub-agent prompt template for Agent dispatch
    _publish_one.sh                  Per-risk Jira publish wrapper
    monitor.py                       Terminal dashboard (Rich)
    monitor_server.py                HTTP API server for web dashboard
    monitor_dashboard.html           Web dashboard frontend
  references/
    business-context.md              Operational facts and business context
    jira-config.md                   Jira API config
    quality-standards.md             Validation rules
    regulatory-framework.md          MAS/SFC instruments
    schemas/                         6 JSON schema files
    workflow/                        6 step definition files

~/.claude/commands/rr/
  review.md                          Single-risk workflow
  all.md                             Batch mode
  status.md                          Progress checker
  fix.md                             Retry helper

~/.claude/commands/rr.md             Router file
```

## Risk Categories

| Prefix | Category |
|--------|----------|
| A | Audit |
| B | Business Continuity Management |
| C | Compliance |
| D | Product / Design |
| ER | Expansion Risk |
| F | Financial |
| I | Investment |
| L | Legal |
| O | Operational |
| OO | Other Operational |
| P | People |
| T | Technology |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `/rr doctor` fails | Run `cd skills/rr && ./install.sh --force` |
| Jira tools not available | Connect Atlassian MCP integration in Claude Code |
| "Project RR not found" | Verify Atlassian account has RR project access |
| Batch mode not launching | Check `JIRA_EMAIL`, `JIRA_API_KEY` are set |
| jq not found | `brew install jq` |
| Batch progress lost | Check `~/rr-work/progress.md` or `~/rr-output/rr-progress.md` |

## Update

```bash
cd choc-skills && git pull && cd skills/rr && ./install.sh --force
```

Or from within Claude Code:

```
/rr update
```

## Version

Current: **5.3.25**

## Licence

MIT
