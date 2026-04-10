---
name: ra:update
description: "Update ra skill to latest version"
allowed-tools: Read, Bash(git *), Bash(bash *)
---

# ra:update — Update Skill to Latest Version

Same pattern as rr:update:
1. Read source repo path from `~/.claude/skills/ra/.source-repo`
2. If found: `git -C <repo-path> pull`, then `bash <repo-path>/skills/ra/install.sh --force`
3. If not found: show clone instructions for https://github.com/oxygn-cloud-ai/choc-skills.git
