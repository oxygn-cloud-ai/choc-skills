# Codebase Concerns

**Analysis Date:** 2026-03-31

## Tech Debt

**Hard-coded Homebrew path in shell scripts:**
- Issue: `/opt/homebrew/bin` is hard-coded in PATH manipulations. This only works on Apple Silicon Macs and fails silently on Intel Macs or when Homebrew is installed elsewhere.
- Files:
  - `skills/iterm2-tmux/bin/tmux-iterm-tabs.sh` (line 20)
  - `skills/iterm2-tmux/bin/tmux-sessions.sh` (line 9)
  - `skills/iterm2-tmux/bin/tmux-picker.sh` (line 7)
- Impact: Tools may fail to find tmux or other Homebrew-installed binaries on non-standard Homebrew installations. Users on Intel Macs with default Homebrew paths (`/usr/local/bin`) will experience silent failures.
- Fix approach: Detect Homebrew path dynamically using `$(brew --prefix)/bin` or check both common paths before prepending. Add fallback error message if tmux cannot be found.

**Hardcoded session background directory in multiple locations:**
- Issue: `.session-backgrounds` directory path is duplicated and hard-coded in multiple files, making refactoring difficult.
- Files:
  - `skills/iterm2-tmux/bin/tmux-iterm-tabs.sh` (line 18)
  - `skills/iterm2-tmux/bin/tmux-attach-session.sh` (line 10)
  - `skills/iterm2-tmux/uninstall.sh` (line 44)
- Impact: Changes to the background directory structure require updates in multiple places. Risk of inconsistency between scripts.
- Fix approach: Define `BG_DIR` as a shared constant sourced from a config file or computed from `INSTALL_DIR`.

**Temporary file in /tmp with no cleanup guarantee:**
- Issue: `mktemp /tmp/tmux-iterm.XXXXXX` creates temporary AppleScript with a trap handler, but `/tmp` contents can be cleared by the OS without warning.
- Files: `skills/iterm2-tmux/bin/tmux-iterm-tabs.sh` (line 128-132)
- Impact: Orphaned `.XXXXXX` temp files could accumulate if the script is interrupted before completion.
- Fix approach: Use `TMPDIR` environment variable (defaults to `/var/folders/*` on macOS) which is safer. Verify trap handler runs before exit. Consider using `mktemp -t` for macOS.

**Lockfile-based synchronization in auto-startup snippet:**
- Issue: A simple `mkdir` race condition guard is used at `$_itmlk="/tmp/iterm2-tmux-autostart.lock"` with a hard-coded 30-second cleanup timeout.
- Files: `skills/iterm2-tmux/install.sh` (lines 354-360)
- Impact: On slow machines or high load, the 30-second timeout may be insufficient. Multiple iTerm2 windows could simultaneously run `tmux-iterm-tabs.sh` causing duplicate tab creation.
- Fix approach: Use a more robust locking mechanism with process verification or adopt a PID-based lockfile pattern with stale lock cleanup.

**Configuration file parsing is fragile:**
- Issue: Configuration values are extracted using `grep` and `cut` with hardcoded field separators, with no error handling for malformed config files.
- Files:
  - `skills/iterm2-tmux/install.sh` (lines 98-99, 129-131, 228-229, 369)
  - `skills/iterm2-tmux/uninstall.sh` (lines 12-13)
- Impact: If `~/.config/iterm2-tmux/config` becomes corrupted or manually edited incorrectly, parsing fails silently. `INSTALL_DIR` or `TMUX_REPOS_DIR` could be set to empty strings, causing script failures.
- Fix approach: Add validation functions to check that parsed config values are non-empty and valid paths. Use safer parsing (e.g., `bash` source with variable checks) or a config validator.

---

## Known Bugs

**Color palette synchronization not guaranteed:**
- Symptoms: Tab color and background watermark color may not match between `tmux-attach-session.sh` and `gen-session-bg.py` if arrays are edited independently.
- Files:
  - `skills/iterm2-tmux/bin/tmux-attach-session.sh` (lines 13-26)
  - `skills/iterm2-tmux/bin/gen-session-bg.py` (lines 13-26)
