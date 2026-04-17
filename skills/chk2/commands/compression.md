---
name: chk2:compression
description: "Test BREACH, CRIME, and decompression attacks"
allowed-tools: Read, Bash(curl *), Bash(openssl *), Bash(python3 *), Bash(echo *), Write
---

# chk2:compression — Compression Attacks

Test for compression-related vulnerabilities on https://myzr.io. Append results to `SECURITY_CHECK.md`.

## Tests

```bash
# CP1: BREACH — check if API responses with auth tokens use gzip compression
# Send request with Accept-Encoding: gzip and check Content-Encoding
curl -sI "https://myzr.io/api" -X POST \
  -H "Content-Type: application/json" \
  -d '{"action":"new-game"}' \
  -H "Accept-Encoding: gzip, deflate, br" \
  -H "User-Agent: Mozilla/5.0" | grep -i "content-encoding"

# Also check on a request that includes session auth
SID=$(curl -s "https://myzr.io/api" -X POST -H "Content-Type: application/json" -d '{"action":"new-game"}' -H "User-Agent: Mozilla/5.0" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sessionId',''))")

curl -sI "https://myzr.io/api" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"action\":\"game-state\",\"sessionId\":\"$SID\"}" \
  -H "Accept-Encoding: gzip, deflate, br" \
  -H "User-Agent: Mozilla/5.0" | grep -i "content-encoding"
```

```bash
# CP2: CRIME — check if TLS compression is enabled
echo | openssl s_client -connect myzr.io:443 -servername myzr.io 2>/dev/null | grep -i "Compression"
```

```bash
# CP3: Decompression bomb — send gzip-compressed 10MB payload (~10KB compressed)
python3 -c "
import gzip, io
# Create ~10MB of repeated data, compresses to ~10KB
data = b'A' * (10 * 1024 * 1024)
buf = io.BytesIO()
with gzip.GzipFile(fileobj=buf, mode='wb') as f:
    f.write(data)
compressed = buf.getvalue()
import sys
sys.stdout.buffer.write(compressed)
" | curl -s -o /dev/null -w "%{http_code} %{time_total}s %{size_download}bytes\n" \
  "https://myzr.io/api" -X POST \
  -H "Content-Encoding: gzip" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Mozilla/5.0" \
  --data-binary @-
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| CP1 | BREACH (compressed auth responses) | API responses containing auth tokens do NOT use `Content-Encoding: gzip` (WARN if compressed) |
| CP2 | CRIME (TLS compression) | `openssl s_client` shows `Compression: NONE` (FAIL if compression enabled) |
| CP3 | Decompression bomb | Server returns 413 or rejects quickly (<2s) when sent gzip-compressed 10MB payload (PASS if rejected) |

## Output

Append to `SECURITY_CHECK.md`:

```markdown
### Compression

| # | Test | Result | Evidence |
|---|------|--------|----------|
| CP1 | BREACH | {PASS/WARN} | {Content-Encoding header value or absent} |
| CP2 | CRIME | {PASS/FAIL} | {Compression value from openssl} |
| CP3 | Decompression bomb | {PASS/FAIL} | {HTTP status and response time} |
```

## After

Ask the user: **Do you want help fixing the compression issues found?** If yes, invoke `/chk2:fix` with context about which compression tests failed.
