---
name: rr:monitor
description: "Live batch progress dashboard via rich TUI"
allowed-tools: Bash(python3 *), Bash(open *)
---

# rr:monitor — Live Batch Progress Dashboard

Context from user: $ARGUMENTS

## What This Does

Opens a **new terminal window** with a live-updating dashboard that monitors the batch run in real time. The dashboard refreshes every 2 seconds and shows phase, progress bar, file counts per stage, and tailed log output. It runs independently of this Claude Code session.

## Prerequisites Check

Run this first:

```bash
python3 -c "import rich" 2>/dev/null && echo "rich: OK" || echo "rich: MISSING"
```

If rich is missing, tell the user to install it:

```
pip3 install rich
```

Wait for them to confirm before proceeding.

## Launch Monitor

Run the monitor server in the background and open the dashboard in the user's browser:

```bash
python3 ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/rr/bin/monitor.py &
echo "Monitor server running at http://localhost:8770"
open "http://localhost:8770"
```

Then tell the user:

```
Monitor running in the background. Dashboard opened at http://localhost:8770
It refreshes every 2 seconds and exits automatically when the batch completes.
Close it with Ctrl+C when done.
```

That's it. Do NOT wait for the monitor to finish. Do NOT try to read its output. It runs independently.
