---
name: chk1:update
description: Update chk1 skill to latest version from source repo or GitHub
allowed-tools: Read, Bash(git *), Bash(bash install.sh *), Bash(curl *), Bash(mkdir *), Bash(grep *), Bash(sed *), Bash(xargs *), Bash(echo *), Bash(tr *)
---

# chk1:update — Update Skill to Latest Version

Context from user: $ARGUMENTS

## Update Process

1. Read the source repo path from `~/.claude/skills/chk1/.source-repo` (if it exists).

2. **If `.source-repo` exists:**
   - Run `git -C <repo-path> pull` to update the local clone
   - Run `bash <repo-path>/skills/chk1/install.sh --force` to reinstall (updates SKILL.md, sub-commands, and router)
   - Read the installed version from `~/.claude/skills/chk1/SKILL.md` and report:
     ```
     chk1 update — Updated to vX.Y.Z
     Restart Claude Code to pick up changes.
     ```

3. **If `.source-repo` is missing**, fall back to a curl-based update:

   a. Read the currently installed version:
      ```bash
      INSTALLED_VER=$(grep -m1 '^version:' ~/.claude/skills/chk1/SKILL.md | sed 's/^version: *//')
      ```

   b. Fetch the remote version:
      ```bash
      REPO="https://raw.githubusercontent.com/oxygn-cloud-ai/choc-skills/main"
      REMOTE_VER=$(curl -sf "$REPO/skills/chk1/SKILL.md" | grep -m1 '^version:' | sed 's/^version: *//')
      ```

   c. If `curl` fails (network down, repo unreachable):
      ```
      chk1 update — Could not reach the remote repo. Check your network and try again.
      ```

   d. If `INSTALLED_VER == REMOTE_VER`:
      ```
      chk1 update — already at vX.Y.Z (latest)
      ```

   e. If a newer version is available, download all files:
      ```bash
      curl -sL "$REPO/skills/chk1/SKILL.md" -o ~/.claude/skills/chk1/SKILL.md
      mkdir -p ~/.claude/commands/chk1
      echo "all quick security scope architecture fix github update" | tr ' ' '\n' | \
        xargs -P 4 -I{} curl -sL "$REPO/skills/chk1/commands/{}.md" -o ~/.claude/commands/chk1/{}.md
      ```

   f. Report the result:
      ```
      chk1 update — Updated from vX.Y.Z to vA.B.C
      Restart Claude Code to pick up changes.
      ```

4. **Note about `.source-repo`**: This marker file is created by the per-skill `install.sh` so future updates know where the cloned repo lives. If you cloned the repo and ran `bash skills/chk1/install.sh`, the marker should be present. If you installed via curl manually, only the curl-based update path will work.
