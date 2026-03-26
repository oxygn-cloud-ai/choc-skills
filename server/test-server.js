#!/usr/bin/env node
// Integration test: server API + WebSocket
const http = require('http');
const { WebSocket } = require('ws');

const PORT = 3099; // Use non-standard port for testing
process.env.PORT = PORT;

// Import server components directly
const express = require('express');
const { WebSocketServer } = require('ws');
const { SessionStore } = require('./sessions');
const { PairCodeStore } = require('./pair-codes');

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ noServer: true });
const sessions = new SessionStore();
const pairCodes = new PairCodeStore();

app.use(express.json());

app.post('/api/new-game', (req, res) => {
  const { sessionId, apiToken } = sessions.create();
  const pairCode = pairCodes.generate(sessionId);
  res.json({ sessionId, pairCode });
});

app.post('/api/pair', (req, res) => {
  const { pairCode } = req.body;
  const sessionId = pairCodes.redeem(pairCode);
  if (!sessionId) return res.status(404).json({ error: 'Invalid or expired pair code' });
  const session = sessions.get(sessionId);
  if (!session) return res.status(404).json({ error: 'Session not found' });
  res.json({ sessionId, token: session.apiToken });
});

app.get('/api/state/:token', (req, res) => {
  const result = sessions.getByToken(req.params.token);
  if (!result) return res.status(404).json({ error: 'Invalid token' });
  res.json({ state: result.session.engine.getState(), summary: result.session.engine.getSummary() });
});

app.post('/api/action/:token', (req, res) => {
  const result = sessions.getByToken(req.params.token);
  if (!result) return res.status(404).json({ error: 'Invalid token' });
  const { action } = req.body;
  const success = result.session.engine.executeAction(action);
  res.json({ success, summary: result.session.engine.getSummary() });
});

app.get('/api/health', (req, res) => res.json({ status: 'ok', sessions: sessions.count }));

server.on('upgrade', (request, socket, head) => {
  const url = new URL(request.url, `http://localhost:${PORT}`);
  const match = url.pathname.match(/^\/ws\/([a-f0-9]+)$/);
  if (!match) { socket.destroy(); return; }
  const session = sessions.get(match[1]);
  if (!session) { socket.destroy(); return; }
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit('connection', ws, request, match[1]);
  });
});

wss.on('connection', (ws, request, sessionId) => {
  sessions.addWsClient(sessionId, ws);
  ws.on('close', () => sessions.removeWsClient(sessionId, ws));
});

// --- Test helpers ---
function fetch(method, path, body) {
  return new Promise((resolve, reject) => {
    const opts = { hostname: 'localhost', port: PORT, path, method, headers: { 'Content-Type': 'application/json' } };
    const req = http.request(opts, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch { resolve({ status: res.statusCode, body: data }); }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

function assert(condition, msg) {
  if (!condition) throw new Error('ASSERTION FAILED: ' + msg);
  console.log('  ✓ ' + msg);
}

// --- Run tests ---
async function runTests() {
  console.log('=== API Tests ===\n');

  // Health
  const health = await fetch('GET', '/api/health');
  assert(health.status === 200, 'Health check returns 200');
  assert(health.body.status === 'ok', 'Health status is ok');

  // New game
  const newGame = await fetch('POST', '/api/new-game');
  assert(newGame.status === 200, 'New game returns 200');
  assert(newGame.body.sessionId.length === 32, 'Session ID is 32 hex chars');
  assert(newGame.body.pairCode.length === 6, 'Pair code is 6 chars');
  console.log('  Session:', newGame.body.sessionId.slice(0, 8) + '...');
  console.log('  Pair code:', newGame.body.pairCode);

  // Pair
  const pair = await fetch('POST', '/api/pair', { pairCode: newGame.body.pairCode });
  assert(pair.status === 200, 'Pair returns 200');
  assert(pair.body.token, 'Pair returns an API token');
  assert(pair.body.sessionId === newGame.body.sessionId, 'Pair returns correct session');
  const token = pair.body.token;

  // Pair code is single-use
  const pair2 = await fetch('POST', '/api/pair', { pairCode: newGame.body.pairCode });
  assert(pair2.status === 404, 'Pair code is single-use (returns 404)');

  // Get state
  const state = await fetch('GET', `/api/state/${token}`);
  assert(state.status === 200, 'Get state returns 200');
  assert(state.body.state.skills === 0, 'Initial skills = 0');
  assert(state.body.state.funds === 5, 'Initial funds = $5');
  assert(typeof state.body.summary === 'string', 'Summary is a string');

  // Execute action: buy tokens
  const buyTokens = await fetch('POST', `/api/action/${token}`, { action: 'buyTokens' });
  assert(buyTokens.status === 200, 'Action returns 200');
  assert(buyTokens.body.success === true, 'Buy tokens succeeded');

  // Execute action: create skill
  const createSkill = await fetch('POST', `/api/action/${token}`, { action: 'createSkill' });
  assert(createSkill.status === 200, 'Create skill returns 200');
  assert(createSkill.body.success === true, 'Create skill succeeded');

  // Invalid token
  const badToken = await fetch('GET', '/api/state/bogus');
  assert(badToken.status === 404, 'Invalid token returns 404');

  // WebSocket test
  console.log('\n=== WebSocket Tests ===\n');
  const wsUrl = `ws://localhost:${PORT}/ws/${newGame.body.sessionId}`;
  const ws = new WebSocket(wsUrl);

  await new Promise((resolve, reject) => {
    let gotFullState = false;
    let gotTick = false;

    ws.on('message', (raw) => {
      const msg = JSON.parse(raw);
      if (msg.type === 'fullState' && !gotFullState) {
        gotFullState = true;
        assert(msg.state.skills >= 0, 'WS fullState has skills');
        assert(msg.state.funds >= 0, 'WS fullState has funds');
      }
      if (msg.type === 'tick' && !gotTick) {
        gotTick = true;
        assert(msg.state, 'WS tick has state');
        assert(Array.isArray(msg.events), 'WS tick has events array');
      }
      if (gotFullState && gotTick) {
        ws.close();
        resolve();
      }
    });

    ws.on('error', reject);
    setTimeout(() => { ws.close(); resolve(); }, 2000);
  });

  console.log('\n=== Pair Code Unit Tests ===\n');
  const { PairCodeStore: PCS } = require('./pair-codes');
  const pc = new PCS();
  const code = pc.generate('session-123');
  assert(code.length === 6, 'Code is 6 chars');
  assert(pc.redeem(code) === 'session-123', 'Redeem returns session');
  assert(pc.redeem(code) === null, 'Second redeem returns null');

  // Case insensitive
  const code2 = pc.generate('session-456');
  assert(pc.redeem(code2.toLowerCase()) === 'session-456', 'Redeem is case-insensitive');

  console.log('\n=== ALL TESTS PASSED ===');
}

server.listen(PORT, async () => {
  try {
    await runTests();
  } catch (e) {
    console.error('\nTEST FAILED:', e.message);
    process.exit(1);
  } finally {
    // Cleanup: destroy all sessions (stops tick timers)
    sessions.cleanup(0);
    server.close();
    wss.close();
    process.exit(0);
  }
});
