# Changelog — chk2

All notable changes to the chk2 skill will be documented in this file.

## [2.2.0] - 2026-04-09

### Changed
- **Security**: Restricted `Bash(*)` to explicit command patterns (`Bash(curl *)`, `Bash(dig *)`, `Bash(openssl *)`, etc.)
- Updated check counts to match actual command files (Core 131, Extended 80, Total 211)
- Updated inline fallback test definitions (TLS 12, DNS 15, API 17, WS 13, WAF 12, Scale 10)
- Per-skill installer now cleans stale command files before installing new version
- Health check threshold updated from 33 to 35 sub-commands

### Fixed
- Help output sub-command count corrected from 33 to 35
- Stale sub-command files no longer persist after upgrade

## [2.1.0] - 2026-04-07

### Added
- New `/chk2 github` subcommand logs SECURITY_CHECK.md FAIL/WARN findings as GitHub Issues with P1-P4 priority labels, category labels, duplicate detection, and milestone assignment
- New `/chk2 update` command file (extracted from inline SKILL.md block) — uses `.source-repo` marker if present, falls back to curl

### Changed
- Replaced inline `## Update Subcommand` block in SKILL.md with routing entries to `commands/update.md` and `commands/github.md`

## [2.0.0] - 2026-04-01

### Added
- Initial release: adversarial security audit for web services
- 11 core test categories (~109 checks): headers, TLS, DNS, CORS, API injection, WebSocket, WAF, infrastructure, brute force, scaling, info disclosure
- 19 extended test categories (~100 checks): cookies, cache, smuggling, auth, transport, redirect, fingerprint, timing, compression, JWT, GraphQL, SSE, IPv6, reporting, hardening, negotiation, proxy, business, backend
- Per-skill installer with router and 33 command file installation
- Deep resolution helper (`/chk2 fix`) with Cloudflare, server-side, and DNS fix guidance
- Results output to SECURITY_CHECK.md
