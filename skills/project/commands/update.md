---
name: project-update
description: Update project skill to latest version
allowed-tools:
  - Read
  - Bash
---

# project:update — Update Skill to Latest Version

Context from user: $ARGUMENTS

## Update Process

1. Read the source repo path from `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/project/.source-repo`

2. If found:
   - Run `git -C <repo-path>/../../.. pull` to update the choc-skills repo (source-repo points at `skills/project`, so go up 3 levels to repo root)
   - Always run `bash <repo-path>/install.sh --force` (the per-skill installer, which updates SKILL.md, sub-commands, and router)
   - Report the installed version after install completes (read from the freshly installed `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/project/SKILL.md`)

3. If `.source-repo` not found:
   ```
   project update — source repo not configured.
   Clone the repo and run install.sh to set up the source link:
     git clone https://github.com/oxygn-cloud-ai/choc-skills.git
     cd choc-skills/skills/project
     bash install.sh
   ```
