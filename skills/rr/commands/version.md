---
name: rr:version
description: "Show installed rr version"
allowed-tools: Read
---

# rr:version — Show Installed Version

Read the `version:` field from `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/rr/SKILL.md` frontmatter and display:

```
rr v<version>
```

Do not continue after displaying the version.
