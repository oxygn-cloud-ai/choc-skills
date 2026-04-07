# Security Issues

Comprehensive security review of claude-skills repository.
Last reviewed: 2026-04-07 | Reviewer: SecurityReviewer agent | Scope: v1.3.0 changes

## Summary

Reviewed 14 changed files across install.sh, CI workflows, test suites, GitHub config, and documentation. The codebase demonstrates strong security awareness -- path traversal prevention, input validation, pinned action SHAs, and integrity verification are already present. A few items warrant attention.

---

## Open Issues

### SEC-001 | BATS teardown deletes $HOME -- test isolation concern
- **Severity:** Important
- **File:** `/Volumes/TB8/OxygnAI/Repos/claude-skills/tests/install.bats`
- **Lines:** 9-16
- **Description:** The test `setup()` reassigns `HOME` to a `mktemp -d` directory, and `teardown()` runs `rm -rf "$HOME"`. This is intentional for test isolation and works correctly when BATS runs each test in a subshell. However, if any test or future refactor causes `HOME` to leak back to the real home directory (e.g., `HOME` gets unset or overwritten), the `rm -rf` would be catastrophic. There is no guard to verify `HOME` is actually a temp directory before deleting.
- **Recommendation:** Add a safety guard in `teardown()`:
  ```bash
  teardown() {
    [[ "$HOME" == /tmp/* || "$HOME" == /private/var/* ]] || return 0
    rm -rf "$HOME"
  }
  ```
- **Status:** OPEN

### SEC-002 | CI workflow uses `${{ matrix.os }}` in job name -- no injection risk but worth noting
- **Severity:** Suggestion
- **File:** `/Volumes/TB8/OxygnAI/Repos/claude-skills/.github/workflows/ci.yml`
- **Line:** 35
- **Description:** The job name uses `${{ matrix.os }}` which is safe because `matrix.os` is defined in the workflow file itself (not from user input). This is NOT a template injection vulnerability. Noted for completeness only -- no action needed.
- **Status:** CLOSED (not a vulnerability)

### SEC-003 | Dependabot ignores major version bumps for GitHub Actions
- **Severity:** Suggestion
- **File:** `/Volumes/TB8/OxygnAI/Repos/claude-skills/.github/dependabot.yml`
- **Lines:** 14-16
- **Description:** The dependabot config ignores `version-update:semver-major` for all dependencies. This means major version bumps to GitHub Actions (which sometimes contain security fixes) will not generate PRs. This is a reasonable trade-off for stability, but the team should periodically audit pinned action versions manually.
- **Recommendation:** Add a quarterly manual review of action versions to the release checklist, or consider allowing major bumps for security-critical actions (e.g., `actions/checkout`).
- **Status:** OPEN (accepted risk, documented)

---

## Closed / Non-Issues (Verified Safe)

### SEC-004 | GitHub Actions use pinned SHA commits -- GOOD
- **File:** `/Volumes/TB8/OxygnAI/Repos/claude-skills/.github/workflows/ci.yml`
- **Description:** All `uses:` directives pin to full commit SHAs (e.g., `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5`), not mutable tags. This prevents supply chain attacks via tag reassignment.
- **Status:** CLOSED (good practice confirmed)

### SEC-005 | Workflow permissions are minimal -- GOOD
- **File:** `/Volumes/TB8/OxygnAI/Repos/claude-skills/.github/workflows/ci.yml`
- **Line:** 9-10
- **Description:** Top-level `permissions: contents: read` restricts all jobs to read-only. No write permissions are granted. This is the correct least-privilege configuration.
- **Status:** CLOSED (good practice confirmed)

### SEC-006 | install.sh path traversal prevention -- GOOD
- **File:** `/Volumes/TB8/OxygnAI/Repos/claude-skills/install.sh`
- **Lines:** 130-138
- **Description:** The `validate_name()` function rejects any skill name that does not match `^[a-zA-Z0-9_-]+$`. This effectively prevents path traversal attacks (e.g., `../etc/passwd`). Test coverage confirms this in `tests/install.bats` line 107-111.
- **Status:** CLOSED (good practice confirmed)

