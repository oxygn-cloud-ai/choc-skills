# Changelog — iterm2-tmux

All notable changes to the iterm2-tmux tool will be documented in this file.

## [1.3.0] - 2026-04-17

### Fixed

- **`--session <project>` mode now iterates `tmux list-windows -t <project>`
  instead of enumerating global `tmux ls` and filtering by tmux env vars.**
  The old logic required each role to be its own tmux session tagged with
  `PROJECT=…` / `ROLE=…` / `ROLE_INDEX=…` environment variables. That
  architecture was superseded in the project skill (one session per project
  with one WINDOW per role), but this script was never updated — so the
  helper silently produced zero tabs on every `/project:launch` invocation.
  Now it verifies the tmux session exists, lists its windows, and opens one
  iTerm2 tab per window. Each tab exec-attaches into a specific window via
  `tmux attach -t session:window`.

- **Autostart is now opt-in (`AUTOSTART_ENABLED=true` in config).** Previously
  any iTerm2 shell launch would fire `tmux-iterm-tabs.sh` with no args, which
  enumerated every unattached global tmux session and opened a tab per
  session — on a host with 17+ project sessions that produced 17+ tabs of
  unrelated projects. This was correct for the old one-tmux-session-per-repo
  architecture but wrong for the per-project-window design. Default is now
  no-op; existing users can restore the behavior by adding
  `AUTOSTART_ENABLED=true` to `~/.config/iterm2-tmux/config`.

### Added

- `tmux-attach-session.sh` accepts an optional 5th arg `[window_name]`. When
  set, it exec-attaches into `session:window_name` instead of just `session`.
  Backwards compatible — args 1-4 unchanged, arg 5 is optional.

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
