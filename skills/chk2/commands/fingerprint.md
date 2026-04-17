---
name: chk2:fingerprint
description: "Test fingerprinting-resistance and isolation headers"
allowed-tools: Read, Bash(curl *), Bash(openssl *), Bash(echo *), Write
---

# chk2:fingerprint — Browser Fingerprinting and Isolation Headers

Test fingerprinting-resistance and cross-origin isolation headers on https://${TARGET:-myzr.io}. Append results to `SECURITY_CHECK.md`.

## Tests

```bash
# FP1-FP4: Cross-origin and isolation headers (single curl, extract all 4 headers)
HEADERS=$(curl -sI "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0")
echo "=== FP1: Permissions-Policy ==="
echo "$HEADERS" | grep -i "permissions-policy" || echo "(absent)"
echo "=== FP2: Cross-Origin-Opener-Policy ==="
echo "$HEADERS" | grep -i "cross-origin-opener-policy" || echo "(absent)"
echo "=== FP3: Cross-Origin-Embedder-Policy ==="
echo "$HEADERS" | grep -i "cross-origin-embedder-policy" || echo "(absent)"
echo "=== FP4: Cross-Origin-Resource-Policy ==="
echo "$HEADERS" | grep -i "cross-origin-resource-policy" || echo "(absent)"

# FP5: Certificate Transparency SCT
echo | openssl s_client -connect ${TARGET:-myzr.io}:443 -servername ${TARGET:-myzr.io} -ct 2>/dev/null | grep -iE "SCT|signed certificate timestamp"
echo | openssl s_client -connect ${TARGET:-myzr.io}:443 -servername ${TARGET:-myzr.io} 2>/dev/null | openssl x509 -noout -text | grep -iA2 "CT Precertificate SCTs"

# FP6: HSTS preload list check
curl -s "https://hstspreload.org/api/v2/status?domain=${TARGET:-myzr.io}" -H "User-Agent: Mozilla/5.0"
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| FP1 | Permissions-Policy | `Permissions-Policy` header is present. WARN if absent |
| FP2 | Cross-Origin-Opener-Policy | `Cross-Origin-Opener-Policy` is set to `same-origin`. WARN if absent |
| FP3 | Cross-Origin-Embedder-Policy | `Cross-Origin-Embedder-Policy` header is present. WARN if absent |
| FP4 | Cross-Origin-Resource-Policy | `Cross-Origin-Resource-Policy` header is present. WARN if absent |
| FP5 | Certificate Transparency SCT | Certificate includes SCT extension (Signed Certificate Timestamp). WARN if absent |
| FP6 | HSTS preload | Domain appears on the HSTS preload list (hstspreload.org). WARN if not listed |

## Output

Write to `SECURITY_CHECK.parts/fingerprint.md`:

```markdown
### Fingerprint

| # | Test | Result | Evidence |
|---|------|--------|----------|
| FP1 | Permissions-Policy | {PASS/WARN} | {header value or absent} |
| FP2 | Cross-Origin-Opener-Policy | {PASS/WARN} | {header value or absent} |
| FP3 | Cross-Origin-Embedder-Policy | {PASS/WARN} | {header value or absent} |
| FP4 | Cross-Origin-Resource-Policy | {PASS/WARN} | {header value or absent} |
| FP5 | Certificate Transparency SCT | {PASS/WARN} | {SCT presence in cert} |
| FP6 | HSTS preload | {PASS/WARN} | {preload status from API} |
...
```

## After

Ask the user: **Do you want help fixing the fingerprint/isolation issues found?** If yes, invoke `/chk2:fix` with context about which fingerprint tests failed.

## Status signal

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
