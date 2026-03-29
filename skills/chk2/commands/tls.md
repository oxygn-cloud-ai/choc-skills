# chk2:tls — TLS/SSL Configuration

Test TLS configuration on https://myzr.io. Append results to `SECURITY_CHECK.md`.

## Tests

```bash
# TLS version support
for ver in ssl3 tls1 tls1_1 tls1_2 tls1_3; do
  result=$(echo | openssl s_client -connect myzr.io:443 -servername myzr.io -$ver 2>&1 | grep "Protocol")
  echo "$ver: $result"
done

# Cipher suite
echo | openssl s_client -connect myzr.io:443 -servername myzr.io 2>/dev/null | grep "Cipher\|Protocol"

# Certificate details
echo | openssl s_client -connect myzr.io:443 -servername myzr.io 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName

# OCSP stapling
echo | openssl s_client -connect myzr.io:443 -servername myzr.io -status 2>/dev/null | grep -i "OCSP"
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| T1 | SSLv3 disabled | Connection with `-ssl3` must fail |
| T2 | TLS 1.0 disabled | Connection with `-tls1` must fail |
| T3 | TLS 1.1 disabled | Connection with `-tls1_1` must fail |
| T4 | TLS 1.2 enabled | Connection with `-tls1_2` must succeed |
| T5 | TLS 1.3 enabled | Connection with `-tls1_3` must succeed |
| T6 | Strong cipher | Cipher must be AES-256 or CHACHA20 |
| T7 | Certificate valid | notAfter date is in the future |
| T8 | Certificate covers domain | SAN includes `myzr.io` and `*.myzr.io` |
| T9 | OCSP stapling | OCSP response present (WARN if not) |

## Output

Append to `SECURITY_CHECK.md`:

```markdown
### TLS

| # | Test | Result | Evidence |
|---|------|--------|----------|
| T1 | SSLv3 disabled | {PASS/FAIL} | {connection result} |
...
```

## After

Ask the user: **Do you want help fixing the TLS issues found?** If yes, invoke `/chk2:fix` with context about which TLS tests failed.
