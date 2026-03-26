#!/usr/bin/env node
// Quick smoke test for game-engine.js
const { GameEngine, fmt } = require('./game-engine');

const game = new GameEngine();
const s = game.state;

// --- Initial state ---
console.log('=== Initial State ===');
console.log('Skills:', s.skills, '| Funds:', s.funds, '| Tokens:', s.tokens);
console.log('Phase:', s.phase, '| Generators:', Object.keys(s.generators).length);
console.log('Events after init:', game.drainEvents().length, '(should be 0)');

// --- Buy tokens ---
console.log('\n=== Buy Tokens ===');
const bought = game.buyTokens();
console.log('Bought:', bought, '| Tokens:', Math.floor(s.tokens), '| Funds:', s.funds.toFixed(2));
const events1 = game.drainEvents();
console.log('Events:', events1.length, events1.map(e => e.type).join(', '));

// --- Create skill ---
console.log('\n=== Create Skill ===');
const created = game.createSkill();
console.log('Created:', created, '| Skills:', s.skills, '| Tokens:', Math.floor(s.tokens));

// --- Buy autocoder (need skills first) ---
console.log('\n=== Accumulate Skills ===');
// Give ourselves some skills to buy an autocoder
s.skills = 100;
s.totalSkills = 100;
s.tokens = 1000;
game.drainEvents();

const boughtGen = game.buyGenerator('autocoder');
console.log('Bought autocoder:', boughtGen, '| Count:', s.generators.autocoder.count);
const events2 = game.drainEvents();
console.log('Events:', events2.length, events2.map(e => e.type).join(', '));

// --- Run some ticks ---
console.log('\n=== Run 100 Ticks ===');
for (let i = 0; i < 100; i++) game.tick();
const tickEvents = game.drainEvents();
console.log('Skills after 100 ticks:', Math.floor(s.skills));
console.log('Phase:', s.phase);
console.log('Auto rate:', fmt(Math.floor(game.getAutoRate())), '/sec');
console.log('Events from ticks:', tickEvents.length);
console.log('Event types:', [...new Set(tickEvents.map(e => e.type))].join(', '));

// --- Test getAvailableActions ---
console.log('\n=== Available Actions ===');
s.skills = 10000;
s.totalSkills = 10000;
s.tokens = 5000;
s.funds = 500;
game._unlockCheck();
game.drainEvents();
const actions = game.getAvailableActions();
console.log('Actions:', actions.length);
actions.forEach(a => console.log(' -', a));

// --- Test executeAction ---
console.log('\n=== Execute Action ===');
const result = game.executeAction('buyGenerator:autocoder');
console.log('Execute buyGenerator:autocoder:', result, '| Count:', s.generators.autocoder.count);

// --- Test getSummary ---
console.log('\n=== Summary ===');
console.log(game.getSummary());

// --- Test upgrades ---
console.log('\n=== Buy Upgrade ===');
s.skills = 50;
s.totalSkills = 50;
const upgResult = game.buyUpgrade('prompt');
console.log('Bought prompt upgrade:', upgResult, '| perClick:', s.perClick);

// --- Verify no crashes on full game progression ---
console.log('\n=== Full Progression (fast forward) ===');
const game2 = new GameEngine();
const s2 = game2.state;
s2.funds = 1e15;
s2.tokens = 1e9;
s2.maxTokens = 1e9;
s2.skills = 1e12;
s2.totalSkills = 1e12;

// Buy everything
game2.buyGenerator('autocoder');
for (let i = 0; i < 5; i++) game2.buyGenerator('autocoder');
game2._unlockCheck();
for (let i = 0; i < 5; i++) game2.buyGenerator('pipeline');
game2._unlockCheck();
for (let i = 0; i < 3; i++) game2.buyGenerator('factory');
game2._unlockCheck();

game2.buyUpgrade('prompt');
game2.buyUpgrade('chain');
game2.buyUpgrade('multi');
game2.buyUpgrade('agi');

// GPU progression
s2.gpu.unlocked = true;
for (let i = 0; i < 5; i++) game2.buyGPU('rent');
for (let i = 0; i < 5; i++) game2.buyGPU('buy');
for (let i = 0; i < 3; i++) game2.buyGPU('datacenter');
for (let i = 0; i < 3; i++) game2.buyGPU('megacluster');

// Cosmic
s2.cosmic.unlocked = true;
for (let i = 0; i < 10; i++) game2.buyCosmic('orbital');
for (let i = 0; i < 10; i++) game2.buyCosmic('dyson');

game2.drainEvents();

// Run many ticks
for (let i = 0; i < 1000; i++) game2.tick();
const finalEvents = game2.drainEvents();

console.log('Final skills:', fmt(Math.floor(s2.totalSkills)));
console.log('Phase:', s2.phase);
console.log('Events from 1000 ticks:', finalEvents.length);
console.log('Singularity:', s2.singularityActive);
console.log('Void:', s2.voidTriggered);

console.log('\n=== ALL TESTS PASSED ===');
