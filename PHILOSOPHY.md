# PHILOSOPHY.md — choc-skills

## Vision

A complete, AI-native operational toolkit for Chocolate Finance. In 12 months, choc-skills replaces manual processes across risk, security, compliance, project management, and infrastructure — Claude becomes the primary operator for routine work.

## Mission

Give the Chocolate Finance team professional-grade skills that make Claude Code deeply capable in every operational domain the business needs. Each skill is an expert, not a generalist.

## Audience

Internal — built for Chocolate Finance's specific workflows, standards, and compliance requirements.

## Design Principles

Ordered by priority:

1. **Deep over broad.** Each skill must be expert-level in its domain. A skill that does one thing with mastery beats a skill that superficially covers many. If a skill can't go deep, it shouldn't exist yet.

2. **Safety always.** Skills must never store, expose, or modify credentials or secrets. Every action must be traceable and explainable. Destructive operations require reversibility by design.

3. **Configuration is explicit.** Skills require configuration by the user and by the project. No hidden defaults that silently change behavior. The user and project `CLAUDE.md` / `PROJECT_CONFIG.json` are the authoritative sources of truth for how a skill behaves in context.

4. **Session-aware.** Skills respect the multi-session architecture. A skill knows which role is calling it and adjusts behavior accordingly — a fixer session gets different affordances than a reviewer session.

5. **Trust the skill, ensure reversibility.** Skills can act autonomously on external systems (Jira, GitHub) within their documented scope. But every external write must be reversible — creates can be deleted, updates can be rolled back. No one-way doors.

6. **Independence.** Every skill works standalone. No hidden dependencies between skills. A user can install one skill without needing any other.

## Quality Bar

No skill ships without ALL of:

- Full BATS test coverage
- Complete README.md with usage, examples, and troubleshooting
- `help`, `doctor`, and `version` subcommands
- CHANGELOG.md
- Passing `validate-skills.sh` with zero errors
- Passing `/chk1` adversarial audit
- Regenerated checksums

This bar is non-negotiable. A skill that doesn't meet it stays in a branch.

## Non-Negotiables

These are absolute rules with zero exceptions:

1. **Credential safety.** Skills must never store, expose, or modify credentials, API keys, tokens, or secrets. Not for any reason, not ever.

2. **Auditability.** Every action a skill takes must be traceable. If someone asks "what did this skill do and why?", the answer must be findable in logs, commits, or Jira.

3. **Independence.** Skills work standalone. Installing skill A must never require skill B. Skills may complement each other but must never depend on each other.

4. **Reversibility.** Every external action must have an undo path. If a skill creates a Jira issue, it must be deletable. If it modifies a label, the old state must be recoverable. No one-way doors in automation.
