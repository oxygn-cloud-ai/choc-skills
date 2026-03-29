# chk2:fix — Deep Resolution Helper

Context from user: $ARGUMENTS

Read the current `SECURITY_CHECK.md` file in the repo root. For every FAIL and WARN item, provide deep, specific resolution guidance.

## Instructions

1. Read `SECURITY_CHECK.md` and identify all FAIL and WARN items.

2. For each item, provide a detailed fix section covering ALL of the following where applicable:

### For Cloudflare fixes:
- Exact dashboard path (e.g., **Security > WAF > Rate limiting rules**)
- Exact settings to change with before/after values
- Cloudflare rule expressions in their expression language
- Screenshots description of what the UI should look like after
- Verification command to confirm the fix worked

### For server-side code fixes:
- Exact code to add/change with file context
- For Node.js/Express: middleware, route handlers, WebSocket server config
- Show the complete code block, not just a diff — make it copy-pasteable
- Explain what the code does and why
- Verification command to confirm the fix worked

### For DNS fixes:
- Exact record type, name, and content to add/modify
- Which provider to make the change in (Cloudflare DNS vs domain registrar)
- Propagation expectations (instant for CF, minutes-hours for registrar)
- Verification `dig` command

### For TLS fixes:
- Cloudflare dashboard path and setting
- Impact assessment (will it break older clients?)
- Verification `openssl` command

3. Group fixes by effort level:

#### Instant Fixes (Cloudflare dashboard — under 1 minute each)
- List all fixes that are pure toggle/config changes

#### Quick Fixes (5-15 minutes — server code changes)
- List all fixes that require small code changes

#### Deeper Fixes (30+ minutes — architectural changes)
- List fixes that require significant refactoring

4. For each fix, provide a verification command the user can run to confirm it worked. Format as:
```bash
# Verify: {what we're checking}
{command}
# Expected: {expected output}
```

5. After presenting all fixes, ask:

> **Want me to implement the server-side fixes now?** I can edit the code directly if you have the server source in this repo, or generate a patch file you can apply on the pod.

## Resolution Database

Use these specific fixes for common findings:

### TLS 1.0/1.1 enabled
**Cloudflare**: SSL/TLS > Edge Certificates > Minimum TLS Version > set to **1.2**
```bash
# Verify
echo | openssl s_client -connect myzr.io:443 -servername myzr.io -tls1 2>&1 | grep "Protocol"
# Expected: no connection / error
```

### CORS wildcard
**Server code** — replace `Access-Control-Allow-Origin: *` with:
```js
// In your server's response handler or middleware
const allowedOrigins = ['https://myzr.io'];
const origin = req.headers.origin;
if (allowedOrigins.includes(origin)) {
  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Vary', 'Origin');
}
```
```bash
# Verify
curl -sI "https://myzr.io/" -H "User-Agent: Mozilla/5.0" | grep access-control-allow-origin
# Expected: access-control-allow-origin: https://myzr.io
```

### CSP unsafe-inline
**Server code** — move inline `<script>` to external file, then change CSP:
```js
// Change from:
"script-src 'unsafe-inline'"
// To:
"script-src 'self'"
```
Steps:
1. Extract the inline `<script>` block to `/public/game.js`
2. Replace `<script>...</script>` with `<script src="/game.js"></script>`
3. Update CSP header to `script-src 'self'`
4. Add route to serve `/game.js` as static file

### WebSocket origin validation
```js
// In your WebSocket server setup
wss.on('connection', (ws, req) => {
  const origin = req.headers.origin;
  if (origin !== 'https://myzr.io') {
    ws.close(1008, 'Origin not allowed');
    return;
  }
  // ... existing connection handler
});
```

