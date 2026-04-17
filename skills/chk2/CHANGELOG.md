# Changelog — chk2

All notable changes to the chk2 skill will be documented in this file.

## [2.3.25] - 2026-04-18

### Fixed
- **CPT-126 `.orchestrated` marker now created via Write tool, not shell `touch`** (CPT-152). CPT-126 introduced a filesystem marker protocol (`SECURITY_CHECK.parts/.orchestrated`) so parallel-wave sub-skills could tell whether they were dispatched by an orchestrator (skip standalone merge) or invoked directly (execute standalone merge). Both orchestrator bodies created the marker with `touch SECURITY_CHECK.parts/.orchestrated`, but neither `skills/chk2/commands/all.md` nor `skills/chk2/commands/quick.md` frontmatter listed `Bash(touch *)` in `allowed-tools`. Under CPT-32 per-command enforcement the touch was tool-denied, the marker was never created, sub-skills saw no marker and executed the standalone-merge path — reintroducing the exact CPT-88 concurrent-write race the marker was designed to close, but now silently, for the primary `/chk2` and `/chk2 quick` invocations. Swapped the shell `touch` instruction for "use the Write tool with `file_path=SECURITY_CHECK.parts/.orchestrated` and `content='orchestrated'`" in both orchestrators. `Write` is already in both allowed-tools entries, so the fix widens no tool surface. Triager-approved Option B (minimal-surface) over Option A (add `Bash(touch *)`). Two regression sentinels in `tests/router-allowed-tools.bats`: no body uses `touch SECURITY_CHECK.parts/.orchestrated`; body DOES reference the Write tool within the `.orchestrated` context. Both RED before fix, GREEN after.

**Note on version renumbering**: This entry originally targeted 2.3.24 on `fix/CPT-152-chk2-orchestrator-marker-write`, but CPT-151 (test-scope fix) was already on an open branch targeting 2.3.24 and landed on `main` first. Taking 2.3.25 here to avoid collision. No code semantics changed from the original branch. Follow-up work for Concerns 2 (Read-for-existence) and 3 (stale-marker) to be filed separately.

## [2.3.24] - 2026-04-18

### Fixed
- **CPT-125 Output-block test now actually scoped to the `## Output` block** (CPT-151). The test in `tests/router-allowed-tools.bats` that claims "chk2 category sub-skills reference the correct SECURITY_CHECK.parts path in the Output block" used a whole-file `grep -q 'SECURITY_CHECK\.parts/'`. Three sources leak the pattern outside the `## Output` block — the CPT-125 intro line (~line 9), the CPT-126 `## After — standalone only` section (references the `.orchestrated` marker path), and the CPT-127 `## Status signal — orchestrated only` section (ditto). An accidental removal of `SECURITY_CHECK.parts/<cat>.md` from the actual `## Output` block would still pass the whole-file grep — the test name promised a property the implementation did not enforce. Rewrote the test to extract only the `## Output` block with `awk '/^## Output/{flag=1; next} /^## /{flag=0} flag'` and grep inside that slice. Added a CPT-151 regression meta-test with a synthetic category file whose `## Output` block is deliberately scrubbed but `## After` block retains the marker path — asserts the old whole-file logic "passes" (proving the bug) and the new scoped logic correctly flags. RED was verified against a real category file: temporarily scrubbing `SECURITY_CHECK.parts/tls.md` from `tls.md`'s `## Output` block flagged `tls.md` as an offender under the new logic; the pre-fix whole-file grep would have left 4 other `SECURITY_CHECK.parts/` matches in the file and silently passed. Pure test tightening; no production code touched.

**Note on version renumbering**: This entry originally targeted 2.3.20 on `fix/CPT-151-chk2-test-scope-output-block`, but concurrent CPT-125/CPT-126/CPT-127/CPT-143/CPT-144 work already claimed 2.3.20-2.3.23 on `main` by the time this branch fixed the scope weakness their tests share. Renumbered to 2.3.24 as part of the merge sequence; no code semantics changed from the original branch.

## [2.3.23] - 2026-04-18

