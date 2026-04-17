#!/usr/bin/env bats
# Tests for CPT-31: monitor.py + monitor_server.py — eliminate redundant log/dir reads
# Red-green TDD — these tests must FAIL before implementation, PASS after.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
MONITOR="$REPO_ROOT/skills/rr/bin/monitor.py"
MONITOR_SERVER="$REPO_ROOT/skills/rr/bin/monitor_server.py"

# --- monitor.py: helpers accept log_content parameter ---

@test "monitor.py get_phase accepts log_content parameter" {
  grep -q 'def get_phase.*log_content' "$MONITOR"
}

@test "monitor.py get_log_tail accepts log_content parameter" {
  grep -q 'def get_log_tail.*log_content' "$MONITOR"
}

@test "monitor.py get_start_time accepts log_content parameter" {
  grep -q 'def get_start_time.*log_content' "$MONITOR"
}

@test "monitor.py is_complete accepts log_content parameter" {
  grep -q 'def is_complete.*log_content' "$MONITOR"
}

# --- monitor.py: build_dashboard reads log once ---

@test "monitor.py build_dashboard reads batch.log once" {
  # Should call _read_log_once() once and store in log_content
  grep -q 'log_content.*=.*_read_log_once' "$MONITOR"
}

# --- monitor.py: directory caching ---

@test "monitor.py count_files accepts dir_cache parameter" {
  grep -q 'def count_files.*dir_cache\|def count_files.*cache' "$MONITOR"
}

@test "monitor.py list_files accepts dir_cache parameter" {
  grep -q 'def list_files.*dir_cache\|def list_files.*cache' "$MONITOR"
}

# --- monitor_server.py: helpers accept log_content parameter ---

@test "monitor_server.py get_phase accepts log_content parameter" {
  grep -q 'def get_phase.*log_content' "$MONITOR_SERVER"
}

@test "monitor_server.py get_log_tail accepts log_content parameter" {
  grep -q 'def get_log_tail.*log_content' "$MONITOR_SERVER"
}

@test "monitor_server.py is_complete accepts log_content parameter" {
  grep -q 'def is_complete.*log_content' "$MONITOR_SERVER"
}

@test "monitor_server.py get_start_time accepts log_content parameter" {
  grep -q 'def get_start_time.*log_content' "$MONITOR_SERVER"
}

# --- monitor_server.py: build_api_response reads log once ---

@test "monitor_server.py build_api_response reads batch.log once" {
  grep -q 'log_content.*=.*_read_log_once' "$MONITOR_SERVER"
}

# --- monitor_server.py: directory caching ---

@test "monitor_server.py count_files accepts dir_cache parameter" {
  grep -q 'def count_files.*dir_cache\|def count_files.*cache' "$MONITOR_SERVER"
}

@test "monitor_server.py list_stems accepts dir_cache parameter" {
  grep -q 'def list_stems.*dir_cache\|def list_stems.*cache' "$MONITOR_SERVER"
}

# --- Python syntax check ---

@test "monitor.py is valid Python" {
  python3 -c "import py_compile; py_compile.compile('$MONITOR', doraise=True)"
}

@test "monitor_server.py is valid Python" {
  python3 -c "import py_compile; py_compile.compile('$MONITOR_SERVER', doraise=True)"
}
