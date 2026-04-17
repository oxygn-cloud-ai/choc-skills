# Changelog — chk2

All notable changes to the chk2 skill will be documented in this file.

## [2.3.15] - 2026-04-18

### Fixed
- **Conflicting action flags in `install.sh` now die at parse time** (CPT-123): see the chk1 entry for the full write-up. Same fix, applied identically to chk2's per-skill installer; `--help --uninstall` / `--version --uninstall` / `--uninstall --check` now error out with `Conflicting action flags: --<prev> and <current> — pick one` instead of silently running the last action.

**Note on version renumbering**: This entry originally targeted 2.3.14 on `fix/CPT-123-installer-conflict-detection`, but CPT-115 (update xargs allowed-tools) landed on `main` and claimed 2.3.14 first. Renumbered to 2.3.15 as part of the merge sequence; no code semantics changed from the original branch.

## [2.3.14] - 2026-04-17

### Fixed
- **`/chk2 update` tool-denied under CPT-32 enforcement**: CPT-19 rewrote the update body to fetch 35 sub-commands in parallel via `echo "…" | tr ' ' '\n' | xargs -P 4 -I{} curl ...` but didn't extend `skills/chk2/commands/update.md`'s `allowed-tools` frontmatter. Under per-command enforcement, `xargs`, `echo`, and `tr` were denied, the parallel-download stage failed, and the update flow silently left sub-commands un-updated. Added `Bash(xargs *), Bash(echo *), Bash(tr *)` to the update allowed-tools list (CPT-115).

## [2.3.13] - 2026-04-17

### Fixed
- **Timing-test sample stability on CDN-fronted targets**: CPT-18 reduced TM1/TM2 (timing.md) and BF3 (backend.md) from 5 → 3 samples per side for perf. Against a CDN, a single slow response moves the 3-sample mean by more than the 50 ms PASS/WARN threshold, flipping verdicts on network jitter rather than application behaviour. Restored to 5 samples per side and updated the Checks table to specify "median" as the comparison statistic so the auditor uses a robust stat. No net runtime regression — same as pre-CPT-18 cost (CPT-106).
- **Vacuous RC4 regression test**: `tests/chk2-redundant-requests.bats` RC4 test used `sed -n '/^# RC4/,/^\`\`\`$/p'` against a file where `# RC4` is an indented comment inside an else-branch — the range never matched, `grep -c curl` returned 0, and the test silently passed regardless of content. Rewrote to inspect the merged RC3+RC4 block directly (from `# RC3 + RC4:` header through the closing outer `fi`) and assert exactly 1 curl call. A future edit that reintroduces a dedicated RC4 curl would now drive the count to ≥2 and fail this test (CPT-106).

**Note on version renumbering**: This entry originally targeted 2.3.12 on `fix/CPT-106-chk2-timing-samples-rc4-test`, but CPT-101 (reporting RCE fix) landed on `main` and claimed 2.3.12 first. Renumbered to 2.3.13 as part of the merge sequence; no code semantics changed from the original branch.

## [2.3.12] - 2026-04-17

### Security
- **Local RCE via server-controlled `security.txt Expires:` field**: `skills/chk2/commands/reporting.md` RC4 interpolated `$exp_date` (derived from the HTTP response body) directly into a `python3 -c "…"` source string wrapped in single-quoted Python literals. A hostile target serving `Expires: 2026-01-01'+__import__('os').popen('…').read()+'` could break out of the string literal and execute arbitrary commands as the auditor's user when `/chk2:reporting` (or `/chk2:all`, which dispatches it) runs. Replaced the interpolation with stdin delivery — `printf '%s' "$exp_date" | python3 -c "…sys.stdin.read()…"` — so the value is treated as data, not source. Injection impossible regardless of content. Regression test in `tests/chk2-reporting-expires-injection.bats` runs the hostile payload and confirms no sentinel file is created (CPT-101).

**Note on version renumbering**: This entry originally targeted 2.3.11 on `fix/CPT-101-chk2-reporting-expires-rce`, but CPT-99 (SSE probe close) landed on `main` and claimed 2.3.11 first. Renumbered to 2.3.12 as part of the merge sequence; no code semantics changed from the original branch.

## [2.3.11] - 2026-04-17

### Fixed
- **SSE Phase 1 probe not closed before Phase 2**: `skills/chk2/commands/sse.md` SE2 two-phase SSE connection-limit test opened a discovery probe in Phase 1 without closing it deterministically. Python GC eventually closed the socket, but on servers with a concurrent SSE cap (e.g. 20) the stale probe held slot 0 into Phase 2, so Phase 2's 20 concurrent opens got only 19 slots and SE2 reported "19/20 succeeded" — an artificial, measurement-created finding. Probe is now wrapped in `with urlopen(req, timeout=5) as resp:` so it closes on every exit path (including `break`) (CPT-99).

**Note on version renumbering**: This entry originally targeted 2.3.10 on `fix/CPT-99-chk2-sse-probe-close`, but CPT-98 (chk2 doctor jq check) landed on `main` and claimed 2.3.10 first. Renumbered to 2.3.11 as part of the merge sequence; no code semantics changed from the original branch.

## [2.3.10] - 2026-04-17

### Fixed
- **Silent audit evidence loss on missing `jq`**: `/chk2 doctor` and pre-flight now verify `jq` availability. `/chk2 auth` AU3 (concurrent-session limit check introduced in CPT-16) relies on `jq -r --arg i "$i" ...` with `2>/dev/null`, so a missing jq binary silently produced zero AU3 evidence — the user saw no error and had no way to distinguish "test passed" from "jq was missing". Doctor now reports `[PASS|FAIL] jq`; pre-flight aborts with a clear error message directing the user to install jq before re-running (CPT-98).

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

## [2.3.0] - 2026-04-17

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