- Trigger: Manually edit `TAB_COLORS` in `.sh` file without editing `ACCENTS` in `.py` file, or vice versa.
- Workaround: Both files have matching color lists; ensure they stay synchronized during any future color palette edits.

**Symlink installer does not preserve script permissions:**
- Symptoms: If scripts are installed via symlink mode, the symlink itself has the source file's permissions, which may not be executable if the source is not executable.
- Files: `skills/iterm2-tmux/install.sh` (lines 297-299)
- Trigger: If `bin/*.sh` files are accidentally committed without executable bit.
- Workaround: Copy mode (`--copy`) works correctly. Run `chmod +x ~/.local/bin/tmux-*.sh` after symlink install if scripts are not executable.

---

## Security Considerations

**iTerm2 plist file handling (low risk):**
- Risk: `install.sh` imports a pre-configured iTerm2 plist file without signing or checksum verification. A malicious plist could modify iTerm2 behavior.
- Files: `skills/iterm2-tmux/install.sh` (lines 313-321)
- Current mitigation: Plist is embedded in the repo and installed only if user confirms. Backup is created before overwrite. File contents are not validated.
- Recommendations: Add a SHA256 checksum verification before importing. Consider documenting the specific settings being applied (already done in README, which is helpful). Optionally sign the plist or include checksum in git commits.

**Shell injection in AppleScript generation (medium risk):**
- Risk: User input (session names, labels) is interpolated directly into AppleScript code without proper escaping. Quotes in session names could break syntax.
- Files: `skills/iterm2-tmux/bin/tmux-iterm-tabs.sh` (lines 140-141, 147-153)
- Current mitigation: Session names are sanitized by `sanitize_name()` which removes special characters. However, this sanitization happens after the session is created, and the `label` (from `lookup_label()`) is not sanitized.
- Recommendations: Apply escaping to both `$label` and `$s` before inserting into AppleScript. Example: replace `"` with `\"`. Test with session names containing quotes.

**Temporary file created with world-readable permissions (low risk):**
- Risk: `mktemp /tmp/tmux-iterm.XXXXXX` creates files with default permissions (0600 on most systems), which is safe. However, `/tmp` itself is world-writable.
- Files: `skills/iterm2-tmux/bin/tmux-iterm-tabs.sh` (line 128)
- Current mitigation: Temporary file is deleted via trap handler immediately after use. Content is AppleScript, not sensitive data.
- Recommendations: Use `mktemp -t` (macOS-specific) to create in `$TMPDIR` instead. Verify trap handler executes on all exit paths (including errors).

**Credentials and secrets in .env files (not applicable):**
- No `.env` files detected in the repo. Config files do not contain hardcoded API keys, tokens, or credentials.

---

## Performance Bottlenecks

**Python background image generation blocks tab creation:**
- Problem: `gen-session-bg.py` is called sequentially for each session in a loop, blocking AppleScript generation. If Python is slow or if Pillow is not available, tab creation waits.
- Files: `skills/iterm2-tmux/bin/tmux-iterm-tabs.sh` (lines 106-121)
- Cause: Generator runs in foreground loop with no parallelization or timeout. If Python hangs, the entire script hangs.
- Improvement path:
  1. Run generation in background parallel jobs with a timeout
  2. Pre-generate images asynchronously before AppleScript
  3. Skip generation if it takes >5 seconds per image
  4. Make background images optional without blocking tab creation

**Session creation with directory changing inside tmux:**
- Problem: Each new tmux session runs `tmux send-keys` to `cd` into the project directory, which blocks until the shell processes the command.
- Files: `skills/iterm2-tmux/bin/tmux-sessions.sh` (lines 37-44)
- Cause: `send-keys` is synchronous and waits for the key press to be processed. With many sessions, this adds up.
- Improvement path:
  1. Use `tmux new-session -c "$dir"` to set the working directory at creation time instead of sending `cd` later
  2. This avoids a shell command execution per session

