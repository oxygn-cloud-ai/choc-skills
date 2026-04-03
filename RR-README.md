# rr — Risk Register Assessment Skill

**Full documentation for the `rr` Claude Code skill.**

A structured, adversarial risk assessment workflow for a Jira-based risk register (project RR). Produces time-stamped, schema-validated Review tickets with full audit trail.

---

## Table of Contents

1. [What the Skill Does](#1-what-the-skill-does)
2. [Requirements](#2-requirements)
3. [Installation](#3-installation)
4. [Usage](#4-usage)
5. [Updating](#5-updating)
6. [Uninstalling](#6-uninstalling)
7. [Configuration Reference](#7-configuration-reference)
8. [Architecture and File Structure](#8-architecture-and-file-structure)
9. [Schemas and Validation](#9-schemas-and-validation)
10. [Risk Categories](#10-risk-categories)
11. [Regulatory Framework](#11-regulatory-framework)
12. [Troubleshooting](#12-troubleshooting)
13. [Security Considerations](#13-security-considerations)
14. [Limitations](#14-limitations)

---

## 1. What the Skill Does

The `rr` skill automates the quarterly review of a Jira-based risk register. It connects to Jira (project key: `RR`), retrieves risk items, and produces structured assessments that are published back as Review child tickets under each parent Risk.

### Two Operating Modes

#### Single Risk Mode (`/rr RR-220`)

An interactive, 6-step workflow for assessing one risk at a time:

| Step | Name | What Happens | User Interaction |
|------|------|-------------|-----------------|
| 1 | **Extract & Draft** | Retrieves the risk from Jira via MCP, fetches all child tickets (existing Reviews and Mitigations), exports the data to JSON, and drafts an initial assessment grounded in business context and regulatory framework. | None (automatic) |
| 2 | **Adversarial Review** | Challenges the draft assessment against 8 criteria: factual accuracy, regulatory precision, evidential basis for ratings, control assessment rigour, scope discipline, actionability of recommendations, completeness of evidences, and logical coherence. Verifies regulatory citations via web search. | None (automatic) |
| 3 | **Rectified Assessment** | Addresses every challenge from Step 2 by either correcting the assessment or retaining the original position with justification. All changes are tracked in a `changes_from_previous` object. | None (automatic) |
| 4 | **Discussion** | Claude initiates a conversation with you about unresolved points in the assessment. It asks one question at a time about internal controls, regulatory obligations, data quality, and judgment-based ratings. You can also raise your own challenges. | Interactive Q&A |
| 5 | **Final Assessment** | Incorporates all discussion outcomes into a final assessment. Presents it to you for review. | You must confirm before proceeding |
| 6 | **Publish to Jira** | Creates (or updates) a Review child ticket under the parent Risk in Jira. Attaches all 7 workflow JSON files as artifacts. Updates the progress file if running in batch mode. | None (automatic) |

Each completed review produces **7 JSON files** that form a complete audit trail:

| File | Schema | Step |
|------|--------|------|
| `<key>_export.json` | `jira-export.schema.json` | 1 |
| `<key>_<date>_assessment_1.json` | `assessment.schema.json` | 1 |
| `<key>_<date>_adversarial_review.json` | `adversarial-review.schema.json` | 2 |
| `<key>_<date>_assessment_2.json` | `assessment.schema.json` | 3 |
| `<key>_<date>_discussion.json` | `discussion.schema.json` | 4 |
| `<key>_<date>_assessment_final.json` | `assessment.schema.json` | 5 |
| `<key>_<date>_jira_ticket.json` | `jira-ticket.schema.json` | 6 |

#### Batch Mode (`/rr all`)

Fully autonomous parallel processing for reviewing the entire risk register in one session:

| Phase | Duration | Action |
|-------|----------|--------|
| 1 | ~30s | Query Jira for all Risk items (paginated, 100 per request) |
| 2 | ~10s | Filter out risks already reviewed this quarter (idempotency) |
| 3 | ~30s | Chunk remaining risks into batches of 10 |
| 4 | ~15min | Dispatch up to 20 parallel sub-agents via the Anthropic API, each assessing 10 risks |
| 5 | ~2min | Collect and validate sub-agent responses, auto-correct rating matrix violations |
| 6 | ~10min | Create Review child tickets in Jira (up to 50 parallel API calls) |
| 7 | ~5s | Post Slack notification with summary |

**Total: approximately 30 minutes for 200 risks.**

Sub-agents are stateless Claude API calls with all business context and regulatory framework embedded in the system prompt. Each sub-agent performs its own self-adversarial review internally (draft, challenge, rectify) before returning the final assessment.

If `ANTHROPIC_API_KEY` is not set or the orchestrator scripts are missing, batch mode falls back to **sequential mode**: Claude processes risks one at a time through the full 6-step interactive workflow, tracking progress in a resumable progress file.

---

## 2. Requirements

### Required for All Modes

| Requirement | How to Check | How to Install |
|------------|-------------|----------------|
| Claude Code CLI | `claude --version` | [docs.anthropic.com](https://docs.anthropic.com/en/docs/claude-code) |
| Atlassian MCP integration | `/rr doctor` (checks MCP connectivity) | Connect via Claude Code settings or [claude.ai](https://claude.ai) integrations |
| Access to Jira project RR | Verify in Jira: chocfin.atlassian.net | Request from Jira admin |
| `curl` | `which curl` | Pre-installed on macOS |
| `bash` 3.2+ | `bash --version` | Pre-installed on macOS |

### Required for Batch Mode Only

| Requirement | How to Check | How to Install |
|------------|-------------|----------------|
| `jq` | `which jq` | `brew install jq` |
| `ANTHROPIC_API_KEY` | `echo $ANTHROPIC_API_KEY` | [console.anthropic.com](https://console.anthropic.com) |
| `JIRA_EMAIL` | `echo $JIRA_EMAIL` | Your Jira account email |
| `JIRA_API_KEY` | `echo $JIRA_API_KEY` | [id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens) |

### Optional

| Requirement | Purpose |
|------------|---------|
| `SLACK_WEBHOOK_URL` | Receive a Slack notification when batch mode completes |

### Setting Environment Variables

Add to your shell profile (`~/.zshrc`, `~/.bashrc`, or `~/.zprofile`):

```bash
export ANTHROPIC_API_KEY="your-key-here"
export JIRA_EMAIL="your-email@company.com"
export JIRA_API_KEY="your-token-here"
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."  # optional
```

Then reload: `source ~/.zshrc`

**Important:** Never commit these values to any repository. The skill references them via environment variables only.

---

## 3. Installation

### Recommended: Per-Skill Installer

The `rr` skill includes orchestrator scripts, reference files, and sub-commands that the root installer does not handle. Always use the per-skill installer:

```bash
git clone https://github.com/oxygn-cloud-ai/claude-skills.git
cd claude-skills/skills/rr
./install.sh
```

This installs:

| Destination | Contents | Count |
|------------|----------|-------|
| `~/.claude/skills/rr/SKILL.md` | Main skill definition | 1 file |
| `~/.claude/skills/rr/.source-repo` | Repo path marker (enables `/rr update`) | 1 file |
| `~/.claude/skills/rr/orchestrator/` | Batch orchestrator scripts | 8 files |
| `~/.claude/skills/rr/references/` | Schemas, workflow steps, business context, regulatory framework | 16 files |
| `~/.claude/commands/rr/` | Sub-command files (review, all, status, fix) | 4 files |
| `~/.claude/commands/rr.md` | Router file | 1 file |

### Verify Installation

```bash
./install.sh --check
```

Or from within Claude Code:

```
/rr doctor
```

Expected output (all green):

```
rr doctor -- Environment Health Check

  [PASS] curl: /usr/bin/curl
  [PASS] jq: /usr/bin/jq
  [PASS] ANTHROPIC_API_KEY: set
  [PASS] JIRA_EMAIL: set
  [PASS] JIRA_API_KEY: set
  [PASS] reference files: 9 files found
  [PASS] orchestrator scripts: 2 files found
  [PASS] sub-commands: 4 files in ~/.claude/commands/rr/
  [PASS] Atlassian MCP: connected (1 result)
  [PASS] version: 2.7.1

  Result: 10 passed, 0 warnings, 0 failed
```

### Why Not the Root Installer?

Running `./install.sh rr` from the repo root only copies `SKILL.md`. It does **not** copy the orchestrator scripts, reference files, or sub-commands. The skill will fail with missing reference file errors if installed this way.

---

## 4. Usage

### Commands at a Glance

| Command | Mode | Description |
|---------|------|-------------|
| `/rr RR-220` | Single | Review a specific risk (interactive 6-step workflow) |
| `/rr all` | Batch | Review all risks (parallel sub-agents or sequential fallback) |
| `/rr all --force` | Batch | Review all risks, bypassing the quarterly filter |
| `/rr all T` | Batch | Review only Technology risks |
| `/rr all C` | Batch | Review only Compliance risks |
| `/rr all --reset` | Batch | Delete batch work directory and start fresh |
| `/rr status` | Utility | Check progress of a running or completed batch (snapshot) |
| `/rr monitor` | Utility | Real-time batch progress monitor (live dashboard, auto-refreshes every 5s) |
| `/rr fix` | Utility | Re-run failed assessments or publications |
| `/rr update` | Utility | Update to the latest version from the git repo |
| `/rr doctor` | Utility | Run environment health checks |
| `/rr help` | Utility | Display usage guide |
| `/rr version` | Utility | Show installed version |

### Single Risk Review

```
/rr RR-220
```

Claude will:

1. Retrieve RR-220 from Jira and display the risk details
2. Draft an initial assessment (you'll see it rendered as markdown)
3. Adversarially challenge the draft and show the challenge report
4. Rectify the assessment and show what changed
5. Begin a discussion with you — Claude asks questions about unresolved points. Answer them one at a time. When done, say "proceed" or "continue"
6. Present the final assessment and ask for your confirmation
7. After you confirm, create the Review ticket in Jira and attach all files

**The entire workflow takes 5-15 minutes per risk**, depending on how much discussion is needed.

Natural language also works:

```
Review RR-220
Assess the technology risks
Do a risk review of RR-315
```

### Batch Review

```
/rr all
```

If `ANTHROPIC_API_KEY`, `JIRA_EMAIL`, and `JIRA_API_KEY` are set, this launches the parallel orchestrator in the background. You'll see:

```
RR batch review launched.

Running in background (~30 minutes for 200 risks).
Slack notification on completion (if SLACK_WEBHOOK_URL set).

Monitor: /rr monitor (or /rr status for a snapshot)
```

#### Batch Flags

| Flag | Effect |
|------|--------|
| `--force` | Process all risks regardless of whether they've been reviewed this quarter |
| `--reset` | Delete the work directory and start fresh (asks for confirmation) |
| `T`, `C`, `F`, etc. | Filter by risk category prefix |

#### Checking Progress

```
/rr monitor
```

Launches a live dashboard that refreshes every 5 seconds, showing current phase, file counts for each stage (dispatch, collection, publication), a progress bar, and the last log entry. Exits automatically when the batch completes.

For a one-shot snapshot instead:

```
/rr status
```

#### Fixing Failures

```
/rr fix
```

Lists failed assessments and failed Jira publications. Offers to retry sub-agent failures (via the retry script) or re-publish via MCP tools.

### Sequential Batch Mode (Fallback)

If the orchestrator prerequisites are not met, `/rr all` falls back to processing risks one at a time through the full 6-step workflow. Progress is saved to `~/rr-output/rr-progress.md` after each completed risk. If your context window fills up:

1. Claude saves progress automatically
2. Start a new chat
3. Type `/rr all` again
4. It resumes from where it left off

---

## 5. Updating

### From Claude Code

```
/rr update
```

This reads the `.source-repo` marker written during installation, pulls the latest code from the git repo, compares versions, and re-runs the installer if an update is available.

### Manually

```bash
cd claude-skills
git pull
cd skills/rr
./install.sh --force
```

### Checking Your Version

```
/rr version
```

---

## 6. Uninstalling

### Via the Installer

```bash
cd claude-skills/skills/rr
./install.sh --uninstall
```

This removes:
- `~/.claude/skills/rr/` (SKILL.md, orchestrator, references)
- `~/.claude/commands/rr/` (sub-command files)
- `~/.claude/commands/rr.md` (router file)

### Manually

```bash
rm -rf ~/.claude/skills/rr
rm -rf ~/.claude/commands/rr
rm -f ~/.claude/commands/rr.md
```

### Cleaning Up Output Files

The skill writes output to two directories that are NOT removed by uninstall:

```bash
rm -rf ~/rr-output   # Single-risk assessment outputs
rm -rf ~/rr-work     # Batch mode working directory
```

---

## 7. Configuration Reference

### Environment Variables

| Variable | Default | Required | Purpose |
|----------|---------|----------|---------|
| `RR_OUTPUT_DIR` | `~/rr-output` | No | Directory where individual risk assessment JSON files are saved |
| `RR_WORK_DIR` | `~/rr-work` | No | Working directory for batch orchestrator (intermediate files, logs, results) |
| `ANTHROPIC_API_KEY` | _(none)_ | For batch parallel mode | API key for Claude sub-agent dispatch |
| `JIRA_EMAIL` | _(none)_ | For batch mode | Email address for Jira REST API basic auth |
| `JIRA_API_KEY` | _(none)_ | For batch mode | API token for Jira REST API basic auth |
| `SLACK_WEBHOOK_URL` | _(none)_ | No | Incoming webhook URL for batch completion notification |
| `RR_MODEL` | `claude-sonnet-4-20250514` | No | Claude model used by batch sub-agents |
| `ANTHROPIC_API_VERSION` | `2023-06-01` | No | Anthropic API version header |
| `RR_CATEGORY_FILTER` | _(none)_ | No | Pre-set category filter for batch mode (alternative to `/rr all T`) |

### Jira Configuration

These values are hard-coded in the reference files and orchestrator scripts:

| Setting | Value |
|---------|-------|
| Jira Instance | chocfin.atlassian.net |
| Cloud ID | `81a55da4-28c8-4a49-8a47-03a98a73f152` |
| Project Key | `RR` |
| Risk Issue Type ID | `12724` |
| Review Issue Type ID | `12686` |
| Mitigation Issue Type ID | `12722` |
| Default Assignee | James Shanahan (`712020:fd08a63d-8c2c-4412-8761-834339d9475c`) |

### Quarterly Labels

Review tickets are automatically labelled based on the month of assessment:

| Assessment Month | Label |
|-----------------|-------|
| January - March | `Q1-Risk-Review` |
| April - June | `Q2-Risk-Review` |
| July - September | `Q3-Risk-Review` |
| October - December | `Q4-Risk-Review` |

---

## 8. Architecture and File Structure

### Installed Layout

```
~/.claude/skills/rr/
  SKILL.md                                Main skill definition (frontmatter + router + inline fallback)
  .source-repo                            Repo path for /rr update
  orchestrator/
    rr-batch.sh                           Main batch orchestrator (7 phases)
    dispatch.sh                           Standalone parallel dispatch script
    collect.sh                            Result collection and validation
    retry.sh                              Failed batch retry with backoff
    publish.sh                            Jira publication manifest generator
    _dispatch_one.sh                      Per-batch dispatch wrapper (macOS-safe parallelism)
    _publish_one.sh                       Per-risk publish wrapper (macOS-safe parallelism)
    sub-agent-system-prompt.txt           System prompt embedded in all sub-agent API calls
  references/
    business-context.md                   Operational facts and business context
    jira-config.md                        Jira API connection details and MCP tool usage
    quality-standards.md                  Validation rules and prohibited actions
    regulatory-framework.md              MAS/SFC applicable regulatory instruments
    schemas/
      enums.schema.json                  Shared enum definitions and rating matrix
      assessment.schema.json             Assessment output (Steps 1d, 3, 5)
      adversarial-review.schema.json     Adversarial review output (Step 2)
      discussion.schema.json             Discussion log output (Step 4)
      jira-export.schema.json            Jira data export output (Step 1c)
      jira-ticket.schema.json            Jira ticket creation record (Step 6)
    workflow/
      step-1-extract.md                  Detailed instructions for Step 1
      step-2-adversarial.md              Detailed instructions for Step 2
      step-3-rectify.md                  Detailed instructions for Step 3
      step-4-discussion.md               Detailed instructions for Step 4
      step-5-finalise.md                 Detailed instructions for Step 5
      step-6-publish.md                  Detailed instructions for Step 6

~/.claude/commands/rr/
  review.md                               Single-risk interactive workflow
  all.md                                  Batch mode (parallel + sequential fallback)
  status.md                               Progress checker
  monitor.md                              Real-time batch progress monitor
  fix.md                                  Retry helper

~/.claude/commands/rr.md                  Router (maps /rr arguments to sub-commands)
```

### Batch Mode Working Directory

Created at runtime by the orchestrator at `${RR_WORK_DIR:-~/rr-work}/`:

```
~/rr-work/
  batch.log                               Timestamped execution log
  progress.md                             Human-readable completion summary
  discovery.json                          Phase 1: all risks from Jira
  filter-result.json                      Phase 2: filtered list
  extracts/batch_N.json                   Phase 3: risk batches (10 per file)
  payloads/payload_N.json                 Phase 4: API request bodies
  results/result_N.json                   Phase 4: raw API responses
  errors/error_N.json                     Phase 4: failed batches
  assessments/batch_N.json                Phase 5: validated batch assessments
  individual/RR-N.json                    Phase 5: per-risk assessments
  jira-results/RR-N.json                  Phase 6: created ticket responses
  jira-errors/RR-N.json                   Phase 6: failed publications
  logs/dispatch_N.log                     Per-process logs (parallel dispatch)
  logs/publish_N.log                      Per-process logs (parallel publish)
  retry-queue.txt                         Batch IDs to retry
```

---

## 9. Schemas and Validation

Every JSON output file is validated against a strict JSON Schema. The schemas enforce:

- **Enum compliance** — All field values must match the exact allowed values (e.g., `likelihood` must be `Low`, `Medium`, or `High` — never `low` or `HIGH`)
- **Rating matrix compliance** — The combination of `likelihood` and `impact` must produce the correct `rating` per the matrix. If not, the assessment is invalid.
- **Minimum field lengths** — Narrative must be at least 100 characters, rationales at least 50 characters, actions at least 20 characters
- **Conditional requirements** — If `source_type` is `web_search` or `regulatory_publication`, a `url` field is required
- **Pattern validation** — Control IDs must match `C\d{3}`, recommendation IDs must match `R\d{3}`, challenge IDs must match `CH\d{3}`

### Rating Matrix

This is enforced at every validation checkpoint:

| Likelihood | Low Impact | Medium Impact | High Impact |
|------------|-----------|--------------|------------|
| **High** | Medium | High | **Critical** |
| **Medium** | Low | Medium | High |
| **Low** | Low | Low | Medium |

Only `High x High` produces `Critical`. This is the only way to reach `Critical` — it cannot be manually assigned.

---

## 10. Risk Categories

| Prefix | Category | Example Summary |
|--------|----------|----------------|
| A | Audit | Audit finding remediation delays |
| B | Business Continuity Management | BCM plan not tested within SLA |
| C | Compliance | Regulatory reporting deadline breach |
| D | Product / Design | Product feature exploited by users |
| ER | Expansion Risk | Regulatory licensing delays in new jurisdiction |
| F | Financial | Revenue concentration in single product |
| I | Investment | Counterparty default on fund holdings |
| L | Legal | Contract enforceability across jurisdictions |
| O | Operational | Operational process failure |
| OO | Other Operational | Miscellaneous operational risk |
| P | People | Key person dependency |
| T | Technology | System outage or cyber incident |

Filter batch mode by category: `/rr all T` (Technology only), `/rr all C` (Compliance only), etc. Multi-letter codes (`ER`, `OO`) are supported.

---

## 11. Regulatory Framework

Assessments are grounded in the following regulatory instruments. The skill verifies citations via web search during Step 2 (Adversarial Review).

### Singapore (MAS)

- Guidelines on Risk Management Practices -- Board and Senior Management (Revised March 2013)
- Guidelines on Risk Management Practices -- Operational Risk / GORM (2013; consultation 2026)
- Guidelines on Risk Management Practices -- Technology Risk / TRM (January 2021)
- Notice on Technology Risk Management / FSM-N05 (Effective 10 May 2024) -- **legally binding**
- Notice on Cyber Hygiene / FSM-N06 (Effective 10 May 2024) -- **legally binding**
- Guidelines on Business Continuity Management (June 2022) -- next BCM audit due by June 2027
- Guidelines on Outsourcing for FIs other than Banks (Revised 11 December 2024)
- Notice on Prevention of Money Laundering and Countering the Financing of Terrorism / SFA04-N02 (Updated 2024)
- Guidelines on Licensing, Registration and Conduct of Business for FMCs / SFA04-G05 (Revised October 2019)
- Notice on Risk Based Capital Adequacy Requirements / SFA04-N13
- Guidelines on Fair Dealing

### Hong Kong (SFC)

- Securities and Futures Ordinance (Cap 571)
- SFC Code of Conduct
- SFC Fund Manager Code of Conduct (FMCC)

### General Standards

- ISO 31000 -- Risk management principles
- COSO ERM -- Enterprise risk management

The full regulatory reference with applicability notes is in `~/.claude/skills/rr/references/regulatory-framework.md`.

---

## 12. Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `/rr doctor` shows `[FAIL]` for reference files | Installed via root `./install.sh` instead of per-skill installer | `cd skills/rr && ./install.sh --force` |
| `/rr RR-220` says "Atlassian MCP not available" | Atlassian MCP integration not connected | Connect Atlassian in Claude Code settings or at claude.ai |
| "Project RR not found" from Jira | Your Atlassian account doesn't have access to the RR project | Request access from Jira admin |
| Batch mode says "Missing required environment variables" | `ANTHROPIC_API_KEY`, `JIRA_EMAIL`, or `JIRA_API_KEY` not set | Add to `~/.zshrc` and `source ~/.zshrc` |
| Batch mode falls back to sequential | Orchestrator scripts missing or env vars not set | Run `/rr doctor` to identify what's missing |
| `jq: command not found` during batch | jq not installed | `brew install jq` |
| Batch progress lost | Work directory deleted or session crashed | Check `~/rr-work/progress.md` or `~/rr-output/rr-progress.md` |
| Duplicate Review tickets created | Ran batch twice on same day without `--force` | The quarterly filter should prevent this. If it didn't, check the filter-result.json for issues |
| Step 6 fails with 401 | Jira credentials expired or wrong | Regenerate API token at id.atlassian.com |
| Step 6 fails with 403 | No permission to create issues in RR project | Request Create permission from Jira admin |
| File attachments fail | `JIRA_EMAIL` or `JIRA_API_KEY` not set for curl-based attachment | Set both env vars |
| Assessment JSON validation fails | Sub-agent returned non-compliant data | Check the error in `~/rr-work/errors/`. The collect phase auto-corrects rating matrix violations but other errors are logged |
| `/rr update` says "source repo not configured" | Installed manually instead of via install.sh | Re-install: `cd skills/rr && ./install.sh --force` |
| Context limit reached during sequential batch | Too many risks processed in one session | Normal behaviour. Start a new chat and type `/rr all` to resume |

---

## 13. Security Considerations

### Secrets Handling

- **Environment variables only.** The skill never stores API keys, tokens, or credentials in files. All secrets are referenced via `$ANTHROPIC_API_KEY`, `$JIRA_EMAIL`, `$JIRA_API_KEY`, and `$SLACK_WEBHOOK_URL`.
- **Doctor never displays values.** The `/rr doctor` command reports whether variables are set, never their contents.
- **Orchestrator scripts inherit from shell.** Batch mode scripts read credentials from the environment at runtime. They are never written to disk.

### Jira Access

- **Read operations** use the Atlassian MCP integration (governed by your Claude Code MCP permissions).
- **Write operations** (creating Review tickets, attaching files) use MCP for ticket creation and `curl` with basic auth for file attachments.
- **The skill never modifies parent Risk items or existing child tickets.** This is an explicit prohibition enforced in the workflow instructions.

### Sub-Agent Isolation

- Batch mode sub-agents are **stateless API calls**. They have no tool access, no file system access, and no MCP access. They receive risk data and return JSON.
- All reference material (business context, regulatory framework, rating matrix) is embedded in the sub-agent system prompt. Sub-agents cannot access anything beyond what is provided.

### Output Files

- Assessment JSON files are written to `~/rr-output/` (configurable). These may contain sensitive business information (risk descriptions, control assessments, regulatory citations).
- Batch working files in `~/rr-work/` include raw API responses and Jira payloads.
- Neither directory is cleaned up automatically. Delete them manually when no longer needed.

---

## 14. Limitations

1. **Sub-agents cannot perform web search.** Batch mode sub-agents have no tool access. Regulatory citations are based on the embedded reference material only. Single-risk mode (interactive) does use web search for citation verification in Step 2.

2. **Sub-agents cannot access Jira directly.** All Jira I/O is handled by the orchestrator scripts or the main Claude session. Sub-agents only receive the risk data provided to them.

3. **Discussion step skipped in batch mode.** To enable autonomous processing, Step 4 (interactive discussion with user) is skipped in batch mode. Sub-agents perform self-adversarial review instead.

4. **Same-day file collisions.** If you run a single-risk review twice for the same risk on the same day, the second run overwrites the first (files use `<key>_<date>` naming without timestamps). This is by design for simplicity.

5. **Quarterly filter depends on Jira data.** The idempotency filter checks for existing Review tickets created in the current quarter. If Reviews are created outside the skill (manually in Jira), the filter still counts them.

6. **macOS only for batch orchestrator.** The shell scripts are adapted for macOS bash 3.2. They may work on Linux but have not been tested there.

7. **Maximum ~200 risks per batch session.** API rate limits constrain the practical batch size. The retry mechanism handles transient failures, but sustained rate limiting will leave batches in the error queue for `/rr fix`.

8. **Context window limits in sequential mode.** When processing risks sequentially (fallback mode), Claude's context window fills after approximately 3-5 risks. The progress file enables resumption across sessions, but each new session starts with fresh context.

---

<div align="center">
<sub>Part of <a href="https://github.com/oxygn-cloud-ai/claude-skills">claude-skills</a> by <a href="https://github.com/oxygn-cloud-ai">Oxygn Cloud AI</a></sub>
</div>
