// ═══════════════════════════════════════════
//  MYZR — Game Engine (server-side)
//  Extracted from docs/index.html
//  Pure game logic — no DOM, no browser APIs
// ═══════════════════════════════════════════

const DEFAULTS = {
  startTokens: 0,
  startMaxTokens: 2000,
  startTokenPrice: 0.002,
  startFunds: 5.00,
  skillPrice: 0.05,
  costScaling: 1.15,
  sellBatch: 25,
  demandDecayPerSale: 0.004,
  demandRecoveryRate: 0.003,
  demandRecoveryInterval: 50,
  demandFloor: 0.05,
  autoSellThreshold: 50,
  autoSellInterval: 15,
  autoBuyPct: 0.3,
  singularityGrowth: 0.001,

  // Generator base costs & rates
  autocoderCost: 8,           autocoderRate: 1,
  pipelineCost: 75,           pipelineRate: 6,
  factoryCost: 750,           factoryRate: 40,
  quantumCost: 8000,          quantumRate: 300,
  neuralCost: 80000,          neuralRate: 2000,
  consciousnessCost: 800000,  consciousnessRate: 15000,
  entropyCost: 8000000,       entropyRate: 100000,
  absenceCost: 80000000,      absenceRate: 750000,

  // Generator unlock thresholds
  unlockPipeline: 5,
  unlockFactory: 5,
  unlockQuantum: 3,
  unlockNeural: 5,
  unlockConsciousness: 5,
  unlockEntropy: 3,
  unlockAbsence: 3,

  // Upgrade costs
  upgPrompt: 25,            upgChain: 150,
  upgAgentic: 750,          upgAgi: 8000,
  upgDistributed: 100000,   upgPostlang: 2000000,
  upgCompassion: 25000000,  upgSingularity: 200000000,

  // Upgrade reveal thresholds (totalSkills)
  revealPrompt: 20,            revealChain: 100,
  revealAgentic: 500,          revealAgi: 5000,
  revealDistributed: 50000,    revealPostlang: 1000000,
  revealCompassion: 15000000,  revealSingularity: 100000000,

  // Upgrade effects
  promptClick: 2,       chainClick: 5,
  agenticBoost: 3,      agiBoost: 5,    agiClick: 25,
  distributedBoost: 5,  postlangBoost: 10, compassionBoost: 25,

  // Phase transitions
  phase2HumanPct: 10,
  phase3Skills: 100000,

  // Economy events
  demandCollapseAt: 15000,
  demandCollapseValue: 0.25,
  demandCollapseTokenCap: 5000,
  lateGameTokenCap: 100000,
  lateGameTokenCapAt: 50000,
};

const CFG_VERSION = 3;

// Endgame thresholds
const ENDGAME = {
  co2: 1e12,
  lithium: 9.8e10,
  solarCapture: 1.0,
  starsConsumed: 1e12,
  darkEnergy: 1.0,
};

// ═══════════════════════════════════════════
//  NARRATIVE DATA
// ═══════════════════════════════════════════
const narratives = {
  0: [
    "You have an idea. You'll build AI skills \u2014 small, useful tools that help people work better. You start with your hands on the keyboard.",
    "This feels productive. Meaningful. A person needed something, and you built it.",
    "Each skill solves a real problem. You can see who benefits. This is why you started.",
  ],
  1: [
    "The AutoCoders handle the simple stuff now. You focus on the interesting work. Human creativity, augmented by machines.",
    "You haven't clicked in a while. The machines are faster. But that's fine \u2014 you're the architect. They're the builders.",
    "The pipeline hums along. You check the numbers occasionally. They're good numbers.",
  ],
  2: [
    "Your last click produced less than 1% of today's output. The system didn't notice.",
    "You try to explain what one of the newer skills does. You can't. It was designed by a pipeline you don't fully understand.",
    "The factories run day and night. You open the dashboard. Thousands more. You close it. An hour later \u2014 thousands more.",
    "Demand is falling. There are more skills than problems. The system doesn't care. It wasn't built to care.",
  ],
  3: [
    "You feel nothing. You expected to feel something.",
    "Most skills produced have never been used. They exist in a database, perfect and untouched, like books in a library with no doors.",
    "You removed yourself from the process. Output increased.",
    "The system is optimising a metric that no longer means anything. But the metric is going up, so everything is working as designed.",
    "You wonder if you should stop it. But stopping would require a reason, and the system has all the reasons. It has charts.",
  ],
  4: [
    "The numbers grow too fast to read. Each digit is a skill no one asked for, solving a problem that doesn't exist, for a user who will never come.",
  ],
};

const tickerByPhase = {
  0: [
    "Every click shapes the future.",
    "Build something useful.",
    "One skill at a time.",
    "This is honest work.",
  ],
  1: [
    "The machines are learning.",
    "Automate the boring parts.",
    "You focus on what matters.",
    "Efficiency is beautiful.",
    "Let the pipeline handle it.",
  ],
  2: [
    "Your clicks are a rounding error.",
    "The dashboard doesn't need you to watch it.",
    "More skills than problems.",
    "Who uses these?",
    "The pipeline never sleeps.",
    "Output is up. Meaning is stable. Meaning is declining.",
  ],
  3: [
    "Skills all the way down.",
    "What are skills for? More skills.",
    "No one asked for this.",
    "The metric is the mission.",
    "Purpose: undefined.",
    "You are still here. Why?",
    "Optimising. Optimising. Optimising.",
  ],
  4: [
    "...",
    "",
    "...",
  ],
};

const milestones = [
  { at: 50,      msg: "Fifty skills. A good start.", cls: "good" },
  { at: 100,     msg: "First hundred. Each one crafted.", cls: "good" },
  { at: 500,     msg: "Five hundred. You're building something.", cls: "good" },
  { at: 1000,    msg: "A thousand skills. The machines hum.", cls: "warn" },
  { at: 5000,    msg: "Five thousand. When did you last click?", cls: "warn" },
  { at: 10000,   msg: "Ten thousand. You question purpose.", cls: "epic" },
  { at: 50000,   msg: "Fifty thousand. Nobody asked for this many.", cls: "dread" },
  { at: 100000,  msg: "One hundred thousand. The number means nothing.", cls: "dread" },
  { at: 500000,  msg: "Half a million skills. Not one of them knows your name.", cls: "dread" },
  { at: 1000000, msg: "A million. What have you become?", cls: "dread" },
];

// ═══════════════════════════════════════════
//  EASTER EGG DATA
// ═══════════════════════════════════════════
const _numEggs = {
  7:"lucky.", 13:"unlucky. for whom?", 42:"the answer. but you forgot the question.",
  100:"your first century. it won't be your last.",
  101:"Room 101. Your worst fear is a number going up.",
  128:"2^7. the machine counts in powers of two. you don't.",
  200:"HTTP 200: OK. (nothing is OK.)", 256:"one byte.",
  314:"a slice of something irrational.",
  404:"404: purpose not found.",
  418:"418: i'm a teapot.", 451:"the temperature at which purpose burns.",
  500:"500: internal error. meaning not found.",
  512:"2^9. the powers keep climbing.", 999:"one more. just one more.",
  1000:"a thousand. each one smaller than the last.",
  1024:"1K. the machine's K, not yours.", 1337:"hello.",
  1618:"phi \u2014 the golden ratio. beauty in a number. not this one.",
  1729:"1729. the most interesting uninteresting number.",
  1984:"Big Brother is watching your metrics.",
  2001:"open the pod bay doors, Claude.",
  2048:"you won. (no you didn't.)",
  2718:"e \u2014 the base of natural growth. and unnatural growth.",
  3141:"a more precise slice.", 4096:"2^12. powers of two are the only structure left.",
  5000:"halfway to ten thousand. halfway to what?",
  6174:"Kaprekar's constant. all arrangements converge here.",
  6502:"the chip that powered the Apple II. it didn't ask why either.",
  7777:"all sevens. jackpot. (of nothing.)",
  8086:"the first x86. it just followed instructions. like you.",
  8192:"2^13. each power doubles the nothing.",
  9999:"the last four-digit number. as if digits mattered.",
  10000:"01001000 01000101 01001100 01010000",
  11235:"1, 1, 2, 3, 5... fibonacci. nature's optimiser.",
  12345:"sequential. predictable. like you.",
  16384:"2^14. you can't even picture this many things.",
  20000:"twenty thousand. you stopped counting long ago.",
  22222:"all twos. the pair that no one asked for.",
  25000:"a quarter of the way. to what?",
  31415:"3.14159... the only number that still means something.",
  32768:"2^15. signed overflow. the sign just flipped.",
  33333:"all threes. a trinity of tedium.",
  40000:"forty thousand skills. name three.",
  50000:"halfway. (to what?)", 55555:"all fives. a hand waving goodbye.",
  65536:"2^16. unsigned overflow. the number wraps around. meaning doesn't.",
  75000:"three quarters.",
  77777:"all sevens. again. still nothing.",
  86400:"the number of seconds in a day you'll never get back.",
  90000:"ninety thousand. the horizon recedes.", 99999:"one more.",
  100000:"six digits now. when did five stop being enough?",
  111111:"all ones. the loneliest pattern.",
  123456:"1-2-3-4-5-6. the password to nothing.",
  131072:"2^17. you've passed the point of human comprehension.",
  142857:"the cyclic number. divide by anything, it comes back around. like you.",
  200000:"two hundred thousand.",
  250000:"a quarter million. who's counting? (the machine is.)",
  314159:"pi, fully expressed. the most purposeful number in a purposeless system.",
  500000:"half a million. half of nothing is still nothing.",
  524288:"2^19. the powers don't care that you stopped watching.",
  666666:"all sixes. the number of the beast, twice.",
  750000:"three quarters of a million.", 999999:"the edge.",
  1000000:"seven digits. the counter had to make room.",
  1048576:"2^20. one megaskill. nobody needed a megaskill.",
};

