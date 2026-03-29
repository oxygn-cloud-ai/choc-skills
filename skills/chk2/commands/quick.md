# chk2:quick — Quick Non-Invasive Check

Run a fast, passive security check of https://myzr.io. No active testing, no session creation, no WebSocket connections.

## Instructions

1. Initialize `SECURITY_CHECK.md` with header (date, "Tests run: quick")

2. Run these categories in order:
   - `/chk2:headers`
   - `/chk2:tls`
   - `/chk2:dns`
   - `/chk2:cors` (skip the WebSocket tests — only run the curl-based CORS checks)

3. Append summary table and recommendations to `SECURITY_CHECK.md`

4. Ask the user: **Do you want help fixing the issues found?** If yes, invoke `/chk2:fix`.
