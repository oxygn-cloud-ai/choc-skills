// ═══════════════════════════════════════════
//  MYZR — Session Management
//  In-memory session store: sessionId → game instance
// ═══════════════════════════════════════════

const crypto = require('crypto');
const { GameEngine } = require('./game-engine');

const TICK_INTERVAL = 100; // ms — matches client's 100ms tick

class SessionStore {
  constructor() {
    // sessionId → { engine, wsClients, tickTimer, apiToken, createdAt, lastActivity }
    this._sessions = new Map();
  }

  create() {
    const sessionId = crypto.randomBytes(16).toString('hex');
    const apiToken = crypto.randomBytes(24).toString('base64url');
    const engine = new GameEngine();

    const session = {
      engine,
      wsClients: new Set(),
      tickTimer: null,
      apiToken,
      createdAt: Date.now(),
      lastActivity: Date.now(),
    };

    // Start the game loop
    session.tickTimer = setInterval(() => {
      engine.tick();
      const events = engine.drainEvents();
      if (events.length > 0 || session.wsClients.size > 0) {
        this._broadcast(session, events);
      }
    }, TICK_INTERVAL);

    this._sessions.set(sessionId, session);
    return { sessionId, apiToken };
  }

  get(sessionId) {
    const session = this._sessions.get(sessionId);
    if (session) session.lastActivity = Date.now();
    return session || null;
  }

  getByToken(apiToken) {
    for (const [sessionId, session] of this._sessions) {
      if (session.apiToken === apiToken) {
        session.lastActivity = Date.now();
        return { sessionId, session };
      }
    }
    return null;
  }

  addWsClient(sessionId, ws) {
    const session = this._sessions.get(sessionId);
    if (!session) return false;
    session.wsClients.add(ws);
    session.lastActivity = Date.now();

    // Send full state on connect
    this._sendTo(ws, {
      type: 'fullState',
      state: session.engine.getState(),
    });
    return true;
  }

  removeWsClient(sessionId, ws) {
    const session = this._sessions.get(sessionId);
    if (session) session.wsClients.delete(ws);
  }

  destroy(sessionId) {
    const session = this._sessions.get(sessionId);
    if (!session) return;
    clearInterval(session.tickTimer);
    for (const ws of session.wsClients) {
      ws.close(1000, 'Session ended');
    }
    this._sessions.delete(sessionId);
  }

  // Broadcast state + events to all connected WebSocket clients
  _broadcast(session, events) {
    if (session.wsClients.size === 0) return;
    const msg = JSON.stringify({
      type: 'tick',
      state: session.engine.getState(),
      events,
    });
    for (const ws of session.wsClients) {
      if (ws.readyState === 1) { // OPEN
        ws.send(msg);
      }
    }
  }

  _sendTo(ws, data) {
    if (ws.readyState === 1) {
      ws.send(JSON.stringify(data));
    }
  }

  // Cleanup stale sessions (no activity for 1 hour)
  cleanup(maxAge = 60 * 60 * 1000) {
    const now = Date.now();
    for (const [sessionId, session] of this._sessions) {
      if (now - session.lastActivity > maxAge) {
        this.destroy(sessionId);
      }
    }
  }

  get count() {
    return this._sessions.size;
  }
}

module.exports = { SessionStore };