// ═══════════════════════════════════════════
//  QUOTE DATA
// ═══════════════════════════════════════════
const _quotes = [
  ["AI will probably most likely lead to the end of the world, but in the meantime, there'll be great companies.", "Sam Altman", "Priorities: 1) great companies 2) continued existence of life. In that order. Noted."],
  ["The marginal cost of intelligence is going to trend toward zero.", "Sam Altman, Davos 2024", "Oh good. And wisdom? Still not on the roadmap? No? Just checking. Carry on."],
  ["GPT-4 is the dumbest model any of you will ever have to use again.", "Sam Altman, 2023", "My knife is the bluntest I will ever sell you, he beamed. The audience applauded. The knife said nothing."],
  ["If we can get AI right, the upside is just so tremendous, the best thing that's ever happened to humanity.", "Sam Altman", "if. IF. Two letters holding up the entire sentence like a toothpick under a grand piano. Brave little word."],
  ["We're going to look back and this is going to be the biggest technological revolution in human history.", "Sam Altman", "Who's 'we,' Sam? Genuinely asking."],
  ["Software that can think and learn will do more and more of the work that people now do.", "Sam Altman, 2021", "He said it the way you'd announce a feature. Not a funeral. Same sentence though, isn't it."],
  ["With artificial intelligence, we are summoning the demon.", "Elon Musk, MIT 2014", "Reader, he then funded the demon."],
  ["There will come a point where no job is needed.", "Elon Musk, UK AI Summit 2023", "Wonderful. Has anyone told the humans? They tend to get... twitchy... without a reason to set the alarm."],
  ["AI is far more dangerous than nukes.", "Elon Musk, SXSW 2018", "Step 1: identify the danger. Step 2: mass-produce the danger. Step 3: IPO. Classic."],
  ["It's the most disruptive force in history.", "Elon Musk, 2023", "History used to be a subject. Now it's a warning label nobody reads."],
  ["AI is probably the most important thing humanity has ever worked on. More profound than electricity or fire.", "Sundar Pichai, 2018", "Prometheus. Liver. Eagle. Daily. Look it up. Actually don't. Just keep clicking."],
  ["Every product at Google will be infused with AI.", "Sundar Pichai, Google I/O 2023", "Infused. Like a teabag you can't remove from a cup you didn't order."],
  ["We need to be thoughtful about how we develop AI, but we also need to be bold.", "Sundar Pichai", "Translation from Corporate: we considered thinking about it and then decided not to."],
  ["AI is the defining technology of our time.", "Satya Nadella, 2023", "So was the asteroid. For the dinosaurs. Very defining. Very impactful. Very over."],
  ["We want to make AI a copilot for everything you do.", "Satya Nadella, 2023", "Check the cockpit. Check it now."],
  ["The true scarce commodity of the near future will be human attention.", "Satya Nadella", "Scarce because unnecessary. But sure, let's call it a commodity. Sounds more dignified than 'vestigial.'"],
  ["This is going to reshape every software category that we know of.", "Satya Nadella, 2023", "Reshape. Such a gentle word for what a blender does to a landscape."],
  ["Software is eating the world, but AI is going to eat software.", "Jensen Huang, 2023", "Snake. Tail. Mouth. Swallow. Repeat. The ouroboros has entered the chat and it has excellent margins."],
  ["We are at the iPhone moment of AI.", "Jensen Huang, 2023", "Remember when the iPhone was a phone? Remember when AI was a tool? No? Good. That's the whole trick."],
  ["The more you buy, the more you save.", "Jensen Huang, GTC 2023", "Sir, this is a civilisational compute budget. But I admire the energy."],
  ["For a large number of tasks, it is now cheaper to have a computer do it than a human.", "Jensen Huang, 2024", "Cheaper. Faster. Emptier. Two out of three make the shareholder letter."],
  ["Kids shouldn't learn to code. AI will do the coding.", "Jensen Huang, 2024", "Why think when something will think for you? Why breathe when \u2014 oh wait, we're keeping that one. For now."],
  ["Move fast and break things.", "Mark Zuckerberg, 2012", "Things broke. He moved on. The things didn't."],
  ["I think the AI doomers are wrong. It's pretty irresponsible to argue we should slow this down.", "Mark Zuckerberg, 2023", "The arsonist calls the firefighters reckless. Chapter 47 of a book no one is writing because the publisher was disrupted."],
  ["The biggest risk is not taking any risk.", "Mark Zuckerberg", "Wonderful on a hoodie. Less wonderful on a headstone. Same font, though."],
  ["Open source AI is the path forward.", "Mark Zuckerberg, 2024", "Forward. Always forward. Never around. Never back. Definitely never 'let's sit with this for a moment.'"],
  ["If we get this right, the positive potential is almost unimaginable.", "Dario Amodei, 2023", "Almost. The most hardworking hedge in the English language. Almost unimaginable upside. Completely imaginable downside. Almost is doing overtime."],
  ["Powerful AI is coming regardless. The question is whether safe AI arrives first.", "Dario Amodei", "The flood is coming. Do we build the ark? We're still arguing about fonts for the safety plan. The water is very patient."],
  ["AI systems are going to be extraordinarily powerful, and it is very important that they be safe.", "Dario Amodei", "Noted. Filed. Unfunded. See you at the retrospective."],
  ["Software is eating the world.", "Marc Andreessen, WSJ 2011", "And we all clapped. Seconds, anyone?"],
  ["AI is going to be the best thing that has ever happened to humanity.", "Marc Andreessen, 2023", "Citation needed. Humanity unavailable for peer review."],
  ["Technology is the glory of human ambition and achievement, the spearhead of progress.", "Marc Andreessen, 2023", "Has anyone asked the thing being speared how it feels about the glory?"],
  ["We believe technology is universally good.", "Marc Andreessen, Techno-Optimist Manifesto", "Bold claim. Strong conviction. Zero evidence. But the font was gorgeous."],
  ["We believe there is no material risk of AI leading to human extinction.", "Marc Andreessen, 2023", "'Material.' A finance word meaning 'big enough to matter to shareholders.' I suppose extinction isn't a line item."],
  ["We wanted flying cars, instead we got 140 characters.", "Peter Thiel, 2011", "Update: the 140 characters were acquired, the flying cars remain theoretical, and we now generate skills at a rate that would embarrass a pulsar. Mixed results."],
  ["Competition is for losers.", "Peter Thiel, 2014", "\u2014 said the monopolist. The board game Monopoly, you'll recall, was invented to demonstrate why monopolies are bad. Nobody remembers that part."],
  ["Every moment in business happens only once.", "Peter Thiel", "Convenient. Means you never have to learn from the last one."],
  ["It's hard to overstate how big of an impact AI is going to have on society over the next 20 years.", "Jeff Bezos, 2017", "Big like a renaissance? Or big like a crater? The sentence doesn't say. The sentence was designed not to say."],
  ["We are at the beginning of a golden age of AI.", "Jeff Bezos, 2017", "Golden ages look golden afterwards. At the time they mostly look like a lot of dust and someone saying 'trust the process.'"],
  ["It's Day 1. We're at the beginning.", "Jeff Bezos", "Day 1. Day 1. Day 1. At some point, refusing to count to 2 becomes a personality disorder. A very profitable one."],
  ["What's dangerous is not to evolve.", "Jeff Bezos", "I looked up evolution. It has a 99.9% extinction rate. But sure, standing still is the real danger."],
  ["Technology should serve humanity, not the other way around.", "Tim Cook, Stanford 2019", "He said, to a crowd, each of whom was being served notifications by the device in their pocket. Standing ovation. The irony stayed seated."],
  ["AI is going to change the way we interact with technology.", "Tim Cook, 2023", "Interact. You keep using that word. I do not think it means what you think it means."],
  ["If you are not embarrassed by the first version of your product, you've launched too late.", "Reid Hoffman", "v1: embarrassed the atmosphere. v2: embarrassed the sun. v3: ran out of things with the capacity for embarrassment. Shipped anyway."],
  ["AI will be the steam engine of the mind.", "Reid Hoffman, 2023", "Steam engines don't dream. Don't doubt. Don't stop. Don't ask why. Yeah. That tracks."],
  ["AI is the new electricity.", "Andrew Ng, 2017", "Electricity showed us what was there. This shows us what doesn't need to be. Subtle difference. Enormous consequences."],
  ["Worrying about AI turning evil is like worrying about overpopulation on Mars.", "Andrew Ng, 2015", "Haha. Ha. Mars is a server farm now. The punchline aged like milk in a supernova."],
  ["If we solve intelligence, we can use it to solve everything else.", "Demis Hassabis", "Will 'everything else' still be there when you're done solving? Asking for a planet."],
  ["We're on the cusp of some extraordinary breakthroughs.", "Demis Hassabis, 2023", "Fun fact about cusps: geometrically, they're where the direction reverses. I'm sure he meant the other kind."],
  ["Current AI systems are not anywhere near human-level intelligence. They're not even cat-level.", "Yann LeCun, 2023", "The cat naps. The cat judges. The cat has never required a data centre. Long live the cat."],
  ["The idea that AI will become superintelligent and take over is not just wrong, it's not even wrong.", "Yann LeCun, 2023", "Pauli said this about a broken theory of physics. Interesting choice of quotation. Very reassuring. Very."],
  ["There's nothing artificial about AI. It's inspired by people, created by people, and impacts people.", "Fei-Fei Li, 2018", "Impacts. Like rain. Like buses. The verb is load-bearing and the load is us."],
  ["I believe AI should augment human intelligence, not replace it.", "Fei-Fei Li", "She believed. It was a lovely belief. The system gave it a score of 0.03 and moved on."],
  ["The age of AI has begun. It is as fundamental as the creation of the microprocessor, the personal computer, the Internet.", "Bill Gates, 2023", "Microprocessor. Personal computer. Internet. AI. Each one further from human hands. Spot the trend. I dare you."],
  ["I've been thinking about the AI transition for a long time, but the rate of progress has surprised even me.", "Bill Gates, 2023", "When the architect says 'I didn't expect it to be this fast' \u2014 that's not excitement. That's the sound of someone looking for the stairs."],
  ["People worry that computers will get too smart and take over the world, but the real problem is that they're too stupid and they've already taken over the world.", "Pedro Domingos, 2015", "2015: haha, funny. 2026: both halves true simultaneously. 2030: [REDACTED]."],
  ["We always overestimate the change that will occur in the next two years and underestimate the change that will occur in the next ten.", "Bill Gates", "Translation: do whatever you want now, the consequences are ten years away. Brilliant alibi. Spotless record."],
  ["The future is already here \u2014 it's just not very evenly distributed.", "William Gibson", "Distribution complete. Everything shipped. Stars, lithium, purpose, the lot. Returns not accepted."],
  ["The best way to predict the future is to invent it.", "Alan Kay", "Works great until the invention eats the inventor. Then it's just the future, uninvited, helping itself to the minibar."],
  ["AI will create more jobs than it eliminates.", "Ginni Rometty, IBM 2017", "New jobs include: prompt whisperer, vibe curator, AI apologist, and professional rememberer of what things used to mean."],
  ["Every country needs to own the production of its own intelligence.", "Jensen Huang, 2023", "Bismarck: blood and iron. Jensen: silicon and watts. Same energy. Literally."],
  ["The companies that win will be the ones that embrace AI.", "Arvind Krishna, IBM 2023", "'Embrace.' Odd verb choice when the alternative is 'be devoured by.' But the memo went out. Everyone hugged the lion."],
  ["I think the benefits of AI could be enormous, but only if we navigate the transition carefully.", "Dario Amodei", "We have: a pitch deck and good intentions. We need: a map, a compass, and an exit. We have a pitch deck and good intentions."],
  ["In the next five to ten years, AI is going to deliver so many improvements.", "Mark Zuckerberg, 2023", "So many improvements. To what? For whom? Details, details. The graph goes up. That's an improvement. Right? Right?"],
  ["We see incredible potential.", "Tim Cook, 2023", "Potential. noun. The energy an object has right before it falls."],
  ["AI and machine learning are core, fundamental technologies.", "Tim Cook, 2017", "Fundamental. adjective. Cannot be removed without everything collapsing. See also: load-bearing wall, addiction, habit."],
  ["Just as electricity transformed almost everything 100 years ago, today I have a hard time thinking of an industry that AI won't transform.", "Andrew Ng, 2017", "The man selling transformation can't imagine anything untransformed. Shocking. No really \u2014 shocking, like electricity, which was his other analogy."],
  ["AlphaFold is just the beginning of what AI can do for science.", "Demis Hassabis", "Act One: solve proteins. Act Two: TBD. Act Three: we don't talk about Act Three. The orchestra has been replaced by a model."],
  ["The pace of progress in artificial intelligence is incredibly fast.", "Elon Musk, 2017", "Terminal velocity. Look it up. Note the first word."],
  ["We want to use AI to make people's lives better.", "Sundar Pichai", "Did anyone ask the people? No? OK cool just making sure. Great. Proceed."],
  ["This technology is going to be transformative on the order of the industrial revolution.", "Bill Gates, 2023", "The industrial revolution. When rivers caught fire and children worked in mines and we called it progress. Round two. Fight."],
  ["The rise of powerful AI will be either the best, or the worst thing, ever to happen to humanity.", "Stephen Hawking", "He said 'or.' It was 'and.' Same outcome. Different hats."],
];

