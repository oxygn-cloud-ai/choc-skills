# Changelog — iterm2-tmux

All notable changes to the iterm2-tmux tool will be documented in this file.

## [1.0.5] - 2026-04-18

### Fixed
- **`tmux-attach-session.sh` session-file read preserves trailing newlines** (CPT-159). CPT-147's temp-file handoff wrote raw session names to a file and read them back via `SESSION="$(cat "$session_file")"`. Bash command substitution strips ALL trailing newlines from its captured output — a session name that ends in `\n` bytes loses them on read, so the name the attach helper resolves against tmux doesn't match the bytes `tmux-iterm-tabs.sh` wrote. The commit's stated "full-byte round-trip" contract was violated for the trailing-NL edge. Replaced the plain substitution with the sentinel-x trick: `SESSION=$(cat "$session_file"; printf x); SESSION="${SESSION%x}"`. The extra `x` byte forces command substitution to have non-NL trailing content, so bash preserves any preceding `\n` bytes; the parameter expansion strips the sentinel, leaving the exact byte sequence intact. Two bats regressions in `tests/tmux-iterm-tabs.bats`: round-trip a session name ending in `\n\n` and assert `SESSION_HEX=6162630a0a` (bytes `a b c \n \n`); static check that the sentinel-x pattern appears in the script.

## [1.0.4] - 2026-04-18

### Security / Fixed
- **Raw tmux target name no longer passes through AppleScript string interpolation or shell-quoted args** (CPT-147). CPT-29 over-sanitised (broke attach for control-char names). CPT-105 under-sanitised (reverted the over-sanitisation but left the raw identifier interpolated into `write text "$ATTACH_SCRIPT '$safe_first' '$safe_first_label' 0"` — newline/CR/tab in a session name break the AppleScript parser, and a literal single quote escapes the argument and can inject into the shell command line). Neither commit alone delivered safe + functional attach for the full input domain. Fix: `bin/tmux-iterm-tabs.sh` now writes each raw session name to its own temp file under `$(mktemp -d /tmp/tmux-iterm-sessions.XXXXXX)` and passes `--session-file <path>` to `bin/tmux-attach-session.sh`. The file PATH (controlled by us, no shell hazards) flows through AppleScript; the session VALUE never does. `bin/tmux-attach-session.sh` now accepts `--session-file <path>` as an alternative to the positional argument, reads the name via `cat` (preserving all bytes intact, including `\n`, `\r`, `\t`, `'`), then `rm -f`s the file for single-shot semantics. Legacy positional form is preserved for any external callers. Four bats regressions in `tests/tmux-iterm-tabs.bats` enforce the new shape: temp-dir creation, `--session-file` in the AppleScript write-text line, no raw `$safe_first`/`$safe_s` interpolation, and an end-to-end flag-parse test that round-trips NL/CR/TAB/`'` bytes through the file. The obsolete CPT-105 "safe_first derives from raw $first" test was removed (superseded — the variable no longer exists; its semantic is now carried by the file round-trip).

## [1.0.3] - 2026-04-17

### Fixed
- **Regression (CPT-105)**: `bin/tmux-iterm-tabs.sh` no longer sanitises the tmux session identifier passed to `tmux attach -t` — only the user-visible AppleScript label is sanitised. CPT-29 conflated AppleScript-literal safety with tmux-identifier safety; the combined sanitisation made sessions whose names contained control characters unreachable via the generated attach command. AppleScript-injection prevention from CPT-29 is preserved via the label-only sanitisation and the existing `\` / `"` escaping of the interpolated identifier.

## [1.0.2] - 2026-04-17

### Changed
- **Performance**: `bin/tmux-sessions.sh` and `bin/tmux-iterm-tabs.sh` replace per-call `sanitize_name` subshell (`$(sanitize_name "$raw")`) with `_SAFE_NAME` global-setting pattern — eliminates one fork per call site (CPT-20).

## [1.0.1] - 2026-04-13

### Fixed
- **Security**: Added `sanitize_for_applescript()` to strip control characters (newlines, CR, tabs, null bytes, escape sequences) from session names before AppleScript generation, preventing injection via crafted tmux session names

## [1.0.0] - 2026-03-30

### Added
- Initial release: iTerm2 + tmux tab orchestration
- Colored tabs per repo directory with configurable label/color mappings
- Session management: attach, picker, background watermarks
- Auto-start via zshrc snippet
- Install/uninstall scripts
- tmux.conf.recommended with sensible defaults
