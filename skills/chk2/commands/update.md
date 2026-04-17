---
name: chk2:update
description: "Update chk2 skill to latest version"
allowed-tools: Read, Bash(git *), Bash(bash install.sh *), Bash(curl *), Bash(grep *), Bash(sed *)
---

# chk2:update — Update Skill to Latest Version

Context from user: $ARGUMENTS

## Update Process

1. Read the source repo path from `~/.claude/skills/chk2/.source-repo` (if it exists).

2. **If `.source-repo` exists:**
   - Run `git -C <repo-path> pull` to update the local clone
   - Run `bash <repo-path>/skills/chk2/install.sh --force` to reinstall (updates SKILL.md, sub-commands, and router)
   - Read the installed version from `~/.claude/skills/chk2/SKILL.md` and report:
     ```
     chk2 update — Updated to vX.Y.Z (33 sub-commands installed)
     Restart Claude Code to pick up changes.
     ```

3. **If `.source-repo` is missing**, fall back to a curl-based update:

   a. Read the currently installed version:
      ```bash
      INSTALLED_VER=$(grep -m1 '^version:' ~/.claude/skills/chk2/SKILL.md | sed 's/^version: *//')
      ```

   b. Fetch the remote version:
      ```bash
      REPO="https://raw.githubusercontent.com/oxygn-cloud-ai/choc-skills/main"
      REMOTE_VER=$(curl -sf "$REPO/skills/chk2/SKILL.md" | grep -m1 '^version:' | sed 's/^version: *//')
      ```

   c. If `curl` fails (network down, repo unreachable):
      ```
      chk2 update — Could not reach the remote repo. Check your network and try again.
      ```

   d. If `INSTALLED_VER == REMOTE_VER`:
      ```
      chk2 update — already at vX.Y.Z (latest)
      ```

   e. If a newer version is available, download all files:
      ```bash
      curl -sL "$REPO/skills/chk2/SKILL.md" -o ~/.claude/skills/chk2/SKILL.md
      mkdir -p ~/.claude/commands/chk2
      echo "all quick headers tls dns cors api ws waf infra brute scale disclosure \
            fix github update cookies cache smuggling auth transport redirect \
            fingerprint timing compression jwt graphql sse ipv6 reporting hardening \
            negotiation proxy business backend" | tr ' ' '\n' | grep -v '^$' | \
        xargs -P 4 -I{} curl -sL "$REPO/skills/chk2/commands/{}.md" -o ~/.claude/commands/chk2/{}.md
      ```

   f. Report the result:
      ```
      chk2 update — Updated from vX.Y.Z to vA.B.C
      Restart Claude Code to pick up changes.
      ```

4. **Note about `.source-repo`**: This marker file is created by the per-skill `install.sh` so future updates know where the cloned repo lives. If you cloned the repo and ran `bash skills/chk2/install.sh`, the marker should be present. If you installed via curl manually, only the curl-based update path will work.