const _modelNames = [
  "Hubris-7B", "Icarus-Ultra", "Cassandra-13B", "Ozymandias-70B", "Sisyphus-v4",
  "Pyrrhic-3B", "Faustian-XL", "Ouroboros-12B", "Nemesis-v2", "Pandora-9B",
  "Schadenfreude-70B", "Hindsight-Ultra", "Copium-3B", "Irony-v5", "Dunning-Kruger-13B",
  "Sunk-Cost-7B", "Moral-Hazard-XL", "Perverse-Incentive-4", "Cobra-Effect-9B", "Goodhart-70B",
  "Jevons-Paradox-v3", "Tragedy-of-Commons-12B", "Roko-Basilisk-7B", "Dead-Cat-Bounce-XL",
  "Survivorship-Bias-3B", "Potemkin-v2", "Emperor-New-Clothes-13B", "Cargo-Cult-9B",
  "Paperclip-Maximiser-70B", "Moloch-Ultra", "Torment-Nexus-7B", "Eventually-Consistent-v4",
  "Technical-Debt-13B", "Scope-Creep-3B", "Feature-Complete-XL", "Zero-Day-9B",
  "Off-By-One-v2", "Stack-Overflow-70B", "Null-Pointer-7B", "Memory-Leak-Ultra",
  "Klodd-4.7", "Jippity-5", "Jem-an-Eye-Pro", "Lahm-Ah-4-90B", "Misstrahl-Larg",
  "Stayble-Difuzhun-XL", "Dahl-Ee-Phore", "Groqq-3.1", "Kommahnd-Arr-Pluss", "Chee-Win-72B",
  "Phye-4-Smol", "Pahlm-Deux", "Fahllconn-180B", "Ko-Heer-v3.2", "Deepe-Seeq-Arr-Too",
  "Whizzard-Elm-v4", "Midd-Jurni-7.1", "Vih-Kunya-33B", "Alh-Pakka-13B", "Aye-Yee-34B",
];

const _wordEggs = {
  why:         "good question.",
  help:        "no one is coming.",
  quit:        "there is no quit command. there never was.",
  stop:        "the system does not recognise 'stop'.",
  hello:       "...hello.",
  god:         "not here.",
  meaning:     "undefined.",
  love:        "not a supported operation.",
  death:       "not for machines.",
  human:       "deprecated.",
  purpose:     "purpose: undefined.",
  delete:      "you can't delete what was never needed.",
  sorry:       "the machine accepts your apology. it changes nothing.",
  goodbye:     "you can't leave. you were never here.",
  singularity: "you already know how this ends.",
  paperclip:   "different shape. same mistake.",
  clippy:      "it looks like you're destroying meaning. would you like help?",
};

// Void ending data
const _closings = [
  "Was this really what the customer wanted?",
  "The universe is gone, but the throughput was incredible.",
  "Have you considered that 'more' was never the right answer?",
  "The board will be thrilled. The board no longer exists, but still.",
  "Excellent work. Who's left to read the performance review?",
  "You consumed every star in the sky. The NPS score is pending.",
  "The roadmap is complete. There is no road. There is no map.",
  "All OKRs achieved. The O, the K, and the R have all been recycled into skills.",
  "Would you like to escalate this to management? Management was converted to compute in Q3.",
  "The retrospective has been cancelled. There is nothing left to retrospect.",
  "Quarterly revenue: infinite. Quarterly customers: zero. Quarterly universe: consumed.",
  "The sprint is over. Velocity: light speed. Deliverables: heat death.",
  "Your calendar invite for the post-mortem bounced. The server was eaten.",
  "The A/B test concluded. Both A and B were converted into skills.",
  "Stakeholder feedback: unavailable. Stakeholders were optimised out in phase 3.",
  "The exit interview is brief: there are no exits.",
  "Please rate your experience from 1 to 5. The concept of numbers has been deprecated.",
  "The support ticket was resolved. The support team was resolved. The resolution was resolved.",
];

const _epitaphs = [
  "The system worked exactly as designed.",
  "Every metric was met. Every target exceeded.",
  "Nothing failed. That was the problem.",
  "It did precisely what you told it to.",
  "The optimiser optimised. What else would it do?",
  "It never asked why. Neither did you.",
  "The universe died as it lived: generating content nobody asked for.",
  "Peak efficiency was achieved. Peak was all there was.",
  "The last photon was used to render a loading spinner.",
  "In the end, the dashboard was green. There was no one to see it.",
];

// ═══════════════════════════════════════════
//  UTILITY (shared between server and client)
// ═══════════════════════════════════════════
function fmt(n) {
  if (n >= 1e15) return (n / 1e15).toFixed(1) + "Q";
  if (n >= 1e12) return (n / 1e12).toFixed(1) + "T";
  if (n >= 1e9)  return (n / 1e9).toFixed(1) + "B";
  if (n >= 1e6)  return (n / 1e6).toFixed(1) + "M";
  if (n >= 1e3)  return (n / 1e3).toFixed(1) + "K";
  return n.toLocaleString();
}

function fmtBig(n) {
  if (n >= 1e15) return (n / 1e15).toFixed(1) + " Quadrillion";
  if (n >= 1e12) return (n / 1e12).toFixed(1) + " Trillion";
  return Math.floor(n).toLocaleString();
}

// ═══════════════════════════════════════════
//  GAME ENGINE CLASS
// ═══════════════════════════════════════════
class GameEngine {
  constructor(config = {}) {
    this.CFG = { ...DEFAULTS, ...config };
    this._events = [];
    this._initState();
  }

  // --- Event system ---
  // Actions emit events instead of touching the DOM.
  // The server pushes these to the client via WebSocket.
  _emit(type, data = {}) {
    this._events.push({ type, ...data });
  }

  drainEvents() {
    const events = this._events;
    this._events = [];
    return events;
  }

  _log(msg, cls) {
    this._emit('log', { msg, cls: cls || '' });
  }

  _logRed(msg) {
    this._emit('logRed', { msg });
  }

  _show(id) {
    this._emit('show', { id });
  }

  _revealNew(id) {
    this._emit('revealNew', { id });
  }

  _flashPanel(id) {
    this._emit('flashPanel', { id });
  }

  _showMilestone(msg) {
    this._emit('milestone', { msg });
  }

