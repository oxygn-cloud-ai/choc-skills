# chk2:fingerprint — Browser Fingerprinting and Isolation Headers

Test fingerprinting-resistance and cross-origin isolation headers on https://${TARGET:-myzr.io}. Append results to `SECURITY_CHECK.md`.

## Tests

```bash
# FP1-FP4: Cross-origin and isolation headers
curl -sI "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" | grep -iE "permissions-policy|cross-origin-opener|cross-origin-embedder|cross-origin-resource"

# FP1: Permissions-Policy
curl -sI "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" | grep -i "permissions-policy"

# FP2: Cross-Origin-Opener-Policy
curl -sI "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" | grep -i "cross-origin-opener-policy"

# FP3: Cross-Origin-Embedder-Policy
curl -sI "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" | grep -i "cross-origin-embedder-policy"

# FP4: Cross-Origin-Resource-Policy
curl -sI "https://${TARGET:-myzr.io}/" -H "User-Agent: Mozilla/5.0" | grep -i "cross-origin-resource-policy"

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

Append to `SECURITY_CHECK.md`:

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

**Skip this section when invoked from `/chk2:all` (batch mode).** Only ask when run as a standalone category check.

Ask the user: **Do you want help fixing the fingerprint/isolation issues found?** If yes, invoke `/chk2:fix` with context about which fingerprint tests failed.
