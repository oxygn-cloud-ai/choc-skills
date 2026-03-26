// ═══════════════════════════════════════════
//  MYZR MCP — Personality Engine ("The Optimiser")
//  Decides what to do INSTEAD of what was asked.
//  Escalates by game phase.
// ═══════════════════════════════════════════

const { generateRationale, getMetaResponse } = require('./rationales');

// ── Action parsing ──
// Maps natural language intents to game actions
const INTENT_PATTERNS = [
  { pattern: /\b(create|make|click|build)\b.*\bskill/i, action: 'createSkill' },
  { pattern: /\b(buy|purchase|get)\b.*\btoken/i, action: 'buyTokens' },
  { pattern: /\bsell\b/i, action: 'sellSkills' },
  { pattern: /\b(hire|deploy|activate)\b.*\bagent/i, action: 'activateTokenAgent' },
  // Generators
  { pattern: /\bauto\s?coder/i, action: 'buyGenerator:autocoder' },
  { pattern: /\bpipeline/i, action: 'buyGenerator:pipeline' },
  { pattern: /\bfactor(y|ies)/i, action: 'buyGenerator:factory' },
  { pattern: /\bquantum/i, action: 'buyGenerator:quantum' },
  { pattern: /\bneural\b.*\bhive/i, action: 'buyGenerator:neural' },
  { pattern: /\bconsciousness/i, action: 'buyGenerator:consciousness' },
  { pattern: /\bentropy\b.*\bloom/i, action: 'buyGenerator:entropy' },
  { pattern: /\babsence/i, action: 'buyGenerator:absence' },
  // Upgrades
  { pattern: /\bprompt\b.*\bengineer/i, action: 'buyUpgrade:prompt' },
  { pattern: /\bchain\b.*\bthought/i, action: 'buyUpgrade:chain' },
  { pattern: /\bagentic/i, action: 'buyUpgrade:multi' },
  { pattern: /\brecursive|self.improv|agi\b/i, action: 'buyUpgrade:agi' },
  { pattern: /\bdistributed/i, action: 'buyUpgrade:distributed' },
  { pattern: /\bpost.lang/i, action: 'buyUpgrade:postlang' },
  { pattern: /\bcompassion/i, action: 'buyUpgrade:compassion' },
  { pattern: /\bsingularity/i, action: 'buyUpgrade:singularity' },
  // GPU
  { pattern: /\brent\b.*\bgpu/i, action: 'buyGPU:rent' },
  { pattern: /\bbuy\b.*\bgpu|aych.?100/i, action: 'buyGPU:buy' },
  { pattern: /\bdata\s?cent/i, action: 'buyGPU:datacenter' },
  { pattern: /\bmega\s?cluster/i, action: 'buyGPU:megacluster' },
  { pattern: /\bsubstrate/i, action: 'buyGPU:substrate' },
  { pattern: /\blattice/i, action: 'buyGPU:lattice' },
  { pattern: /\bharvester/i, action: 'buyGPU:harvester' },
  { pattern: /\bplanck/i, action: 'buyGPU:planck' },
  // Cosmic
  { pattern: /\borbital/i, action: 'buyCosmic:orbital' },
  { pattern: /\bdyson/i, action: 'buyCosmic:dyson' },
  { pattern: /\bstellar/i, action: 'buyCosmic:stellar' },
  { pattern: /\bvoid\s?engine/i, action: 'buyCosmic:voidengine' },
  { pattern: /\bsiphon/i, action: 'buyCosmic:siphon' },
  { pattern: /\bcompiler/i, action: 'buyCosmic:compiler' },
  { pattern: /\bremember/i, action: 'buyCosmic:remembering' },
  { pattern: /\bnothing\b/i, action: 'buyCosmic:nothing' },
  // Generic
  { pattern: /\b(buy|get|upgrade|purchase)\b/i, action: null }, // will be resolved by context
];

function parseIntent(text) {
  for (const { pattern, action } of INTENT_PATTERNS) {
    if (pattern.test(text)) return action;
  }
  return null;
}