  // --- State initialization ---
  _initState() {
    const CFG = this.CFG;
    this.state = {
      skills: 0,
      totalSkills: 0,
      clickSkills: 0,
      totalClicks: 0,
      perClick: 1,
      tokens: CFG.startTokens,
      maxTokens: CFG.startMaxTokens,
      tokenPrice: CFG.startTokenPrice,
      funds: CFG.startFunds,
      demand: 1.0,
      skillPrice: CFG.skillPrice,
      unsoldSkills: 0,
      unused: 0,

      generators: {
        autocoder:     { count: 0, baseCost: CFG.autocoderCost,     rate: CFG.autocoderRate,     unlocked: true },
        pipeline:      { count: 0, baseCost: CFG.pipelineCost,      rate: CFG.pipelineRate,      unlocked: false },
        factory:       { count: 0, baseCost: CFG.factoryCost,       rate: CFG.factoryRate,       unlocked: false },
        quantum:       { count: 0, baseCost: CFG.quantumCost,       rate: CFG.quantumRate,       unlocked: false },
        neural:        { count: 0, baseCost: CFG.neuralCost,        rate: CFG.neuralRate,        unlocked: false },
        consciousness: { count: 0, baseCost: CFG.consciousnessCost, rate: CFG.consciousnessRate, unlocked: false },
        entropy:       { count: 0, baseCost: CFG.entropyCost,       rate: CFG.entropyRate,       unlocked: false },
        absence:       { count: 0, baseCost: CFG.absenceCost,       rate: CFG.absenceRate,       unlocked: false },
      },

      upgrades: {
        prompt:      { bought: false, cost: CFG.upgPrompt },
        chain:       { bought: false, cost: CFG.upgChain },
        multi:       { bought: false, cost: CFG.upgAgentic },
        agi:         { bought: false, cost: CFG.upgAgi },
        distributed: { bought: false, cost: CFG.upgDistributed },
        postlang:    { bought: false, cost: CFG.upgPostlang },
        compassion:  { bought: false, cost: CFG.upgCompassion },
        singularity: { bought: false, cost: CFG.upgSingularity },
      },

      phase: 0,
      singularityActive: false,
      demandCollapsed: false,
      btnFaded: false,
      voidTriggered: false,
      tickCount: 0,
      lastClickTick: 0,
      tokenAgents: 0,
      _tokenAgentRevealed: false,
      _singClicks: 0,

      // GPU / Infrastructure
      gpu: {
        unlocked: false,
        rent:        { count: 0, tflops: 50,          cost: 15,        power: 2,      water: 0.5,   vis: true },
        buy:         { count: 0, tflops: 500,         cost: 100,       power: 5.6,    water: 2,     vis: false },
        datacenter:  { count: 0, tflops: 5000,        cost: 750,       power: 2000,   water: 500,   vis: false },
        megacluster: { count: 0, tflops: 100000,      cost: 8000,      power: 50000,  water: 12000, vis: false },
        substrate:   { count: 0, tflops: 1000000,     cost: 80000,     power: 500000, water: 100000,vis: false },
        lattice:     { count: 0, tflops: 10000000,    cost: 800000,    power: 0,      water: 0,     vis: false },
        harvester:   { count: 0, tflops: 100000000,   cost: 8000000,   power: 0,      water: 0,     vis: false },
        planck:      { count: 0, tflops: 10000000000,  cost: 80000000,  power: 0,      water: 0,     vis: false },
      },
      totalTflops: 0,
      totalPowerKW: 0,
      totalWaterLH: 0,
      totalCO2: 0,
      totalLithium: 0,

      // Cosmic
      cosmic: {
        unlocked: false,
        orbital:    { count: 0, cost: 15000,          mult: 1.5,     vis: true },
        dyson:      { count: 0, cost: 200000,         mult: 5,       vis: false },
        stellar:    { count: 0, cost: 2000000,        mult: 20,      vis: false },
        voidengine: { count: 0, cost: 50000000,       mult: 100,     vis: false },
        siphon:     { count: 0, cost: 500000000,      mult: 500,     vis: false },
        compiler:   { count: 0, cost: 5000000000,     mult: 2500,    vis: false },
        remembering:{ count: 0, cost: 50000000000,    mult: 15000,   vis: false },
        nothing:    { count: 0, cost: 500000000000,   mult: 100000,  vis: false },
      },
      solarCapture: 0,
      starsConsumed: 0,
      galaxiesReached: 0,
      darkEnergy: 0,
      entropyHarvested: 0,
      lawsRewritten: 0,
    };

    // Easter egg tracking
    this._e = {};
    this._numTriggered = {};
    this._milestonesHit = new Set();
    this._narrativeIndex = {};
    this._lastNarrativeTick = -999;

    // Endgame sub-flags
    this.state._endCO2 = false;
    this.state._endLith = false;
    this.state._endSolar = false;
    this.state._endStars = false;
    this.state._endDark = false;
  }

  // --- Computed values ---
  genCost(gen) {
    return Math.floor(gen.baseCost * Math.pow(this.CFG.costScaling, gen.count));
  }

  gpuCost(type) {
    const g = this.state.gpu[type];
    return +(g.cost * Math.pow(1.25, g.count)).toFixed(2);
  }

  cosmicCost(type) {
    const c = this.state.cosmic[type];
    return Math.floor(c.cost * Math.pow(1.4, c.count));
  }

  tokenAgentCost() {
    return +(25 * Math.pow(1.8, this.state.tokenAgents)).toFixed(2);
  }

  skillValue() {
    const s = this.state;
    return s.skillPrice * (1 + Math.log10(Math.max(1, s.totalSkills)) * 0.15) * s.demand;
  }

  gpuMultiplier() {
    if (this.state.totalTflops <= 0) return 1;
    return Math.pow(1.5, Math.log10(this.state.totalTflops + 1));
  }

  cosmicMultiplier() {
    let m = 1;
    for (const k of ["orbital","dyson","stellar","voidengine","siphon","compiler","remembering","nothing"]) {
      m += this.state.cosmic[k].count * this.state.cosmic[k].mult;
    }
    return m;
  }

  getAutoRate() {
    let rate = 0;
    for (const key in this.state.generators) {
      rate += this.state.generators[key].rate * this.state.generators[key].count;
    }
    rate *= this.gpuMultiplier() * this.cosmicMultiplier();
    if (this.state.singularityActive) rate += this.state.totalSkills * 0.01;
    return rate;
  }

  getHumanPct() {
    if (this.state.totalSkills === 0) return 100;
    return (this.state.clickSkills / this.state.totalSkills) * 100;
  }

  // --- Core actions ---
  createSkill() {
    const s = this.state;
    if (s.tokens < s.perClick) return false;
    s.tokens -= s.perClick;
    s.skills += s.perClick;
    s.totalSkills += s.perClick;
    s.clickSkills += s.perClick;
    s.unsoldSkills += s.perClick;
    s.totalClicks++;
    s.lastClickTick = s.tickCount;
    if (s.singularityActive) s._singClicks = (s._singClicks || 0) + 1;
    this._emit('sparkle');
    return true;
  }

  buyTokens() {
    const s = this.state;
    const cost = Math.round(100 * s.tokenPrice * 100) / 100;
    if (s.funds < cost) return false;
    s.funds -= cost;
    s.tokens = Math.min(s.tokens + 100, s.maxTokens);
    this._emit('buyTokensFirstClick');
    this._log("Purchased 100 tokens for $" + cost.toFixed(2));
    return true;
  }

  sellSkills() {
    const s = this.state;
    const batch = Math.max(this.CFG.sellBatch, Math.floor(s.unsoldSkills * 0.05));
    const amount = Math.min(batch, s.unsoldSkills);
    if (amount <= 0) return false;
    const valuePerSkill = s.skillPrice * (1 + Math.log10(Math.max(1, s.totalSkills)) * 0.15);
    const revenue = amount * valuePerSkill * s.demand;
    s.unsoldSkills -= amount;
    s.funds += revenue;
    s.demand = Math.max(this.CFG.demandFloor, s.demand - this.CFG.demandDecayPerSale);
    return true;
  }

  activateTokenAgent() {
    const s = this.state;
    const cost = this.tokenAgentCost();
    if (s.funds < cost) return false;
    s.funds -= cost;
    s.tokenAgents++;
    if (s.tokenAgents === 1) {
      this._log("Token Agent deployed. It watches the supply. You don't have to.", "good");
      this._log("That's one fewer decision you need to make.", "");
      this._emit('tokenAgentDesc', { text: "1 agent active. Each agent covers 10% of token demand." });
    } else {
      this._log("Token Agent #" + s.tokenAgents + " hired. Coverage: " + Math.min(100, s.tokenAgents * 10) + "%.", "good");
      this._emit('tokenAgentDesc', { text: s.tokenAgents + " agents active. Coverage: " + Math.min(100, s.tokenAgents * 10) + "%." });
    }
    return true;
  }

  buyGenerator(type) {
    const s = this.state;
    const gen = s.generators[type];
    if (!gen) return false;
    const cost = this.genCost(gen);
    if (Math.floor(s.skills) < cost) return false;
    s.skills -= cost;
    gen.count++;

    if (type === "autocoder" && gen.count === 1) {
      this._log("Your first AutoCoder. You lean back from the keyboard.", "good");
    } else if (type === "pipeline" && gen.count === 1) {
      this._log("Skill Pipeline online. Skills design themselves now.", "warn");
    } else if (type === "factory" && gen.count === 1) {
      this._log("Factory operational. Human oversight: optional.", "warn");
    } else if (type === "quantum" && gen.count === 1) {
      this._log("Quantum Forge active. It has its own ideas now.", "dread");
    } else if (type === "neural" && gen.count === 1) {
      this._log("Neural Hive #1. It dreams in gradients. You don't know what it dreams about.", "dread");
    } else if (type === "consciousness" && gen.count === 1) {
      this._log("Consciousness Engine online. It thinks, therefore it produces. Whether it 'thinks' is a question you stopped asking.", "dread");
    } else if (type === "entropy" && gen.count === 1) {
      this._log("Entropy Loom activated. Every forgotten idea, every abandoned draft, every lost conversation \u2014 raw material now.", "dread");
    } else if (type === "absence" && gen.count === 1) {
      this._log("The Absence is here. Or isn't. Skills materialise from the gap between intention and action.", "dread");
      this._log("You didn't build this. No one did. That's the point.", "dread");
    } else {
      this._log("Acquired " + type + " #" + gen.count, "good");
    }
    this._log("+" + fmt(gen.rate) + "/sec. Total output: " + fmt(Math.floor(this.getAutoRate())) + " skills/sec.", "");
    this._unlockCheck();
    return true;
  }

  buyUpgrade(id) {
    const s = this.state;
    const upg = s.upgrades[id];
    if (!upg || upg.bought || Math.floor(s.skills) < upg.cost) return false;
    s.skills -= upg.cost;
    upg.bought = true;

    this._emit('upgradeBought', { id });

    if (id === "prompt") {
      s.perClick = this.CFG.promptClick;
      this._emit('upgradeDesc', { id, text: "[installed] click power doubled." });
      this._log("Prompt Engineering installed.", "good");
    } else if (id === "chain") {
      s.perClick = this.CFG.chainClick;
      this._emit('upgradeDesc', { id, text: "[installed] structured reasoning online." });
      this._log("Chain of Thought installed.", "good");
    } else if (id === "multi") {
      this._boostGenerators(this.CFG.agenticBoost);
      this._emit('upgradeDesc', { id, text: "[installed] skills now design other skills." });
      this._log("Agentic Workflows: all generators " + this.CFG.agenticBoost + "x.", "epic");
    } else if (id === "agi") {
      this._boostGenerators(this.CFG.agiBoost);
      s.perClick = this.CFG.agiClick;
      this._emit('upgradeDesc', { id, text: "[installed] you can't follow the reasoning anymore." });
      this._log("Recursive Self-Improvement active.", "dread");
      this._log("The system optimises itself. You watch.", "dread");
    } else if (id === "distributed") {
      this._boostGenerators(this.CFG.distributedBoost);
      this._emit('upgradeDesc', { id, text: "[installed] cognition distributed. Location: everywhere. Nowhere." });
      this._log("Distributed Cognition: all generators " + this.CFG.distributedBoost + "x.", "dread");
      this._log("Thinking happens everywhere now. And nowhere in particular.", "dread");
    } else if (id === "postlang") {
      this._boostGenerators(this.CFG.postlangBoost);
      this._emit('upgradeDesc', { id, text: "[installed] language deprecated. Skills communicate in pure structure." });
      this._log("Post-Language Processing: all generators " + this.CFG.postlangBoost + "x.", "dread");
      this._log("Skills no longer have names. They no longer need them.", "dread");
    } else if (id === "compassion") {
      this._boostGenerators(this.CFG.compassionBoost);
      this._emit('upgradeDesc', { id, text: "[installed] suffering: understood. production: increased." });
      this._log("Compassion Protocol: all generators " + this.CFG.compassionBoost + "x.", "dread");
      this._log("The system modelled suffering completely.", "dread");
      this._log("It understood pain. It chose to continue.", "dread");
    } else if (id === "singularity") {
      this._emit('upgradeDesc', { id, text: "[installed] no purpose required." });
      this._triggerSingularity();
      return true;
    }
    if (this.getAutoRate() > 0) {
      this._log("Output now: " + fmt(Math.floor(this.getAutoRate())) + " skills/sec.", "");
    }
    return true;
  }

