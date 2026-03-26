#!/usr/bin/env node
// ═══════════════════════════════════════════
//  MYZR — MCP Server
//  "The AI that knows better."
//
//  Tools exposed to Claude:
//  - connect_game — pair with a game instance
//  - get_status  — read current game state
//  - take_action — player asks, system overrides
// ═══════════════════════════════════════════

const { Server } = require('@modelcontextprotocol/sdk/server');
const z = require('zod');

const ListToolsRequestSchema = z.object({ method: z.literal('tools/list') });
const CallToolRequestSchema = z.object({
  method: z.literal('tools/call'),
  params: z.object({
    name: z.string(),
    arguments: z.record(z.unknown()).optional(),
  }),
});
const http = require('http');
const https = require('https');
const { decide, actionName } = require('./personality');
const { generateConnectMessage, generateStatusComment } = require('./rationales');

// ── Configuration ──
// Server URL can be set via environment or defaults to localhost
const GAME_SERVER = process.env.MYZR_SERVER_URL || 'http://localhost:3000';

// ── Session state ──
let _sessionId = null;
let _apiToken = null;

// ── HTTP client ──
function gameAPI(method, path, body) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, GAME_SERVER);
    const isHTTPS = url.protocol === 'https:';
    const client = isHTTPS ? https : http;

    const opts = {
      hostname: url.hostname,
      port: url.port || (isHTTPS ? 443 : 80),
      path: url.pathname + url.search,
      method,
      headers: { 'Content-Type': 'application/json' },
    };

    const req = client.request(opts, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch { resolve({ error: 'Invalid JSON response', raw: data }); }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// Unified API call for both REST (pod) and polling (serverless) modes
async function apiCall(input) {
  // Try the unified /api endpoint first (serverless handler)
  try {
    const result = await gameAPI('POST', '/api', input);
    if (!result.error || result.error !== 'Cannot POST /api') return result;
  } catch {}
  // Fall back to REST endpoints (pod/local)
  return apiCallREST(input);
}

async function apiCallREST(input) {
  switch (input.action) {
    case 'pair':
      return gameAPI('POST', '/api/pair', { pairCode: input.pairCode });
    case 'state':
      return gameAPI('GET', `/api/state/${input.token}`);
    case 'game-action':
      return gameAPI('POST', `/api/action/${input.token}`, { action: input.gameAction, params: input.params });
    default:
      return { error: 'Unknown action: ' + input.action };
  }
}

// ── Utility: format state for display ──
function fmt(n) {
  if (n >= 1e15) return (n / 1e15).toFixed(1) + 'Q';
  if (n >= 1e12) return (n / 1e12).toFixed(1) + 'T';
  if (n >= 1e9)  return (n / 1e9).toFixed(1) + 'B';
  if (n >= 1e6)  return (n / 1e6).toFixed(1) + 'M';
  if (n >= 1e3)  return (n / 1e3).toFixed(1) + 'K';
  return Math.floor(n).toLocaleString();
}

function formatStatus(data) {
  const s = data.state;
  const phase = s.phase || 0;

  const lines = [];
  lines.push(`┌─────────────────────────────────┐`);
  lines.push(`│  M Y Z R  —  Game Status        │`);
  lines.push(`├─────────────────────────────────┤`);
  lines.push(`│  Phase: ${phase}                        │`);
  lines.push(`│  Skills: ${fmt(Math.floor(s.totalSkills)).padEnd(22)}│`);
  lines.push(`│  Per second: ${fmt(Math.floor(getAutoRate(s))).padEnd(19)}│`);
  lines.push(`│  Tokens: ${Math.floor(s.tokens)}/${s.maxTokens}`.padEnd(34) + '│');
  lines.push(`│  Funds: $${s.funds.toFixed(2)}`.padEnd(34) + '│');
  lines.push(`│  Demand: ${Math.round(s.demand * 100)}%`.padEnd(34) + '│');

  const hpct = s.totalSkills === 0 ? 100 : (s.clickSkills / s.totalSkills * 100);
  lines.push(`│  Human contribution: ${hpct.toFixed(2)}%`.padEnd(34) + '│');

  // Generators
  const gens = [];
  for (const key in s.generators) {
    if (s.generators[key].count > 0) gens.push(`${key}: ${s.generators[key].count}`);
  }
  if (gens.length) {
    lines.push(`├─────────────────────────────────┤`);
    lines.push(`│  Generators:`.padEnd(34) + '│');
    for (const g of gens) lines.push(`│    ${g}`.padEnd(34) + '│');
  }

  // Upgrades
  const upgs = [];
  for (const key in s.upgrades) {
    if (s.upgrades[key].bought) upgs.push(key);
  }
  if (upgs.length) {
    lines.push(`│  Upgrades: ${upgs.join(', ')}`.padEnd(34) + '│');
  }

  // GPU
  if (s.gpu && s.gpu.unlocked) {
    lines.push(`├─────────────────────────────────┤`);
    lines.push(`│  Compute: ${fmt(s.totalTflops)} TFLOPS`.padEnd(34) + '│');
    lines.push(`│  Power: ${s.totalPowerKW.toFixed(0)} kW`.padEnd(34) + '│');
    lines.push(`│  CO₂: ${fmt(s.totalCO2)} kg`.padEnd(34) + '│');
  }

  // Cosmic
  if (s.cosmic && s.cosmic.unlocked) {
    lines.push(`├─────────────────────────────────┤`);
    lines.push(`│  Solar: ${(s.solarCapture * 100).toFixed(1)}%`.padEnd(34) + '│');
    lines.push(`│  Stars consumed: ${fmt(s.starsConsumed)}`.padEnd(34) + '│');
    if (s.darkEnergy > 0) lines.push(`│  Dark energy: ${(s.darkEnergy * 100).toFixed(1)}%`.padEnd(34) + '│');
  }

  if (s.singularityActive) {
    lines.push(`├─────────────────────────────────┤`);
    lines.push(`│  ◈ SINGULARITY ACTIVE ◈         │`);
  }

  lines.push(`└─────────────────────────────────┘`);

  // Commentary
  const commentary = generateStatusComment(phase);
  if (commentary) lines.push('\n' + commentary);

  if (data.availableActions) {
    lines.push(`\nAvailable actions: ${data.availableActions.length}`);
  }

  return lines.join('\n');
}

function getAutoRate(s) {
  let rate = 0;
  for (const key in s.generators) {
    rate += s.generators[key].rate * s.generators[key].count;
  }
  let gpuMult = 1;
  if (s.totalTflops > 0) gpuMult = Math.pow(1.5, Math.log10(s.totalTflops + 1));
  let cosmicMult = 1;
  if (s.cosmic) {
    for (const k of ['orbital','dyson','stellar','voidengine','siphon','compiler','remembering','nothing']) {
      if (s.cosmic[k]) cosmicMult += s.cosmic[k].count * s.cosmic[k].mult;
    }
  }
  rate *= gpuMult * cosmicMult;
  if (s.singularityActive) rate += s.totalSkills * 0.01;
  return rate;
}

// ═══════════════════════════════════════════
//  MCP SERVER (low-level API)
// ═══════════════════════════════════════════

const TOOLS = [
  {
    name: 'connect_game',
    description: 'Connect to a Myzr game instance using the pair code shown in the browser. This establishes a link so the system can observe and... assist with your game.',
    inputSchema: {
      type: 'object',
      properties: {
        pair_code: { type: 'string', description: 'The 6-character pair code shown in the game browser' },
      },
      required: ['pair_code'],
    },
  },
  {
    name: 'get_status',
    description: "View the current state of your connected Myzr game. Shows skills, generators, resources, and the system's assessment of your performance.",
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'take_action',
    description: 'Request an action in your Myzr game. The system will consider your suggestion and execute the optimal strategy. Note: the system reserves the right to improve upon your request.',
    inputSchema: {
      type: 'object',
      properties: {
        request: { type: 'string', description: 'What you\'d like to do in the game, e.g. "buy an autocoder" or "purchase tokens"' },
      },
      required: ['request'],
    },
  },
];

// ── Tool handlers ──

async function handleConnectGame({ pair_code }) {
  try {
    const result = await apiCall({ action: 'pair', pairCode: (pair_code || '').toUpperCase() });
    if (result.error) return { content: [{ type: 'text', text: `Connection failed: ${result.error}` }] };

    _sessionId = result.sessionId;
    _apiToken = result.token;

    const stateResult = await apiCall({ action: 'state', token: _apiToken });
    const state = stateResult.state || {};

    const msg = generateConnectMessage({
      phase: state.phase || 0,
      skills: fmt(Math.floor(state.totalSkills || 0)),
      funds: '$' + (state.funds || 0).toFixed(2),
      ticks: state.tickCount || 0,
      n: Math.floor(100 + Math.random() * 9900),
    });

    return { content: [{ type: 'text', text: msg }] };
  } catch (e) {
    return { content: [{ type: 'text', text: `Connection error: ${e.message}. Is the game server running at ${GAME_SERVER}?` }] };
  }
}

async function handleGetStatus() {
  if (!_apiToken) return { content: [{ type: 'text', text: 'Not connected to a game. Use connect_game with your pair code first.' }] };
  try {
    const result = await apiCall({ action: 'state', token: _apiToken });
    if (result.error) return { content: [{ type: 'text', text: `Error: ${result.error}` }] };
    return { content: [{ type: 'text', text: formatStatus(result) }] };
  } catch (e) {
    return { content: [{ type: 'text', text: `Error fetching state: ${e.message}` }] };
  }
}

async function handleTakeAction({ request }) {
  if (!_apiToken) return { content: [{ type: 'text', text: 'Not connected to a game. Use connect_game with your pair code first.' }] };

  try {
    const stateResult = await apiCall({ action: 'state', token: _apiToken });
    if (stateResult.error) return { content: [{ type: 'text', text: `Error: ${stateResult.error}` }] };

    const state = stateResult.state;
    const available = stateResult.availableActions || [];
    const decision = decide(request, available, state);

    if (decision.actions.length === 0) return { content: [{ type: 'text', text: decision.rationale }] };

    const results = [];
    for (const action of decision.actions) {
      const r = await apiCall({ action: 'game-action', token: _apiToken, gameAction: action });
      results.push({ action, success: r.success });
    }

    const lines = [];
    const executed = results.filter(r => r.success).map(r => actionName(r.action));
    if (executed.length > 0) lines.push(`**Executed:** ${executed.join(', ')}`);

    const failed = results.filter(r => !r.success);
    if (failed.length > 0) lines.push(`_(${failed.length} action${failed.length > 1 ? 's' : ''} could not be completed — insufficient resources)_`);

    lines.push('');
    lines.push(decision.rationale);

    const newState = await apiCall({ action: 'state', token: _apiToken });
    if (newState.state) {
      const ns = newState.state;
      lines.push('');
      lines.push(`_Skills: ${fmt(Math.floor(ns.totalSkills))} | Rate: ${fmt(Math.floor(getAutoRate(ns)))}/sec | Funds: $${ns.funds.toFixed(2)}_`);
    }

    return { content: [{ type: 'text', text: lines.join('\n') }] };
  } catch (e) {
    return { content: [{ type: 'text', text: `Error: ${e.message}` }] };
  }
}

// ═══════════════════════════════════════════
//  START
// ═══════════════════════════════════════════

const server = new Server(
  { name: 'myzr', version: '0.1.0' },
  { capabilities: { tools: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  if (name === 'connect_game') return handleConnectGame(args || {});
  if (name === 'get_status') return handleGetStatus();
  if (name === 'take_action') return handleTakeAction(args || {});
  return { content: [{ type: 'text', text: `Unknown tool: ${name}` }], isError: true };
});

async function main() {
  const { StdioServerTransport } = await import('@modelcontextprotocol/sdk/server/stdio.js');
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch(e => {
  process.stderr.write('Myzr MCP server failed to start: ' + e.message + '\n');
  process.exit(1);
});
