# my-skill — Short Description

A Claude Code skill that does X.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- List any other requirements (git, node, etc.)

## Installation

### From repo root (recommended)

```bash
./install.sh my-skill
```

### Manual (no clone needed)

```bash
mkdir -p ~/.claude/skills/my-skill
curl -sL https://raw.githubusercontent.com/oxygn-cloud-ai/claude-skills/main/skills/my-skill/SKILL.md \
  -o ~/.claude/skills/my-skill/SKILL.md
```

## Usage

In Claude Code:

```
/my-skill              Run with defaults
/my-skill <arg>        Run with a specific argument
/my-skill doctor       Check environment health
/my-skill help         Display usage guide
```

## What it does

Describe the skill's purpose and methodology.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Skill not appearing | Verify: `ls ~/.claude/skills/my-skill/SKILL.md` |
| Skill is outdated | `./install.sh --force my-skill` |

## Update

```bash
cd claude-skills && git pull && ./install.sh --force my-skill
```

## Uninstall

```bash
./install.sh --uninstall my-skill
```

## Version

Current: **1.0.0**

## License

MIT