### SEC-007 | install.sh pipe install prevention -- GOOD
- **File:** `/Volumes/TB8/OxygnAI/Repos/claude-skills/install.sh`
- **Lines:** 38-41
- **Description:** The installer detects and rejects `curl | bash` style pipe execution. This forces users to clone the repo first, preventing MITM attacks on the installation stream.
- **Status:** CLOSED (good practice confirmed)

### SEC-008 | install.sh SHA256 integrity verification -- GOOD
- **File:** `/Volumes/TB8/OxygnAI/Repos/claude-skills/install.sh`
- **Lines:** 205-219
- **Description:** After copying SKILL.md, the installer verifies both byte-level (`cmp -s`) and cryptographic (`shasum -a 256`) integrity. This dual verification catches both truncation and corruption.
- **Status:** CLOSED (good practice confirmed)

### SEC-009 | set -e bug fix is correct -- GOOD
- **File:** `/Volumes/TB8/OxygnAI/Repos/claude-skills/install.sh`
- **Lines:** 396-398
- **Description:** The previous `[ "$failed" -gt 0 ] && warn` pattern would cause `set -e` to exit the script when `failed` was 0 (because the `[` test returns non-zero and the `&&` short-circuits). The fix uses `if/then` which is correct and does not trigger `set -e`.
- **Status:** CLOSED (bug fix verified correct)

### SEC-010 | Security issue template redirects vulnerabilities to private channels -- GOOD
- **File:** `/Volumes/TB8/OxygnAI/Repos/claude-skills/.github/ISSUE_TEMPLATE/security.yml`
- **Description:** The template explicitly instructs users to report actual vulnerabilities via private channels (email or GitHub Security Advisories), not public issues. The form is restricted to non-critical concerns only. This prevents accidental public disclosure.
- **Status:** CLOSED (good practice confirmed)

### SEC-011 | No secrets or credentials in any changed file -- GOOD
- **Description:** Reviewed all 14 files. No API keys, tokens, passwords, or sensitive values are present. No `.env` files are referenced or created. No network calls are made from install.sh or scripts.
- **Status:** CLOSED (verified clean)

### SEC-012 | validate-skills.sh command file routing is safe
- **File:** `/Volumes/TB8/OxygnAI/Repos/claude-skills/scripts/validate-skills.sh`
- **Lines:** 91-99
- **Description:** The new routing-style skill validation checks for `commands/{subcmd}.md` file existence using `[ -f "${dir}/commands/${subcmd}.md" ]`. The `subcmd` variable is hardcoded to `help`, `doctor`, `version` in the for loop -- not user-controlled. No command injection risk.
- **Status:** CLOSED (verified safe)

### SEC-013 | CI inline scripts do not use untrusted input
- **File:** `/Volumes/TB8/OxygnAI/Repos/claude-skills/.github/workflows/ci.yml`
- **Description:** All `run:` blocks use only filesystem operations on checked-out repo contents. No PR titles, branch names, commit messages, or other attacker-controlled strings are interpolated into shell commands. No template injection (`${{ }}`) inside `run:` blocks references user-controlled data.
- **Status:** CLOSED (verified safe)

---

## Risk Summary

| Category | Finding |
|---|---|
| Command Injection | None found |
| Path Traversal | Mitigated by validate_name() |
| CI Supply Chain | Mitigated by SHA-pinned actions + read-only permissions |
| Secrets Exposure | None found |
| Permission Issues | None found |
| Template Injection | None found |
| Test Safety | SEC-001: teardown rm -rf guard recommended |

**Overall assessment:** The codebase has strong security practices. One actionable item (SEC-001) and one accepted-risk item (SEC-003) remain open.