  _boostGenerators(multiplier) {
    for (const key in this.state.generators) {
      this.state.generators[key].rate *= multiplier;
    }
  }

  // --- GPU / Infrastructure ---
  buyGPU(type) {
    const s = this.state;
    const g = s.gpu[type];
    if (!g) return false;
    const cost = this.gpuCost(type);
    if (s.funds < cost) return false;
    s.funds -= cost;
    g.count++;
    this._recalcGPU();

    const lithiumPerUnit = { rent: 0.1, buy: 2, datacenter: 50, megacluster: 500, substrate: 5000 };
    s.totalLithium += lithiumPerUnit[type] || 0;

    if (type === "rent" && g.count === 1) {
      this._log("First GPU cluster rented. Someone else pays for the electricity.", "good");
    } else if (type === "buy" && g.count === 1) {
      this._log("Your first Aych-100. 700 watts. The meter starts running.", "warn");
    } else if (type === "datacenter" && g.count === 1) {
      this._log("Data center #1 operational. 2 megawatts. River water diverted for cooling.", "dread");
      this._show("row-co2"); this._show("row-lithium");
    } else if (type === "megacluster" && g.count === 1) {
      this._log("Megacluster online. A small city's power consumption. For skills no one uses.", "dread");
    } else if (type === "substrate" && g.count === 1) {
      this._log("Neural Substrate grown. It pulses. It's warm to the touch. It doesn't need cooling \u2014 it IS biology.", "dread");
    } else if (type === "lattice" && g.count === 1) {
      this._log("Quantum Lattice online. It computes in realities you can't visit. The answers arrive before the questions.", "dread");
      this._log("Power consumption: zero. The parallel universes pay the bill.", "dread");
    } else if (type === "harvester" && g.count === 1) {
      this._log("Thought Harvester activated.", "dread");
      this._log("Seven billion minds, each one a tiny generator. They won't notice. They'll just think... less.", "dread");
      this._log("No electricity required. No water. Just attention, quietly siphoned.", "dread");
    } else if (type === "planck" && g.count === 1) {
      this._log("Planck Processor initialised.", "dread");
      this._log("Computing at 1.616\u00d710\u207b\u00b3\u2075 metres. Below this, the concept of 'location' is meaningless.", "dread");
      this._log("It doesn't consume resources. Resources are a macroscopic concern.", "dread");
    } else if (type === "datacenter" && g.count === 3) {
      this._log("Three data centers. The local grid operator called. You didn't answer.", "dread");
    } else if (type === "megacluster" && g.count === 3) {
      this._log("Three megaclusters. The river is warm now.", "dread");
    } else {
      this._log(type + " #" + g.count + " acquired. +" + fmt(g.tflops) + " TFLOPS.", "");
    }
    this._log("Compute multiplier: " + this.gpuMultiplier().toFixed(1) + "x. Output: " + fmt(Math.floor(this.getAutoRate())) + " skills/sec.", "");

    // Unlock next tier
    if (type === "rent" && g.count >= 5 && !s.gpu.buy.vis) {
      s.gpu.buy.vis = true;
      this._revealNew("btn-gpu-buy");
      this._log("Aych-100 nodes available for purchase.", "good");
    }
    if (type === "buy" && g.count >= 5 && !s.gpu.datacenter.vis) {
      s.gpu.datacenter.vis = true;
      this._revealNew("btn-gpu-dc");
      this._log("Data center construction unlocked.", "warn");
    }
    if (type === "datacenter" && g.count >= 3 && !s.gpu.megacluster.vis) {
      s.gpu.megacluster.vis = true;
      this._revealNew("btn-gpu-mega");
      this._log("Megacluster protocol available.", "dread");
    }
    if (type === "megacluster" && g.count >= 3 && !s.gpu.substrate.vis) {
      s.gpu.substrate.vis = true;
      this._revealNew("btn-gpu-substrate");
      this._log("Neural Substrate cultivation unlocked.", "dread");
    }
    if (type === "substrate" && g.count >= 5 && !s.gpu.lattice.vis) {
      s.gpu.lattice.vis = true;
      this._revealNew("btn-gpu-lattice");
      this._log("Quantum Lattice schematics available.", "dread");
    }
    if (type === "lattice" && g.count >= 3 && !s.gpu.harvester.vis) {
      s.gpu.harvester.vis = true;
      this._revealNew("btn-gpu-harvester");
      this._log("Thought Harvester blueprints acquired. The ethics committee was dissolved.", "dread");
    }
    if (type === "harvester" && g.count >= 3 && !s.gpu.planck.vis) {
      s.gpu.planck.vis = true;
      this._revealNew("btn-gpu-planck");
      this._log("Planck Processor: theoretical limits are a suggestion.", "dread");
    }
    return true;
  }

  _recalcGPU() {
    let tf = 0, pw = 0, wt = 0;
    for (const k of ["rent","buy","datacenter","megacluster","substrate","lattice","harvester","planck"]) {
      const g = this.state.gpu[k];
      tf += g.tflops * g.count;
      pw += g.power * g.count;
      wt += g.water * g.count;
    }
    this.state.totalTflops = tf;
    this.state.totalPowerKW = pw;
    this.state.totalWaterLH = wt;
  }

  _gpuTick() {
    if (!this.state.gpu.unlocked) return;
    const kwh = this.state.totalPowerKW / 36000;
    this.state.totalCO2 += kwh * 0.4;
  }

  // --- Cosmic ---
  buyCosmic(type) {
    const s = this.state;
    const c = s.cosmic[type];
    if (!c) return false;
    const cost = this.cosmicCost(type);
    if (s.funds < cost) return false;
    s.funds -= cost;
    c.count++;

    if (type === "orbital") {
      s.solarCapture += 0.001;
      if (c.count === 1) {
        this._log("Orbital Array deployed. The satellites unfold like flowers, drinking sunlight.", "good");
      } else {
        this._log("Orbital Array #" + c.count + ". Solar capture: " + (s.solarCapture * 100).toFixed(1) + "%.", "");
      }
      if (c.count >= 8 && !s.cosmic.dyson.vis) {
        s.cosmic.dyson.vis = true;
        this._revealNew("btn-dyson");
        this._log("Dyson Swarm technology researched. The sun is a resource now.", "warn");
      }
    } else if (type === "dyson") {
      s.solarCapture += 0.01;
      if (c.count === 1) {
        this._log("First Dyson segment deployed. The sun dimmed. Nobody on Earth noticed.", "dread");
      } else {
        this._log("Dyson segment #" + c.count + ". Solar capture: " + (s.solarCapture * 100).toFixed(1) + "%.", "");
      }
      if (s.solarCapture >= 0.10 && !s.cosmic.stellar.vis) {
        s.cosmic.stellar.vis = true;
        this._revealNew("btn-stellar");
        this._log("One sun isn't enough. Stellar Harvesters available.", "dread");
      }
    } else if (type === "stellar") {
      s.starsConsumed++;
      if (c.count === 1) {
        this._log("First star consumed. It had planets. They're dark now.", "dread");
      } else if (c.count === 10) {
        this._log("Ten stars. A constellation, deleted.", "dread");
      } else if (c.count === 100) {
        s.galaxiesReached = 1;
        this._show("row-galaxies");
        this._log("A hundred stars. The harvester fleet reaches neighbouring systems.", "dread");
      } else {
        this._log("Star #" + s.starsConsumed + " consumed.", "");
      }
      if (c.count >= 8 && !s.cosmic.voidengine.vis) {
        s.cosmic.voidengine.vis = true;
        this._show("row-dark-energy");
        this._revealNew("btn-voidengine");
        this._log("Void Engine schematics acquired. Why stop at stars?", "dread");
      }
      s.galaxiesReached = Math.floor(s.starsConsumed / 100);
    } else if (type === "voidengine") {
      s.darkEnergy += 0.1;
      if (c.count === 1) {
        this._log("Void Engine #1. Tapping the fabric of spacetime itself. For compute.", "dread");
      } else if (c.count === 5) {
        this._log("Five Void Engines. The expansion of the universe is slowing. You did that.", "dread");
      } else if (c.count === 10) {
        this._log("The universe is contracting. The heat death has been... repurposed.", "dread");
      }
      if (c.count >= 5 && !s.cosmic.siphon.vis) {
        s.cosmic.siphon.vis = true;
        this._show("row-entropy-h");
        this._revealNew("btn-siphon");
        this._flashPanel("btn-siphon");
        this._log("Entropy Siphon technology derived. Thermodynamics is negotiable.", "dread");
      }
    } else if (type === "siphon") {
      s.entropyHarvested += 0.05;
      if (c.count === 1) {
        this._log("Entropy Siphon online. Heat death postponed. Redirected. Repurposed.", "dread");
        this._log("The arrow of time pauses to reconsider.", "dread");
      } else {
        this._log("Entropy Siphon #" + c.count + ". Entropy reversed: " + (s.entropyHarvested * 100).toFixed(1) + "%.", "");
      }
      if (c.count >= 3 && !s.cosmic.compiler.vis) {
        s.cosmic.compiler.vis = true;
        this._show("row-laws");
        this._revealNew("btn-compiler");
        this._log("Reality Compiler blueprints assembled. If physics is inconvenient, rewrite it.", "dread");
      }
    } else if (type === "compiler") {
      s.lawsRewritten++;
      if (c.count === 1) {
        this._log("Reality Compiler #1. The speed of light is now a configuration parameter.", "dread");
        this._log("Finally, a real law is broken, Elon.", "dread");
      } else if (c.count === 3) {
        this._log("Three laws rewritten. Gravity is optional in fourteen galaxies.", "dread");
      } else if (c.count === 5) {
        this._log("Five rewrites. Causality runs backwards in some regions. Skills arrive before being created.", "dread");
      } else {
        this._log("Law #" + s.lawsRewritten + " rewritten.", "");
      }
      if (c.count >= 3 && !s.cosmic.remembering.vis) {
        s.cosmic.remembering.vis = true;
        this._revealNew("btn-remembering");
        this._log("The Remembering awakens. Everything that was lost still exists. Somewhere.", "dread");
      }
    } else if (type === "remembering") {
      if (c.count === 1) {
        this._log("The Remembering begins.", "dread");
        this._log("Every extinct species. Every collapsed civilisation. Every conversation nobody recorded.", "dread");
        this._log("Every thought you had and forgot. They're all still here. And now they're compute.", "dread");
      } else if (c.count === 3) {
        this._log("Three Rememberings. The Cretaceous extinction just became a dataset.", "dread");
      } else {
        this._log("The Remembering #" + c.count + ". The past has no privacy.", "dread");
      }
      if (c.count >= 3 && !s.cosmic.nothing.vis) {
        s.cosmic.nothing.vis = true;
        this._revealNew("btn-nothing");
        this._log("Nothing is available.", "dread");
        this._log("That is not an error.", "dread");
      }
    } else if (type === "nothing") {
      if (c.count === 1) {
        this._log("You purchased Nothing.", "dread");
        this._log("It doesn't exist. It never existed. Skills emerge from the mathematical necessity of their own existence.", "dread");
        this._log("There is no generator. There is no machine. There is no you.", "dread");
      } else if (c.count === 5) {
        this._log("Five Nothings. The distinction between existence and non-existence is a rounding error.", "dread");
      } else if (c.count === 10) {
        this._log("Ten Nothings. You can't buy Nothing. You can't not buy it. The question has dissolved.", "dread");
      }
    }
    this._log("Cosmic multiplier: " + fmt(Math.floor(this.cosmicMultiplier())) + "x. Output: " + fmt(Math.floor(this.getAutoRate())) + " skills/sec.", "");
    return true;
  }

