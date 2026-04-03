#!/usr/bin/env python3
"""RR Batch Monitor — comprehensive live dashboard using Rich.

Standalone script that runs in its own terminal window.
Polls ~/rr-work/ every 2 seconds and displays:
  - Per-batch sub-agent status (dispatched/running/success/error)
  - Per-risk assessment and publication status
  - Error details with actual error messages
  - Color-coded log stream (30 lines)
  - Overall progress with elapsed time

Usage:
    python3 monitor.py
    RR_WORK_DIR=/custom/path python3 monitor.py
"""

import os
import sys
import json
import time
from pathlib import Path
from datetime import datetime

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
    d = WORK_DIR / subdir
    if not d.exists():
        return 0
    return len([f for f in d.iterdir() if f.is_file()])


def list_files(subdir):
    d = WORK_DIR / subdir
    if not d.exists():
        return []
    return sorted([f.stem for f in d.iterdir() if f.is_file()])


def read_json_field(filename, field, default=0):
    f = WORK_DIR / filename
    if not f.exists():
        return default
    try:
        data = json.loads(f.read_text())
        return data.get(field, default)
    except Exception:
        return default


def get_phase():
    log = WORK_DIR / "batch.log"
    if not log.exists():
        return 0, "No log"
    try:
        lines = log.read_text().splitlines()
    except Exception:
        return 0, "Read error"
    names = {
        1: "Discovery", 2: "Quarterly Filter", 3: "Extraction",
        4: "Sub-Agent Dispatch", 5: "Collection", 6: "Publication", 7: "Completion",
    }
    for line in reversed(lines):
        if "PHASE" in line:
            for word in line.split():
                if word.isdigit() and int(word) in names:
                    return int(word), names[int(word)]
    return 0, "Starting..."


def get_log_tail(n=30):
    log = WORK_DIR / "batch.log"
    if not log.exists():
        return []
    try:
        lines = log.read_text().splitlines()
        return lines[-n:] if lines else []
    except Exception:
        return []


def get_start_time():
    log = WORK_DIR / "batch.log"
    if not log.exists():
        return None
    try:
        first_line = log.read_text().splitlines()[0]
        ts = first_line.split("]")[0].lstrip("[")
        return datetime.strptime(ts, "%Y-%m-%d %H:%M:%S")
    except Exception:
        return None


def is_complete():
    log = WORK_DIR / "batch.log"
    if not log.exists():
        return False
    try:
        return "BATCH COMPLETE" in log.read_text()
    except Exception:
        return False


def get_risk_keys():
    disco = WORK_DIR / "discovery.json"
    if not disco.exists():
        return []
    try:
        data = json.loads(disco.read_text())
        return [r["key"] for r in data.get("risks", [])]
    except Exception:
        return []


def get_error_detail(subdir, key):
    f = WORK_DIR / subdir / f"{key}.json"
    if not f.exists():
        return None
    try:
        data = json.loads(f.read_text())
        resp = data.get("response", "")
        if isinstance(resp, str) and "errorMessages" in resp:
            try:
                inner = json.loads(resp)
                msgs = inner.get("errorMessages", [])
                errs = inner.get("errors", {})
                if msgs:
                    return "; ".join(msgs)
                if errs:
                    return "; ".join(f"{k}: {v}" for k, v in errs.items())
            except Exception:
                pass
        return data.get("error", "unknown")
    except Exception:
        return "parse_error"


def build_batch_table():
    batches = sorted(
        WORK_DIR.glob("extracts/batch_*.json"),
        key=lambda p: int(p.stem.replace("batch_", ""))
    )
    if not batches:
        return None

    table = Table(title="Sub-Agent Batches", show_header=True, header_style="bold", expand=True)
    table.add_column("#", width=3, justify="right")
    table.add_column("Risks", width=6, justify="right")
    table.add_column("Dispatch", width=9, justify="center")
    table.add_column("Result", width=9, justify="center")
    table.add_column("Status", width=14)

    for batch_file in batches:
        num = batch_file.stem.replace("batch_", "")
        try:
            batch_data = json.loads(batch_file.read_text())
            risk_count = len(batch_data) if isinstance(batch_data, list) else "?"
        except Exception:
            risk_count = "?"

        has_payload = (WORK_DIR / f"payloads/payload_{num}.json").exists()
        has_result = (WORK_DIR / f"results/result_{num}.json").exists()
        has_error = (WORK_DIR / f"errors/error_{num}.json").exists()

        dispatch_str = "[green]sent[/]" if has_payload else "[dim]pending[/]"
        if has_result:
            result_str = "[green]success[/]"
            status_str = "[green]✓ done[/]"
        elif has_error:
            result_str = "[red]failed[/]"
            err = get_error_detail("errors", f"error_{num}")
            status_str = f"[red]✗ {str(err)[:20]}[/]" if err else "[red]✗ error[/]"
        elif has_payload:
            result_str = "[yellow]waiting[/]"
            status_str = "[yellow]… running[/]"
        else:
            result_str = "[dim]—[/]"
            status_str = "[dim]pending[/]"

        table.add_row(num, str(risk_count), dispatch_str, result_str, status_str)

    return table