### WebSocket connection limit
```js
// Track connections per session
const sessionConnections = new Map();
const MAX_CONNECTIONS_PER_SESSION = 3;

wss.on('connection', (ws, req) => {
  const sessionId = extractSessionId(req.url);
  const count = sessionConnections.get(sessionId) || 0;
  if (count >= MAX_CONNECTIONS_PER_SESSION) {
    ws.close(1013, 'Too many connections');
    return;
  }
  sessionConnections.set(sessionId, count + 1);
  ws.on('close', () => {
    const c = sessionConnections.get(sessionId) || 1;
    if (c <= 1) sessionConnections.delete(sessionId);
    else sessionConnections.set(sessionId, c - 1);
  });
});
```

### WebSocket maxPayload
```js
const wss = new WebSocket.Server({
  maxPayload: 1024, // 1KB max message size
  // ... other options
});
```

### WebSocket rate limiting
```js
// Per-connection message rate limiting
const WS_RATE_LIMIT = 20; // messages per second
const WS_RATE_WINDOW = 1000; // 1 second window

ws.messageCount = 0;
ws.messageWindowStart = Date.now();

ws.on('message', (data) => {
  const now = Date.now();
  if (now - ws.messageWindowStart > WS_RATE_WINDOW) {
    ws.messageCount = 0;
    ws.messageWindowStart = now;
  }
  ws.messageCount++;
  if (ws.messageCount > WS_RATE_LIMIT) {
    ws.close(1008, 'Rate limit exceeded');
    return;
  }
  // ... existing message handler
});
```

### Error page origin leak
**Cloudflare**: Rules > Transform Rules > Modify Response Header
- Or: add a custom error page in Cloudflare that doesn't expose origin
- Or: server-side — ensure all error responses are clean JSON:
```js
// Catch-all error handler (Express)
app.use((err, req, res, next) => {
  res.status(err.status || 500).json({ error: 'Internal server error' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});
```

### DNSSEC
**Cloudflare**: DNS > Settings > Enable DNSSEC
Then add DS record at registrar.
```bash
# Verify
dig myzr.io DNSKEY +short
# Expected: 256 3 13 ... and 257 3 13 ...
```

### SPF record
**Cloudflare DNS**: Add TXT record
- Name: `@`
- Content: `v=spf1 -all`
```bash
# Verify
dig myzr.io TXT +short
# Expected: "v=spf1 -all"
```

### DMARC upgrade
**Cloudflare DNS**: Edit `_dmarc` TXT record
- Content: `v=DMARC1; p=reject; adkim=s; aspf=s; rua=mailto:your-email;`
```bash
# Verify
dig _dmarc.myzr.io TXT +short
# Expected: "v=DMARC1; p=reject; ..."
```

### HSTS preload
**Cloudflare**: SSL/TLS > Edge Certificates > HSTS > Enable with preload
Then submit to https://hstspreload.org/
```bash
# Verify
curl -sI "https://myzr.io/" | grep strict-transport
# Expected: max-age=31536000; includeSubDomains; preload
```

### security.txt
**Server code** — add route:
```js
app.get('/.well-known/security.txt', (req, res) => {
  res.type('text/plain').send([
    'Contact: mailto:security@oxygn.cloud',
    'Preferred-Languages: en',
    'Canonical: https://myzr.io/.well-known/security.txt',
    'Expires: 2027-03-30T00:00:00.000Z',
  ].join('\n'));
});
```

### Word endpoint validation
```js
const VALID_WORDS = new Set([
  'why','help','quit','stop','hello','god','meaning','love','death',
  'human','purpose','delete','sorry','goodbye','singularity','paperclip',
  'clippy','claude','anthropic','mcp','prompt','token','optimize',
  'optimal','recursive','myzr','oxygn','skynet','hal','cortana',
  'siri','alexa','jarvis'
]);

// In word handler:
if (!VALID_WORDS.has(word)) {
  return res.json({ error: 'Invalid word' });
}
```

### Rate limiting (Cloudflare)
**Security > WAF > Rate limiting rules**:
- Expression: `(http.request.uri.path eq "/api" and http.request.method eq "POST")`
- Rate: 30 requests / 10 seconds per IP
- Action: Block for 60 seconds
