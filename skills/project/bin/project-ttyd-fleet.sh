#!/usr/bin/env bash
set -uo pipefail

# project-ttyd-fleet — manage a fleet of ttyd servers, one per role, so each
# tmux window is reachable as its own browser tab.
#
# Implements: CPT-73 Option 7 (ttyd browser-tab-per-role)
#
# USAGE
#   project-ttyd-fleet.sh start <session> [--base-port <N>] [--roles a,b,...]
#   project-ttyd-fleet.sh stop  <session>
#   project-ttyd-fleet.sh status <session>
#   project-ttyd-fleet.sh --help
#
# START
#   For each window index 0..N-1 in the named tmux session, start:
#     ttyd -p <BASE_PORT + index> -W tmux attach -t <session> \; select-window -t <index>
#   Record PIDs to $TTYD_FLEET_STATE_DIR/<session>.pids. Default state dir is
#   ~/.ttyd-fleet.
#
# STOP
#   Read PID file, TERM each PID, wait, remove the file.
#
# STATUS
#   Read PID file, report which PIDs are still alive and their ports.
#
# SECURITY WARNING
#   Default bind is 127.0.0.1 (-i lo). NEVER expose ttyd -W (writable mode) on a
#   public interface without TLS and basic auth — -W is functionally a
#   network-reachable shell on your Mac. For LAN use, prefer Tailscale MagicDNS.

SCRIPT_NAME="$(basename "$0")"
TTYD_FLEET_STATE_DIR="${TTYD_FLEET_STATE_DIR:-${HOME}/.ttyd-fleet}"
BASE_PORT=7681
ROLES_OVERRIDE=""

usage() {
  cat <<EOF
${SCRIPT_NAME} — fleet of ttyd servers, one per tmux window

USAGE
  ${SCRIPT_NAME} start <session> [--base-port <N>] [--roles r1,r2,...]
  ${SCRIPT_NAME} stop <session>
  ${SCRIPT_NAME} status <session>
  ${SCRIPT_NAME} --help

ARGUMENTS
  <session>          tmux session name (e.g. choc-skills)
  --base-port <N>    first port in the fleet (default 7681; ports N..N+windows-1)
  --roles r1,r2,...  explicit role list (default: all windows in the tmux session)

ENV
  TTYD_FLEET_STATE_DIR    where PID files live (default: ~/.ttyd-fleet)

SECURITY
  Binds to 127.0.0.1 only. Never expose -W publicly without TLS + auth.
  See skills/project/commands/launch.md for LAN / Tailscale guidance.

EXIT
  0  success
  1  ttyd not installed, tmux session missing, or runtime error
  2  invalid flag / usage error
EOF
}

# ---------------------------------------------------------------
# Flag parse
# ---------------------------------------------------------------

if [ $# -lt 1 ]; then
  usage >&2
  exit 2
fi

SUBCMD="$1"
shift

case "$SUBCMD" in
  --help|-h) usage; exit 0 ;;
  start|stop|status) : ;;
  *) echo "unknown subcommand: $SUBCMD" >&2; usage >&2; exit 2 ;;
esac

if [ $# -lt 1 ]; then
  echo "missing <session> argument" >&2
  exit 2
fi
SESSION="$1"
shift

while [ $# -gt 0 ]; do
  case "$1" in
    --base-port) BASE_PORT="$2"; shift ;;
    --base-port=*) BASE_PORT="${1#*=}" ;;
    --roles) ROLES_OVERRIDE="$2"; shift ;;
    --roles=*) ROLES_OVERRIDE="${1#*=}" ;;
    *) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

PID_FILE="${TTYD_FLEET_STATE_DIR}/${SESSION}.pids"

# ---------------------------------------------------------------
# Commands
# ---------------------------------------------------------------

cmd_start() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux not installed" >&2
    return 1
  fi
  if ! command -v ttyd >/dev/null 2>&1; then
    echo "ttyd not installed — install with: brew install ttyd" >&2
    return 1
  fi
  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "tmux session '${SESSION}' not found — run /project:launch first" >&2
    return 1
  fi
  if [ -f "$PID_FILE" ]; then
    echo "fleet already running for '${SESSION}' (state: ${PID_FILE}). Run 'stop' first." >&2
    return 1
  fi

  # Resolve role list
  local roles
  if [ -n "$ROLES_OVERRIDE" ]; then
    roles="$ROLES_OVERRIDE"
  else
    # Read window names from tmux
    roles=$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  fi

  if [ -z "$roles" ]; then
    echo "no windows / roles found for session '${SESSION}'" >&2
    return 1
  fi

  mkdir -p "$TTYD_FLEET_STATE_DIR"

  # Start ttyd per role, bound to localhost
  local idx=0
  local pids=()
  IFS=',' read -r -a role_list <<< "$roles"
  for role in "${role_list[@]}"; do
    local port=$((BASE_PORT + idx))
    # Start ttyd in background, bound to 127.0.0.1 for safety
    # -W = writable (allow stdin), -i lo = bind loopback only
    ttyd -p "$port" -W -i lo \
      tmux attach -t "$SESSION" \; select-window -t "$idx" \
      >/dev/null 2>&1 &
    local pid=$!
    pids+=("${pid}:${port}:${role}")
    idx=$((idx + 1))
  done

  # Write PID file
  printf '%s\n' "${pids[@]}" > "$PID_FILE"
  echo "started ${#pids[@]} ttyd server(s) for session '${SESSION}'"
  for entry in "${pids[@]}"; do
    IFS=':' read -r pid port role <<< "$entry"
    printf "  %-20s http://localhost:%d  (pid %s)\n" "$role" "$port" "$pid"
  done
  echo ""
  echo "State file: ${PID_FILE}"
  echo "Stop with:  ${SCRIPT_NAME} stop ${SESSION}"
}

cmd_stop() {
  if [ ! -f "$PID_FILE" ]; then
    echo "no fleet running for '${SESSION}'" >&2
    return 0
  fi

  local count=0
  while IFS=':' read -r pid port role; do
    [ -z "$pid" ] && continue
    if kill -0 "$pid" 2>/dev/null; then
      kill -TERM "$pid" 2>/dev/null || true
      count=$((count + 1))
    fi
  done < "$PID_FILE"

  # Wait briefly for clean shutdown
  sleep 0.3

  # Force-kill any stragglers
  while IFS=':' read -r pid port role; do
    [ -z "$pid" ] && continue
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done < "$PID_FILE"

  rm -f "$PID_FILE"
  echo "stopped ${count} ttyd server(s) for '${SESSION}'"
}

cmd_status() {
  if [ ! -f "$PID_FILE" ]; then
    echo "no fleet running for '${SESSION}'"
    return 1
  fi

  echo "Fleet for '${SESSION}':"
  local alive=0 dead=0
  while IFS=':' read -r pid port role; do
    [ -z "$pid" ] && continue
    if kill -0 "$pid" 2>/dev/null; then
      printf "  [RUN]  %-20s http://localhost:%-5d  pid %s\n" "$role" "$port" "$pid"
      alive=$((alive + 1))
    else
      printf "  [DEAD] %-20s http://localhost:%-5d  pid %s\n" "$role" "$port" "$pid"
      dead=$((dead + 1))
    fi
  done < "$PID_FILE"
  echo ""
  echo "  ${alive} running, ${dead} dead"
  [ "$dead" -eq 0 ]
}

case "$SUBCMD" in
  start)  cmd_start ;;
  stop)   cmd_stop ;;
  status) cmd_status ;;
esac