---

## Fragile Areas

**Session name sanitization is lossy:**
- Files: `skills/iterm2-tmux/bin/tmux-iterm-tabs.sh` (lines 22-30), `skills/iterm2-tmux/bin/tmux-sessions.sh` (lines 18-26)
- Why fragile: Directory names like `foo.bar`, `foo:bar`, `foo bar` are converted to `foo-bar`. If two distinct directory names sanitize to the same session name (e.g., `foo.bar` and `foo:bar` both become `foo-bar`), only one tmux session is created and the other directory is silently skipped.
- Safe modification: Add a collision detection step. Log a warning if multiple directories map to the same sanitized name. Consider a more sophisticated hashing approach for long names.
- Test coverage: No tests for collision detection. Add test cases with directory names that would collide.

**AppleScript error handling is minimal:**
- Files: `skills/iterm2-tmux/bin/tmux-iterm-tabs.sh` (line 163-166)
- Why fragile: If AppleScript fails, the error message is printed but execution continues silently. No indication that tabs were not created. User may think the script succeeded when it actually failed.
- Safe modification: Check the exit code of `osascript`. If it fails, exit with error code and report which sessions could not be attached.
- Test coverage: No tests for AppleScript failures. Add tests with invalid session names.

**Configuration file is optional and has no validation:**
- Files: `skills/iterm2-tmux/bin/tmux-iterm-tabs.sh` (line 12), `skills/iterm2-tmux/bin/tmux-sessions.sh` (line 6)
- Why fragile: If `~/.config/iterm2-tmux/config` does not exist, scripts silently fall back to defaults. If config is partially edited (e.g., `TMUX_REPOS_DIR=` with no value), the default applies, but scripts may fail downstream with unclear error messages.
- Safe modification: Add a `validate_config()` function that checks for empty values and verifies paths exist. Fail loudly if config is corrupted.
- Test coverage: No tests for missing or invalid config. Add tests.

**iTerm2 auto-startup locks to `/tmp` with predictable names:**
- Files: `skills/iterm2-tmux/install.sh` (line 354)
- Why fragile: Lock file path `/tmp/iterm2-tmux-autostart.lock` is predictable. If a user runs multiple iTerm2 instances or if the system has a clock skew, the lock could be held by a stale process. The 30-second cleanup timeout may not be enough if the script hangs.
- Safe modification: Include the iTerm2 process ID in the lock path to make it unique per instance. Use `kill -0` to verify the lock holder is still alive before waiting.
- Test coverage: No tests for lock contention or cleanup. Add tests.

**No error handling for tmux command failures:**
- Files: Multiple files call `tmux` commands (e.g., `tmux ls`, `tmux new-session`, `tmux send-keys`)
- Why fragile: Some commands have `2>/dev/null` redirects which hide errors. Others rely on exit codes but don't distinguish between "no sessions" and "tmux crashed". If tmux server becomes corrupted or unresponsive, scripts may enter a broken state.
- Safe modification: Add explicit error checking for each `tmux` command. Distinguish between expected errors (no sessions) and unexpected errors (tmux server failure). Log detailed errors.
- Test coverage: No integration tests with tmux. Add tests.

---

## Scaling Limits

**Session picker assumes < 100 sessions:**
- Files: `skills/iterm2-tmux/bin/tmux-picker.sh` (lines 62, 66)
- Current capacity: Assumes single-digit to double-digit sessions (formatting uses `%2d`).
- Limit: With 100+ sessions, the picker becomes unwieldy (long list, user must count to find selection number). No pagination or search.
- Scaling path: Implement fzf-based selection or add pagination for large session lists.

**AppleScript tab creation is synchronous:**
- Files: `skills/iterm2-tmux/bin/tmux-iterm-tabs.sh` (line 163)
- Current capacity: ~20 tabs can be created in reasonable time.
- Limit: With 50+ sessions, AppleScript generation and execution becomes slow (AppleScript is not fast). iTerm2 UI may become unresponsive.
- Scaling path: Use iTerm2's native Python API instead of AppleScript, or create tabs in batches with delays between them.

