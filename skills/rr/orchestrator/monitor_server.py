#!/usr/bin/env python3
"""RR Batch Monitor — HTTP API server.

Serves ~/rr-work/ data as JSON endpoints for the web dashboard.
Also serves the static HTML dashboard file.

Usage:
    python3 monitor_server.py [--port 8770]
    RR_WORK_DIR=/custom/path python3 monitor_server.py
"""

import os
import sys
import json
import glob
import http.server
import socketserver
from pathlib import Path
from urllib.parse import urlparse, parse_qs

WORK_DIR = Path(os.environ.get("RR_WORK_DIR", Path.home() / "rr-work"))
PORT = int(sys.argv[sys.argv.index("--port") + 1]) if "--port" in sys.argv else 8770
SCRIPT_DIR = Path(__file__).parent


def count_files(subdir):
    d = WORK_DIR / subdir
    if not d.exists():
        return 0
    return len([f for f in d.iterdir() if f.is_file() and f.suffix == ".json"])


def list_stems(subdir):
    d = WORK_DIR / subdir
    if not d.exists():
        return []
    return sorted([f.stem for f in d.iterdir() if f.is_file() and f.suffix == ".json"])


def read_json_safe(path):
    try:
        return json.loads(Path(path).read_text())
    except Exception:
        return None


def get_phase():
    log = WORK_DIR / "batch.log"
    if not log.exists():
        return {"num": 0, "name": "No log"}
    try:
        lines = log.read_text().splitlines()
    except Exception:
        return {"num": 0, "name": "Read error"}
    names = {
        1: "Discovery", 2: "Quarterly Filter", 3: "Extraction",
        4: "Sub-Agent Dispatch", 5: "Collection", 6: "Publication", 7: "Completion",
    }
    for line in reversed(lines):
        if "PHASE" in line:
            for word in line.split():
                if word.isdigit() and int(word) in names:
                    return {"num": int(word), "name": names[int(word)]}
    return {"num": 0, "name": "Starting..."}


def get_log_tail(n=50):
    log = WORK_DIR / "batch.log"
    if not log.exists():
        return []
    try:
        lines = log.read_text().splitlines()
        return lines[-n:]
    except Exception:
        return []


def is_complete():
    log = WORK_DIR / "batch.log"
    if not log.exists():
        return False
    try:
        return "BATCH COMPLETE" in log.read_text()
    except Exception:
        return False


def get_start_time():
    log = WORK_DIR / "batch.log"
    if not log.exists():
        return None
    try:
        first_line = log.read_text().splitlines()[0]
        return first_line.split("]")[0].lstrip("[")
    except Exception:
        return None


def build_batch_status():
    batches = sorted(
        WORK_DIR.glob("extracts/batch_*.json"),
        key=lambda p: int(p.stem.replace("batch_", ""))
    )
    in_progress_keys = set(list_stems("progress"))

    result = []
    for bf in batches:
        num = bf.stem.replace("batch_", "")
        try:
            data = json.loads(bf.read_text())
            risk_count = len(data) if isinstance(data, list) else 0
            risk_keys = [r.get("key", "?") for r in data] if isinstance(data, list) else []
        except Exception:
            risk_count = 0
            risk_keys = []

        has_payload = (WORK_DIR / f"payloads/payload_{num}.json").exists()
        has_result = (WORK_DIR / f"results/result_{num}.json").exists()
        has_error = (WORK_DIR / f"errors/error_{num}.json").exists()

        # Count how many risks in this batch have reported progress
        reported = sum(1 for k in risk_keys if k in in_progress_keys)

        status = "pending"
        if has_result:
            status = "success"
        elif has_error:
            status = "error"
        elif has_payload:
            status = "running"

        result.append({
            "num": int(num),
            "risks": risk_count,
            "risk_keys": risk_keys,
            "dispatched": has_payload,
            "result": has_result,
            "error": has_error,
            "status": status,
            "reported": reported,
        })
    return result


