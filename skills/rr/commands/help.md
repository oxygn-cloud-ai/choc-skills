# rr:help — Usage Guide

First, read the `version:` field from `~/.claude/skills/rr/SKILL.md` frontmatter to get the current version number.

Display the following and stop. Do not proceed to any other action. Replace `{version}` with the actual version read above.

```
rr v{version} — Risk Register Assessment

USAGE
  /rr RR-220           Review a specific risk (interactive 6-step workflow)
  /rr all              Batch review all risks (parallel sub-agents)
  /rr all --force      Batch all risks, ignore quarterly filter
  /rr all T            Batch Technology risks only
  /rr all --reset      Clear batch work directory
  /rr status           Check batch progress (snapshot)
  /rr monitor          Real-time batch progress monitor (live refresh)
  /rr fix              Re-run failed assessments
  /rr update           Update rr to latest version
  /rr help             Display this usage guide
  /rr doctor           Check environment health
  /rr version          Show installed version

MODES
  Single Risk    /rr RR-NNN    Interactive 6-step workflow with user discussion
  Batch Mode     /rr all       Autonomous parallel processing via Claude Code agents

ENVIRONMENT VARIABLES
  RR_OUTPUT_DIR         Output directory (default: ~/rr-output)
  RR_WORK_DIR           Batch work directory (default: ~/rr-work)
  JIRA_EMAIL            Required for batch mode Jira API
  JIRA_API_KEY          Required for batch mode Jira API
  SLACK_WEBHOOK_URL     Optional batch completion notification

WORKFLOW (Single Risk)
  Step 1: Extract & Draft     Retrieve from Jira, initial assessment
  Step 2: Adversarial Review  Challenge against 8 criteria
  Step 3: Rectified Assessment Address challenges
  Step 4: Discussion          Resolve uncertainties with user
  Step 5: Final Assessment    User confirms before publishing
  Step 6: Publish to Jira     Create Review child ticket

LOCATION
  ~/.claude/skills/rr/SKILL.md
  ~/.claude/commands/rr/*.md (sub-commands)
  ~/.claude/skills/rr/orchestrator/ (batch scripts)
  ~/.claude/skills/rr/references/ (schemas, workflow, context)
```

End of help output. Do not continue.
