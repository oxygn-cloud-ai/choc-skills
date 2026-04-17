# Changelog — iterm2-tmux

All notable changes to the iterm2-tmux tool will be documented in this file.

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
