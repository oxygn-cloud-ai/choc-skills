# OPSvdd:update — Update Skill to Latest Version

Context from user: $ARGUMENTS

## Update process

1. Read the source repo path from `~/.claude/skills/OPSvdd/.source-repo`.

2. If found:
   - Run `git -C <repo-path> pull` to update the repo.
   - Always run `bash <repo-path>/install.sh --force` (the per-skill installer, which updates SKILL.md, subcommand files, references/, and router).
   - Report the installed version after install completes (read from the freshly installed `~/.claude/skills/OPSvdd/SKILL.md`).

3. If `.source-repo` not found:

   ```
   OPSvdd update — source repo not configured.
   Clone the repo and run install.sh to set up the source link:

     git clone https://github.com/oxygn-cloud-ai/choc-skills.git
     cd choc-skills/skills/OPSvdd
     bash install.sh
   ```
