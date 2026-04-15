# Changelog — iterm2-tmux

All notable changes to the iterm2-tmux tool will be documented in this file.

## [1.2.1] - 2026-04-15

### Fixed
- Prefix+P bind no longer assumes the separate `project` skill is installed. The bind now runtime-probes for `~/.local/bin/project-picker.sh` and falls back to iterm2-tmux's own `~/.local/bin/tmux-picker.sh` (which the installer does ship). Previously the hardcoded path would silently fail for users who installed iterm2-tmux alone.
- Tab-title comment header no longer emitted when only the picker bind is being appended.
- Doctor/install grep for the picker bind now anchors on `^[[:space:]]*bind-key` so stray comments mentioning the script name don't mask missing binds.

## [1.2.0] - 2026-04-15

### Added
- Installer now wires `bind-key P` popup into `~/.tmux.conf`. This is the primary role-switcher on Blink/iOS where iTerm2 tabs don't exist; previously it was only documented, never installed.
- `doctor` check flags missing picker keybind.

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
