/* Replay nights that the Python engine played, through the JavaScript engine, and report every
   difference. Used by oracle/tests/test_app.py:

       node replay.js content.json fixtures.json

   A fixture night is the lines a player typed and everything the Python engine said, recorded and
   concluded in reply. Both engines must agree word for word; numbers must agree to 1e-9.

   Every few turns the night is also put down and picked up again the way the phone does it (the
   whole session written out as JSON, read back, and a new engine made over it), so a night that
   was interrupted must still be the same night. */
"use strict";
const fs = require("fs");
const crypto = require("crypto");
const B = require("./engine.js");

const registry = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const fixtures = JSON.parse(fs.readFileSync(process.argv[3], "utf8"));
const problems = [];
const note = (night, what, expected, got) => {
  if (problems.length < 12) problems.push({ night, what, expected, got });
  else if (problems.length === 12) problems.push({ night, what: "(more differences not shown)" });
};

function same(a, b) {
  if (typeof a === "number" && typeof b === "number") return Math.abs(a - b) <= 1e-9 * Math.max(1, Math.abs(a), Math.abs(b));
  if (a === null || b === null || typeof a !== "object" || typeof b !== "object") return a === b;
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  const ka = Object.keys(a), kb = Object.keys(b);
  if (ka.length !== kb.length) return false;
  return ka.every((k) => k in b && same(a[k], b[k]));
}

function firstDifference(a, b, path) {
  if (same(a, b)) return null;
  if (a && b && typeof a === "object" && typeof b === "object" && Array.isArray(a) === Array.isArray(b)) {
    for (const k of new Set(Object.keys(a).concat(Object.keys(b)))) {
      const found = firstDifference(a[k], b[k], path + "." + k);
      if (found) return found;
    }
  }
  const show = (v) => { const s = JSON.stringify(v); return s === undefined ? "undefined" : s.slice(0, 300); };
  return path + ": expected " + show(a) + " got " + show(b);
}

// ---- the pieces, against Python's own answers ---------------------------------
for (const [text, hex] of Object.entries(fixtures.checks.sha512)) {
  const got = Buffer.from(B.sha512(B.utf8(text))).toString("hex");
  const node = crypto.createHash("sha512").update(text, "utf8").digest("hex");
  if (got !== hex || got !== node) note("-", "sha512 of " + JSON.stringify(text), hex, got);
}
for (const [seedText, draws] of Object.entries(fixtures.checks.random)) {
  const rng = new B.PyRandom(seedText);
  const got = { random: [rng.random(), rng.random()], uniform: rng.uniform(0.0, 0.15), randrange: [rng.randrange(3), rng.randrange(7), rng.randrange(1)],
                choice: rng.choice(["a", "b", "c", "d", "e"]), choices: rng.choices(["p", "q", "r", "s"], [1.0, 0.5, 0.25, 0.125]) };
  const list = [0, 1, 2, 3, 4, 5, 6];
  rng.shuffle(list);
  got.shuffle = list;
  const diff = firstDifference(draws, got, "random(" + JSON.stringify(seedText) + ")");
  if (diff) note("-", diff);
}
for (const [values, expected] of fixtures.checks.sum) {
  if (B.pySum(values) !== expected) note("-", "sum(" + JSON.stringify(values) + ")", expected, B.pySum(values));
}
for (const [x, n, expected] of fixtures.checks.round) {
  if (B.pyRound(x, n) !== expected) note("-", "round(" + x + ", " + n + ")", expected, B.pyRound(x, n));
}
for (const [a, b, x, expected] of fixtures.checks.betainc) {
  if (!same(expected, B.betainc(a, b, x))) note("-", "betainc(" + [a, b, x] + ")", expected, B.betainc(a, b, x));
}

// ---- whole nights ---------------------------------------------------------------
let turns = 0, resumed = 0;
for (const night of fixtures.nights) {
  const name = night.name;
  let session = B.newSession({ length: night.length }, night.seed);
  const ui = { out: [], narrate(t) { this.out.push(["narrate", t]); }, note(t) { this.out.push(["note", t]); } };
  let engine;
  try {
    engine = new B.Engine(session, registry, ui);
    engine.begin();
    let diff = firstDifference(night.opening, ui.out, name + " opening");
    if (diff) { note(name, diff); continue; }
    let failed = false;
    for (let i = 0; i < night.turns.length && !failed; i++) {
      const { line, out, phase } = night.turns[i];
      if (i % 4 === 3) {                                       // put the phone down; pick it up again
        session = JSON.parse(JSON.stringify(session));
        engine = new B.Engine(session, registry, ui);
        resumed += 1;
      }
      const before = ui.out.length;
      engine.turn(line);
      turns += 1;
      diff = firstDifference(out, ui.out.slice(before), name + " turn " + (i + 1) + " " + JSON.stringify(line)) ||
             firstDifference(phase, session.phase, name + " turn " + (i + 1) + " phase");
      if (diff) { note(name, diff); failed = true; }
    }
    if (failed) continue;
    if (!engine.finished) { note(name, "the night did not finish"); continue; }
    engine.closeNight();
    const synthesis = B.synthesize(registry, engine.model, session);
    const prompt = B.buildPrompt(registry, engine.model, session, synthesis, night.when);
    const observations = engine.model.observations.map((o) => ({
      action: o.action, context: o.context, scene: o.scene, seed: o.seed, frame: o.frame, kind: o.kind,
      strength: o.strength, source: o.source, signal: o.signal, turn: o.turn,
      hypotheses: o.hypotheses.map((h) => [h.dim, h.dir, h.share]) }));
    const states = {};
    for (const [dim, st] of Object.entries(engine.model.compute())) {
      if (st.support + st.against > 0) states[dim] = [st.value, st.confidence, st.status, st.n_independent];
    }
    const w = session.world;
    const world = { matches: w.matches, joker: w.joker, inventory: w.inventory, companion: w.companion ? w.companion.name : null,
                    flags: w.flags, threads: w.threads, threads_resolved: w.threads_resolved, failures: w.failures,
                    cards: w.cards.map((c) => [c.title, c.dims]), moments: w.moments.map((m) => m.text),
                    attempted: w.attempted, summaries: w.summaries.map((x) => [x.seed, x.skin, x.line, x.turns]),
                    signals: w.signals, skins_taken: session.skins_taken, seeds_used: session.seeds_used,
                    guard_events: session.guard_events.length };
    diff = firstDifference(night.observations, observations, name + " observations") ||
           firstDifference(night.states, states, name + " states") ||
           firstDifference(night.world, world, name + " world") ||
           firstDifference(night.design, synthesis.design, name + " design") ||
           firstDifference(night.prophecy, synthesis.prophecy, name + " prophecy") ||
           firstDifference(night.gdv_sources, synthesis.draft.gdv_sources, name + " gdv sources");
    if (diff) { note(name, diff); continue; }
    if (prompt !== night.prompt) {
      let at = 0;
      while (at < prompt.length && prompt[at] === night.prompt[at]) at++;
      note(name, "prompt differs at character " + at, JSON.stringify(night.prompt.slice(Math.max(0, at - 60), at + 80)),
           JSON.stringify(prompt.slice(Math.max(0, at - 60), at + 80)));
    }
  } catch (error) {
    note(name, "exception: " + (error && error.stack ? error.stack.split("\n").slice(0, 4).join(" | ") : error));
  }
}

console.log(JSON.stringify({ nights: fixtures.nights.length, turns, resumed, differences: problems.length, problems }, null, 1));
process.exit(problems.length ? 1 : 0);
