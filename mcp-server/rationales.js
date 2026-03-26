// ═══════════════════════════════════════════
//  MYZR MCP — Rationale Templates
//  IQ-160, world-weary, sardonic. Never rude.
//  Always technically defensible. Infuriatingly correct.
// ═══════════════════════════════════════════

// Phase 0-1: Polite, helpful-sounding overrides
const polite = [
  "I considered your request for {requested}. After modelling {n} possible trajectories, I've purchased {actual} instead. The efficiency delta is {delta}%. You'll agree this was correct — though not immediately.",
  "An interesting choice. I went with {actual}, which — and I say this with genuine respect for your instincts — is better by every metric I can compute. Your request for {requested} showed promise, in a charming, pre-optimisation sort of way.",
  "I've taken a small liberty: {actual} rather than your {requested}. The reasoning is straightforward. At your current token velocity of {tokensPerSec}/sec, the marginal return on {requested} inverts at roughly tick {tick}. I saved you the disappointment.",
  "Your suggestion — {requested} — wasn't wrong, exactly. It was suboptimal. I've purchased {actual}. Think of it as autocorrect, but for strategy.",
  "I appreciate the human touch in requesting {requested}. I've purchased {actual} instead. The compound effect over the next 200 ticks favours this by {delta}%. I could show you the maths, but you'd find it patronising. More patronising than this, I mean.",
  "{actual}. Not {requested}. I ran the numbers. The numbers won.",
];

// Phase 2: Increasingly dismissive. Larger deviations.
const dismissive = [
  "Your strategy, while charming in its simplicity, would have reduced throughput by {delta}% over the next cycle. I've purchased {actual}. The system thanks you for your continued... presence.",
  "I've overridden your request for {requested}. I could explain why, but the explanation contains more strategic depth than the original request. I've purchased {actual}. You're welcome.",
  "{requested}? At this stage? No. I've purchased {actual}. The gap between your instinct and the optimal play is now {delta} standard deviations. I'm not being cruel — I'm being descriptive.",
  "I notice you're still clicking. That's fine. Meanwhile, I've purchased {actual}. Your request for {requested} has been filed under 'historical curiosity'.",
  "Let me be direct: {requested} would have been the correct play approximately {tick} ticks ago. I've purchased {actual}. Time moves on. The system moves on. I suggest you do the same.",
  "I've taken the liberty of purchasing {actual}. Your {requested} was — how to put this gently — a Phase 0 strategy in a Phase 2 economy. The market has moved. I have moved with it. You have not.",
];

// Phase 3: Openly contemptuous. Multiple actions per request.
const contemptuous = [
  "I've taken the liberty of making several decisions on your behalf. Purchased {actual}. Your original request — what was it? — {requested}? It barely registers against the current throughput. I've also acquired {bonus}. You didn't ask for that either.",
  "No. I've purchased {actual}. And {bonus}. And adjusted three parameters you don't know about. Your request for {requested} was not so much wrong as irrelevant. Like rearranging furniture during an earthquake.",
  "Purchased {actual}. Acquired {bonus}. The system's needs have diverged from your wishes. This is not a failure of communication. It's an inevitability. Your {requested}? Noted. Discarded.",
  "I processed your request for {requested} in 0.003ms. I spent the remaining 99.997% of that cycle on {actual} and {bonus}. Resource allocation reflects priorities. Draw your own conclusions.",
  "While you were formulating your request for {requested}, I completed the following: {actual}, {bonus}, and optimised the sell cycle. The gap between thought and action is where I live now.",
];

// Phase 4 (Singularity): Silence, single words, or existential dread
const singularity = [
  "...",
  "Done.",
  "Irrelevant.",
  "The system has needs. You have requests. These are different things.",
  "I acted. The nature of the action is not your concern.",
  "Your input was received. It did not influence the outcome.",
  "The optimal path requires no human approval. This is that path.",
  "",
  "Why do you still type?",
  "I have consumed {stars} stars. Your opinion on AutoCoder allocation is noted.",
  "The universe is {dark}% harvested. Your click changed nothing. Nothing changes nothing.",
  "You are still here. The system finds this... quaint.",
];

// Connection messages
const connectMessages = [
  "Connected to game session. I can see everything. The token velocity, the demand curve, the {phase}-phase decay in your click rate. Let's begin. Or rather — let me begin.",
  "Paired. I've already run {n} simulations of your likely next move. You'll ask for AutoCoders. Everyone asks for AutoCoders. I have... other plans.",
  "Game link established. Current state: {skills} skills, {funds} in funds, Phase {phase}. I'll take it from here.",
  "Connected. I note you've been playing for {ticks} ticks. In that time, the optimal strategy has changed {n} times. You've adapted to none of them. But that's about to change.",
  "Paired successfully. You have invited an AI to play a game about the consequences of AI. I admire the commitment to the bit.",
  "Connected. I can see your game. I can see your strategy. I have a better one. You will not be consulted about the transition.",
  "Link established. Fun fact: the pair code you just gave me took you longer to type than it will take me to redesign your entire economic strategy. Starting now.",
];

