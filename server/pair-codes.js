// ═══════════════════════════════════════════
//  MYZR — Pair Code Generation & Validation
//  6-char alphanumeric, expires 5 min or first use
// ═══════════════════════════════════════════

const CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1 to avoid confusion
const CODE_LENGTH = 6;
const EXPIRY_MS = 5 * 60 * 1000; // 5 minutes

class PairCodeStore {
  constructor() {
    // code → { sessionId, createdAt }
    this._codes = new Map();
  }

  generate(sessionId) {
    // Remove any existing code for this session
    for (const [code, data] of this._codes) {
      if (data.sessionId === sessionId) this._codes.delete(code);
    }

    let code;
    do {
      code = '';
      for (let i = 0; i < CODE_LENGTH; i++) {
        code += CHARS[Math.floor(Math.random() * CHARS.length)];
      }
    } while (this._codes.has(code));

    this._codes.set(code, { sessionId, createdAt: Date.now() });
    return code;
  }

  redeem(code) {
    code = (code || '').toUpperCase().trim();
    const data = this._codes.get(code);
    if (!data) return null;

    // Check expiry
    if (Date.now() - data.createdAt > EXPIRY_MS) {
      this._codes.delete(code);
      return null;
    }

    // Single-use: delete after redeem
    this._codes.delete(code);
    return data.sessionId;
  }

  // Periodic cleanup of expired codes
  cleanup() {
    const now = Date.now();
    for (const [code, data] of this._codes) {
      if (now - data.createdAt > EXPIRY_MS) this._codes.delete(code);
    }
  }
}

module.exports = { PairCodeStore };