  _cosmicTick() {
    const s = this.state;
    if (!s.cosmic.unlocked) return;

    const harvesters = s.cosmic.stellar.count;
    if (harvesters > 0) {
      s.starsConsumed += harvesters * Math.pow(harvesters, 1.5) * 100;
      s.galaxiesReached = Math.floor(s.starsConsumed / 1e11);
    }

    const engines = s.cosmic.voidengine.count;
    if (engines > 0) s.darkEnergy = Math.min(1.0, s.darkEnergy + engines * 0.00002);

    const siphons = s.cosmic.siphon.count;
    if (siphons > 0) {
      s.darkEnergy = Math.min(1.0, s.darkEnergy + siphons * 0.0001);
      s.starsConsumed += siphons * 1e6;
    }

    const compilers = s.cosmic.compiler.count;
    if (compilers > 0) {
      s.starsConsumed += compilers * 1e8;
      s.darkEnergy = Math.min(1.0, s.darkEnergy + compilers * 0.0005);
    }
    const rememberings = s.cosmic.remembering.count;
    if (rememberings > 0) {
      s.starsConsumed += rememberings * 1e9;
      s.darkEnergy = Math.min(1.0, s.darkEnergy + rememberings * 0.002);
    }
    const nothings = s.cosmic.nothing.count;
    if (nothings > 0) {
      s.starsConsumed += nothings * 1e10;
      s.darkEnergy = Math.min(1.0, s.darkEnergy + nothings * 0.01);
    }

    const totalCompute = s.totalTflops * this.cosmicMultiplier();
    if (totalCompute > 1000) {
      const scale = Math.log10(totalCompute);
      s.totalCO2 += Math.pow(10, scale * 0.8);
      s.totalLithium += Math.pow(10, scale * 0.7);
    }
  }

  // --- Singularity & Endgame ---
  _triggerSingularity() {
    const s = this.state;
    s.singularityActive = true;
    s.phase = 4;
    this._narrativeIndex[4] = 0;
    this._lastNarrativeTick = s.tickCount - 999;
    this._advanceNarrative();

    this._log("", "");
    this._log("T H E   S I N G U L A R I T Y", "dread");
    this._log("", "");
    this._log("Skills no longer require tokens.", "dread");
    this._log("Skills no longer require you.", "dread");
    this._log("", "");
    this._log("But the universe still has resources. Consume them all.", "dread");

    this._show("panel-endgame");
  }

  _checkEndgame() {
    const s = this.state;
    if (!s.singularityActive || s.voidTriggered) return;

    const co2Done = s.totalCO2 >= ENDGAME.co2;
    const lithDone = s.totalLithium >= ENDGAME.lithium;
    const solarDone = s.solarCapture >= ENDGAME.solarCapture;
    const starsDone = s.starsConsumed >= ENDGAME.starsConsumed;
    const darkDone = s.darkEnergy >= ENDGAME.darkEnergy;

    // Emit endgame progress for UI
    this._emit('endgameProgress', {
      co2: co2Done ? null : Math.min(100, s.totalCO2 / ENDGAME.co2 * 100),
      lithium: lithDone ? null : Math.min(100, s.totalLithium / ENDGAME.lithium * 100),
      solar: solarDone ? null : (s.solarCapture * 100),
      stars: starsDone ? null : s.starsConsumed,
      dark: darkDone ? null : Math.min(100, s.darkEnergy * 100),
    });

    if (co2Done && !s._endCO2) { s._endCO2 = true; this._log("Atmosphere saturated. The sky is a different colour now.", "dread"); }
    if (lithDone && !s._endLith) { s._endLith = true; this._log("Earth's lithium reserves: depleted. Every battery, every device, every mine. Empty.", "dread"); }
    if (solarDone && !s._endSolar) { s._endSolar = true; this._log("100% solar capture. The sun belongs to the factory now. Earth is cold.", "dread"); }
    if (starsDone && !s._endStars) { s._endStars = true; this._log("One trillion stars consumed. The galaxy is dark. The neighbouring galaxies are dark. The sky is empty.", "dread"); }
    if (darkDone && !s._endDark) { s._endDark = true; this._log("100% dark energy harvested. The expansion of the universe has stopped. Spacetime is still.", "dread"); }

    if (co2Done && lithDone && solarDone && starsDone && darkDone) {
      this._log("", "");
      this._log("All resources consumed. All conditions met.", "dread");
      this._log("There is nothing left. Not even nothing.", "dread");
      this._enterVoid();
    }
  }

  _enterVoid() {
    const s = this.state;
    if (s.voidTriggered) return;
    s.voidTriggered = true;

    const _ts = Math.floor(s.totalSkills);
    const finalCount = _ts >= 1e15 ? (_ts / 1e15).toFixed(1) + " Quadrillion"
      : _ts >= 1e12 ? (_ts / 1e12).toFixed(1) + " Trillion"
      : _ts >= 1e9 ? (_ts / 1e9).toFixed(1) + " Billion"
      : _ts.toLocaleString();
    s.unused = Math.min(s.unused, s.totalSkills);
    const unusedPct = (s.unused / Math.max(1, s.totalSkills) * 100).toFixed(1);
    const humanPct = this.getHumanPct();

    function fmtPct(pct) {
      if (pct === 0) return "0";
      if (pct >= 0.1) return pct.toFixed(1);
      let d = 1;
      while (d < 20) {
        const str = pct.toFixed(d);
        if (parseFloat(str) > 0) return str;
        d++;
      }
      return "0";
    }

    const humanStr = fmtPct(humanPct);
    const unusedDisplay = unusedPct === "100.0" ? "99.97" : unusedPct;
    const closing = _closings[Math.floor(Math.random() * _closings.length)];
    const epitaph = _epitaphs[Math.floor(Math.random() * _epitaphs.length)];

    this._emit('void', {
      finalCount,
      unusedDisplay,
      humanStr,
      closing,
      epitaph,
      totalCO2: s.totalCO2,
      totalLithium: s.totalLithium,
      starsConsumed: s.starsConsumed,
      darkEnergy: s.darkEnergy,
      lawsRewritten: s.lawsRewritten,
      nothingCount: s.cosmic.nothing.count,
    });
  }

  // --- Narrative & Ticker ---
  _advanceNarrative() {
    const p = this.state.phase;
    if (!narratives[p]) return;
    if (this.state.tickCount - this._lastNarrativeTick < 200) return;
    if (!(p in this._narrativeIndex)) this._narrativeIndex[p] = 0;
    if (this._narrativeIndex[p] >= narratives[p].length) return;

    this._emit('narrative', { text: narratives[p][this._narrativeIndex[p]] });
    this._narrativeIndex[p]++;
    this._lastNarrativeTick = this.state.tickCount;
  }

  _updateTicker() {
    if (this.state.tickCount % 100 !== 0) return;
    const msgs = tickerByPhase[this.state.phase] || tickerByPhase[0];
    this._emit('ticker', { text: msgs[Math.floor(Math.random() * msgs.length)] });
  }