**Background image generation has no disk cleanup:**
- Files: `skills/iterm2-tmux/bin/tmux-iterm-tabs.sh` (lines 105-121)
- Current capacity: ~200 sessions with unique images (PNG files ~10KB each = ~2MB total)
- Limit: If `.session-backgrounds` directory is never cleaned, it can grow indefinitely. Deleted directories still have leftover PNG files.
- Scaling path: Implement LRU cache cleanup. Delete images for sessions that no longer exist.

---

## Dependencies at Risk

**Python + Pillow dependency is optional but not gracefully degraded:**
- Risk: Background image generation fails silently if Pillow is not installed or if Python is not available. User gets no image but also no warning (warnings go to stderr).
- Files: `skills/iterm2-tmux/bin/tmux-iterm-tabs.sh` (lines 107-121)
- Impact: User may think feature works but images are actually missing. Hard to debug.
- Migration plan: Make image generation a separate optional step. Add explicit `--no-backgrounds` flag. Log to a file if images fail to generate.

**Homebrew path assumption:**
- Risk: Scripts hard-code `/opt/homebrew/bin` which breaks on Intel Macs or non-standard Homebrew installs.
- Files: `skills/iterm2-tmux/bin/tmux-iterm-tabs.sh`, `tmux-sessions.sh`, `tmux-picker.sh`
- Impact: Scripts fail silently if tmux is not found in the expected path.
- Migration plan: Dynamic path detection (see Tech Debt section above).

---

## Missing Critical Features

**No rollback or undo for install:**
- Problem: Installer modifies `~/.zshrc`, `~/.tmux.conf`, and iTerm2 plist. If installation fails partway, no automatic rollback occurs. User must manually undo changes.
- Blocks: Safe uninstall. User confidence in installation.

**No dry-run mode:**
- Problem: Installer runs interactively but has no `--dry-run` option to show what will happen without making changes.
- Blocks: Scripted deployment. User validation before installation.

**No support for non-macOS shells:**
- Problem: All scripts hard-code bash-isms and AppleScript. No fallback for zsh, fish, or other shells. Works only on macOS.
- Blocks: Cross-platform support. Linux users cannot use this tool.

**No comprehensive logging:**
- Problem: Errors are printed to stderr but not logged to a file. User cannot review what happened after the script runs.
- Blocks: Debugging. Auditing for security or compliance.

---

## Test Coverage Gaps

**Installation and uninstall not tested:**
- What's not tested: Full install/uninstall workflow. Config file generation and parsing. Permission handling. Symlink vs copy mode.
- Files: `skills/iterm2-tmux/install.sh`, `uninstall.sh`
- Risk: Regressions in installer could break user installations silently.
- Priority: High — installer is critical path.

**tmux session creation not tested:**
- What's not tested: Session creation with special characters in directory names. Session name collisions. Handling of symlinked directories.
- Files: `skills/iterm2-tmux/bin/tmux-sessions.sh`
- Risk: Silent failures when creating sessions for directories with unusual names.
- Priority: High.

**iTerm2 tab creation not tested:**
- What's not tested: AppleScript generation and execution. Tab color application. Background image loading. Handling of iTerm2 API changes.
- Files: `skills/iterm2-tmux/bin/tmux-iterm-tabs.sh`
- Risk: Tab creation could fail silently without user knowing.
- Priority: High.

**chk1 skill logic not tested:**
- What's not tested: Scope auto-detection logic. Diff parsing. Audit output format. Edge cases (empty diff, no commits, etc.).
- Files: `skills/chk1/SKILL.md`
- Risk: Audits could be incomplete or incorrect without user knowing.
- Priority: High.

**Edge cases in shell scripts:**
- What's not tested: Filenames with spaces or special characters. Very long directory names. Non-standard tmux configurations. Missing dependencies. Interrupted installations.
- Files: All `.sh` files
- Risk: Scripts may fail or behave unexpectedly in edge cases.
- Priority: Medium.

---

*Concerns audit: 2026-03-31*
