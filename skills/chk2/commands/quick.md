---
name: chk2:quick
description: "Quick passive security check (headers+tls+dns+cors)"
allowed-tools: Read, Write, Bash(mkdir *), Bash(cat *), Bash(rm *), AskUserQuestion
---

# chk2:quick — Quick Non-Invasive Check

Run a fast, passive security check of https://myzr.io. No active testing, no session creation, no WebSocket connections.

## Instructions

1. Initialize the output tree:
   - `mkdir -p SECURITY_CHECK.parts`
   - `rm -f SECURITY_CHECK.parts/*.md`
   - `touch SECURITY_CHECK.parts/.orchestrated` (marker that suppresses each sub-skill's standalone-merge step — CPT-126)
   - Start a fresh `SECURITY_CHECK.md` with header (date, "Tests run: quick")

2. Run these categories in order (each writes to `SECURITY_CHECK.parts/<category>.md`):
   - `/chk2:headers`
   - `/chk2:tls`
   - `/chk2:dns`
   - `/chk2:cors` (skip the WebSocket tests — only run the curl-based CORS checks)

3. Merge the part files into `SECURITY_CHECK.md` in order:

   ```bash
   for category in headers tls dns cors; do
     part="SECURITY_CHECK.parts/${category}.md"
     [ -f "$part" ] && { cat "$part" >> SECURITY_CHECK.md; echo "" >> SECURITY_CHECK.md; }
   done
   rm -f SECURITY_CHECK.parts/.orchestrated
   ```

4. Append summary table and recommendations to `SECURITY_CHECK.md`

5. Ask the user: **Do you want help fixing the issues found?** If yes, invoke `/chk2:fix`.
