# Changelog — iterm2-tmux

All notable changes to the iterm2-tmux tool will be documented in this file.

## [1.1.0] - 2026-04-13

### Fixed
- `--session` mode no longer triggers autostart tabs for all `/Repos` directories
- Added session-active sentinel file to suppress autostart within 60s of `--session` launch
- Lock directory is now recreated with fresh mtime instead of using `mkdir -p`
- Locks refreshed after AppleScript completes to extend suppression window
- Removed legacy autostart block from `~/.zshrc` (superseded by managed block)

## [1.0.0] - 2026-03-30

### Added
- Initial release: iTerm2 + tmux tab orchestration
- Colored tabs per repo directory with configurable label/color mappings
- Session management: attach, picker, background watermarks
- Auto-start via zshrc snippet
- Install/uninstall scripts
- tmux.conf.recommended with sensible defaults
