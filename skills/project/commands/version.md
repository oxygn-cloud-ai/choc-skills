---
name: project-version
description: Show installed skill version
allowed-tools:
  - Bash
  - Read
---

# project:version — Show Installed Version

Read the `version:` line from `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/project/SKILL.md` frontmatter and output:

```
project vX.Y.Z
```

If the file is missing, output: `project (not installed)`.

Stop after displaying.
