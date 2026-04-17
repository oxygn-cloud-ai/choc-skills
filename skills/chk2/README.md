# chk2 — Adversarial Security Audit

A Claude Code skill that runs comprehensive security audits against web services. Tests across 30 categories with ~209 individual checks, outputs a scored report, and offers guided remediation.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- `curl`, `dig`, `openssl` (standard on macOS/Linux)
- `python3` with `websockets` package (`pip3 install websockets`)

## Installation

### From repo root (recommended)

```bash
./install.sh chk2
```

### Standalone (from skill directory)

```bash
cd skills/chk2
./install.sh
```

### Manual (no clone needed)

```bash
# Main skill
mkdir -p ~/.claude/skills/chk2
curl -sL https://raw.githubusercontent.com/oxygn-cloud-ai/choc-skills/main/skills/chk2/SKILL.md \
  -o ~/.claude/skills/chk2/SKILL.md

# Sub-commands
mkdir -p ~/.claude/commands/chk2
for f in all headers tls dns cors api ws waf infra brute scale disclosure quick fix; do
  curl -sL "https://raw.githubusercontent.com/oxygn-cloud-ai/choc-skills/main/skills/chk2/commands/${f}.md" \
    -o ~/.claude/commands/chk2/${f}.md
done
```

## Usage

In Claude Code:

```
/chk2                Run all test categories (~100 checks)
/chk2 all            Same as above
/chk2 quick          Fast passive-only subset (headers+tls+dns+cors)
/chk2 headers        HTTP security headers (14 checks)
/chk2 tls            TLS/SSL configuration (9 checks)
/chk2 dns            DNS, DNSSEC, email security (10 checks)
/chk2 cors           CORS and origin validation (8 checks)
/chk2 api            API fuzzing, injection, type confusion (12 checks)
/chk2 ws             WebSocket security (10 checks)
/chk2 waf            WAF rules and rate limiting (10 checks)
/chk2 infra          Cloudflare infrastructure (12 checks)
/chk2 brute          Session enumeration (8 checks)
/chk2 scale          Connection limits, payload sizes (6 checks)
/chk2 disclosure     Information disclosure (10 checks)
/chk2 fix            Deep resolution helper for failed checks
/chk2 doctor         Check environment health
/chk2 help           Display usage guide
```

## What it does

Runs adversarial security tests against a target web service and produces `SECURITY_CHECK.md` with PASS/FAIL/WARN results and evidence for every check.

### Test categories

| Category | Checks | What it tests |
|----------|--------|---------------|
| headers | 14 | HSTS, CSP, X-Frame-Options, CORS, referrer policy |
| tls | 9 | TLS versions, ciphers, OCSP, certificate validity |
| dns | 10 | DNSSEC, SPF, DMARC, CAA, NS records |
| cors | 8 | CORS policy, preflight, WebSocket origin validation |
| api | 12 | Injection (SQLi, NoSQL, prototype pollution, command, template), fuzzing |
| ws | 10 | Origin check, connection limits, message flood, binary frames |
| waf | 10 | Scanner UA blocking, rate limiting, method restrictions |
| infra | 12 | CF config, source exposure, path traversal, error page leaks |
| brute | 8 | Session ID entropy, pair code strength, enumeration resistance |
| scale | 6 | Payload limits, nesting depth, concurrent connections |
| disclosure | 10 | Error pages, stack traces, version headers, data exposure |

### Fix helper

After any test run, say "yes" when asked **"Do you want help fixing this?"** to get:

- Exact Cloudflare dashboard paths and settings
- Copy-pasteable server code fixes
- DNS record changes
- Verification commands for each fix
- Fixes grouped by effort level (instant / quick / deeper)

## File structure

```
skills/chk2/
  SKILL.md              Main skill definition
  README.md             This file
  install.sh            Installer (skill + sub-commands)
  commands/
    all.md              Run all categories
    quick.md            Fast passive subset
    headers.md          HTTP headers tests
    tls.md              TLS/SSL tests
    dns.md              DNS tests
    cors.md             CORS tests
    api.md              API fuzzing tests
    ws.md               WebSocket tests
    waf.md              WAF tests
    infra.md            Infrastructure tests
    brute.md            Brute force tests
    scale.md            Scaling tests
    disclosure.md       Info disclosure tests
    fix.md              Deep resolution helper
```

## Installs to

```
~/.claude/skills/chk2/SKILL.md          Main skill
~/.claude/commands/chk2.md              Router (dispatches to sub-commands)
~/.claude/commands/chk2/*.md            14 sub-command files
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Skill not appearing | `ls ~/.claude/skills/chk2/SKILL.md` |
| Sub-commands not found | `ls ~/.claude/commands/chk2/*.md` |
| WebSocket tests fail | `pip3 install websockets` |
| Rate limited during tests | Tests auto-retry after 65s wait |
| Target unreachable | Check server is running, try `/chk2 doctor` |

## Update

```bash
cd choc-skills && git pull && ./install.sh --force chk2
```

## Uninstall

```bash
cd skills/chk2 && ./install.sh --uninstall
```

Or manually:
```bash
rm -rf ~/.claude/skills/chk2 ~/.claude/commands/chk2 ~/.claude/commands/chk2.md
```

## Version

Current: **2.3.21**

## License

MIT