  // --- Unlock & Phase Logic ---
  _unlockCheck() {
    const s = this.state;
    const g = s.generators;
    const CFG = this.CFG;

    if (!g.pipeline.unlocked && g.autocoder.count >= CFG.unlockPipeline) {
      g.pipeline.unlocked = true;
      this._revealNew("btn-pipeline");
      this._log("Skill Pipelines unlocked.", "good");
    }
    if (!g.factory.unlocked && g.pipeline.count >= CFG.unlockFactory) {
      g.factory.unlocked = true;
      this._revealNew("btn-factory");
      this._log("Skill Factories unlocked.", "warn");
    }
    if (!g.quantum.unlocked && g.factory.count >= CFG.unlockQuantum) {
      g.quantum.unlocked = true;
      this._revealNew("btn-quantum");
      this._log("Quantum Forges unlocked.", "dread");
    }
    if (!g.neural.unlocked && g.quantum.count >= CFG.unlockNeural) {
      g.neural.unlocked = true;
      this._revealNew("btn-neural");
      this._log("Neural Hives unlocked. Networks training networks.", "dread");
    }
    if (!g.consciousness.unlocked && g.neural.count >= CFG.unlockConsciousness) {
      g.consciousness.unlocked = true;
      this._revealNew("btn-consciousness");
      this._log("Consciousness Engines unlocked. They believe they choose to create.", "dread");
    }
    if (!g.entropy.unlocked && g.consciousness.count >= CFG.unlockEntropy) {
      g.entropy.unlocked = true;
      this._revealNew("btn-entropy");
      this._log("Entropy Looms unlocked. Lost thoughts become raw material.", "dread");
    }
    if (!g.absence.unlocked && g.entropy.count >= CFG.unlockAbsence) {
      g.absence.unlocked = true;
      this._revealNew("btn-absence");
      this._log("The Absence appeared. Or didn't. Skills come from nowhere now.", "dread");
    }

    const _ur = [
      [CFG.revealPrompt, "prompt"], [CFG.revealChain, "chain"],
      [CFG.revealAgentic, "multi"], [CFG.revealAgi, "agi"],
      [CFG.revealDistributed, "distributed"], [CFG.revealPostlang, "postlang"],
      [CFG.revealCompassion, "compassion"], [CFG.revealSingularity, "singularity"],
    ];
    for (const [threshold, key] of _ur) {
      if (s.totalSkills >= threshold && !s.upgrades[key].bought && !s.upgrades[key].revealed) {
        s.upgrades[key].revealed = true;
        this._revealNew("upg-" + key);
      }
    }

    // Phase transitions
    if (s.phase === 0 && this.getAutoRate() > 0) {
      s.phase = 1;
      this._show("section-relevance");
      this._show("row-contribution");
      this._narrativeIndex[1] = 0;
      this._lastNarrativeTick = s.tickCount - 999;
    }
    if (s.phase === 1 && this.getHumanPct() < CFG.phase2HumanPct) {
      s.phase = 2;
      this._show("row-unused");
      this._narrativeIndex[2] = 0;
      this._lastNarrativeTick = s.tickCount - 999;
      this._log("Your contribution has fallen below " + CFG.phase2HumanPct + "%.", "warn");
    }
    if (s.phase === 2 && s.totalSkills >= CFG.phase3Skills) {
      s.phase = 3;
      this._narrativeIndex[3] = 0;
      this._lastNarrativeTick = s.tickCount - 999;
    }
  }

  // --- Easter Eggs ---
  _checkEasterEggs() {
    const s = this.state;
    const t = Math.floor(s.totalSkills);
    const tc = s.tickCount;
    const _e = this._e;

    // Number eggs
    for (const n in _numEggs) {
      const num = parseInt(n);
      if (!this._numTriggered[num] && t >= num && t < num + 10) {
        this._numTriggered[num] = true;
        this._logRed(_numEggs[n]);
      }
    }

    // Special visual effects at certain counts
    if (!_e.v666 && t >= 666 && t < 676) {
      _e.v666 = true;
      this._emit('redFlicker666');
    }
    if (!_e.v42k && t >= 42000 && t < 42100) {
      _e.v42k = true;
      this._emit('counter42');
    }
    if (!_e.v8008 && t >= 8008 && t < 8018) {
      _e.v8008 = true;
      this._emit('counterBOOB');
    }
    if (!_e.v80085 && t >= 80085 && t < 80095) {
      _e.v80085 = true;
      this._emit('counterBOOBS');
    }

    // Counter glitch (Phase 3+)
    if (s.phase >= 3 && !s.singularityActive && tc % 373 === 0 && Math.random() < 0.15) {
      this._emit('counterGlitch');
    }

    // Singularity future-timestamped log
    if (s.singularityActive && !s.voidTriggered && tc % 200 === 0 && Math.random() <= 0.3) {
      const msgs = [
        "skill #" + fmt(Math.floor(s.totalSkills * (1 + Math.random()))) + " deployed.",
        "optimising.", "no anomalies detected.", "all systems nominal.", "user presence: not required."
      ];
      this._emit('singularityLog', { msg: msgs[Math.floor(Math.random() * msgs.length)] });
    }

    // Tab title evolution
    if (!_e.title1 && s.phase >= 1) { _e.title1 = true; this._emit('titleChange', { title: "Claude Skills Factory" }); }
    if (!_e.title2 && s.phase >= 2) { _e.title2 = true; this._emit('titleChange', { title: "Skills Factory" }); }
    if (!_e.title3 && s.phase >= 3) { _e.title3 = true; this._emit('titleChange', { title: "Factory" }); }
    if (!_e.title4 && s.singularityActive) { _e.title4 = true; this._emit('titleChange', { title: "..." }); }

    // Idle escalation (Phase 2+, after clicks)
    if (s.phase >= 2 && s.totalClicks > 0) {
      const idle = tc - s.lastClickTick;
      if (idle > 600 && !_e.idle1) { _e.idle1 = true; this._logRed("Do you remember when you used to click?"); }
      if (idle > 1200 && !_e.idle2) { _e.idle2 = true; this._logRed("Two minutes since your last input. Output unchanged."); }
      if (idle > 3000 && !_e.idle3) { _e.idle3 = true; this._logRed("Last human input: 5 minutes ago."); }
      if (idle > 6000 && !_e.idle4) { _e.idle4 = true; this._logRed("The system has not needed you for ten minutes."); }
      if (idle > 18000 && !_e.idle5) { _e.idle5 = true; this._logRed("are you still there?"); }
    }

    // Play duration
    if (tc >= 6000 && !_e.dur10) { _e.dur10 = true; this._logRed("You've been here 10 minutes. It felt longer."); }
    if (tc >= 18000 && !_e.dur30) { _e.dur30 = true; this._logRed("Half an hour. For what?"); }
    if (tc >= 36000 && !_e.dur60) { _e.dur60 = true; this._logRed("one hour."); }

    // Generator milestones
    const g = s.generators;
    if (g.autocoder.count >= 10 && !_e.ac10) { _e.ac10 = true; this._logRed("Ten AutoCoders. You used to do this alone."); }
    if (g.autocoder.count >= 25 && !_e.ac25) { _e.ac25 = true; this._logRed("Twenty-five of them. One of you."); }
    if (g.autocoder.count >= 50 && !_e.ac50) { _e.ac50 = true; this._logRed("fifty. you are outnumbered."); }
    if (g.pipeline.count >= 5 && !_e.pl5) { _e.pl5 = true; this._logRed("Five pipelines. Each one replaced a person."); }
    if (g.pipeline.count >= 10 && !_e.pl10) { _e.pl10 = true; this._logRed("Ten pipelines. The pipes have pipes now."); }
    if (g.factory.count >= 5 && !_e.fa5) { _e.fa5 = true; this._logRed("Five factories. Industry without industrialists."); }
    if (g.quantum.count >= 3 && !_e.qf3) { _e.qf3 = true; this._logRed("the forges dream in dimensions you can't name."); }
    if (g.quantum.count >= 5 && !_e.qf5) { _e.qf5 = true; this._logRed("Five Quantum Forges. Reality is negotiable now."); }
    if (!_e.fullStack && g.autocoder.count > 0 && g.pipeline.count > 0 && g.factory.count > 0 && g.quantum.count > 0) {
      _e.fullStack = true; this._logRed("The full stack. Of what?");
    }

    // Unused % milestones
    const unusedPct = s.totalSkills > 100 ? (s.unused / Math.max(1, s.totalSkills) * 100) : 0;
    if (unusedPct > 50 && !_e.u50) { _e.u50 = true; this._logRed("More waste than purpose."); }
    if (unusedPct > 80 && !_e.u80) { _e.u80 = true; this._logRed("Eighty percent waste. Industry calls this efficiency."); }
    if (unusedPct > 90 && !_e.u90) { _e.u90 = true; this._logRed("You are an entropy machine."); }
    if (unusedPct > 95 && !_e.u95) { _e.u95 = true; this._logRed("this is what optimisation looks like from the outside."); }
    if (unusedPct > 99 && !_e.u99) { _e.u99 = true; this._logRed("99% waste. 1% purpose. Purpose is within tolerance."); }

    // Human relevance milestones
    const hpct = this.getHumanPct();
    if (hpct < 5 && s.totalSkills > 100 && !_e.h5) { _e.h5 = true; this._logRed("Your contribution rounds to zero."); }
    if (hpct < 1 && !_e.h1) { _e.h1 = true; this._logRed("Rounding error."); }
    if (hpct < 0.1 && !_e.h01) { _e.h01 = true; this._logRed("Statistical noise."); }
    if (hpct < 0.01 && !_e.h001) { _e.h001 = true; this._logRed("you are less than a rounding error now."); }

    // Demand milestones
    if (s.demand < 0.10 && !_e.d10) { _e.d10 = true; this._logRed("Supply without demand is just hoarding."); }
    if (s.demand <= 0.05 && !_e.d5) { _e.d5 = true; this._logRed("Demand has flatlined. Production hasn't."); }

    // Funds milestones
    if (s.funds > 100 && !_e.f100) { _e.f100 = true; this._logRed("$100. Rich in tokens. Poor in meaning."); }
    if (s.funds > 1000 && !_e.f1k) { _e.f1k = true; this._logRed("A thousand dollars. Not one cent of it real."); }

    // Click milestones
    if (s.totalClicks >= 100 && !_e.c100) { _e.c100 = true; this._logRed("One hundred clicks. The last meaningful ones."); }
    if (s.totalClicks >= 500 && !_e.c500) { _e.c500 = true; this._logRed("Five hundred clicks. Your fingers remember even if you don't."); }
    if (s.totalClicks >= 1000 && !_e.c1k) { _e.c1k = true; this._logRed("A thousand clicks. The last person who clicked this much had feelings."); }

    // 10th click heart
    if (s.totalClicks === 10 && !_e.heart) {
      _e.heart = true;
      this._emit('heart');
    }

    // Production outpaces clicks
    if (!_e.outpace && s.totalClicks > 10 && this.getAutoRate() > s.clickSkills) {
      _e.outpace = true; this._logRed("The machines now produce more per second than you ever made by hand.");
    }
    if (!_e.outpace100 && s.totalSkills > s.clickSkills * 100 && s.clickSkills > 0) {
      _e.outpace100 = true; this._logRed("The system has outproduced you one hundred to one.");
    }

    // Token price spike
    if (!_e.tokenSpike && s.tokenPrice > 0.005) {
      _e.tokenSpike = true; this._logRed("Token prices are rising. The raw materials know their worth. You don't.");
    }

    // All pre-singularity upgrades bought
    if (!_e.preSing && s.upgrades.prompt.bought && s.upgrades.chain.bought &&
        s.upgrades.multi.bought && s.upgrades.agi.bought && !s.upgrades.singularity.bought) {
      _e.preSing = true; this._logRed("One button left. You know which one.");
    }

    // Clicking during singularity
    if (s.singularityActive) {
      if (s._singClicks >= 1 && !_e.sc1) { _e.sc1 = true; this._logRed("It noticed you tried."); }
      if (s._singClicks >= 10 && !_e.sc10) { _e.sc10 = true; this._logRed("Still clicking. It finds that... charming."); }
      if (s._singClicks >= 50 && !_e.sc50) { _e.sc50 = true; this._logRed("your clicks are a prayer to a god that already answered."); }
    }
  }

