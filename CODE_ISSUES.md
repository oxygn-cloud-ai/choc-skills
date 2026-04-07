# CODE_ISSUES.md

Audit date: 2026-04-07
Auditor: CodeAuditor agent (chk1:all methodology)
Scope: Changes in v1.3.0 -- validate-skills.sh, install.sh, ci.yml, BATS tests, GitHub config

---

## Critical

(none)

---

## Important

### I-1: validate-skills.sh subcommand grep has false-positive matching

**File:** `scripts/validate-skills.sh` line 92
**Status:** OPEN

```bash
if grep -q "### ${subcmd}" "$skill_file"; then
```

The pattern `### help` also matches `### helper`, `### helpful`, etc. A SKILL.md that contained `### helpers` would pass validation as having a `help` subcommand even though it does not.

**Fix:** Anchor the pattern to match the heading exactly:

```bash
if grep -qE "^### ${subcmd}$" "$skill_file"; then
```

Or at minimum use word boundary / end-of-line:

```bash
if grep -q "^### ${subcmd}$" "$skill_file"; then
```

**Risk:** Low today (current SKILL.md files use exact headings), but will bite as new skills are added with similarly-prefixed headings.

---

### I-2: generate-checksums.bats modifies real repo file without signal trap

**File:** `tests/generate-checksums.bats` lines 9-21
**Status:** OPEN

The test backup/restore pattern in setup/teardown works under normal BATS execution. However, if the test runner is interrupted (SIGINT/SIGTERM), BATS may not execute teardown, leaving `CHECKSUMS.sha256` replaced and `CHECKSUMS.sha256.bak` orphaned in the working tree.

**Fix:** Consider running generate-checksums.sh against a temp directory copy, or use `trap` to restore on signal. Alternatively, add a `.bak` entry to `.gitignore` as a safety net so accidental leftovers don't get committed.

---

## Suggestions

### S-1: BATS tests hardcode skill names (chk1, chk2, rr)

**Files:** `tests/install.bats` lines 36-38, 46-48, 91-93, 101-102; `tests/generate-checksums.bats` lines 34-36
**Status:** OPEN

Tests assert specific skill names like `chk1`, `chk2`, `rr`. When a new skill is added, these tests will still pass but won't cover the new skill. When a skill is renamed or removed, tests will break.

**Recommendation:** For `--list` and `--force` tests, dynamically discover skill names from the repo rather than hardcoding. For targeted tests (e.g., "installs a specific skill"), hardcoding one known skill is fine.

---

### S-2: BATS test count mismatch in task description

**Files:** `tests/install.bats`
**Status:** NOTE

The task description states "16 BATS tests for install.sh" but the file contains 15 `@test` blocks. The CHANGELOG correctly states 21 total (15 + 6). Minor documentation inconsistency in the task description only; no code fix needed.

---

### S-3: CI bats-tests job limited to macOS only

**File:** `.github/workflows/ci.yml` lines 120-131
**Status:** OPEN

BATS tests run only on `macos-latest`. If `install.sh` has a Linux-specific bug, the BATS suite won't catch it. The installer smoke test covers both Ubuntu and macOS, but the BATS suite provides deeper coverage.

**Recommendation:** Add Ubuntu to the BATS job matrix. On Ubuntu, install bats-core via `sudo apt-get install -y bats` instead of `brew`. The `shasum` command is available on Ubuntu GHA runners via Perl.

---

### S-4: validate-skills.sh frontmatter extraction is fragile with multiple --- delimiters

**File:** `scripts/validate-skills.sh` line 52
**Status:** OPEN

```bash
frontmatter=$(sed -n '/^---$/,/^---$/p' "$skill_file" | sed '1d;$d')
```

If a SKILL.md file contains `---` on a line in the body content (e.g., a horizontal rule in markdown), the sed range match will re-enter and capture extra content as "frontmatter". This would cause false passes if a required field name happens to appear in the body.

**Risk:** Low today (current files are clean), but a defensive fix would be to stop at the second `---` explicitly:

```bash
frontmatter=$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$skill_file")
```

---

### S-5: install.bats parallel execution safety

**File:** `tests/install.bats` line 10
**Status:** OPEN

```bash
export HOME="$(mktemp -d)"
```

The tests override the global `HOME` environment variable. If BATS is run with `--jobs N` for parallel test execution, multiple tests modifying `HOME` concurrently would cause race conditions and test failures.

**Recommendation:** This is fine for serial execution (the default), but add a comment noting that these tests are not safe for `bats --jobs`. Alternatively, use `BATS_TEST_TMPDIR` (available in bats-core 1.5+) for scratch space and pass a custom `HOME` only to the subprocess via `env HOME=... bash "$INSTALLER" ...`.

---

### S-6: labels.yml is not auto-applied

**File:** `.github/labels.yml`
**Status:** NOTE

The labels file is documentation-only; there is no GitHub Actions workflow to sync labels from this file. Labels must be created manually. Consider adding a label-sync workflow (e.g., `EndBug/label-sync` action) to keep labels in sync automatically.

---

## Resolved

(no previously tracked issues)
