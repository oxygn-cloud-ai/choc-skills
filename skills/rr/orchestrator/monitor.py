#!/usr/bin/env python3
"""RR Batch Monitor — live dashboard using Rich.

Standalone script that runs in its own terminal window.
Polls ~/rr-work/ every 2 seconds and displays a live dashboard.

Usage:
    python3 monitor.py
    RR_WORK_DIR=/custom/path python3 monitor.py
"""

import os
import sys
import json
import time
from pathlib import Path

try:
    from rich.live import Live
    from rich.table import Table
    from rich.panel import Panel
    from rich.text import Text
    from rich.console import Console, Group
except ImportError:
    print("Rich library required. Install with:")
    print("  pip3 install rich")
    sys.exit(1)

WORK_DIR = Path(os.environ.get("RR_WORK_DIR", Path.home() / "rr-work"))


def count_files(subdir):
    """Count files in a subdirectory of the work dir."""
    d = WORK_DIR / subdir
    if not d.exists():
        return 0
    return len([f for f in d.iterdir() if f.is_file()])


def read_json_field(filename, field, default=0):
    """Read a single field from a JSON file in the work dir."""
    f = WORK_DIR / filename
    if not f.exists():
        return default
    try:
        data = json.loads(f.read_text())
        return data.get(field, default)
    except Exception:
        return default


def get_phase():
    """Detect current phase from batch.log."""
    log = WORK_DIR / "batch.log"
    if not log.exists():
        return "?", "No log"
    try:
        lines = log.read_text().splitlines()
    except Exception:
        return "?", "Read error"
    names = {
        1: "Discovery",
        2: "Quarterly Filter",
        3: "Extraction",
        4: "Sub-Agent Dispatch",
        5: "Collection",
        6: "Publication",
        7: "Completion",
    }
    for line in reversed(lines):
        if "PHASE" in line:
            for word in line.split():
                if word.isdigit() and int(word) in names:
                    return word, names[int(word)]
    return "?", "Starting..."


def get_log_tail(n=8):
    """Get the last n lines from batch.log."""
    log = WORK_DIR / "batch.log"
    if not log.exists():
        return ["No log file"]
    try:
        lines = log.read_text().splitlines()
        return lines[-n:] if lines else ["Empty log"]
    except Exception:
        return ["Error reading log"]


def is_complete():
    """Check if the batch run has completed."""
    progress = WORK_DIR / "progress.md"
    log = WORK_DIR / "batch.log"
    if not progress.exists() or not log.exists():
        return False
    try:
        return "BATCH COMPLETE" in log.read_text()
    except Exception:
        return False


def build_dashboard():
    """Build the Rich dashboard layout."""
    total_risks = read_json_field("discovery.json", "total", 0)
    to_process = read_json_field("filter-result.json", "to_process", 0)

    results = count_files("results")
    errors = count_files("errors")
    assessments = count_files("individual")
    jira_ok = count_files("jira-results")
    jira_err = count_files("jira-errors")
    batches = count_files("extracts")

    phase_num, phase_name = get_phase()
    complete = is_complete()
    pct = (jira_ok * 100 // to_process) if to_process > 0 else 0

    # Status line
    if complete:
        status = Text(
            f"  COMPLETE — Phase {phase_num}: {phase_name}",
            style="bold green",
        )
    else:
        status = Text(
            f"  Phase {phase_num}: {phase_name}  [{pct}%]",
            style="bold cyan",
        )

    # Progress bar
    bar_width = 40
    filled = pct * bar_width // 100
    bar_str = "#" * filled + "-" * (bar_width - filled)
    progress_text = Text(f"  [{bar_str}] {pct}%", style="bold")

    # Stage table
    table = Table(show_header=True, header_style="bold", expand=True)
    table.add_column("Stage", style="dim", width=24)
    table.add_column("Done", justify="right", width=8)
    table.add_column("Total", justify="right", width=8)
    table.add_column("", width=3)

    def icon(done, total):
        if total == 0:
            return ""
        if done >= total:
            return "[green]✓[/]"
        if done > 0:
            return "[yellow]…[/]"
        return "[dim]·[/]"

    table.add_row("Risks discovered", str(total_risks), str(total_risks), icon(total_risks, total_risks))
    table.add_row("Filtered to process", str(to_process), str(total_risks), icon(to_process, total_risks))
    table.add_row("Batches created", str(batches), str(batches), icon(batches, batches))
    table.add_row("Sub-agent results", str(results), str(batches), icon(results, batches))
    table.add_row("Sub-agent errors", str(errors), "", "[red]✗[/]" if errors > 0 else "")
    table.add_row("Assessments extracted", str(assessments), str(to_process), icon(assessments, to_process))
    table.add_row("Published to Jira", str(jira_ok), str(to_process), icon(jira_ok, to_process))
    table.add_row("Jira errors", str(jira_err), "", "[red]✗[/]" if jira_err > 0 else "")

    # Log tail
    log_lines = get_log_tail(8)
    log_text = Text("\n".join(log_lines), style="dim")
    log_panel = Panel(log_text, title="Recent Log", border_style="dim")

    # Compose
    group = Group(status, progress_text, "", table, "", log_panel)
    return Panel(
        group,
        title="[bold] RR BATCH MONITOR [/]",
        subtitle="[dim]Ctrl+C to exit[/]",
        border_style="blue",
    )


def main():
    if not WORK_DIR.exists():
        print(f"No work directory at {WORK_DIR}")
        print("Start a batch first: /rr all")
        sys.exit(1)

    console = Console()
    console.print(f"[dim]Monitoring {WORK_DIR} — refreshing every 2s[/]\n")

    try:
        with Live(build_dashboard(), console=console, refresh_per_second=0.5) as live:
            while True:
                time.sleep(2)
                live.update(build_dashboard())
                if is_complete():
                    time.sleep(3)
                    break
    except KeyboardInterrupt:
        pass

    console.print("\n[dim]Monitor stopped.[/]")


if __name__ == "__main__":
    main()
