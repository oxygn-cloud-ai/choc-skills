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

[Install](#install) &bull; [Skills](#skills) &bull; [Contributing](CONTRIBUTING.md)

---

</div>

## Skills

| Skill | Version | Command | Description | Docs |
|-------|---------|---------|-------------|------|
| **chk1** | v2.4.9 | `/chk1` | Adversarial implementation audit — fault-finding, risk-exposing review of code changes | [README](skills/chk1/README.md) |
| **chk2** | v2.3.20 | `/chk2` | Adversarial security audit for web services — 211 checks across 30 categories | [README](skills/chk2/README.md) |
| **project** | v1.2.7 | `/project` | Project repository administration — create, audit, configure, status check with multi-session workflow scaffolding | [README](skills/project/README.md) |
| **ra** | v1.0.8 | `/ra` | Bespoke risk assessment — interview-driven assessment of documents, initiatives, concepts, incidents | [README](skills/ra/README.md) |
| **rr** | v5.3.20 | `/rr` | Risk register assessment — interactive 6-step workflow or autonomous batch mode | [README](skills/rr/README.md) |

## Standalone Tools

| Tool | Description | Docs |
|------|-------------|------|
| **iterm2-tmux** | iTerm2 + tmux tab orchestration — one coloured tab per repo directory (macOS only) | [README](skills/iterm2-tmux/README.md) |

## Install

### All skills

```bash
git clone https://github.com/oxygn-cloud-ai/choc-skills.git
cd choc-skills
./install.sh
```

Skills with sub-commands (chk1, chk2, project, ra, rr) have per-skill installers for full setup. The root installer will prompt you when a per-skill installer is available.

### A specific skill

```bash
./install.sh chk1
```

### Full setup (with sub-commands and routers)

```bash
cd skills/chk1 && ./install.sh    # or chk2, project, ra, rr
```

### Verify

```bash
./install.sh --check
```

### Update

```bash
git pull && ./install.sh --update
```

### Uninstall

```bash
./install.sh --uninstall chk1        # Remove one skill
./install.sh --uninstall --all        # Remove all skills
```

## Adding a New Skill

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide. Quick version:

1. `cp -r _template skills/my-skill`
2. Edit `SKILL.md` and `README.md`
3. Create `CHANGELOG.md` in the skill directory
4. Run `./scripts/validate-skills.sh`
5. Submit a PR

## License

MIT

---

<div align="center">
<sub>Built by <a href="https://github.com/oxygn-cloud-ai">Oxygn Cloud AI</a></sub>
</div>