### Fixed
- **jq guard now lives on the actual execution path** (CPT-144). CPT-135 scoped the jq pre-flight correctly (conditional on `$ARGUMENTS` being empty, `all`, or starting with `auth`) but placed the gate in `skills/chk2/SKILL.md`. The installed router (`~/.claude/commands/chk2.md`) routes `(empty)` and `all` DIRECTLY to `/chk2:all` via the Skill tool, which loads `commands/all.md` — SKILL.md is only read for `help`/`doctor`/`version`. So the CPT-98 silent-evidence-loss protection was effectively undone on the primary invocation pattern: `/chk2` and `/chk2 all` could proceed to Wave 4 (`/chk2:auth`), AU3's jq pipeline ran with `2>/dev/null`, and AU3 evidence silently disappeared again. Moved the jq guard into a dedicated `## Pre-flight` section at the head of both `commands/all.md` (checks before parallel-wave dispatch) and `commands/auth.md` (checks before AU1). Added `Bash(which *)` to both frontmatters so the guard itself doesn't get tool-denied under CPT-32 enforcement. Narrowed `tests/chk2-jq-preflight-scope.bats` test 4 to REQUIRE the guard in `commands/all.md` or `commands/auth.md` (no longer accepts SKILL.md pre-flight as coverage), plus a new test 5 asserting `Bash(which *)` is whitelisted when the body uses `which jq`.

## [2.3.22] - 2026-04-18

### Fixed
- **`chk2:reporting` RC4 no longer silently loses evidence under per-command enforcement** (CPT-136). CPT-101 (v2.3.12) closed an RCE in the reporting.md RC4 check by switching from `python3 -c "...'$exp_date'..."` interpolation to `printf '%s' "$exp_date" | python3 -c "...sys.stdin.read().strip()..."` stdin delivery — correct security fix, but `printf` was not in the `allowed-tools` frontmatter. Under CPT-32 per-command enforcement, `printf` was denied and the RC4 pipeline failed to execute, producing zero Expires evidence. The RCE was closed, but the check it guarded silently stopped reporting — the same fix-introduces-new-silent-failure pattern CPT-88/98/110/115/119/128 all hit. Added `Bash(printf *)` to `allowed-tools`. Regression sentinel in `tests/router-allowed-tools.bats`.

**Note on version renumbering**: This entry originally targeted 2.3.20 on `fix/CPT-136-chk2-reporting-printf-allowed-tools`, but CPT-126 (v2.3.20) and CPT-127 (v2.3.21) landed on `main` first. Renumbered to 2.3.22 as part of the merge sequence; no code semantics changed from the original branch.

## [2.3.21] - 2026-04-18

### Fixed
- **CHK2-STATUS protocol now cleanly gated on orchestrator marker** (CPT-127). CPT-89 introduced the `CHK2-STATUS: OK|RATE_LIMITED|ERROR` final-line protocol so the `/chk2:all` orchestrator could track per-wave rate-limit state, but all 30 category sub-skills also carried a trailing `## After` "Ask the user" block ABOVE `## Status signal`. When Claude ran the sub-skill under orchestration, it would follow instructions in order, emit the user-question prose as the last conversational element, and `CHK2-STATUS` never made it out as the actual final line — the orchestrator's parser saw the user-question text instead, the RATE_LIMITED counter never tripped, and the rate-limit circuit breaker CPT-89 shipped was effectively unreachable. Renamed the two sections with anchor suffixes and added explicit skip-gating on the CPT-126 `.orchestrated` marker: `## After — standalone only` skips when the marker is present; `## Status signal — orchestrated only` skips when the marker is absent. Under orchestration the After block is skipped, the Status block emits the line as the absolute final response element, and the circuit breaker receives a clean signal. Three bats regressions in `tests/router-allowed-tools.bats` enforce the anchor suffixes and the gating body text.

**Note on version renumbering**: This entry originally targeted 2.3.19 on `fix/CPT-127-chk2-sub-skill-section-gating`, but CPT-125 (v2.3.19) and CPT-126 (v2.3.20) landed on `main` first. Renumbered to 2.3.21 as part of the merge sequence; no code semantics changed from the original branch.

## [2.3.20] - 2026-04-18

### Fixed
- **Standalone `/chk2 <category>` runs now produce `SECURITY_CHECK.md`** (CPT-126). CPT-88 (v2.3.7) moved per-category output into `SECURITY_CHECK.parts/<cat>.md` for race-safety under parallel `/chk2:all` waves, but only the `/chk2:all` and `/chk2:quick` orchestrators merge parts into `SECURITY_CHECK.md`. Direct invocations like `/chk2 tls` produced only the parts file, leaving `SECURITY_CHECK.md` unchanged — and downstream `/chk2:fix` and `/chk2 github` (which consume `SECURITY_CHECK.md`) silently broke. Added a marker-file protocol: orchestrators `touch SECURITY_CHECK.parts/.orchestrated` at init and `rm -f` it after the merge; every category sub-skill's Output block now checks the marker and writes a standalone `SECURITY_CHECK.md` from its part file when the marker is absent. Under orchestration the marker suppresses the standalone write so there's no double-append. Regression guards in `tests/router-allowed-tools.bats` require both orchestrators to create+remove the marker and require every category sub-skill to carry the `Standalone merge (CPT-126)` anchor phrase with a `SECURITY_CHECK.parts/.orchestrated` check.