def build_risk_panel():
    assessed_keys = set(list_files("individual"))
    published_keys = set(list_files("jira-results"))
    pub_error_keys = set(list_files("jira-errors"))
    all_keys = get_risk_keys()

    if not all_keys:
        return None

    counts = {"published": 0, "pub_error": 0, "assessed": 0, "pending": 0}
    risk_statuses = []
    for key in all_keys:
        if key in published_keys:
            counts["published"] += 1
            risk_statuses.append((key, "published"))
        elif key in pub_error_keys:
            counts["pub_error"] += 1
            risk_statuses.append((key, "pub_error"))
        elif key in assessed_keys:
            counts["assessed"] += 1
            risk_statuses.append((key, "assessed"))
        else:
            counts["pending"] += 1
            risk_statuses.append((key, "pending"))

    total = len(all_keys)
    summary = Text()
    summary.append(f"  {total} risks: ", style="bold")
    summary.append(f"{counts['published']} published", style="green")
    summary.append("  ")
    summary.append(f"{counts['assessed']} assessed", style="cyan")
    summary.append("  ")
    if counts["pub_error"] > 0:
        summary.append(f"{counts['pub_error']} failed", style="red")
        summary.append("  ")
    summary.append(f"{counts['pending']} pending", style="dim")

    active = [(k, s) for k, s in risk_statuses if s != "published"]

    if not active and counts["published"] == total:
        done_text = Text("  All risks published successfully.", style="green")
        return Panel(Group(summary, done_text), title="Risk Status", border_style="cyan")

    table = Table(show_header=True, header_style="bold", expand=True, show_lines=False)
    table.add_column("Risk", width=10)
    table.add_column("Status", width=14)
    table.add_column("Detail", ratio=1)

    for key, status in active[:40]:
        if status == "pub_error":
            err = get_error_detail("jira-errors", key)
            table.add_row(key, "[red]✗ pub failed[/]", f"[red]{err}[/]" if err else "")
        elif status == "assessed":
            table.add_row(key, "[cyan]✓ assessed[/]", "[dim]awaiting publication[/]")
        elif status == "pending":
            table.add_row(key, "[dim]· pending[/]", "")

    remaining = len(active) - 40
    if remaining > 0:
        table.add_row("", f"[dim]+{remaining} more[/]", "")

    return Panel(Group(summary, table), title="Risk Status", border_style="cyan")


def colorize_log_line(line):
    text = Text(line)
    upper = line.upper()
    if "SUCCESS" in upper:
        text.stylize("green")
    elif "FAILED" in upper or "ERROR" in upper:
        text.stylize("red")
    elif "SKIP" in upper:
        text.stylize("yellow")
    elif "PHASE" in upper or "BATCH COMPLETE" in upper or "====" in line:
        text.stylize("bold cyan")
    elif "PUBLISHING" in upper or "DISPATCHING" in upper:
        text.stylize("dim")
    elif "ATTACHED" in upper:
        text.stylize("green dim")
    elif "WARN" in upper or "RETRY" in upper or "Rate limited" in line:
        text.stylize("yellow bold")
    else:
        text.stylize("dim")
    return text


def build_log_panel():
    lines = get_log_tail(30)
    if not lines:
        return Panel(Text("No log output yet.", style="dim"), title="Log Stream", border_style="dim")

    log_content = Text()
    for i, line in enumerate(lines):
        log_content.append_text(colorize_log_line(line))
        if i < len(lines) - 1:
            log_content.append("\n")

    return Panel(log_content, title=f"Log Stream (last {len(lines)} lines)", border_style="dim")


