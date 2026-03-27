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

[Install](#install) &nbsp;&bull;&nbsp; [Add a Skill](#adding-a-new-skill)

---

</div>

## Available Skills

| Skill | Command | Description |
|-------|---------|-------------|
| **chk1** | `/chk1` | Adversarial implementation audit — fault-finding, risk-exposing, deviation-detecting review of recent changes |

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

### List available skills

```bash
./install.sh --list
```

### Uninstall a skill

```bash
rm -rf ~/.claude/skills/<skill-name>
```

## How Skills Work

Each skill lives in `skills/<name>/` and contains:

```
skills/chk1/
  SKILL.md      <- The skill definition (YAML frontmatter + instructions)
  README.md     <- Documentation
  install.sh    <- Per-skill installer (optional)
```

The installer copies `SKILL.md` to `~/.claude/skills/<name>/SKILL.md`, which Claude Code automatically discovers and makes available as a slash command.

### SKILL.md Format

```yaml
---
name: my-skill
description: What it does (shown in skill listings)
user-invocable: true
disable-model-invocation: true       # only runs when YOU invoke it
allowed-tools: Read, Grep, Glob      # restrict tool access
argument-hint: [optional args]
---

# Skill instructions in Markdown...
```

## Adding a New Skill

1. Copy the template:
   ```bash
   cp -r _template skills/my-skill
   ```

2. Edit `skills/my-skill/SKILL.md` — fill in the frontmatter and write your instructions

3. Edit `skills/my-skill/README.md` — document usage

4. Test locally:
   ```bash
   ./install.sh my-skill
   # Then in Claude Code: /my-skill
   ```

5. Submit a PR

## Project Structure

```
claude-skills/
  README.md            <- You are here
  install.sh           <- Root installer (all skills or by name)
  _template/           <- Skeleton for new skills
    SKILL.md
    README.md
  skills/              <- All skills live here
    chk1/
      SKILL.md
      README.md
      install.sh
```

## License

MIT

---

<div align="center">
<sub>Built by <a href="https://github.com/oxygn-cloud-ai">Oxygn Cloud AI</a></sub>
</div>