def build_risk_status():
    assessed = set(list_stems("individual"))
    published = set(list_stems("jira-results"))
    pub_errors = set(list_stems("jira-errors"))
    in_progress = set(list_stems("progress"))  # tool-use progress reports

    disco = WORK_DIR / "discovery.json"
    all_keys = []
    if disco.exists():
        try:
            data = json.loads(disco.read_text())
            all_keys = [r["key"] for r in data.get("risks", [])]
        except Exception:
            pass

    risks = []
    counts = {"published": 0, "assessed": 0, "failed": 0, "in_progress": 0, "pending": 0}
    for key in all_keys:
        if key in published:
            counts["published"] += 1
            risks.append({"key": key, "status": "published"})
        elif key in pub_errors:
            counts["failed"] += 1
            err_data = read_json_safe(WORK_DIR / f"jira-errors/{key}.json")
            error_msg = ""
            if err_data:
                resp = err_data.get("response", "")
                if isinstance(resp, str):
                    try:
                        inner = json.loads(resp)
                        errs = inner.get("errors", {})
                        msgs = inner.get("errorMessages", [])
                        error_msg = "; ".join(msgs) if msgs else "; ".join(f"{k}: {v}" for k, v in errs.items())
                    except Exception:
                        error_msg = err_data.get("error", "unknown")
                else:
                    error_msg = err_data.get("error", "unknown")
            risks.append({"key": key, "status": "failed", "error": error_msg})
        elif key in assessed:
            counts["assessed"] += 1
            risks.append({"key": key, "status": "assessed"})
        elif key in in_progress:
            counts["in_progress"] += 1
            prog_data = read_json_safe(WORK_DIR / f"progress/{key}.json")
            risks.append({
                "key": key,
                "status": "in_progress",
                "inherent_rating": prog_data.get("inherent_rating") if prog_data else None,
                "residual_rating": prog_data.get("residual_rating") if prog_data else None,
            })
        else:
            counts["pending"] += 1
            risks.append({"key": key, "status": "pending"})

    return {"counts": counts, "total": len(all_keys), "risks": risks}


def build_live_progress():
    """Read per-risk progress files from sub-agent tool-use reports."""
    progress_dir = WORK_DIR / "progress"
    if not progress_dir.exists():
        return []
    results = []
    for f in sorted(progress_dir.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True):
        if f.suffix == ".json":
            data = read_json_safe(f)
            if data:
                results.append(data)
    return results


def build_api_response():
    total_risks = 0
    to_process = 0
    disco = WORK_DIR / "discovery.json"
    if disco.exists():
        d = read_json_safe(disco)
        if d:
            total_risks = d.get("total", 0)

    filt = WORK_DIR / "filter-result.json"
    if filt.exists():
        f = read_json_safe(filt)
        if f:
            to_process = f.get("to_process", f.get("total", 0))

    phase = get_phase()
    complete = is_complete()
    start = get_start_time()

    return {
        "total_risks": total_risks,
        "to_process": to_process or total_risks,
        "phase": phase,
        "complete": complete,
        "start_time": start,
        "batches": build_batch_status(),
        "risks": build_risk_status(),
        "progress": build_live_progress(),
        "log": get_log_tail(50),
        "counts": {
            "extracts": count_files("extracts"),
            "payloads": count_files("payloads"),
            "results": count_files("results"),
            "errors": count_files("errors"),
            "individual": count_files("individual"),
            "jira_results": count_files("jira-results"),
            "jira_errors": count_files("jira-errors"),
        },
    }


class MonitorHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/api/status":
            data = build_api_response()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(data).encode())
            return

        if parsed.path == "/" or parsed.path == "/index.html":
            dash = SCRIPT_DIR / "monitor_dashboard.html"
            if dash.exists():
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(dash.read_bytes())
                return

        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        pass  # Suppress request logging


def main():
    if not WORK_DIR.exists():
        print(f"No work directory at {WORK_DIR}")
        print("Start a batch first: /rr all")
        sys.exit(1)

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), MonitorHandler) as httpd:
        print(f"RR Monitor server running at http://localhost:{PORT}")
        print(f"Monitoring: {WORK_DIR}")
        print("Press Ctrl+C to stop")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")


if __name__ == "__main__":
    main()