def build_error_panel():
    jira_errors = list_files("jira-errors")
    dispatch_errors = list_files("errors")

    if not jira_errors and not dispatch_errors:
        return None

    text = Text()
    if dispatch_errors:
        text.append("Sub-Agent Failures:\n", style="bold red")
        for name in dispatch_errors[:10]:
            err = get_error_detail("errors", name)
            text.append(f"  {name}: {err}\n", style="red")
        if len(dispatch_errors) > 10:
            text.append(f"  ... +{len(dispatch_errors) - 10} more\n", style="dim red")

    if jira_errors:
        if dispatch_errors:
            text.append("\n")
        text.append("Jira Publication Failures:\n", style="bold red")
        for key in jira_errors[:15]:
            err = get_error_detail("jira-errors", key)
            text.append(f"  {key}: {err}\n", style="red")
        if len(jira_errors) > 15:
            text.append(f"  ... +{len(jira_errors) - 15} more\n", style="dim red")

    return Panel(text, title="[red]Errors[/]", border_style="red")


def build_dashboard():
    total_risks = read_json_field("discovery.json", "total", 0)
    to_process = read_json_field("filter-result.json", "to_process", 0)
    if to_process == 0:
        to_process = total_risks

    assessments = count_files("individual")
    jira_ok = count_files("jira-results")
    phase_num, phase_name = get_phase()
    complete = is_complete()
    now = time.strftime("%H:%M:%S")

    start = get_start_time()
    elapsed = ""
    if start:
        delta = datetime.now() - start
        mins = int(delta.total_seconds() // 60)
        secs = int(delta.total_seconds() % 60)
        elapsed = f"  Elapsed: {mins}m {secs}s"

    # Phase-aware progress percentage
    if phase_num <= 3:
        pct = phase_num * 10
    elif phase_num == 4:
        results = count_files("results")
        batches = max(count_files("extracts"), 1)
        pct = 30 + (20 * results // batches)
    elif phase_num == 5:
        pct = 50 + (20 * assessments // max(to_process, 1))
    elif phase_num == 6:
        pct = 70 + (30 * jira_ok // max(to_process, 1))
    elif phase_num == 7:
        pct = 100
    else:
        pct = 0
    pct = min(pct, 100)

    if complete:
        header = Text(f"  COMPLETE — Phase {phase_num}: {phase_name}    {now}{elapsed}", style="bold green")
    else:
        header = Text(f"  Phase {phase_num}: {phase_name}    [{pct}%]    {now}{elapsed}", style="bold cyan")

    bar_width = 50
    filled = pct * bar_width // 100
    bar_str = "█" * filled + "░" * (bar_width - filled)
    bar_text = Text(f"  {bar_str} {pct}%")
    bar_text.stylize("green" if complete else "cyan", 2, 2 + filled)

    sections = [header, bar_text, Text("")]

    batch_table = build_batch_table()
    if batch_table:
        sections.append(batch_table)
        sections.append(Text(""))

    risk_panel = build_risk_panel()
    if risk_panel:
        sections.append(risk_panel)
        sections.append(Text(""))

    error_panel = build_error_panel()
    if error_panel:
        sections.append(error_panel)
        sections.append(Text(""))

    sections.append(build_log_panel())

    subtitle = "[green]Batch complete[/]" if complete else "[dim]Ctrl+C to exit — refreshes every 2s[/]"
    return Panel(
        Group(*sections),
        title="[bold] RR BATCH MONITOR [/]",
        subtitle=subtitle,
        border_style="green" if complete else "blue",
    )


def main():
    if not WORK_DIR.exists():
        print(f"No work directory at {WORK_DIR}")
        print("Start a batch first: /rr all")
        sys.exit(1)

    console = Console()
    console.print(f"[dim]Monitoring {WORK_DIR}[/]\n")

    try:
        with Live(build_dashboard(), console=console, refresh_per_second=0.5, screen=True) as live:
            while True:
                time.sleep(2)
                live.update(build_dashboard())
                if is_complete():
                    time.sleep(5)
                    break
    except KeyboardInterrupt:
        pass

    console.print("\n[dim]Monitor stopped.[/]")


if __name__ == "__main__":
    main()
