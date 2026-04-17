---
name: chk2:backend
description: "Test backend fingerprinting exposure"
allowed-tools: Read, Bash(curl *), Bash(python3 *), Bash(echo *), Bash(rm *), Write
---

# chk2:backend — Backend Fingerprinting

Test backend fingerprinting exposure on https://${TARGET:-myzr.io}. Append results to `SECURITY_CHECK.md`.

## Tests

```bash
# BF1: Error behavior fingerprinting — send different invalid requests
# Check for Node.js patterns (SyntaxError, TypeError, "at Object.", "at Module.")
curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/json" -d "{invalid" -H "User-Agent: Mozilla/5.0"
# Check for Python patterns (Traceback, File "...", IndentationError)
curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: text/xml" -d "<xml>" -H "User-Agent: Mozilla/5.0"
# Check for PHP patterns (Fatal error, Warning:, Notice:)
curl -s "https://${TARGET:-myzr.io}/api" -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "action=health" -H "User-Agent: Mozilla/5.0"
# Trigger method not allowed
curl -s "https://${TARGET:-myzr.io}/api" -X PATCH -H "User-Agent: Mozilla/5.0"
# Very long URL
curl -s -o /dev/null -w "%{http_code}" "https://${TARGET:-myzr.io}/$(python3 -c "print('a'*8000)")" -H "User-Agent: Mozilla/5.0"

# BF2: Default favicon hash — download /favicon.ico and compute md5
curl -s "https://${TARGET:-myzr.io}/favicon.ico" -o /tmp/favicon_chk.ico -H "User-Agent: Mozilla/5.0" -w "%{http_code}" 2>/dev/null
FAVICON_STATUS=$?
if [ -f /tmp/favicon_chk.ico ]; then
  FAVICON_MD5=$(md5 -q /tmp/favicon_chk.ico 2>/dev/null || md5sum /tmp/favicon_chk.ico 2>/dev/null | awk '{print $1}')
  FAVICON_SIZE=$(wc -c < /tmp/favicon_chk.ico | tr -d ' ')
  echo "Favicon MD5: $FAVICON_MD5"
  echo "Favicon size: $FAVICON_SIZE bytes"
  rm -f /tmp/favicon_chk.ico
fi
```

```python
import urllib.request, time, statistics, json

TARGET = "myzr.io"

# Known default favicon MD5 hashes (common frameworks)
KNOWN_FAVICONS = {
    "1b6d70a2e86a090e145e23e6d07d4048": "Django",
    "b0bca3a01f855ab5fc60e6ce4f1e29e0": "WordPress",
    "d41d8cd98f00b204e9800998ecf8427e": "Empty file",
    "aafb43889c72c5a7c8b2e6142b615614": "Apache Tomcat",
    "a27c2d56609aefb4bcf0bc58ffc2a8d5": "Express.js default",
    "71e30c507ca3fa005e2d1322a5aa8fb4": "Spring Boot",
    "2cc15cfae0e4fa8d4c2c1c7e4b8e0d21": "Laravel",
    "c8c25e79a80e1a1b0b10c7e6d3b8e50c": "Next.js default",
    "3749a3e43bcad3e0e5bdb2f6d67d0a89": "Ruby on Rails",
}

# BF3: Timing-based detection — measure response times for different path types
paths = {
    "static_html": "/",
    "static_asset": "/favicon.ico",
    "api_health": "/api",
    "not_found": "/nonexistent-path-12345",
    "error_trigger": "/api",
}

methods_and_data = {
    "static_html": ("GET", None),
    "static_asset": ("GET", None),
    "api_health": ("POST", json.dumps({"action": "health"}).encode()),
    "not_found": ("GET", None),
    "error_trigger": ("POST", b"{invalid"),
}

for label, path in paths.items():
    timings = []
    method, data = methods_and_data[label]
    for _ in range(5):
        req = urllib.request.Request(
            f"https://{TARGET}{path}",
            data=data,
            headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"},
            method=method,
        )
        start = time.perf_counter()
        try:
            urllib.request.urlopen(req, timeout=10)
        except urllib.error.HTTPError:
            pass
        except Exception:
            pass
        elapsed = (time.perf_counter() - start) * 1000
        timings.append(elapsed)

    avg = statistics.mean(timings)
    std = statistics.stdev(timings) if len(timings) > 1 else 0
    print(f"  {label:20s}  avg={avg:7.1f}ms  std={std:5.1f}ms  (min={min(timings):.1f}, max={max(timings):.1f})")
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| BF1 | Error behavior fingerprinting | Error responses do NOT contain framework-identifiable patterns: Node.js (`SyntaxError`, `at Object.`, `at Module.`), Python (`Traceback`, `File "`), PHP (`Fatal error`, `Warning:`), or Java (`java.lang.`, `at com.`). WARN if framework identifiable from error output |
| BF2 | Default favicon hash | `/favicon.ico` MD5 hash does NOT match known framework default hashes (Django, Express, Spring Boot, etc.). WARN if matches a known default. PASS if custom or 404 |
| BF3 | Timing-based detection | Informational only — report average response times for static, dynamic, and error paths. Note significant timing differences that could reveal architecture |

## Output

Write to `SECURITY_CHECK.parts/backend.md`:

```markdown
### Backend

| # | Test | Result | Evidence |
|---|------|--------|----------|
| BF1 | Error behavior fingerprinting | {PASS/WARN} | {framework patterns found or "no identifiable patterns"} |
| BF2 | Default favicon hash | {PASS/WARN} | {MD5 hash and match result} |
| BF3 | Timing-based detection | {INFO} | {avg response times per path type} |
...
```

## After

Ask the user: **Do you want help fixing the backend fingerprinting issues found?** If yes, invoke `/chk2:fix` with context about which backend tests failed.

## Status signal

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
