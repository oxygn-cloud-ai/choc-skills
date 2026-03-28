<div align="center">

```
   _____ _                 _        ____  _    _ _ _
  / ____| |               | |      / ___|| | _(_) | |___
 | |    | | __ _ _   _  __| | ___ \___ \| |/ / | | / __|
 | |    | |/ _` | | | |/ _` |/ _ \ ___) |   <| | | \__ \
 | |____| | (_| | |_| | (_| |  __/|____/|_|\_\_|_|_|___/
  \_____|_|\__,_|\__,_|\__,_|\___|
```

**Community-built skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code)**

Install a skill. Type a slash command. Get superpowers.

---

[Install](#install) &nbsp;&bull;&nbsp; [Available Skills](#available-skills) &nbsp;&bull;&nbsp; [Add a Skill](#adding-a-new-skill)

---

</div>

## Available Skills

| Skill | Command | Description |
|-------|---------|-------------|
| **chk1** | `/chk1` | Adversarial implementation audit — fault-finding, risk-exposing, deviation-detecting review of recent changes |

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and working
- `git` (required by most skills)
- `bash` (macOS, Linux, or WSL on Windows)
- `curl` (only for manual install method)

## Install

### All skills

```bash
git clone https://github.com/oxygn-cloud-ai/claude-skills.git
cd claude-skills
./install.sh
```

### A specific skill

```bash
./install.sh chk1
```

### Manual (no clone needed)

```bash
mkdir -p ~/.claude/skills/chk1
curl -sL https://raw.githubusercontent.com/oxygn-cloud-ai/claude-skills/main/skills/chk1/SKILL.md \
  -o ~/.claude/skills/chk1/SKILL.md
```

### Pipe-friendly

```bash
curl -sL https://raw.githubusercontent.com/oxygn-cloud-ai/claude-skills/main/install.sh | bash
```

Non-interactive mode is auto-detected. Use `--force` to overwrite existing installations.

### Verify installation

```bash
./install.sh --check
```

### Update all skills

```bash
git pull && ./install.sh --update
```

### List available skills

```bash
./install.sh --list
```

### Uninstall

```bash
./install.sh --uninstall chk1        # Remove one skill
./install.sh --uninstall --all        # Remove all skills
```

## Installer Reference

```
./install.sh                    Install all skills
./install.sh <name>             Install a specific skill
./install.sh --uninstall <name> Uninstall a skill
./install.sh --uninstall --all  Uninstall all skills
./install.sh --update           Reinstall all (no prompts)
./install.sh --check            Verify installation health
./install.sh --list             List available skills
./install.sh --version          Show installer version
./install.sh --help             Full help

Options:
  -f, --force     Overwrite without prompting
  -q, --quiet     Suppress non-error output
```

## How Skills Work

Each skill lives in `skills/<name>/` and contains:

```
skills/chk1/
  SKILL.md      <- The skill definition (YAML frontmatter + instructions)
  README.md     <- Documentation
  install.sh    <- Per-skill installer (optional, delegates to root)
```

The installer copies `SKILL.md` to `~/.claude/skills/<name>/SKILL.md`, which Claude Code automatically discovers and makes available as a slash command.

### SKILL.md Format

```yaml
---
name: my-skill
version: 1.0.0
description: What it does (shown in skill listings)
user-invocable: true
disable-model-invocation: true       # only runs when YOU invoke it
allowed-tools: Read, Grep, Glob      # restrict tool access
argument-hint: [args | help | doctor | version]
---

# Skill instructions in Markdown...
```

Every skill should support these subcommands:
- `help` — usage guide
- `doctor` — environment health check
- `version` — installed version

## Adding a New Skill

1. Copy the template:
   ```bash
   cp -r _template skills/my-skill
   ```

2. Edit `skills/my-skill/SKILL.md` — fill in the frontmatter and write your instructions

3. Edit `skills/my-skill/README.md` — document usage, prerequisites, troubleshooting

4. Test locally:
   ```bash
   ./install.sh my-skill
   # Then in Claude Code: /my-skill help
   # Then: /my-skill doctor
   # Then: /my-skill (actual usage)
   ```

5. Submit a PR

## Project Structure

```
claude-skills/
  README.md            <- You are here
  install.sh           <- Root installer
  LICENSE              <- MIT
  _template/           <- Skeleton for new skills
    SKILL.md
    README.md
  skills/              <- All skills live here
    chk1/
      SKILL.md
      README.md
      install.sh
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Skill not appearing in Claude Code | Verify: `ls ~/.claude/skills/<name>/SKILL.md` |
| "Permission denied" during install | Check permissions: `ls -la ~/.claude/` |
| Skill is outdated | `git pull && ./install.sh --force <name>` |
| Installation health check fails | `./install.sh --check` then `./install.sh --update` |
| Non-interactive install skips skills | Add `--force`: `./install.sh --force` |

## License

MIT

---

<div align="center">
<sub>Built by <a href="https://github.com/oxygn-cloud-ai">Oxygn Cloud AI</a></sub>
</div>
