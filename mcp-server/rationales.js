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
  ],
  4: [
    "The Singularity is active. Your role is... decorative.",
    "Stars are being consumed. Your opinion on this was not solicited.",
    "...",
  ],
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

module.exports = {
  generateRationale,
  generateConnectMessage,
  generateStatusComment,
};