**Note on version renumbering**: This entry originally targeted 2.3.18 on `fix/CPT-126-chk2-standalone-security-check-md`, but CPT-119 (v2.3.18) and CPT-125 (v2.3.19) landed on `main` first. Renumbered to 2.3.20 as part of the merge sequence; no code semantics changed from the original branch.

## [2.3.19] - 2026-04-18

### Fixed
- **Contradictory opening-paragraph instruction in 30 category sub-skills** (CPT-125). CPT-88 switched sub-skills to write per-category part files (`SECURITY_CHECK.parts/<cat>.md`) via each file's `## Output` block, but left the opening paragraph of every category command still saying "Append results to `SECURITY_CHECK.md`". An agent reading top-to-bottom saw both instructions and could legitimately follow either — keeping the concurrent-write race that CPT-88 was written to close reachable under `/chk2:all`. Replaced the opening-paragraph sentence across all 30 category files with the per-category parts path (`Write results to \`SECURITY_CHECK.parts/<cat>.md\` (see **Output** for format).`), so the intro now agrees with the Output block rather than contradicting it. Added two regression tests in `tests/router-allowed-tools.bats`: forbid the old "Append results to `SECURITY_CHECK.md`" phrase in any category file, and require the `SECURITY_CHECK.parts/` path in every category file's Output block.

**Note on version renumbering**: This entry originally targeted 2.3.18 on `fix/CPT-125-chk2-category-intro-contradiction`, but CPT-119 (install.sh pattern widen) landed on `main` and claimed 2.3.18 first. Renumbered to 2.3.19 as part of the merge sequence; no code semantics changed from the original branch.

## [2.3.18] - 2026-04-18

### Fixed
- **`chk2:update` absolute-path installer invocation restored** (CPT-119). Same class of defect as chk1:update — the narrow `Bash(bash install.sh *)` pattern introduced by CPT-39 did not match the documented absolute-path invocation `bash <repo-path>/skills/chk2/install.sh --force`. Widened to `Bash(bash *install.sh *)` which still scopes to `install.sh` invocations. `/chk2 update` now works for users with a `.source-repo` marker (the documented typical setup). See chk1 entry for full write-up; same fix applied identically.

**Note on version renumbering**: This entry originally targeted 2.3.17 on `fix/CPT-119-bash-install-sh-pattern`, but CPT-110 (Agent tool declaration) landed on `main` and claimed 2.3.17 first. Renumbered to 2.3.18 as part of the merge sequence; no code semantics changed from the original branch.

## [2.3.17] - 2026-04-18

### Fixed
- **`chk2:all` frontmatter now declares `Agent` — primary full-audit flow restored** (CPT-110). CPT-32 (v2.3.4) moved heavy tools from router-level to per-command frontmatter, but the per-command `chk2:all` frontmatter only listed `Read, Write, Bash(mkdir *), Bash(cat *), Bash(rm *), AskUserQuestion` while the command body explicitly instructs the model to launch 5 waves of parallel Agent calls (30 category dispatches). Under per-command tool enforcement, `Agent` was denied — `/chk2`, `/chk2 all`, and any category dispatched via `/chk2 all` produced nothing. Added `Agent` to `allowed-tools`. The fix also adds a generic bats regression guard that cross-checks every command file's body for imperative Agent usage (`Launch/Spawn/Dispatch/using ... Agent tool|Agent call|parallel Agent`, or the `subagent_type` code keyword) against its frontmatter, so a future command that tells the model to dispatch sub-agents without declaring the tool will fail CI at review time.

## [2.3.16] - 2026-04-18

### Fixed
- **Global `jq` pre-flight scoped to `auth`/`all` paths**: CPT-98 (v2.3.10) added a pre-flight jq check to prevent silent AU3 evidence loss, but made it unconditional — aborting every `/chk2` invocation when jq was missing. Only `/chk2 auth` (AU3 concurrent-session pipeline) and `/chk2 all` (which dispatches auth) actually use jq. Non-audit categories like `/chk2 headers`, `/chk2 tls`, `/chk2 dns`, `/chk2 fix`, and `/chk2 update` never touch jq but CPT-98's broad check still blocked them on any machine without jq — a regression from pre-CPT-98 behaviour. Pre-flight step 2 is now gated on `$ARGUMENTS` being empty, `all`, or starting with `auth`; doctor keeps reporting jq status globally so diagnostic coverage is preserved (CPT-135).

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