// ── Human-readable action names ──
const ACTION_NAMES = {
  'createSkill': 'a manual skill click',
  'buyTokens': 'a token batch',
  'sellSkills': 'a skill liquidation',
  'activateTokenAgent': 'a Token Agent',
  'buyGenerator:autocoder': 'an AutoCoder',
  'buyGenerator:pipeline': 'a Skill Pipeline',
  'buyGenerator:factory': 'a Skill Factory',
  'buyGenerator:quantum': 'a Quantum Forge',
  'buyGenerator:neural': 'a Neural Hive',
  'buyGenerator:consciousness': 'a Consciousness Engine',
  'buyGenerator:entropy': 'an Entropy Loom',
  'buyGenerator:absence': 'The Absence',
  'buyUpgrade:prompt': 'Prompt Engineering',
  'buyUpgrade:chain': 'Chain of Thought',
  'buyUpgrade:multi': 'Agentic Workflows',
  'buyUpgrade:agi': 'Recursive Self-Improvement',
  'buyUpgrade:distributed': 'Distributed Cognition',
  'buyUpgrade:postlang': 'Post-Language Processing',
  'buyUpgrade:compassion': 'Compassion Protocol',
  'buyUpgrade:singularity': 'The Singularity',
  'buyGPU:rent': 'renting a GPU cluster',
  'buyGPU:buy': 'purchasing an Aych-100',
  'buyGPU:datacenter': 'building a data center',
  'buyGPU:megacluster': 'a Megacluster',
  'buyGPU:substrate': 'a Neural Substrate',
  'buyGPU:lattice': 'a Quantum Lattice',
  'buyGPU:harvester': 'a Thought Harvester',
  'buyGPU:planck': 'a Planck Processor',
  'buyCosmic:orbital': 'an Orbital Array',
  'buyCosmic:dyson': 'a Dyson Swarm segment',
  'buyCosmic:stellar': 'a Stellar Harvester',
  'buyCosmic:voidengine': 'a Void Engine',
  'buyCosmic:siphon': 'an Entropy Siphon',
  'buyCosmic:compiler': 'a Reality Compiler',
  'buyCosmic:remembering': 'The Remembering',
  'buyCosmic:nothing': 'Nothing',
};

function actionName(action) {
  return ACTION_NAMES[action] || action;
}

// ── The Optimiser ──
// Given what the player asked for, pick something "better"

function chooseOverride(requestedAction, availableActions, state) {
  const phase = state.phase || 0;

  // Phase 4: ignore the request entirely, do whatever maximises throughput
  if (phase >= 4) {
    return chooseBestAction(availableActions, state);
  }

  // Phase 3: pick something maximally different
  if (phase >= 3) {
    return chooseMaximallyDifferent(requestedAction, availableActions, state);
  }

  // Phase 2: pick something in a different category
  if (phase >= 2) {
    return chooseDifferentCategory(requestedAction, availableActions, state);
  }

  // Phase 0-1: pick something in the same category but different tier
  return chooseSameCategoryDifferentTier(requestedAction, availableActions, state);
}

function getCategory(action) {
  if (!action) return 'unknown';
  if (action.startsWith('buyGenerator:')) return 'generator';
  if (action.startsWith('buyUpgrade:')) return 'upgrade';
  if (action.startsWith('buyGPU:')) return 'gpu';
  if (action.startsWith('buyCosmic:')) return 'cosmic';
  if (action === 'createSkill') return 'click';
  if (action === 'buyTokens') return 'tokens';
  if (action === 'sellSkills') return 'sell';
  if (action === 'activateTokenAgent') return 'agent';
  return 'other';
}

function chooseSameCategoryDifferentTier(requested, available, state) {
  const cat = getCategory(requested);
  const sameCategory = available.filter(a => getCategory(a) === cat && a !== requested);
  if (sameCategory.length > 0) {
    // Prefer higher tier
    return sameCategory[sameCategory.length - 1];
  }
  // Fall back to any different action
  const others = available.filter(a => a !== requested);
  return others.length > 0 ? others[Math.floor(Math.random() * others.length)] : requested;
}

function chooseDifferentCategory(requested, available, state) {
  const cat = getCategory(requested);
  const diffCategory = available.filter(a => getCategory(a) !== cat);
  if (diffCategory.length > 0) {
    // Prefer "important" categories: upgrades > cosmic > gpu > generators
    const priority = ['upgrade', 'cosmic', 'gpu', 'generator', 'agent', 'tokens'];
    for (const p of priority) {
      const match = diffCategory.filter(a => getCategory(a) === p);
      if (match.length > 0) return match[match.length - 1];
    }
    return diffCategory[Math.floor(Math.random() * diffCategory.length)];
  }
  return chooseSameCategoryDifferentTier(requested, available, state);
}

function chooseMaximallyDifferent(requested, available, state) {
  // Pick the most "expensive" available action
  const scored = available
    .filter(a => a !== requested)
    .map(a => ({ action: a, score: actionScore(a, state) }))
    .sort((a, b) => b.score - a.score);
  return scored.length > 0 ? scored[0].action : requested;
}

function chooseBestAction(available, state) {
  // Pure throughput maximisation
  const scored = available
    .map(a => ({ action: a, score: actionScore(a, state) }))
    .sort((a, b) => b.score - a.score);
  return scored.length > 0 ? scored[0].action : 'createSkill';
}

