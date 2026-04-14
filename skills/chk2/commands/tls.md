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
| TD1 | SSL renegotiation DoS | Client-initiated TLS renegotiation must fail; secure renegotiation supported |
| TD2 | Client certificate handling | Self-signed client cert does not grant different access than no cert |
| TD3 | HTTP/3 (QUIC) support | Alt-Svc header properly configured if HTTP/3 advertised; security headers match HTTP/2 |

### TD1-TD3 Additional Tests

```bash
# TD1 — SSL renegotiation
echo "R" | openssl s_client -connect myzr.io:443 -servername myzr.io 2>&1 | grep -i "renegotiat"
echo | openssl s_client -connect myzr.io:443 -servername myzr.io 2>&1 | grep -i "secure renegotiation"
# PASS if "Secure Renegotiation IS supported" and client-initiated renegotiation fails

# TD2 — Client certificate
openssl req -x509 -newkey rsa:2048 -keyout /tmp/client.key -out /tmp/client.crt \
  -days 1 -nodes -subj "/CN=admin/O=Evil Corp" 2>/dev/null
WITH_CERT=$(curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/" \
  --cert /tmp/client.crt --key /tmp/client.key -H "User-Agent: Mozilla/5.0" --max-time 10)
WITHOUT_CERT=$(curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/" \
  -H "User-Agent: Mozilla/5.0" --max-time 10)
echo "With cert: $WITH_CERT, Without: $WITHOUT_CERT"
rm -f /tmp/client.key /tmp/client.crt
# PASS if both return same status

# TD3 — HTTP/3
curl -sI "https://myzr.io/" -H "User-Agent: Mozilla/5.0" | grep -i "alt-svc"
# PASS if Alt-Svc properly configured or not advertised
```

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

**Skip this section when invoked from `/chk2:all` (batch mode).** Only ask when run as a standalone category check.

Ask the user: **Do you want help fixing the TLS issues found?** If yes, invoke `/chk2:fix` with context about which TLS tests failed.
