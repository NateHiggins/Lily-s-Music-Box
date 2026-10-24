/* THE BLANK DECK: the touch screen.

   It does only what a typist at the terminal could do: it sends lines of text to the engine and
   shows what comes back. The buttons type for you (the deck types "hint", a way types its own
   name), so a night played here is the same night, measured the same way. Nothing is sent
   anywhere: the page has no network code at all. */
(function () {
"use strict";

const B = window.BlankDeck, registry = window.BLANK_DECK_CONTENT;
const bridge = window.AndroidBridge || null;                 // present inside the Android app only
const $ = (id) => document.getElementById(id);
const NIGHT = "blankdeck.night", LAST = "blankdeck.last", SETTINGS = "blankdeck.settings";
const LAYING_OUT = "The Proprietor turns the deck face down, cuts it once, and begins to lay the cards out between " +
                   "you, slowly, in a pattern you do not recognise.";
const PENCILLED = "A blank card has worked a little way out of the deck.";
const media = (query) => Boolean(window.matchMedia && window.matchMedia(query).matches);
const calm = media("(prefers-reduced-motion: reduce)"), coarse = media("(pointer: coarse)");
const wait = (ms) => new Promise((done) => setTimeout(done, calm ? 0 : ms));

// What is kept, is kept in this browser. Where the browser refuses, the page remembers for as long as it is open.
const store = {
  works: true, memory: {},
  get(key) {
    let raw = null;
    try { raw = localStorage.getItem(key); } catch (e) { this.works = false; }
    if (raw === null || raw === undefined) raw = key in this.memory ? this.memory[key] : null;
    if (raw === null) return null;
    try { return JSON.parse(raw); } catch (e) { return null; }
  },
  set(key, value) {
    const raw = JSON.stringify(value);
    this.memory[key] = raw;
    try { localStorage.setItem(key, raw); } catch (e) { this.works = false; }
  },
  remove(key) {
    delete this.memory[key];
    try { localStorage.removeItem(key); } catch (e) { this.works = false; }
  },
};

let session = null, engine = null, pending = [], current = null, screen = "start";
let cameFromStart = false, deckSeen = 0, stagger = 0, readingRun = 0;
const ui = {
  narrate(text) { pending.push({ kind: "house", text }); },
  note(text) { pending.push({ kind: "note", text }); },
  card(title, image) { pending.push({ kind: "card", title, image }); },
};

// A kept night is only worth reopening if this build still has its rooms.
const usable = (night) => Boolean(night && night.phase && night.phase !== "done" && night.scene && night.world &&
  Array.isArray(night.transcript) && registry.seeds[night.scene.seed] &&
  (night.scene.thresholds || []).every((id) => registry.skins[id]));

// ---- screens -------------------------------------------------------------------
function show(name) {
  screen = name;
  for (const id of ["start", "play", "reading", "prompt"]) $(id).hidden = id !== name;
  $("menu").hidden = true;
  if (name === "start") refreshStart();
}

function refreshStart() {
  const night = store.get(NIGHT), last = store.get(LAST);
  $("resumeBox").hidden = !usable(night);
  $("lastBox").hidden = !(last && last.prompt);
  if (last && last.prompt) $("lastLabel").textContent = "Your last reading is kept: " + last.title + ".";
  const place = bridge ? "phone" : "device";
  const kept = store.works
    ? "This game remembers. What you type, and what the house makes of it, is kept on this " + place +
      " until you erase it (the menu has Forget). Nothing you type leaves it."
    : "This browser will not let the game keep anything, so a night lasts only while this page stays open. " +
      "Nothing you type leaves it.";
  $("keptNote").textContent = kept;
  $("menuKept").textContent = kept;
}

// ---- the log --------------------------------------------------------------------
function entry(kind, build) {
  const el = document.createElement("div");
  el.className = "entry " + kind;
  el.style.animationDelay = Math.min(stagger, 8) * 110 + "ms";
  stagger += 1;
  build(el);
  $("log").appendChild(el);
  return el;
}

/** What the house said, a paragraph at a time. A card that took a face this turn goes where the coat grew warm. */
function appendHouse(text, card) {
  for (const block of String(text).split(/\n\n+/)) {
    if (card && B.CARD_LINES.includes(block)) {
      entry("house", (el) => {
        const p = document.createElement("p");
        p.textContent = block;
        el.appendChild(p);
      });
      appendCard(card.title, card.image);
      card = null;
    } else if (block.startsWith(PENCILLED)) {
      entry("house", (el) => {
        const card = document.createElement("div");
        card.className = "pencil-card";
        const label = document.createElement("span");
        label.textContent = "A blank card works its way out of the deck";
        card.appendChild(label);
        card.appendChild(document.createTextNode(block.split("read: ")[1] || block));
        el.appendChild(card);
      });
    } else if (block.trim()) {
      entry("house", (el) => {
        const p = document.createElement("p");
        p.textContent = block;
        el.appendChild(p);
      });
    }
  }
  if (card) appendCard(card.title, card.image);
}

const appendPlayer = (text) => entry("player", (el) => { el.textContent = text; });
const appendNote = (text) => entry("note", (el) => { el.textContent = text; });

function appendCard(title, image) {
  return entry("house", (el) => {
    const row = document.createElement("div");
    row.className = "faced";
    const mini = document.createElement("i");
    mini.className = "mini";
    const words = document.createElement("div");
    const name = document.createElement("b");
    name.textContent = title;
    const what = document.createElement("em");
    what.textContent = image;
    words.appendChild(name);
    words.appendChild(what);
    row.appendChild(mini);
    row.appendChild(words);
    el.appendChild(row);
  });
}

/** Put what the engine said on the page, and bring `anchor` (the line just typed) to the top of the view. */
function flush(anchor) {
  let card = pending.find((item) => item.kind === "card") || null;
  for (const item of pending) {
    if (item.kind === "note") { appendNote(item.text); continue; }
    if (item.kind !== "house") continue;
    const warm = card && String(item.text).split(/\n\n+/).some((block) => B.CARD_LINES.includes(block));
    appendHouse(item.text, warm ? card : null);
    if (warm) card = null;
  }
  if (card) appendCard(card.title, card.image);
  pending = [];
  stagger = 0;
  const log = $("log");
  requestAnimationFrame(() => { log.scrollTop = anchor ? Math.max(0, anchor.offsetTop - 14) : log.scrollHeight; });
}

function shownFor(text) {                                     // how a line the buttons typed reads in the log
  const low = text.trim().toLowerCase();
  if (low.startsWith("@") && registry.skins[low.slice(1)]) return "You take " + B.shortWay(registry.skins[low.slice(1)]) + ".";
  if (low === "hint") return "You ask the deck.";
  if (low === "inventory") return "You check your pockets.";
  return text;
}

// ---- the hand: ways, pencilled words, the deck ------------------------------------
function drawPips() {
  const pips = $("pips");
  pips.textContent = "";
  if (!session) return;
  const rooms = session.chamber_target + 1;                    // the shop, then the rooms of the night
  const reading = session.chamber_index >= rooms;
  for (let i = 0; i <= rooms; i++) {
    const pip = document.createElement("i");
    if (i === rooms) pip.className = "last" + (reading ? " here" : "");         // the Reading Room
    else pip.className = reading || i < session.chamber_index ? "past" : i === session.chamber_index ? "here" : "";
    pips.appendChild(pip);
  }
  pips.setAttribute("aria-label", reading ? "The Reading Room"
    : "Room " + (session.chamber_index + 1) + " of " + rooms + ", and then the Reading Room");
}

/** The words the deck has already pencilled in this room: what a typist could scroll back and read again.
    Never more than was shown, and never a word whose moment has passed. */
function offeredWords() {
  if (!session || (session.phase !== "chamber" && session.phase !== "reading")) return [];
  const shown = [];
  for (let i = session.transcript.length - 1; i >= 0; i--) {
    const line = session.transcript[i];
    if (line.scene !== session.scene.key) break;
    if (line.role !== "house") continue;
    for (const block of String(line.text).split(/\n\n+/)) {
      if (!block.startsWith(PENCILLED)) continue;
      for (const word of (block.split("read: ")[1] || "").replace(/\.$/, "").split(" / ")) {
        if (word && !shown.includes(word.toLowerCase())) shown.push(word.toLowerCase());
      }
    }
  }
  const still = B.hintWords(registry.seeds[session.scene.seed], session.scene.flags);
  return still.filter((word) => shown.includes(word.toLowerCase()));
}

function updateHand() {
  const ways = $("ways"), chips = $("chips");
  ways.textContent = "";
  chips.textContent = "";
  ways.hidden = chips.hidden = true;
  if (!session || !engine) return;
  const over = engine.finished, threshold = session.phase === "threshold";
  $("sitBtn").hidden = !over;
  $("say").hidden = $("tools").hidden = over;
  $("deckBtn").disabled = threshold;
  $("line").placeholder = threshold ? "Or say where you go" : "What do you do?";
  if (threshold) {
    const ids = (session.scene.thresholds || []).slice(0, 3);
    const places = ids.length >= 3 ? ["Left", "Ahead", "Right"] : ["Left", "Right"];
    ids.forEach((id, i) => {
      const way = B.shortWay(registry.skins[id]);
      const button = document.createElement("button");
      button.type = "button";
      button.className = "way";
      button.style.animationDelay = i * 90 + "ms";
      const where = document.createElement("small");
      where.textContent = places[i];
      const what = document.createElement("span");
      what.textContent = way.charAt(0).toUpperCase() + way.slice(1);
      button.appendChild(where);
      button.appendChild(what);
      button.addEventListener("click", () => send("@" + id));
      ways.appendChild(button);
    });
    ways.hidden = !ids.length;
  } else if (!over) {
    for (const word of offeredWords()) {
      const chip = document.createElement("button");
      chip.type = "button";
      chip.className = "chip";
      chip.textContent = word;
      chip.addEventListener("click", () => send(word));
      chips.appendChild(chip);
    }
    chips.hidden = !chips.childElementCount;
  }
  const count = session.world.cards.length, badge = $("deckCount");
  badge.hidden = count === 0;
  badge.textContent = String(count);
  if (count > deckSeen) { badge.classList.remove("glint"); void badge.offsetWidth; badge.classList.add("glint"); }
  deckSeen = count;
  $("toolHint").textContent = threshold ? "Choose a way."
    : count ? count + (count === 1 ? " card has a face" : " cards have faces") : "";
  drawPips();
}

// ---- a night ----------------------------------------------------------------------
function save() {
  if (session && session.phase !== "done") store.set(NIGHT, session);
}

function begin(length) {
  $("log").textContent = "";
  deckSeen = 0;
  session = B.newSession({ length });
  engine = new B.Engine(session, registry, ui);
  engine.begin();
  show("play");
  const first = appendNote("Say what you do, in your own words: look at things, talk, take, try. " +
                           "If the house does not follow you, tap the deck.");
  flush(first);
  save();
  updateHand();
}

function resume(kept) {
  $("log").textContent = "";
  session = kept;
  engine = new B.Engine(session, registry, ui);
  deckSeen = session.world.cards.length;
  const cards = session.world.cards.slice();
  let lastTyped = null;
  for (const line of session.transcript) {
    stagger = 0;
    if (line.role === "player") { lastTyped = appendPlayer(shownFor(line.text)); continue; }
    appendHouse(line.text, cards.length && cards[0].turn <= line.turn ? cards.shift() : null);
  }
  appendNote("The house has kept your place.");
  show("play");
  flush(lastTyped);
  updateHand();
}

function send(text) {
  text = String(text || "").trim();
  if (!text || !engine || engine.finished) return;
  const typed = appendPlayer(shownFor(text));
  engine.turn(text);
  flush(typed);
  save();
  updateHand();
}

function pockets() {
  if (!session || !engine) return;
  if (session.phase === "threshold" || engine.finished) {      // between rooms it costs nothing to look
    flush(appendNote("You are carrying: " + B.carrying(session.world) + "."));
  } else {
    send("inventory");
  }
}

function finishNight() {
  if (!engine || !session || !engine.finished) return;
  engine.closeNight();
  const synthesis = B.synthesize(registry, engine.model, session);
  const prompt = B.buildPrompt(registry, engine.model, session, synthesis);
  session.phase = "done";
  current = { id: session.id, title: synthesis.design.working_title, prompt, prophecy: synthesis.prophecy, when: Date.now() };
  store.set(LAST, current);
  store.remove(NIGHT);
  session = engine = null;
  cameFromStart = false;
  showReading(true);
}

// ---- the reading ---------------------------------------------------------------------
function readingCard(vision, index) {
  const card = document.createElement("button");
  card.type = "button";
  card.className = "reading-card";
  card.style.animationDelay = index * 120 + "ms";
  card.setAttribute("aria-label", "A card, face down");
  const flip = document.createElement("span");
  flip.className = "flip";
  const back = document.createElement("span");
  back.className = "back";
  const front = document.createElement("span");
  front.className = "front";
  const name = document.createElement("b");
  name.textContent = vision.card;
  const words = document.createElement("span");
  words.textContent = vision.text;
  front.appendChild(name);
  front.appendChild(words);
  flip.appendChild(back);
  flip.appendChild(front);
  card.appendChild(flip);
  return card;
}

function faceUp(card, vision) {
  card.classList.add("turned");
  card.setAttribute("aria-label", vision.card + ". " + vision.text);
}

/** staged: the reading as it happens, one card at a time. Not staged: the same reading, already told. */
async function showReading(staged) {
  const run = ++readingRun, p = current.prophecy;
  const live = () => run === readingRun;
  const smooth = { block: "center", behavior: calm ? "auto" : "smooth" };
  show("reading");
  $("reading").scrollTop = 0;
  $("laying").textContent = LAYING_OUT;
  $("address").textContent = staged ? "" : p.address;
  $("pronouncement").textContent = p.pronouncement;
  $("lastCard").textContent = registry.reading.last_card;
  $("handoff").textContent = registry.reading.handoff_line;
  const ending = ["pronouncement", "lastCard", "handoff", "toPromptBtn"];
  for (const id of ending) $(id).hidden = staged;
  const recollections = $("recollections"), spread = $("spread"), turn = $("turnBtn");
  recollections.textContent = "";
  spread.textContent = "";
  turn.hidden = true;
  const recall = (line) => {
    const li = document.createElement("li");
    li.textContent = line;
    recollections.appendChild(li);
  };
  const cards = p.visions.map(readingCard);

  if (!staged) {
    p.recollections.forEach(recall);
    cards.forEach((card, i) => { faceUp(card, p.visions[i]); spread.appendChild(card); });
    return;
  }

  let turned = 0;
  const markNext = () => cards.forEach((card, i) => card.classList.toggle("next", i === turned));
  const conclude = async () => {
    turn.hidden = true;
    await wait(1200);
    if (!live()) return;
    $("pronouncement").hidden = false;
    $("pronouncement").scrollIntoView(smooth);
    await wait(2600);
    if (!live()) return;
    $("lastCard").hidden = false;
    $("lastCard").scrollIntoView(smooth);
    await wait(1800);
    if (!live()) return;
    $("handoff").hidden = false;
    $("toPromptBtn").hidden = false;
    $("toPromptBtn").scrollIntoView({ block: "end", behavior: smooth.behavior });
  };
  const turnNext = () => {
    if (!live() || turned >= cards.length) return;
    const card = cards[turned];
    faceUp(card, p.visions[turned]);
    card.scrollIntoView(smooth);
    turned += 1;
    markNext();
    turn.textContent = "Turn the next card";
    if (turned >= cards.length) conclude();
  };
  cards.forEach((card, i) => card.addEventListener("click", () => { if (i === turned) turnNext(); }));
  turn.onclick = turnNext;

  await wait(1500);
  if (!live()) return;
  $("address").textContent = p.address;
  for (const line of p.recollections) {
    await wait(1200);
    if (!live()) return;
    recall(line);
  }
  await wait(1400);
  if (!live()) return;
  for (const card of cards) spread.appendChild(card);
  markNext();
  turn.textContent = "Turn the first card";
  turn.hidden = false;
  turn.scrollIntoView({ block: "nearest", behavior: smooth.behavior });
}

// ---- the last card: the prompt ----------------------------------------------------------
function showPrompt() {
  readingRun += 1;
  show("prompt");
  $("prompt").scrollTop = 0;
  $("gameTitle").textContent = current.title;
  const words = current.prompt.split(/\s+/).filter(Boolean).length;
  $("promptMeta").textContent = words.toLocaleString("en-US") + " words, written for an AI coder that has " +
    "THE AI STUDIO MANUAL. It says what your night showed, and what it did not.";
  $("promptText").value = current.prompt;
  $("shareBtn").hidden = !(bridge && bridge.share);
  $("copyStatus").textContent = "";
}

function copyPrompt() {
  const status = $("copyStatus"), text = current.prompt;
  const done = () => { status.textContent = "Copied. Paste it where your builder listens."; };
  const byHand = () => {
    const area = $("promptText");
    area.focus();
    area.select();
    let ok = false;
    try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
    if (ok) done();
    else status.textContent = "This screen cannot copy for you. The whole prompt is selected below: copy it from there.";
  };
  if (bridge && bridge.copy) {
    let ok = false;
    try { ok = bridge.copy(text) !== false; } catch (e) { ok = false; }
    if (ok) { done(); return; }
  }
  if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, byHand);
  else byHand();
}

// ---- the menu -------------------------------------------------------------------------
function setSize(size) {
  const scale = { small: 0.9, medium: 1, large: 1.18 }[size] || 1;
  document.documentElement.style.setProperty("--scale", String(scale));
  for (const [id, name] of [["sizeSmall", "small"], ["sizeMedium", "medium"], ["sizeLarge", "large"]]) {
    $(id).setAttribute("aria-pressed", String(name === size));
  }
  store.set(SETTINGS, { size });
}

function openMenu(open) {
  $("menu").hidden = !open;
  $("menuBtn").setAttribute("aria-expanded", String(open));
  $("forgetConfirm").hidden = true;
  $("leaveBtn").hidden = !session;                          // there is nothing to step out of at the counter
  $("closeMenuBtn").textContent = session ? "Back to the house" : "Close";
  if (open) refreshStart();
}

function forgetEverything() {
  store.remove(NIGHT);
  store.remove(LAST);
  session = engine = current = null;
  pending = [];
  readingRun += 1;
  $("log").textContent = "";
  show("start");
}

// The Android back key: close what is open, and say whether anything was.
window.blankDeckBack = function () {
  if (!$("menu").hidden) { openMenu(false); return true; }
  if (screen === "prompt") { showReading(false); return true; }
  if (screen === "reading" && cameFromStart) { readingRun += 1; show("start"); return true; }
  if (screen === "play") { openMenu(true); return true; }
  return false;
};

// Where a keyboard covers the page instead of resizing it, keep the pen above the keyboard.
function followKeyboard() {
  const view = window.visualViewport;
  let framed = true;
  try { framed = window.top !== window; } catch (e) { framed = true; }
  if (!view || framed) return;
  view.addEventListener("resize", () => {
    const covered = window.innerHeight - view.height > 80;
    $("app").style.height = covered ? view.height + "px" : "";
    if (covered) window.scrollTo(0, 0);
  });
}

// ---- wiring ----------------------------------------------------------------------------
function start(data) {
  const settings = store.get(SETTINGS) || {};
  setSize(settings.size || "medium");
  $("beginBtn").addEventListener("click", () => {
    const picked = document.querySelector('input[name="length"]:checked');
    begin(picked ? picked.value : "standard");
  });
  $("resumeBtn").addEventListener("click", () => { const night = store.get(NIGHT); if (usable(night)) resume(night); });
  $("lastBtn").addEventListener("click", () => {
    const last = store.get(LAST);
    if (last && last.prompt) { current = last; cameFromStart = true; showPrompt(); }
  });
  $("say").addEventListener("submit", (event) => {
    event.preventDefault();
    const line = $("line");
    const text = line.value;
    line.value = "";
    if (coarse) line.blur();                                   // put the keyboard away: the reply is the thing to read
    send(text);
  });
  $("deckBtn").addEventListener("click", () => send("hint"));
  $("pocketsBtn").addEventListener("click", pockets);
  $("sitBtn").addEventListener("click", finishNight);
  $("toPromptBtn").addEventListener("click", showPrompt);
  $("copyBtn").addEventListener("click", copyPrompt);
  $("shareBtn").addEventListener("click", () => {
    try { bridge.share(current.prompt, "Build me a game: " + current.title); }
    catch (e) { $("copyStatus").textContent = "Sharing is not available here."; }
  });
  $("againBtn").addEventListener("click", () => { readingRun += 1; show("start"); });
  $("backToReadingBtn").addEventListener("click", () => showReading(false));
  $("menuBtn").addEventListener("click", () => openMenu(true));
  $("rulesBtn").addEventListener("click", () => openMenu(true));
  $("closeMenuBtn").addEventListener("click", () => openMenu(false));
  $("menu").addEventListener("click", (event) => { if (event.target === $("menu")) openMenu(false); });
  $("sizeSmall").addEventListener("click", () => setSize("small"));
  $("sizeMedium").addEventListener("click", () => setSize("medium"));
  $("sizeLarge").addEventListener("click", () => setSize("large"));
  $("leaveBtn").addEventListener("click", () => { save(); session = engine = null; show("start"); });
  $("forgetBtn").addEventListener("click", () => {
    $("forgetConfirm").hidden = false;
    $("forgetYes").scrollIntoView({ block: "nearest" });
  });
  $("forgetNo").addEventListener("click", () => { $("forgetConfirm").hidden = true; });
  $("forgetYes").addEventListener("click", forgetEverything);
  followKeyboard();

  store.set("blankdeck.probe", 1);                             // find out now whether anything can be kept
  store.remove("blankdeck.probe");

  // A page updated under an open viewer comes back where it was.
  if (data && usable(data.night)) { resume(data.night); return; }
  if (data && data.current && data.current.prompt && (data.screen === "prompt" || data.screen === "reading")) {
    current = data.current;
    cameFromStart = Boolean(data.cameFromStart);
    if (data.screen === "prompt") showPrompt(); else showReading(false);
    return;
  }
  show("start");
}

try {
  if (!B || !registry) throw new Error("the rooms did not load");
  new RegExp("(?<![\\p{L}])a", "u");                           // what the house needs of this browser
  const hot = window.claude && window.claude.hot;
  if (hot && hot.snapshot) {
    hot.snapshot(() => ({ night: session && session.phase !== "done" ? session : null, current, screen, cameFromStart }));
  }
  if (hot && hot.ready) hot.ready(start);
  else start((hot && hot.data) || {});
  window.BLANK_DECK_STARTED = true;
} catch (error) {
  const broken = $("broken");
  broken.hidden = false;
  broken.textContent = "The house cannot open here: " + (error && error.message ? error.message : error) +
    ". On an older phone, updating Android System WebView (or Chrome) in the Play Store usually mends it.";
}
})();
