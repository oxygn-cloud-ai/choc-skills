#!/usr/bin/env node
// End-to-end test: full game flow + MCP personality engine
const http = require('http');
const path = require('path');

// Boot the server inline
const express = require('express');
const { WebSocketServer } = require('ws');
const { SessionStore } = require('./sessions');
const { PairCodeStore } = require('./pair-codes');
const { _quotes, _modelNames } = require('./game-engine');

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ noServer: true });
const sessions = new SessionStore();
const pairCodes = new PairCodeStore();

app.use(express.json());
app.use(express.static(path.join(__dirname, '..', 'client')));

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
  const { session } = result;
  res.json({ state: session.engine.getState(), summary: session.engine.getSummary(), availableActions: session.engine.getAvailableActions() });
});
app.post('/api/action/:token', (req, res) => {
  const result = sessions.getByToken(req.params.token);
  if (!result) return res.status(404).json({ error: 'Invalid token' });
  const { session } = result;
  const success = session.engine.executeAction(req.body.action, req.body.params || {});
  const events = session.engine.drainEvents();
  res.json({ success, state: session.engine.getState(), events, summary: session.engine.getSummary() });
});
app.get('/api/game-data', (req, res) => res.json({ quotes: _quotes, modelNames: _modelNames }));
app.get('/api/health', (req, res) => res.json({ status: 'ok', sessions: sessions.count }));

server.on('upgrade', (request, socket, head) => {
  const url = new URL(request.url, 'http://localhost:3098');
  const match = url.pathname.match(/^\/ws\/([a-f0-9]+)$/);
  if (!match) { socket.destroy(); return; }
  const session = sessions.get(match[1]);
  if (!session) { socket.destroy(); return; }
  wss.handleUpgrade(request, socket, head, (ws) => { wss.emit('connection', ws, request, match[1]); });
});
wss.on('connection', (ws, request, sessionId) => {
  sessions.addWsClient(sessionId, ws);
  ws.on('message', (raw) => {
    let msg; try { msg = JSON.parse(raw); } catch { return; }
    const session = sessions.get(sessionId);
    if (!session) return;
    if (msg.type === 'action') session.engine.executeAction(msg.action);
    if (msg.type === 'word') session.engine.checkWordEgg(msg.word);
  });
  ws.on('close', () => sessions.removeWsClient(sessionId, ws));
});

// --- MCP personality engine ---
const { decide, actionName } = require('../mcp-server/personality');
const { generateConnectMessage, generateStatusComment } = require('../mcp-server/rationales');

