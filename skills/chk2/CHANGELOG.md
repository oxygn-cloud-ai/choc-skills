# Changelog — chk2

All notable changes to the chk2 skill will be documented in this file.

## [2.3.10] - 2026-04-17

### Fixed
- **Design precision**: `/chk2:all` orchestrator now (1) explicitly specifies `subagent_type: general-purpose` in Agent dispatch — previously omitted, silently defaulting — and (2) adds `Skipped` + `Reason` columns to the summary table so circuit-breaker-aborted waves are surfaced as SKIPPED with cause, rather than omitted silently or faked with zero counts. Prevents misleading audit summaries when waves abort or sub-agents return `CHK2-STATUS: ERROR` (CPT-90).

## [2.3.9] - 2026-04-17

### Fixed
- **Hang on unreachable target**: `chk2 doctor` target-reachability curl and the inline pre-flight curl lacked `--max-time` / `--connect-timeout`, causing up to 120-300s blocks on DNS timeouts or TCP black-holes before reporting unreachable. Added `--max-time 10 --connect-timeout 5` to both invocations in `SKILL.md`. Doctor/pre-flight now fail within ~10s on unreachable targets (CPT-63).

## [2.3.8] - 2026-04-17

### Fixed
- **P1 circuit breaker**: `/chk2:all`'s rate-limit circuit breaker had no wire protocol between sub-agents and orchestrator — counter would either never trip (signal missed) or trip spuriously (over-match on "429" in free text). Each of the 30 category sub-skills now ends its response with exactly one final `CHK2-STATUS: OK|RATE_LIMITED|ERROR` line. The orchestrator parses only that line, tracks a `rate_limited_streak`, resets to 0 on OK waves, and aborts after 3 consecutive RATE_LIMITED waves. Contract documented in `SKILL.md` (CPT-89).

### Note on version renumbering
- CPT-89 source branch targeted 2.3.5; 2.3.5–2.3.7 all shipped earlier this cycle, so renumbered to 2.3.8.

## [2.3.7] - 2026-04-17

### Fixed
- **P1 race condition**: `/chk2:all` parallel waves (6 concurrent Agents) previously appended to a single `SECURITY_CHECK.md`, causing silent findings loss under the classic lost-update pattern. Each category sub-skill now writes its section to its own `SECURITY_CHECK.parts/<category>.md` file (one writer per file, no race). The orchestrator (`/chk2:all`) merges parts into `SECURITY_CHECK.md` in deterministic wave order after all waves complete. `/chk2:quick` uses the same pattern for consistency (CPT-88).

### Note on version renumbering
- CPT-88 source branch targeted 2.3.5; 2.3.5 (CPT-76), 2.3.6 (CPT-77) shipped earlier this cycle, so renumbered to 2.3.7.

## [2.3.6] - 2026-04-17

### Fixed
- **Exit-code contract**: `install.sh --check` now exits non-zero when issues are reported (was unconditional `exit 0`). Aligns with root `install.sh --check` behavior (CPT-77).

### Note on version renumbering
- CPT-77 source branch targeted 2.3.5; CPT-76 took 2.3.5 at merge time, so renumbered to 2.3.6.

## [2.3.5] - 2026-04-17

### Fixed
- **Argument parsing**: `install.sh` now uses an order-independent while-loop parser instead of positional `$1` checks. `-f --uninstall` (and other flag combinations) now uninstalls instead of silently re-installing. Unknown flags now exit non-zero (CPT-76).

## [2.3.4] - 2026-04-17

### Changed
- **Performance**: `update.md` parallelises curl downloads with `xargs -P 4` (was sequential `for` loop over 35 command files) (CPT-19).

### Note on version renumbering
- CPT-19's source branch bumped 2.2.0 → 2.2.1 in isolation. By merge time, 2.3.0–2.3.3 had all shipped, so the Merger renumbered CPT-19 to 2.3.4. No code semantics changed.

## [2.3.3] - 2026-04-17

### Changed
- **Performance/Security**: Reduced SKILL.md router `allowed-tools` from 25 entries to 8 (`Read, Grep, Glob, Bash(curl *), Bash(which *), Bash(ls *), Write, AskUserQuestion`) (CPT-32).
- Added YAML frontmatter with per-command `allowed-tools` to all 35 sub-command files.
- Each sub-command now declares only the tools it needs (e.g., `tls.md` gets openssl, `dns.md` gets dig+host+nmap, `github.md` gets gh).
- Eliminated `Bash(bash *)` catch-all from chk2 sub-commands (`update.md` uses scoped `Bash(bash install.sh *)` instead).

### Note on version renumbering
- CPT-32's source branch bumped 2.2.0 → 2.3.0 in isolation. By merge time, 2.3.0/2.3.1/2.3.2 had all shipped, so the Merger renumbered CPT-32 to 2.3.3. No code semantics changed.

## [2.3.2] - 2026-04-17

### Changed
- **Performance**: fingerprint.md FP1-FP4 consolidated from 5 curl calls to 1 (saves 4 HTTP requests) (CPT-18)
- **Performance**: reporting.md RC3+RC4 merged into single fetch — RC4 reuses security.txt content from RC3 (saves 2 HTTP requests) (CPT-18)
- **Performance**: backend.md BF3 timing reduced from 5 to 3 iterations per path (saves 10 HTTP requests) (CPT-18)
- **Performance**: timing.md TM1-TM2 reduced from 5 to 3 iterations each (saves 8 HTTP requests) (CPT-18)
- **Performance**: waf.md F6 rate limit test now has `--max-time 5` per request (prevents hangs) (CPT-18)

### Note on version renumbering
- CPT-18's source branch bumped 2.2.0 → 2.2.2 in isolation. By merge time, 2.3.0 (CPT-8) and 2.3.1 (CPT-16) had already shipped, so the Merger renumbered CPT-18 to 2.3.2. No code semantics changed.

## [2.3.1] - 2026-04-17

### Changed
- **Performance**: RE1 Slowloris test uses ThreadPoolExecutor for concurrent connections (was serial with 30s sleep) — saves ~24s per run (CPT-16)
- **Performance**: AU3 session test uses jq instead of python3 for JSON parsing (eliminates 22 interpreter startups) (CPT-16)
- **Performance**: SE2 SSE test discovers valid path first, then tests concurrency on that path only (avoids 20x redundant 404 probes) (CPT-16)

### Note on version renumbering
- CPT-16's source branch bumped 2.2.0 → 2.2.1 in isolation. By merge time, 2.3.0 (CPT-8) had already shipped, so the Merger renumbered CPT-16 to 2.3.1. No code semantics changed.

## [2.3.0] - 2026-04-14

### Changed
- `/chk2:all` now dispatches 30 categories in 5 parallel waves of 6 using Agent tool calls instead of running all sequentially. Reduces wall-clock time from ~30+ min to ~5-10 min. (CPT-8)
- Added circuit breaker: 3 consecutive waves hitting rate limits aborts remaining waves

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
