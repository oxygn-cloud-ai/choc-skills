---
name: rr:update
description: "Update rr skill to latest version"
allowed-tools: Read, Bash(git *), Bash(bash *)
---

# rr:update — Update Skill to Latest Version

Context from user: $ARGUMENTS

## Update Process

1. Read the source repo path from `~/.claude/skills/rr/.source-repo`

2. If found:
   - Run `git -C <repo-path> pull` to update the repo
   - Always run `<repo-path>/install.sh --force` (the per-skill installer, which updates SKILL.md, bin scripts, reference files, sub-commands, and router). The script is executable and has a shebang — invoke it directly, not via `bash`.
   - Report the installed version after install completes (read from the freshly installed `~/.claude/skills/rr/SKILL.md`)

3. If `.source-repo` not found:
   ```
   rr update — source repo not configured.
   Clone the repo and run install.sh to set up the source link:
     git clone https://github.com/oxygn-cloud-ai/choc-skills.git
     cd choc-skills/skills/rr
     ./install.sh
   ```
