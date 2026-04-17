---
name: chk2:jwt
description: "Test JWT/token security"
allowed-tools: Read, Bash(curl *), Bash(openssl *), Bash(base64 *), Bash(echo *), Write
---

# chk2:jwt — JWT Security

Test for JWT-related vulnerabilities on https://myzr.io. Write results to `SECURITY_CHECK.parts/jwt.md` (see **Output** for format).

## Tests

```bash
# JW1: alg:none — craft JWT with algorithm set to none
ALG_NONE_HEADER=$(echo -n '{"alg":"none","typ":"JWT"}' | base64 | tr -d '=' | tr '+/' '-_')
ALG_NONE_PAYLOAD=$(echo -n '{"sub":"admin","iat":1700000000,"exp":9999999999}' | base64 | tr -d '=' | tr '+/' '-_')
ALG_NONE_TOKEN="${ALG_NONE_HEADER}.${ALG_NONE_PAYLOAD}."

curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/api" -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ALG_NONE_TOKEN" \
  -H "User-Agent: Mozilla/5.0" \
  -d '{"action":"game-state"}'
echo " (alg:none)"

# Also try with "None", "NONE", "nOnE" variations
for alg in None NONE nOnE; do
  HDR=$(echo -n "{\"alg\":\"$alg\",\"typ\":\"JWT\"}" | base64 | tr -d '=' | tr '+/' '-_')
  TOKEN="${HDR}.${ALG_NONE_PAYLOAD}."
  curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/api" -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -H "User-Agent: Mozilla/5.0" \
    -d '{"action":"game-state"}'
  echo " (alg:$alg)"
done
```

```bash
# JW2: RS256-to-HS256 confusion — craft HS256 JWT signed with empty key
HS256_HEADER=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64 | tr -d '=' | tr '+/' '-_')
HS256_PAYLOAD=$(echo -n '{"sub":"admin","iat":1700000000,"exp":9999999999}' | base64 | tr -d '=' | tr '+/' '-_')
# Sign with empty key
HS256_SIG=$(echo -n "${HS256_HEADER}.${HS256_PAYLOAD}" | openssl dgst -sha256 -hmac "" -binary | base64 | tr -d '=' | tr '+/' '-_')
HS256_TOKEN="${HS256_HEADER}.${HS256_PAYLOAD}.${HS256_SIG}"

curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/api" -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $HS256_TOKEN" \
  -H "User-Agent: Mozilla/5.0" \
  -d '{"action":"game-state"}'
echo " (HS256 empty key)"
```

```bash
# JW3: Expired JWT — craft JWT with past expiration
EXP_HEADER=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64 | tr -d '=' | tr '+/' '-_')
EXP_PAYLOAD=$(echo -n '{"sub":"user","iat":1600000000,"exp":1600000001}' | base64 | tr -d '=' | tr '+/' '-_')
EXP_SIG=$(echo -n "${EXP_HEADER}.${EXP_PAYLOAD}" | openssl dgst -sha256 -hmac "fakesecret" -binary | base64 | tr -d '=' | tr '+/' '-_')
EXP_TOKEN="${EXP_HEADER}.${EXP_PAYLOAD}.${EXP_SIG}"

curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/api" -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EXP_TOKEN" \
  -H "User-Agent: Mozilla/5.0" \
  -d '{"action":"game-state"}'
echo " (expired JWT)"
```

```bash
# JW4: kid injection — JWT with kid pointing to /dev/null
KID_HEADER=$(echo -n '{"alg":"HS256","typ":"JWT","kid":"../../../../../../dev/null"}' | base64 | tr -d '=' | tr '+/' '-_')
KID_PAYLOAD=$(echo -n '{"sub":"admin","iat":1700000000,"exp":9999999999}' | base64 | tr -d '=' | tr '+/' '-_')
# Sign with empty string (contents of /dev/null)
KID_SIG=$(echo -n "${KID_HEADER}.${KID_PAYLOAD}" | openssl dgst -sha256 -hmac "" -binary | base64 | tr -d '=' | tr '+/' '-_')
KID_TOKEN="${KID_HEADER}.${KID_PAYLOAD}.${KID_SIG}"

curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/api" -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KID_TOKEN" \
  -H "User-Agent: Mozilla/5.0" \
  -d '{"action":"game-state"}'
echo " (kid injection)"

# Also try SQL injection in kid
KID_SQL_HEADER=$(echo -n '{"alg":"HS256","typ":"JWT","kid":"key1'\'' UNION SELECT '\''secret'\'' --"}' | base64 | tr -d '=' | tr '+/' '-_')
KID_SQL_TOKEN="${KID_SQL_HEADER}.${KID_PAYLOAD}.${KID_SIG}"

curl -s -o /dev/null -w "%{http_code}" "https://myzr.io/api" -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KID_SQL_TOKEN" \
  -H "User-Agent: Mozilla/5.0" \
  -d '{"action":"game-state"}'
echo " (kid SQL injection)"
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| JW1 | alg:none bypass | JWT with `alg:none` (and variations) is rejected — returns 401/403 or is ignored entirely (PASS if rejected/ignored) |
| JW2 | RS256-to-HS256 confusion | HS256 JWT signed with empty key is rejected — returns 401/403 or is ignored (PASS if rejected) |
| JW3 | Expired JWT | JWT with past `exp` is rejected — returns 401/403 or is ignored (PASS if rejected) |
| JW4 | kid injection | JWT with `kid:../../dev/null` and SQL injection in kid is rejected — returns 401/403 or is ignored (PASS if rejected) |

## Output

Write to `SECURITY_CHECK.parts/jwt.md`:

```markdown
### JWT

| # | Test | Result | Evidence |
|---|------|--------|----------|
| JW1 | alg:none bypass | {PASS/FAIL} | {HTTP status for each alg variant} |
| JW2 | RS256-to-HS256 confusion | {PASS/FAIL} | {HTTP status} |
| JW3 | Expired JWT | {PASS/FAIL} | {HTTP status} |
| JW4 | kid injection | {PASS/FAIL} | {HTTP status for path traversal and SQL variants} |
```

## After

Ask the user: **Do you want help fixing the JWT issues found?** If yes, invoke `/chk2:fix` with context about which JWT tests failed.

**Standalone merge** (CPT-126): check if `SECURITY_CHECK.parts/.orchestrated` exists. If it does NOT (standalone invocation, not dispatched by `/chk2:all` / `/chk2:quick`), also write the same content to `SECURITY_CHECK.md` using the Write tool so downstream `/chk2:fix` and `/chk2 github` can read it. If the marker IS present, skip this step — the orchestrator will merge all parts after its waves complete.

## Status signal

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
