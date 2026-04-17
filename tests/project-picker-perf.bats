#!/usr/bin/env bats
# Tests for CPT-17: project-picker.sh — eliminate excessive process forks in TUI render hot path

PICKER="skills/project/bin/project-picker.sh"
TABS="skills/iterm2-tmux/bin/tmux-iterm-tabs.sh"

# --- Finding 1: No echo|awk or echo|grep per row ---

@test "project-picker.sh does not use echo|awk for field extraction" {
  [ -f "$PICKER" ] || skip "project-picker.sh not found"
  # Should use read or parameter expansion, not echo|awk per line
  run grep -c 'echo.*|.*awk' "$PICKER"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
}

@test "project-picker.sh uses read for parsing window fields" {
  [ -f "$PICKER" ] || skip "project-picker.sh not found"
  # Should use 'read -r' to split fields
  run grep 'read -r.*wname\|read.*wname\|read -r.*name.*activity' "$PICKER"
  [ "$status" -eq 0 ]
}

# --- Finding 2: Single tmux list-windows call per session ---

@test "project-picker.sh calls list-windows once not twice per session" {
  [ -f "$PICKER" ] || skip "project-picker.sh not found"
  # get_window_count should not call tmux list-windows separately
  # It should derive count from the same data as get_windows
  run grep -c 'tmux list-windows' "$PICKER"
  # Should have at most 2 calls total (get_windows + show_roles), not 3+
  [ "$status" -eq 0 ]
  [ "$output" -le 2 ]
}

# --- Finding 3: No seq fork for box drawing ---

@test "project-picker.sh draw_box_top does not fork seq" {
  [ -f "$PICKER" ] || skip "project-picker.sh not found"
  run grep -A3 'draw_box_top' "$PICKER"
  [ "$status" -eq 0 ]
  # Should NOT contain $(seq ...)
  ! echo "$output" | grep -q 'seq'
}

@test "project-picker.sh draw_box_bottom does not fork seq" {
  [ -f "$PICKER" ] || skip "project-picker.sh not found"
  run grep -A3 'draw_box_bottom' "$PICKER"
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q 'seq'
}

# --- Finding 4: No echo|sed for ANSI stripping ---

@test "project-picker.sh draw_row does not fork sed for ANSI stripping" {
  [ -f "$PICKER" ] || skip "project-picker.sh not found"
  run grep -A5 'draw_row()' "$PICKER"
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q 'sed'
}

# --- Finding 5: tmux-iterm-tabs.sh inlines sanitize_name ---

@test "tmux-iterm-tabs.sh lookup_label does not fork subshell for sanitize_name" {
  [ -f "$TABS" ] || skip "tmux-iterm-tabs.sh not found"
  # lookup_label should NOT call $(sanitize_name ...)
  run grep -A12 'lookup_label()' "$TABS"
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q '$(sanitize_name'
}