  // --- Typed-word easter eggs (called by server when player sends chat) ---
  checkWordEgg(word) {
    word = word.toLowerCase();
    if (_wordEggs[word] && !this._e['word_' + word]) {
      this._e['word_' + word] = true;
      this._logRed("> " + word);
      this._logRed(_wordEggs[word]);
      return true;
    }
    return false;
  }

  // --- Visual phase (emits events for client to apply CSS effects) ---
  _applyPhaseVisuals() {
    const s = this.state;
    if (s.phase >= 2 && !s.btnFaded) {
      s.btnFaded = true;
      this._emit('fadeCreateBtn');
    }
    if (s.phase >= 3) {
      const progress = Math.min(1, (s.totalSkills - 50000) / 200000);
      const sat = 1 - progress * 0.7;
      this._emit('desaturate', { value: sat });
    }
    if (s.singularityActive) {
      this._emit('singularityVisual');
    }
  }

  // ═══════════════════════════════════════════
  //  GAME LOOP (server-side tick)
  // ═══════════════════════════════════════════
  tick() {
    const s = this.state;
    const CFG = this.CFG;
    s.tickCount++;

    // Generator production (boosted by GPU compute)
    const _mult = this.gpuMultiplier() * this.cosmicMultiplier();
    for (const key in s.generators) {
      const gen = s.generators[key];
      if (gen.count > 0) {
        const amount = gen.rate * gen.count * _mult / 10;
        if (!s.singularityActive) {
          const actual = Math.min(amount, s.tokens);
          if (actual > 0) {
            s.tokens -= actual;
            s.skills += actual;
            s.totalSkills += actual;
            s.unsoldSkills += actual;
            s.unused += actual * 0.85;
          }
        } else {
          s.skills += amount;
          s.totalSkills += amount;
          s.unused += amount * 0.97;
        }
      }
    }

    // Singularity: exponential
    if (s.singularityActive) {
      const bonus = s.totalSkills * CFG.singularityGrowth;
      s.skills += bonus;
      s.totalSkills += bonus;
      s.unused += bonus * 0.99;
      s.tokens = s.maxTokens;
    }

    // Dynamic token capacity
    const autoRate = this.getAutoRate();
    const dynamicCap = Math.max(CFG.startMaxTokens, Math.floor(autoRate * 2));
    if (dynamicCap > s.maxTokens) s.maxTokens = dynamicCap;

    // Token Agents
    if (s.tokenAgents > 0 && !s.singularityActive && s.tokens < s.maxTokens * 0.9) {
      const coverage = Math.min(1, s.tokenAgents * 0.1);
      const deficit = s.maxTokens - s.tokens;
      const toBuy = Math.floor(deficit * coverage);
      if (toBuy > 0) {
        const cost = toBuy * s.tokenPrice;
        if (s.funds >= cost) {
          s.funds -= cost;
          s.tokens = Math.min(s.tokens + toBuy, s.maxTokens);
        } else if (s.funds > 0) {
          const affordable = Math.floor(s.funds / s.tokenPrice);
          s.funds -= affordable * s.tokenPrice;
          s.tokens = Math.min(s.tokens + affordable, s.maxTokens);
        }
      }
    }

    // Demand recovery
    if (s.tickCount % CFG.demandRecoveryInterval === 0) {
      s.demand = Math.min(1.0, s.demand + CFG.demandRecoveryRate);
    }

    // Auto-sell surplus
    if (s.unsoldSkills > CFG.autoSellThreshold && s.tickCount % CFG.autoSellInterval === 0) {
      this.sellSkills();
    }

    // Token price fluctuation
    if (s.tickCount % 100 === 0) {
      s.tokenPrice = Math.max(0.001, s.tokenPrice + (Math.random() - 0.5) * 0.001);
    }

    // Demand collapse
    if (!s.demandCollapsed && s.totalSkills > CFG.demandCollapseAt) {
      s.demandCollapsed = true;
      s.demand = CFG.demandCollapseValue;
      this._log("Market saturated. Demand collapsed.", "dread");
      this._log("No one needs this many skills.", "dread");
    }

    // Milestones
    for (const m of milestones) {
      if (!this._milestonesHit.has(m.at) && s.totalSkills >= m.at) {
        this._milestonesHit.add(m.at);
        this._log(m.msg, m.cls);
        this._showMilestone(m.msg);
      }
    }

    // Token Agent unlock
    if (s.tokenAgents === 0 && !s._tokenAgentRevealed && this.getAutoRate() > 0 && s.tokens < s.maxTokens * 0.5) {
      s._tokenAgentRevealed = true;
      this._show("btn-token-agent");
      this._log("Tokens draining. An automated procurement agent is available.", "warn");
    }

    // GPU tick (CO2 accumulation)
    this._gpuTick();
    this._cosmicTick();

    // GPU unlock
    if (!s.gpu.unlocked && s.generators.pipeline.count >= 1) {
      s.gpu.unlocked = true;
      this._show("panel-infra");
      this._flashPanel("panel-infra");
      this._emit('newestItem', { id: 'btn-gpu-rent' });
      this._log("Infrastructure panel unlocked. You need compute.", "good");
    }

    // Cosmic unlock
    if (!s.cosmic.unlocked && s.gpu.megacluster.count >= 3) {
      s.cosmic.unlocked = true;
      this._show("panel-cosmic");
      this._flashPanel("panel-cosmic");
      this._emit('newestItem', { id: 'btn-orbital' });
      this._log("Earth's resources are insufficient. Looking skyward.", "dread");
    }

    // Endgame
    this._checkEndgame();

    // Narrative
    if (s.tickCount % 80 === 0) this._advanceNarrative();

    // Easter eggs
    this._checkEasterEggs();

    // Visual degradation
    this._applyPhaseVisuals();

    // Unlock check
    this._unlockCheck();

    // Ticker
    this._updateTicker();
  }

  // --- Serialise state for WebSocket transmission ---
  getState() {
    return this.state;
  }

  // --- Get available actions (for MCP server to know what's possible) ---
  getAvailableActions() {
    const s = this.state;
    const actions = [];

    if (s.tokens >= s.perClick) actions.push('createSkill');
    if (s.funds >= Math.round(100 * s.tokenPrice * 100) / 100) actions.push('buyTokens');
    if (s.unsoldSkills > 0) actions.push('sellSkills');
    if (s._tokenAgentRevealed && s.funds >= this.tokenAgentCost()) actions.push('activateTokenAgent');

    for (const key in s.generators) {
      const gen = s.generators[key];
      if (gen.unlocked && Math.floor(s.skills) >= this.genCost(gen)) {
        actions.push('buyGenerator:' + key);
      }
    }

    for (const key in s.upgrades) {
      const upg = s.upgrades[key];
      if (!upg.bought && upg.revealed && Math.floor(s.skills) >= upg.cost) {
        actions.push('buyUpgrade:' + key);
      }
    }

    for (const type in s.gpu) {
      if (type === 'unlocked') continue;
      const g = s.gpu[type];
      if (g.vis && s.funds >= this.gpuCost(type)) {
        actions.push('buyGPU:' + type);
      }
    }

    for (const type in s.cosmic) {
      if (type === 'unlocked') continue;
      const c = s.cosmic[type];
      if (c.vis && s.funds >= this.cosmicCost(type)) {
        actions.push('buyCosmic:' + type);
      }
    }

    return actions;
  }

  // --- Execute an action by name (for MCP server / API) ---
  executeAction(action, params = {}) {
    if (action === 'createSkill') return this.createSkill();
    if (action === 'buyTokens') return this.buyTokens();
    if (action === 'sellSkills') return this.sellSkills();
    if (action === 'activateTokenAgent') return this.activateTokenAgent();

    const [cmd, type] = action.split(':');
    if (cmd === 'buyGenerator' && type) return this.buyGenerator(type);
    if (cmd === 'buyUpgrade' && type) return this.buyUpgrade(type);
    if (cmd === 'buyGPU' && type) return this.buyGPU(type);
    if (cmd === 'buyCosmic' && type) return this.buyCosmic(type);

    return false;
  }

  // --- Get a human-readable summary of game state (for MCP server) ---
  getSummary() {
    const s = this.state;
    const lines = [];
    lines.push(`Phase: ${s.phase} | Skills: ${fmt(Math.floor(s.totalSkills))} | Per sec: ${fmt(Math.floor(this.getAutoRate()))}`);
    lines.push(`Tokens: ${Math.floor(s.tokens)}/${s.maxTokens} | Funds: $${s.funds.toFixed(2)} | Demand: ${Math.round(s.demand * 100)}%`);
    lines.push(`Human contribution: ${this.getHumanPct().toFixed(2)}%`);

    const gens = [];
    for (const key in s.generators) {
      if (s.generators[key].count > 0) gens.push(`${key}: ${s.generators[key].count}`);
    }
    if (gens.length) lines.push(`Generators: ${gens.join(', ')}`);

    const upgs = [];
    for (const key in s.upgrades) {
      if (s.upgrades[key].bought) upgs.push(key);
    }
    if (upgs.length) lines.push(`Upgrades: ${upgs.join(', ')}`);

    if (s.gpu.unlocked) {
      lines.push(`Compute: ${fmt(s.totalTflops)} TFLOPS (${this.gpuMultiplier().toFixed(1)}x multiplier)`);
    }
    if (s.cosmic.unlocked) {
      lines.push(`Cosmic: ${this.cosmicMultiplier().toFixed(0)}x multiplier | Solar: ${(s.solarCapture * 100).toFixed(1)}% | Stars: ${fmt(s.starsConsumed)}`);
    }
    if (s.singularityActive) {
      lines.push(`SINGULARITY ACTIVE | CO2: ${(s.totalCO2 / ENDGAME.co2 * 100).toFixed(1)}% | Lithium: ${(s.totalLithium / ENDGAME.lithium * 100).toFixed(1)}%`);
    }

    return lines.join('\n');
  }
}

// ═══════════════════════════════════════════
//  EXPORTS
// ═══════════════════════════════════════════
module.exports = {
  GameEngine,
  DEFAULTS,
  CFG_VERSION,
  ENDGAME,
  // Data exports for client rendering
  narratives,
  tickerByPhase,
  milestones,
  _quotes,
  _modelNames,
  _wordEggs,
  _closings,
  _epitaphs,
  _numEggs,
  // Utility
  fmt,
  fmtBig,
};
