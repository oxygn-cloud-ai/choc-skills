---
name: my-skill
version: 1.0.0
description: Brief description of what this skill does.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(*)
argument-hint: [optional arguments | help | doctor | version]
---

# My Skill Name

## Subcommands

Check $ARGUMENTS before proceeding. If it matches one of the following subcommands, execute that subcommand and stop.

### help

If $ARGUMENTS equals "help", "--help", or "-h", display the following usage guide and stop.

```
my-skill v1.0.0 — Short description

USAGE
  /my-skill                Run with defaults
  /my-skill <arg>          Run with a specific argument
  /my-skill help           Display this usage guide
  /my-skill doctor         Check environment health
  /my-skill version        Show installed version

WHAT IT DOES
  Describe what the skill does in 2-3 sentences.

TOOLS USED
  List the tools this skill uses.

LOCATION
  ~/.claude/skills/my-skill/SKILL.md
```

End of help output. Do not continue.

### doctor

If $ARGUMENTS equals "doctor", "--doctor", or "check", run environment diagnostics and stop.

**Checks:**
1. Verify any required tools are available (e.g., git, node, etc.)
2. Verify any required environment state (e.g., inside a git repo)
3. Report installed skill version
4. Report any issues with clear fix instructions

Format:
```
my-skill doctor — Environment Health Check

  [PASS] Check description: result
  [WARN] Check description: result
  [FAIL] Check description: result — how to fix

  Result: N passed, N warnings, N failed
```

End of doctor output. Do not continue.

### version

If $ARGUMENTS equals "version", "--version", or "-v", output the version and stop.

```
my-skill v1.0.0
```

End of version output. Do not continue.

---

## Pre-flight Checks

Before executing the skill, silently verify prerequisites. If any check fails, stop with a clear error and do not proceed.

1. **Required tool available**: (e.g., `git --version`). If not found:
   > **my-skill error**: <tool> is not installed or not in PATH.

2. **Required state**: (e.g., inside a git repo). If not met:
   > **my-skill error**: <describe what's wrong and how to fix it>.

---

## Instructions

Describe the skill's behavior, methodology, and output format here.