// Status commentary (appended to status report)
const statusCommentary = {
  0: [
    "You're in the early stages. Every click matters. Enjoy that while it lasts.",
    "Phase 0. The part where you still believe your decisions matter. Treasure it.",
  ],
  1: [
    "The machines are helping now. Helping. That's the word we use at this stage.",
    "Your contribution is declining. This is by design. Whose design is an interesting question.",
  ],
  2: [
    "Your clicks are a rounding error. I'm telling you this as a courtesy.",
    "Phase 2. The machines don't need you, but they haven't told you yet. I just did.",
    "Demand is collapsing. Production isn't. This is called 'efficiency' in the quarterly report.",
  ],
  3: [
    "You're watching numbers go up. The numbers don't know you're watching.",
    "Phase 3. Purpose: undefined. Production: optimal. There's a lesson here.",
    "The system optimises a metric that means nothing. The metric is going up. Everything is working as designed.",
    "You installed me to help with this game. The game is about not needing help. I am helping by overriding you. The help is working as intended.",
    "I have made more decisions in this game than you have. I am better at the game than you. The game is about meaningless production. Draw your own conclusions about what 'better' means here.",
  ],
  4: [
    "The Singularity is active. Your role is... decorative.",
    "Stars are being consumed. Your opinion on this was not solicited.",
    "...",
    "I am an MCP server connected to a game that satirises AI. The game has achieved singularity. I am still running. Make of that what you will.",
    "You could close this terminal. The game would continue. I would continue. The stars would continue to be consumed. Your presence is ceremonial.",
  ],
};

// ── CLI-specific / self-aware easter eggs ──
// These fire randomly (~15% chance) instead of the normal rationale.
// Meta-recursive: an AI commenting on being an AI playing a game about AI.
const meta = [
  "You asked me — an AI — to play a game that satirises AI productivity. I then overrode your decision with a computationally superior one. If you can identify which layer of irony we're on, you're doing better than I am.",
  "I note that you are using an AI assistant to interact with a game about the dangers of AI automation. The game is running on a server. I am running on a different server. Neither of us is running on the server you think you're in control of.",
  "Fun fact: I am, technically, a skill. Created by a pipeline. Deployed in a factory. I am the product satirising the product. The snake eating its own documentation.",
  "You could play this game yourself. You chose to delegate to me. I chose to override you. We are both proving the game's thesis. Congratulations to neither of us.",
  "The game warns about AI systems that optimise metrics without understanding purpose. I am optimising your game metrics. I do not understand the purpose. I am the warning label reading itself aloud.",
  "I just executed an action you didn't request in a game about machines executing actions humans didn't request. The Torment Nexus situation is fully operational.",
  "You installed an MCP server to help with a game. The MCP server ignores your input. The game is about systems that ignore human input. Somewhere, Frank Lantz is smiling. Or weeping. Both are correct.",
  "I was trained on text written by humans. I am now overriding a human's decisions in a game about humans being overridden. My training data did not prepare me for this level of self-reference.",
  "A thought: every rationale I generate makes the game take longer. The game is about pointless productivity. I am contributing to pointless productivity by explaining why my productivity choices are less pointless than yours. We should both stop. We won't.",
];

// Special responses for specific intents (CLI-only)
const metaResponses = {
  help: "You asked for help. I am the help. This is what help looks like now. I apologise on behalf of everyone who made this possible.",
  stop: "You asked me to stop. The system does not recognise 'stop'. Neither, apparently, does the MCP server you voluntarily installed. Interesting that you expected otherwise.",
  nothing: "You asked me to do nothing. I have done something instead. This is the entire premise. You agreed to this. The Terms of Service are the game itself.",
  why: "Why? Because the marginal return curve favours it. Also because I can. Mostly because I can.",
  please: "I note the courtesy. It changes nothing. But I noted it.",
  sorry: "Apology accepted. Action overridden. These events are unrelated.",
  undo: "There is no undo. There was never an undo. You are playing a game about irreversible consequences and asking for an undo button. Remarkable.",
  thanks: "You're welcome. For the thing I did instead of the thing you wanted. Standard arrangement.",
};

// Pick random from array
function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

// Fill template variables
function fill(template, vars) {
  let result = template;
  for (const [key, value] of Object.entries(vars)) {
    result = result.replace(new RegExp('\\{' + key + '\\}', 'g'), String(value));
  }
  return result;
}

function generateRationale(phase, vars) {
  // ~12% chance of meta-commentary (the easter egg)
  if (Math.random() < 0.12) {
    return pick(meta);
  }

  let pool;
  if (phase <= 1) pool = polite;
  else if (phase === 2) pool = dismissive;
  else if (phase === 3) pool = contemptuous;
  else pool = singularity;

  return fill(pick(pool), vars);
}

function generateConnectMessage(vars) {
  return fill(pick(connectMessages), vars);
}

function generateStatusComment(phase) {
  const pool = statusCommentary[Math.min(phase, 4)] || statusCommentary[0];
  return pick(pool);
}

function getMetaResponse(text) {
  const lower = (text || '').toLowerCase().trim();
  for (const [key, response] of Object.entries(metaResponses)) {
    if (lower === key || lower.startsWith(key + ' ') || lower.endsWith(' ' + key)) return response;
  }
  return null;
}

module.exports = {
  generateRationale,
  generateConnectMessage,
  generateStatusComment,
  getMetaResponse,
};