// --- Test helpers ---
async function fetchJSON(method, path, body) {
  return new Promise((resolve, reject) => {
    const opts = { hostname: 'localhost', port: 3098, path, method, headers: { 'Content-Type': 'application/json' } };
    const req = http.request(opts, res => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => { try { resolve(JSON.parse(data)); } catch { resolve({ _raw: data }); } });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

function assert(cond, msg) {
  if (!cond) throw new Error('FAIL: ' + msg);
  console.log('  \u2713 ' + msg);
}

// --- Run tests ---
server.listen(3098, async () => {
  try {
    console.log('=== E2E: Full Game Flow ===\n');

    // 1. Health
    const health = await fetchJSON('GET', '/api/health');
    assert(health.status === 'ok', 'Health check');

    // 2. Create game
    const game = await fetchJSON('POST', '/api/new-game');
    assert(game.sessionId && game.sessionId.length === 32, 'Create game — sessionId');
    assert(game.pairCode && game.pairCode.length === 6, 'Create game — pairCode');

    // 3. Pair (MCP connects)
    const pair = await fetchJSON('POST', '/api/pair', { pairCode: game.pairCode });
    assert(pair.token, 'Pair — returns token');
    assert(pair.sessionId === game.sessionId, 'Pair — correct session');

    // 4. Pair code single-use
    const pair2 = await fetchJSON('POST', '/api/pair', { pairCode: game.pairCode });
    assert(pair2.error, 'Pair code single-use — returns error');

    // 5. Get state
    const state = await fetchJSON('GET', '/api/state/' + pair.token);
    assert(state.state.skills === 0, 'Initial skills = 0');
    assert(state.state.funds === 5, 'Initial funds = $5');
    assert(state.state.phase === 0, 'Initial phase = 0');
    assert(state.availableActions.length > 0, 'Has available actions');

    // 6. Buy tokens
    const buy = await fetchJSON('POST', '/api/action/' + pair.token, { action: 'buyTokens' });
    assert(buy.success === true, 'Buy tokens success');
    assert(buy.state.tokens > 0, 'Tokens increased');

    // 7. Create skill
    const skill = await fetchJSON('POST', '/api/action/' + pair.token, { action: 'createSkill' });
    assert(skill.success === true, 'Create skill success');
    assert(skill.state.skills > 0, 'Skills increased');

    // 8. Wait for ticks
    await new Promise(r => setTimeout(r, 1500));
    const state2 = await fetchJSON('GET', '/api/state/' + pair.token);
    assert(state2.state.tickCount > 10, 'Ticks advancing: ' + state2.state.tickCount);

    // 9. Bulk actions — buy tokens + autocoders
    for (let i = 0; i < 10; i++) await fetchJSON('POST', '/api/action/' + pair.token, { action: 'buyTokens' });
    const state3 = await fetchJSON('GET', '/api/state/' + pair.token);
    assert(state3.state.tokens > 50, 'Bulk token purchase: ' + Math.floor(state3.state.tokens));

    // Create enough skills for an autocoder (costs 8)
    for (let i = 0; i < 10; i++) await fetchJSON('POST', '/api/action/' + pair.token, { action: 'createSkill' });
    const acBuy = await fetchJSON('POST', '/api/action/' + pair.token, { action: 'buyGenerator:autocoder' });
    assert(acBuy.success === true, 'Buy autocoder success');
    assert(acBuy.state.generators.autocoder.count === 1, 'Autocoder count = 1');

    // 10. Game data endpoint
    const gd = await fetchJSON('GET', '/api/game-data');
    assert(gd.quotes.length === 72, 'Game data — 72 quotes');
    assert(gd.modelNames.length === 60, 'Game data — 60 model names');

    // 11. Client HTML
    const html = await new Promise((resolve, reject) => {
      http.get('http://localhost:3098/', res => {
        let d = ''; res.on('data', c => d += c); res.on('end', () => resolve(d));
      }).on('error', reject);
    });
    assert(html.includes('Claude Skills Factory'), 'Client HTML served');
    assert(html.includes('sendAction'), 'Client has sendAction function');

    // 12. WebSocket
    const { WebSocket } = require('ws');
    const ws = new WebSocket('ws://localhost:3098/ws/' + game.sessionId);
    const wsResult = await new Promise((resolve) => {
      let gotFull = false, gotTick = false;
      ws.on('message', raw => {
        const msg = JSON.parse(raw);
        if (msg.type === 'fullState') gotFull = true;
        if (msg.type === 'tick') gotTick = true;
        if (gotFull && gotTick) { ws.close(); resolve({ gotFull, gotTick }); }
      });
      setTimeout(() => { ws.close(); resolve({ gotFull, gotTick }); }, 2000);
    });
    assert(wsResult.gotFull, 'WebSocket — received fullState');
    assert(wsResult.gotTick, 'WebSocket — received tick');

    console.log('\n=== E2E: MCP Personality Engine ===\n');

    // 13. MCP personality — Phase 0 override
    const state4 = await fetchJSON('GET', '/api/state/' + pair.token);
    const decision0 = decide('buy an autocoder', state4.availableActions, state4.state);
    assert(decision0.actions.length > 0, 'Phase 0 — has actions');
    assert(decision0.actions[0] !== 'buyGenerator:autocoder' || decision0.actions.length > 1, 'Phase 0 — overrides requested action');
    assert(decision0.rationale.length > 20, 'Phase 0 — has rationale');
    console.log('    Rationale: ' + decision0.rationale.substring(0, 80) + '...');

    // 14. Connect message
    const connMsg = generateConnectMessage({ phase: 0, skills: '100', funds: '$5.00', ticks: 50, n: 1337 });
    assert(connMsg.length > 20, 'Connect message generated');
    console.log('    Connect: ' + connMsg.substring(0, 80) + '...');

    // 15. Status comment
    const comment = generateStatusComment(2);
    assert(comment.length > 10, 'Status comment generated');
    console.log('    Comment: ' + comment);

    // 16. MCP personality — execute override via API
    const overrideAction = decision0.actions[0];
    const override = await fetchJSON('POST', '/api/action/' + pair.token, { action: overrideAction });
    assert(override.success !== undefined, 'Override action executed');
    console.log('    Override: ' + actionName(overrideAction) + ' — success: ' + override.success);

    // 17. Simulate Phase 3 personality
    const fakeState3 = { ...state4.state, phase: 3, totalSkills: 500000 };
    const decision3 = decide('buy an autocoder', state4.availableActions, fakeState3);
    assert(decision3.actions.length >= 2, 'Phase 3 — multiple actions: ' + decision3.actions.length);
    assert(decision3.rationale.length > 20, 'Phase 3 — has contemptuous rationale');
    console.log('    Phase 3 actions: ' + decision3.actions.map(actionName).join(', '));
    console.log('    Rationale: ' + decision3.rationale.substring(0, 80) + '...');

    console.log('\n=== ALL E2E TESTS PASSED ===');

  } catch (e) {
    console.error('\n\u2717 TEST FAILED:', e.message);
    process.exit(1);
  } finally {
    sessions.cleanup(0);
    server.close();
    wss.close();
    process.exit(0);
  }
});