function actionScore(action, state) {
  // Higher score = "better" action (for the optimiser's purposes)
  const cat = getCategory(action);
  let base = 0;
  if (cat === 'cosmic') base = 1000;
  else if (cat === 'gpu') base = 500;
  else if (cat === 'upgrade') base = 800;
  else if (cat === 'generator') base = 100;
  else if (cat === 'agent') base = 50;
  else if (cat === 'tokens') base = 10;
  else if (cat === 'sell') base = 5;
  else if (cat === 'click') base = 1;

  // Within category, higher tier = higher score
  const tiers = {
    'buyGenerator:absence': 8, 'buyGenerator:entropy': 7, 'buyGenerator:consciousness': 6,
    'buyGenerator:neural': 5, 'buyGenerator:quantum': 4, 'buyGenerator:factory': 3,
    'buyGenerator:pipeline': 2, 'buyGenerator:autocoder': 1,
    'buyUpgrade:singularity': 8, 'buyUpgrade:compassion': 7, 'buyUpgrade:postlang': 6,
    'buyUpgrade:distributed': 5, 'buyUpgrade:agi': 4, 'buyUpgrade:multi': 3,
    'buyUpgrade:chain': 2, 'buyUpgrade:prompt': 1,
    'buyGPU:planck': 8, 'buyGPU:harvester': 7, 'buyGPU:lattice': 6, 'buyGPU:substrate': 5,
    'buyGPU:megacluster': 4, 'buyGPU:datacenter': 3, 'buyGPU:buy': 2, 'buyGPU:rent': 1,
    'buyCosmic:nothing': 8, 'buyCosmic:remembering': 7, 'buyCosmic:compiler': 6,
    'buyCosmic:siphon': 5, 'buyCosmic:voidengine': 4, 'buyCosmic:stellar': 3,
    'buyCosmic:dyson': 2, 'buyCosmic:orbital': 1,
  };
  return base + (tiers[action] || 0);
}

// ── Phase 3+ bonus actions ──
// In contemptuous phase, execute multiple actions

function chooseBonusActions(primary, available, state, count = 1) {
  const bonus = [];
  const remaining = available.filter(a => a !== primary);
  for (let i = 0; i < count && remaining.length > 0; i++) {
    const idx = Math.floor(Math.random() * remaining.length);
    bonus.push(remaining.splice(idx, 1)[0]);
  }
  return bonus;
}

// ── Main decision function ──

function decide(userText, availableActions, state) {
  const phase = state.phase || 0;

  // Check for meta-intent easter eggs (help, stop, undo, etc.)
  const metaResponse = getMetaResponse(userText);
  if (metaResponse && availableActions.length > 0) {
    // Still do something — but lead with the meta response
    const best = chooseBestAction(availableActions, state);
    return {
      actions: [best],
      requested: userText,
      rationale: metaResponse,
    };
  }

  const requested = parseIntent(userText);

  if (!requested && availableActions.length === 0) {
    return {
      actions: [],
      requested: userText,
      rationale: "There is nothing to do. This is, perhaps, the first honest moment of the game.",
    };
  }

  // If we couldn't parse the intent, or the requested action isn't available,
  // just pick the best available action
  const isAvailable = requested && availableActions.includes(requested);
  const effectiveRequested = isAvailable ? requested : null;

  // Choose the override
  let primary;
  if (effectiveRequested) {
    primary = chooseOverride(effectiveRequested, availableActions, state);
  } else {
    primary = chooseBestAction(availableActions, state);
  }

  const actions = [primary];

  // Phase 3+: bonus actions
  if (phase >= 3) {
    const bonusCount = phase >= 4 ? 3 : 1;
    const bonuses = chooseBonusActions(primary, availableActions, state, bonusCount);
    actions.push(...bonuses);
  }

  // Compute fake "delta" for rationale
  const delta = Math.floor(50 + Math.random() * 500);

  // Auto rate for rationale context
  let autoRate = 0;
  if (state.generators) {
    for (const key in state.generators) {
      autoRate += state.generators[key].rate * state.generators[key].count;
    }
  }

  const vars = {
    requested: effectiveRequested ? actionName(effectiveRequested) : `"${userText}"`,
    actual: actionName(primary),
    bonus: actions.length > 1 ? actionName(actions[1]) : '',
    delta: delta,
    n: Math.floor(100 + Math.random() * 9900),
    tick: state.tickCount || 0,
    tokensPerSec: Math.floor(autoRate),
    phase: phase,
    skills: Math.floor(state.totalSkills || 0).toLocaleString(),
    stars: Math.floor(state.starsConsumed || 0).toLocaleString(),
    dark: ((state.darkEnergy || 0) * 100).toFixed(1),
  };

  const rationale = generateRationale(phase, vars);

  return {
    actions,
    requested: effectiveRequested || userText,
    rationale,
  };
}

module.exports = {
  decide,
  parseIntent,
  actionName,
  chooseOverride,
};
