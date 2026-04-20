---
name: ra:version
description: "Show installed ra version"
allowed-tools: Read
---

# ra:version — Show Installed Version

Read `version:` from `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/ra/SKILL.md` frontmatter and display:
```
ra v<version>
```
Do not continue after displaying the version.
