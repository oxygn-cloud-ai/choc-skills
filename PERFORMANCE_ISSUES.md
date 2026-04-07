# Performance Issues

> Last reviewed: 2026-04-07
> Reviewer: PerformanceReviewer agent (Claude Opus 4.6)
> Scope: CI pipeline, BATS tests, shell scripts

---

## PERF-001: macOS CI runner cost — bats-tests job [Important]

**Status:** Open

The `bats-tests` job runs exclusively on `macos-latest`. GitHub-hosted macOS runners cost 10x more per minute than Ubuntu runners (macOS-latest = $0.08/min vs ubuntu-latest = $0.008/min). BATS tests in this repo are portable shell tests that do not require macOS-specific features.

**Impact:** Every push and PR triggers a macOS runner for BATS tests. With ~21 tests, runtime is likely 1-3 minutes, but the cost multiplier adds up over time.

**Recommendation:** Run BATS tests on `ubuntu-latest` instead. BATS is available via `apt-get install bats` on Ubuntu. Reserve macOS for the `installer-smoke-test` matrix where cross-platform validation is the explicit goal. If macOS-specific behavior must be tested, add it as a second matrix entry rather than the sole runner.

---

## PERF-002: Redundant installer-smoke-test matrix [Suggestion]

**Status:** Open

The `installer-smoke-test` job runs on both `ubuntu-latest` and `macos-latest`. This is valuable for verifying cross-platform behavior, but the test steps (--list, --force, --check, verify loop, --uninstall) overlap significantly with the BATS `install.bats` suite which already covers --force, --check, --uninstall, --list, and file verification.

**Impact:** Duplicated test coverage across two jobs. The macOS smoke-test runner costs $0.08/min.

**Recommendation:** Consider whether the smoke test on macOS can be dropped now that BATS tests exist. If kept, document clearly why both are needed (e.g., smoke test validates real-world usage flow vs unit-level BATS tests).

---

## PERF-003: Double integrity verification in install.sh [Suggestion]

**Status:** Open

`install_skill()` (lines 205-219) performs both `cmp -s` (byte comparison) and `shasum -a 256` (SHA256 hash) after every file copy. If `cmp -s` passes, the SHA256 check is redundant — byte-identical files will always have identical hashes. The `shasum` invocation spawns two subprocesses and reads both files from disk a second time.

**Impact:** Low for current file sizes (~374 lines max). Adds ~50-100ms per skill install. With 4 skills this is negligible, but the pattern would scale poorly with many or large skills.

**Recommendation:** Remove the SHA256 verification after `cmp -s` passes, or remove `cmp -s` and keep only SHA256. One integrity check is sufficient.

---

## PERF-004: Repeated grep/sed calls in validate-skills.sh [Suggestion]

**Status:** Open

`validate-skills.sh` extracts frontmatter once (line 52), then uses `echo "$frontmatter" | grep` for each field check (lines 55, 64, 72, 81, 129). Each pipe spawns a subshell + grep. The frontmatter is also extracted with `sed`, then individual fields are extracted with `grep | sed` again.

**Impact:** Minimal with 4 skills. Each skill triggers ~8-10 subprocess spawns for grep/sed. Total overhead is under 1 second.

**Recommendation:** No action needed at current scale. If the skill count grows significantly (20+), consider parsing frontmatter once into variables using a single `awk` pass.

---

## PERF-005: generate-checksums.bats modifies repo working tree [Important]

**Status:** Open

`generate-checksums.bats` runs `generate-checksums.sh` which overwrites `CHECKSUMS.sha256` in the actual repo directory. The test saves/restores via `.bak` file in teardown, but if a test fails mid-execution or BATS is killed, the `.bak` restoration may not run, leaving the repo with modified checksums.

**Impact:** Not a performance issue per se, but a reliability concern that could cause the `verify-checksums` CI job to fail spuriously if tests run in a dirty state. Could also cause developer confusion locally.

**Recommendation:** Modify the test to use a temporary directory for output, or set `OUTPUT` via environment variable so tests can redirect to a temp file. This would also allow tests to run in parallel safely.

---

## PERF-006: No CI caching for brew install bats-core [Suggestion]

**Status:** Open

The `bats-tests` job runs `brew install bats-core` on every invocation without any caching. Homebrew operations on macOS runners can take 30-60 seconds including brew update.

**Impact:** Adds 30-60 seconds to every CI run of the bats-tests job. This compounds with the macOS runner cost (PERF-001).

**Recommendation:** If keeping macOS for BATS tests, cache the Homebrew installation. Alternatively, switching to Ubuntu (PERF-001) and using `sudo apt-get install -y bats` is faster (~5 seconds) and requires no caching.

---

## PERF-007: Six independent CI jobs each checkout the repo separately [Suggestion]

**Status:** Open

The CI workflow defines 6 jobs (shellcheck, validate-skills, installer-smoke-test x2, verify-checksums, file-permissions, bats-tests) that all run `actions/checkout` independently. There is no dependency between most of these jobs, so they run in parallel — which is good — but each incurs runner startup overhead (~15-30 seconds per job).

**Impact:** Total CI wall-clock time is bounded by the slowest job. The parallel approach is correct. However, the lightweight jobs (file-permissions, verify-checksums, validate-skills) could be consolidated into a single "lint" job to reduce runner startup overhead without meaningfully increasing wall time.

**Recommendation:** Consider merging `shellcheck`, `validate-skills`, `file-permissions`, and `verify-checksums` into a single `lint` job with multiple steps. This saves 3 runner spin-ups (~45-90 seconds of billable time) while keeping the fast-path under 1 minute. Keep `installer-smoke-test` and `bats-tests` as separate jobs since they are heavier and benefit from parallelism.

---

## PERF-008: install.sh spawns subshells for each skill enumeration [Suggestion]

**Status:** Open

Multiple functions (`list_skills`, `check_health`, the main install loop) iterate over `${SKILLS_DIR}/*/` with identical filtering logic (`[[ "$name" == _* ]] && continue; [ -f "${dir}/SKILL.md" ] || continue`). Each invocation re-reads the directory.

**Impact:** Negligible with 4 skills. Directory reads are cached by the OS filesystem layer.

**Recommendation:** No action needed. This is clean, readable code. Only refactor if skill count exceeds ~50.

---

## Summary

| ID | Severity | Category | Status |
|----|----------|----------|--------|
| PERF-001 | Important | CI cost | Open |
| PERF-002 | Suggestion | CI overlap | Open |
| PERF-003 | Suggestion | Script efficiency | Open |
| PERF-004 | Suggestion | Script efficiency | Open |
| PERF-005 | Important | Test reliability | Open |
| PERF-006 | Suggestion | CI caching | Open |
| PERF-007 | Suggestion | CI consolidation | Open |
| PERF-008 | Suggestion | Script efficiency | Open |

**Critical:** 0 | **Important:** 2 | **Suggestion:** 6
