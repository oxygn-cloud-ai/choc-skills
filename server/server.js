// ═══════════════════════════════════════════
//  MYZR — Game Server
//  Express + WebSocket, session management
// ═══════════════════════════════════════════

const express = require('express');
const http = require('http');
const { WebSocketServer } = require('ws');
const path = require('path');
const { SessionStore } = require('./sessions');
const { PairCodeStore } = require('./pair-codes');
const { _quotes, _modelNames } = require('./game-engine');

const PORT = process.env.PORT || 3000;

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ noServer: true });

const sessions = new SessionStore();
const pairCodes = new PairCodeStore();

app.use(express.json());

// Serve browser client
app.use(express.static(path.join(__dirname, '..', 'client')));

// ═══════════════════════════════════════════
//  REST API
// ═══════════════════════════════════════════

// Create a new game session
app.post('/api/new-game', (req, res) => {
  const { sessionId, apiToken } = sessions.create();
  const pairCode = pairCodes.generate(sessionId);
  res.json({ sessionId, pairCode });
});

// Pair an MCP server to a game session
app.post('/api/pair', (req, res) => {
  const { pairCode } = req.body;
  if (!pairCode) return res.status(400).json({ error: 'pairCode required' });

  const sessionId = pairCodes.redeem(pairCode);
  if (!sessionId) return res.status(404).json({ error: 'Invalid or expired pair code' });

  const session = sessions.get(sessionId);
  if (!session) return res.status(404).json({ error: 'Session not found' });

  res.json({ sessionId, token: session.apiToken });
});

// Get game state (for MCP server)
app.get('/api/state/:token', (req, res) => {
  const result = sessions.getByToken(req.params.token);
  if (!result) return res.status(404).json({ error: 'Invalid token' });

  const { session } = result;
  res.json({
    state: session.engine.getState(),
    summary: session.engine.getSummary(),
    availableActions: session.engine.getAvailableActions(),
  });
});

// Execute an action (for MCP server)
app.post('/api/action/:token', (req, res) => {
  const result = sessions.getByToken(req.params.token);
  if (!result) return res.status(404).json({ error: 'Invalid token' });

  const { session } = result;
  const { action, params } = req.body;
  if (!action) return res.status(400).json({ error: 'action required' });

  const success = session.engine.executeAction(action, params || {});
  const events = session.engine.drainEvents();

  res.json({
    success,
    state: session.engine.getState(),
    events,
    summary: session.engine.getSummary(),
  });
});

// Static game data (quotes, model names — client fetches once)
let _gameDataCache = null;
app.get('/api/game-data', (req, res) => {
  if (!_gameDataCache) {
    _gameDataCache = JSON.stringify({ quotes: _quotes, modelNames: _modelNames });
  }
  res.type('json').send(_gameDataCache);
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', sessions: sessions.count });
});

// ═══════════════════════════════════════════
//  WEBSOCKET
// ═══════════════════════════════════════════

// Upgrade HTTP → WebSocket at /ws/:sessionId
server.on('upgrade', (request, socket, head) => {
  const url = new URL(request.url, `http://${request.headers.host}`);
  const match = url.pathname.match(/^\/ws\/([a-f0-9]+)$/);

  if (!match) {
    socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
    socket.destroy();
    return;
  }

  const sessionId = match[1];
  const session = sessions.get(sessionId);
  if (!session) {
    socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
    socket.destroy();
    return;
  }

  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit('connection', ws, request, sessionId);
  });
});

wss.on('connection', (ws, request, sessionId) => {
  sessions.addWsClient(sessionId, ws);

  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }

    const session = sessions.get(sessionId);
    if (!session) return;

    // Player actions come via WebSocket too
    if (msg.type === 'action' && msg.action) {
      session.engine.executeAction(msg.action, msg.params || {});
      // Events will be broadcast on next tick
    }

    // Typed-word easter eggs
    if (msg.type === 'word' && msg.word) {
      session.engine.checkWordEgg(msg.word);
    }
  });

  ws.on('close', () => {
    sessions.removeWsClient(sessionId, ws);
  });
});

// ═══════════════════════════════════════════
//  CLEANUP
// ═══════════════════════════════════════════

// Every 10 minutes, clean up stale sessions and expired pair codes
setInterval(() => {
  sessions.cleanup();
  pairCodes.cleanup();
}, 10 * 60 * 1000);

// ═══════════════════════════════════════════
//  START
// ═══════════════════════════════════════════

server.listen(PORT, () => {
  console.log(`Myzr server running on port ${PORT}`);
  console.log(`  Browser: http://localhost:${PORT}`);
  console.log(`  API:     http://localhost:${PORT}/api/health`);
});
