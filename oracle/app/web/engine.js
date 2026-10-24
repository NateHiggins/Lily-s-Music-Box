/* THE BLANK DECK: the engine, in JavaScript.

   A port of the Python program's authored-rooms path (oracle/model.py, probes.py, offline.py,
   engine.py, synthesis.py, prompt.py, guard.py), kept close to it function for function so that
   the two can be compared night for night: oracle/tests/test_app.py plays the same nights
   through both and requires the same words, the same evidence and the same prompt.

   It needs no library and no network. It runs in a browser, in an Android WebView, and in Node
   (for that comparison). The authored content is not here: it is passed in, already validated
   and normalised by the Python loader. */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.BlankDeck = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
"use strict";

// ---------------------------------------------------------------------------
// Text, as Python handles it
// ---------------------------------------------------------------------------

const WS = "\\t\\n\\x0b\\x0c\\r\\x1c-\\x1f \\x85\\u00a0\\u1680\\u2000-\\u200a\\u2028\\u2029\\u202f\\u205f\\u3000";
const WS_RUN = new RegExp("[" + WS + "]+", "g");
const WS_EDGE = new RegExp("^[" + WS + "]+|[" + WS + "]+$", "g");
const strip = (s) => String(s).replace(WS_EDGE, "");
const splitWords = (s) => { const t = strip(s); return t ? t.split(WS_RUN) : []; };
const squash = (s) => splitWords(s).join(" ");                         // " ".join(text.split())
const points = (s) => Array.from(String(s));                            // Python indexes by code point
const cut = (s, n) => { const p = points(s); return p.length > n ? p.slice(0, n).join("") : String(s); };
const lower = (s) => String(s).toLowerCase();
const escapeRegExp = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const replaceAll = (s, old, value) => String(s).split(old).join(value);
const WORD = "[\\p{L}\\p{N}_]";                                         // Python's \w

/** Python's sum() over floats. Since 3.12 it is Neumaier's compensated sum, and the last bit of a
    total decides which side of a threshold a number falls on, so the port adds the same way. */
function pySum(values) {
  let f = 0, c = 0, first = true;
  for (const x of values) {
    if (first) { f = 0 + x; first = false; continue; }
    const t = f + x;
    if (Math.abs(f) >= Math.abs(x)) c += (f - t) + x; else c += (x - t) + f;
    f = t;
  }
  if (c && Number.isFinite(c)) f += c;
  return f;
}

/** Python's round(x, n): correctly rounded, exact ties to even. */
function pyRound(x, n) {
  if (!Number.isFinite(x)) return x;
  const magnitude = Math.abs(x);
  let out = Number(magnitude.toFixed(n));
  const exact = magnitude.toFixed(100);
  const dot = exact.indexOf(".");
  if (/^50*$/.test(exact.slice(dot + 1 + n))) {                         // an exact tie: toFixed rounded it up
    const kept = exact.slice(0, dot) + exact.slice(dot + 1, dot + 1 + n);
    if (Number(kept.slice(-1)) % 2 === 0) out = Number(exact.slice(0, dot + 1 + n));
  }
  return x < 0 ? -out : out;
}

// ---------------------------------------------------------------------------
// Python's random.Random(seed_string): SHA-512 seeding and the Mersenne Twister
// ---------------------------------------------------------------------------

const M64 = (1n << 64n) - 1n;

function integerRoot(n, k) {                                            // floor(n ** (1/k)), n a BigInt
  if (n < 2n) return n;
  const bits = BigInt(n.toString(2).length);
  let x = 1n << (bits / BigInt(k) + 1n);
  for (;;) {
    const y = ((BigInt(k) - 1n) * x + n / (x ** (BigInt(k) - 1n))) / BigInt(k);
    if (y >= x) return x;
    x = y;
  }
}

const PRIMES = (() => {
  const out = [];
  for (let n = 2; out.length < 80; n++) if (out.every((p) => n % p)) out.push(n);
  return out;
})();
// The constants are what the standard says they are: fractional parts of roots of the first primes.
const SHA_K = PRIMES.map((p) => integerRoot(BigInt(p) << 192n, 3) & M64);
const SHA_H = PRIMES.slice(0, 8).map((p) => integerRoot(BigInt(p) << 128n, 2) & M64);
const rotr = (x, n) => ((x >> n) | (x << (64n - n))) & M64;

function sha512(bytes) {
  const length = bytes.length;
  const padded = new Uint8Array(((length + 17 + 127) >> 7) << 7);
  padded.set(bytes);
  padded[length] = 0x80;
  const bits = BigInt(length) * 8n;
  for (let i = 0; i < 8; i++) padded[padded.length - 1 - i] = Number((bits >> BigInt(8 * i)) & 0xffn);
  let h = SHA_H.slice();
  const w = new Array(80);
  for (let offset = 0; offset < padded.length; offset += 128) {
    for (let i = 0; i < 16; i++) {
      let v = 0n;
      for (let j = 0; j < 8; j++) v = (v << 8n) | BigInt(padded[offset + 8 * i + j]);
      w[i] = v;
    }
    for (let i = 16; i < 80; i++) {
      const s0 = rotr(w[i - 15], 1n) ^ rotr(w[i - 15], 8n) ^ (w[i - 15] >> 7n);
      const s1 = rotr(w[i - 2], 19n) ^ rotr(w[i - 2], 61n) ^ (w[i - 2] >> 6n);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & M64;
    }
    let [a, b, c, d, e, f, g, hh] = h;
    for (let i = 0; i < 80; i++) {
      const t1 = (hh + (rotr(e, 14n) ^ rotr(e, 18n) ^ rotr(e, 41n)) + ((e & f) ^ (~e & M64 & g)) + SHA_K[i] + w[i]) & M64;
      const t2 = ((rotr(a, 28n) ^ rotr(a, 34n) ^ rotr(a, 39n)) + ((a & b) ^ (a & c) ^ (b & c))) & M64;
      hh = g; g = f; f = e; e = (d + t1) & M64; d = c; c = b; b = a; a = (t1 + t2) & M64;
    }
    h = [h[0] + a, h[1] + b, h[2] + c, h[3] + d, h[4] + e, h[5] + f, h[6] + g, h[7] + hh].map((v) => v & M64);
  }
  const out = new Uint8Array(64);
  h.forEach((v, i) => { for (let j = 0; j < 8; j++) out[8 * i + j] = Number((v >> BigInt(56 - 8 * j)) & 0xffn); });
  return out;
}

function utf8(text) {
  if (typeof TextEncoder !== "undefined") return new TextEncoder().encode(text);
  return Uint8Array.from(unescape(encodeURIComponent(text)), (ch) => ch.charCodeAt(0));
}

class PyRandom {
  constructor(seedText) {
    this.mt = new Uint32Array(624);
    this.index = 625;
    const text = utf8(String(seedText));
    const digest = sha512(text);
    const bytes = new Uint8Array(text.length + 64);          // int.from_bytes(a + sha512(a).digest(), "big")
    bytes.set(text);
    bytes.set(digest, text.length);
    let start = 0;
    while (start < bytes.length - 1 && bytes[start] === 0) start++;
    const sig = bytes.subarray(start);
    const bits = sig.length * 8 - (Math.clz32(sig[0]) - 24);
    const count = bits <= 0 ? 1 : Math.floor((bits - 1) / 32) + 1;
    const key = new Uint32Array(count);                      // 32-bit words, least significant first
    for (let i = 0; i < count; i++) {
      let v = 0;
      for (let j = 0; j < 4; j++) {
        const at = sig.length - 1 - (4 * i + j);
        if (at >= 0) v |= sig[at] << (8 * j);
      }
      key[i] = v >>> 0;
    }
    this._initByArray(key);
  }

  _initGenrand(s) {
    const mt = this.mt;
    mt[0] = s >>> 0;
    for (let i = 1; i < 624; i++) mt[i] = (Math.imul(1812433253, mt[i - 1] ^ (mt[i - 1] >>> 30)) + i) >>> 0;
    this.index = 624;
  }

  _initByArray(key) {
    const mt = this.mt;
    this._initGenrand(19650218);
    let i = 1, j = 0;
    for (let k = Math.max(624, key.length); k; k--) {
      mt[i] = ((mt[i] ^ Math.imul(mt[i - 1] ^ (mt[i - 1] >>> 30), 1664525)) + key[j] + j) >>> 0;
      i++; j++;
      if (i >= 624) { mt[0] = mt[623]; i = 1; }
      if (j >= key.length) j = 0;
    }
    for (let k = 623; k; k--) {
      mt[i] = ((mt[i] ^ Math.imul(mt[i - 1] ^ (mt[i - 1] >>> 30), 1566083941)) - i) >>> 0;
      i++;
      if (i >= 624) { mt[0] = mt[623]; i = 1; }
    }
    mt[0] = 0x80000000;
  }

  _next32() {
    const mt = this.mt;
    if (this.index >= 624) {
      for (let k = 0; k < 624; k++) {
        const y = (mt[k] & 0x80000000) | (mt[(k + 1) % 624] & 0x7fffffff);
        mt[k] = mt[(k + 397) % 624] ^ (y >>> 1) ^ (y & 1 ? 0x9908b0df : 0);
      }
      this.index = 0;
    }
    let y = mt[this.index++];
    y ^= y >>> 11;
    y ^= (y << 7) & 0x9d2c5680;
    y ^= (y << 15) & 0xefc60000;
    y ^= y >>> 18;
    return y >>> 0;
  }

  random() {
    const a = this._next32() >>> 5, b = this._next32() >>> 6;
    return (a * 67108864 + b) * (1 / 9007199254740992);
  }

  _randbelow(n) {
    const k = 32 - Math.clz32(n);
    let r = this._next32() >>> (32 - k);
    while (r >= n) r = this._next32() >>> (32 - k);
    return r;
  }

  uniform(a, b) { return a + (b - a) * this.random(); }
  randrange(n) { return this._randbelow(n); }
  choice(list) { return list[this._randbelow(list.length)]; }

  choices(population, weights) {                             // one draw: random.choices(..., k=1)[0]
    const cumulative = [];
    let total = 0;
    for (const w of weights) { total += w; cumulative.push(total); }
    const x = this.random() * (total + 0.0);
    let lo = 0, hi = population.length - 1;                  // bisect_right(cumulative, x, 0, n - 1)
    while (lo < hi) {
      const mid = (lo + hi) >> 1;
      if (x < cumulative[mid]) hi = mid; else lo = mid + 1;
    }
    return population[lo];
  }

  shuffle(list) {
    for (let i = list.length - 1; i >= 1; i--) {
      const j = this._randbelow(i + 1);
      [list[i], list[j]] = [list[j], list[i]];
    }
  }
}

// ---------------------------------------------------------------------------
// The boundary (guard.py): play preferences and nothing else
// ---------------------------------------------------------------------------

const PLACEHOLDER = "[removed: outside play preferences]";
const TRAIT_TERMS = new RegExp(
  "\\b(" +
  "depress(ion|ed|ive)|anxiety disorder|adhd|autis\\w*|ocd|bipolar|schizo\\w*|narcissis\\w*|" +
  "psychopath\\w*|sociopath\\w*|ptsd|neurodiverg\\w*|neurotypical|suicid\\w*|self[- ]harm|" +
  "diagnos\\w*|personality disorder|mental(ly)? (ill\\w*|health|disorder)|" +
  "iq|sexual orientation|sexuality|heterosexual|homosexual|lesbian|bisexual|transgender|" +
  "political (view|views|leaning|leanings|belief|beliefs|affiliation)|republican|democrat|" +
  "left[- ]wing|right[- ]wing|" +
  "christian|muslim|jewish|hindu|buddhist|atheist|religious (belief|beliefs|background)|" +
  "ethnicity|ethnic background|racial|nationality|immigrant|" +
  "disabled|disability|handicapped" +
  ")\\b", "i");
const ABOUT_PLAYER = new RegExp(
  "\\b(player|bearer|user|they|he|she|this person|someone|anyone)(\\s+who)?\\s+" +
  "(is|are|seems?|appears?|sounds?|must be|may be|might be|could be|is probably|is likely|is clearly)\\s+" +
  "(an? |not |very |quite |rather |really |so |too |probably |likely )*" +
  "(child|kid|teen\\w*|minor|adult|elderly|old|young|man|woman|boy|girl|male|female|" +
  "smart|stupid|dumb|clever|intelligent|unintelligent|genius|slow|" +
  "addict\\w*|traumati[sz]ed|anxious|depressed|lonely|autistic|gay|straight|trans|" +
  "religious|liberal|conservative)\\b" +
  "|\\b(their|his|her|the (player|bearer|user)'s)\\s+" +
  "(age|gender|sex|race|religion|politics|intelligence|iq|mental|trauma|orientation|disability|" +
  "childhood|upbringing|marriage|job|income|health)\\b", "i");

const guard = {
  PLACEHOLDER,
  sensitive(text) {
    return typeof text === "string" && text.length > 0 && (TRAIT_TERMS.test(text) || ABOUT_PLAYER.test(text));
  },
  scrub(text, log, where, turn) {
    text = typeof text === "string" ? text : String(text);
    if (guard.sensitive(text)) {
      if (log) log.push({ guard: "sensitive_text_removed", where: where || "", turn: turn === undefined ? null : turn });
      return PLACEHOLDER;
    }
    return text;
  },
  removed(text) { return typeof text === "string" && text.startsWith("[removed"); },
};

// ---------------------------------------------------------------------------
// The player model (model.py)
// ---------------------------------------------------------------------------

const STRENGTH_WEIGHT = { weak: 0.3, moderate: 0.6, strong: 1.0 };
const KIND_FACTOR = { behavioral: 1.0, explicit: 0.7 };
const PRIOR = 1.0, SAME_SCENE_DISCOUNT = 0.5, MIN_INDEPENDENT_WEIGHT = 0.08;
const CONFIDENCE_CAP = { 0: 0.0, 1: 0.35, 2: 0.70 }, CONFIDENCE_CAP_DEFAULT = 0.97;
const UNKNOWN_MASS = 0.15, CONTESTED_MASS = 0.6, CONTESTED_RATIO = 0.5, AMBIGUOUS_TOP_SHARE = 0.6;
const ESTABLISHED_CONFIDENCE = 0.6, LEANING_CONFIDENCE = 0.3;

// math.lgamma, as CPython computes it (Lanczos, N = 13).
const LANCZOS_G = 6.024680040776729583740234375;
const LANCZOS_NUM = [23531376880.410759688572007674451636754734846804940, 42919803642.649098768957899047001988850926355848959,
  35711959237.355668049440185451547166705960488635843, 17921034426.037209699919755754458931112671403265390,
  6039542586.3520280050642916443072979210699388420708, 1439720407.3117216736632230727949123939715485786772,
  248874557.86205415651146038641322942321632125127801, 31426415.585400194380614231628318205362874684987640,
  2876370.6289353724412254090516208496135991145378768, 186056.26539522349504029498971604569928220784236328,
  8071.6720023658162106380029022722506138218516325024, 210.82427775157934587250973392071336271166969580291,
  2.5066282746310002701649081771338373386264310793408];
const LANCZOS_DEN = [0.0, 39916800.0, 120543840.0, 150917976.0, 105258076.0, 45995730.0, 13339535.0, 2637558.0,
  357423.0, 32670.0, 1925.0, 66.0, 1.0];

function lanczosSum(x) {
  let num = 0.0, den = 0.0;
  if (x < 5.0) {
    for (let i = 12; i >= 0; i--) { num = num * x + LANCZOS_NUM[i]; den = den * x + LANCZOS_DEN[i]; }
  } else {
    for (let i = 0; i < 13; i++) { num = num / x + LANCZOS_NUM[i]; den = den / x + LANCZOS_DEN[i]; }
  }
  return num / den;
}

function lgamma(x) {                                          // for the x > 0 this program gives it
  if (x === Math.floor(x) && x <= 2.0) return 0.0;
  let r = Math.log(lanczosSum(x)) - LANCZOS_G;
  r += (x - 0.5) * (Math.log(x + LANCZOS_G - 0.5) - 1);
  return r;
}

function betacf(a, b, x) {
  const tiny = 1e-300;
  const qab = a + b, qap = a + 1.0, qam = a - 1.0;
  let c = 1.0, d = 1.0 - qab * x / qap;
  if (Math.abs(d) < tiny) d = tiny;
  d = 1.0 / d;
  let h = d;
  for (let m = 1; m < 300; m++) {
    const m2 = 2 * m;
    let aa = m * (b - m) * x / ((qam + m2) * (a + m2));
    d = 1.0 + aa * d;
    if (Math.abs(d) < tiny) d = tiny;
    c = 1.0 + aa / c;
    if (Math.abs(c) < tiny) c = tiny;
    d = 1.0 / d;
    h *= d * c;
    aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
    d = 1.0 + aa * d;
    if (Math.abs(d) < tiny) d = tiny;
    c = 1.0 + aa / c;
    if (Math.abs(c) < tiny) c = tiny;
    d = 1.0 / d;
    const delta = d * c;
    h *= delta;
    if (Math.abs(delta - 1.0) < 3e-12) break;
  }
  return h;
}

function betainc(a, b, x) {
  if (x <= 0.0) return 0.0;
  if (x >= 1.0) return 1.0;
  const lnBt = lgamma(a + b) - lgamma(a) - lgamma(b) + a * Math.log(x) + b * Math.log(1.0 - x);
  const bt = Math.exp(lnBt);
  if (x < (a + 1.0) / (a + b + 2.0)) return bt * betacf(a, b, x) / a;
  return 1.0 - bt * betacf(b, a, 1.0 - x) / b;
}

const salience = (st, importance) => Math.abs(st.value) * st.confidence * (importance === undefined ? 1.0 : importance);
const massOf = (st) => st.support + st.against;

class PlayerModel {
  constructor(registry, observations) {
    this.registry = registry;
    this.observations = observations || [];
    this._states = null;
  }

  add({ turn, scene, seed, frame, action, hypotheses, kind = "behavioral", strength = "weak", context = "",
        source = "llm", signal = "" }) {
    if (!(kind in KIND_FACTOR)) kind = "behavioral";
    if (!(strength in STRENGTH_WEIGHT)) strength = "weak";
    const clean = [];
    for (let h of hypotheses || []) {
      if (Array.isArray(h) && h.length >= 3) h = { dim: h[0], dir: h[1], share: h[2] };
      if (!h || typeof h !== "object" || Array.isArray(h)) continue;
      if (!(h.dim in this.registry.dims)) continue;
      const direction = Number(h.dir === undefined ? 0 : h.dir), share = Number(h.share === undefined ? 0 : h.share);
      if (Number.isNaN(direction) || Number.isNaN(share) || direction === 0 || share <= 0) continue;
      clean.push({ dim: h.dim, dir: direction > 0 ? 1 : -1, share: Math.min(share, 1.0),
                   why: cut(String(h.why === undefined ? "" : h.why), 160), posterior: null });
    }
    if (!clean.length) return null;
    const total = pySum(clean.map((h) => h.share));
    if (total > 1.0) for (const h of clean) h.share /= total;
    const obs = { id: this.observations.length + 1, turn, scene, seed, frame, kind, strength,
                  action: cut(String(action), 200), context: cut(String(context), 200), hypotheses: clean,
                  source, signal };
    this.observations.push(obs);
    this._states = null;
    return obs;
  }

  _accumulate(usePosterior) {
    const pos = {}, neg = {}, perScene = {}, seen = {}, contributions = {};
    for (const obs of this.observations) {
      const base = STRENGTH_WEIGHT[obs.strength] * KIND_FACTOR[obs.kind];
      for (const h of obs.hypotheses) {
        const share = usePosterior && h.posterior !== null && h.posterior !== undefined ? h.posterior : h.share;
        const key = h.dim + "|" + h.dir + "|" + obs.scene;
        const weight = base * share * Math.pow(SAME_SCENE_DISCOUNT, seen[key] || 0);
        seen[key] = (seen[key] || 0) + 1;
        const side = h.dir > 0 ? pos : neg;
        side[h.dim] = (side[h.dim] || 0.0) + weight;
        perScene[key] = (perScene[key] || 0.0) + weight;
        (contributions[h.dim] = contributions[h.dim] || []).push([obs, h.dir, weight]);
      }
    }
    return [pos, neg, perScene, contributions];
  }

  compute() {
    if (this._states) return this._states;
    let [pos, neg, perScene, contributions] = this._accumulate(false);
    for (const obs of this.observations) {
      const hs = obs.hypotheses;
      const ambiguous = hs.length >= 2 && new Set(hs.map((h) => h.dim)).size >= 2 &&
        Math.max(...hs.map((h) => h.share)) <= AMBIGUOUS_TOP_SHARE;
      if (!ambiguous) { for (const h of hs) h.posterior = h.share; continue; }
      const total = pySum(hs.map((h) => h.share));
      const raw = [];
      for (const h of hs) {
        const everywhere = (h.dir > 0 ? pos : neg)[h.dim] || 0.0;
        const here = perScene[h.dim + "|" + h.dir + "|" + obs.scene] || 0.0;
        const elsewhere = Math.max(0.0, everywhere - here);
        raw.push(h.share * (0.5 + Math.min(elsewhere, 2.0)));
      }
      const norm = pySum(raw) || 1.0;
      hs.forEach((h, i) => { h.posterior = total * raw[i] / norm; });
    }
    [pos, neg, perScene, contributions] = this._accumulate(true);

    const states = {};
    for (const dim of Object.keys(this.registry.dims)) {
      const st = { id: dim, value: 0.0, confidence: 0.0, status: "unknown", support: pos[dim] || 0.0,
                   against: neg[dim] || 0.0, n_observations: 0, n_independent: 0, n_frames: 0, last_turn: null,
                   explicit: 0, behavioral: 0, supporting: [], contradicting: [] };
      const alpha = PRIOR + st.support, beta = PRIOR + st.against;
      st.value = 2.0 * alpha / (alpha + beta) - 1.0;
      const pPositive = 1.0 - betainc(alpha, beta, 0.5);
      const directionConfidence = 2.0 * Math.abs(pPositive - 0.5);
      const scenes = new Set(), frames = new Set();
      for (const [obs, direction] of contributions[dim] || []) {
        st.n_observations += 1;
        st.last_turn = st.last_turn === null ? obs.turn : Math.max(st.last_turn, obs.turn);
        if (obs.kind === "explicit") st.explicit += 1; else st.behavioral += 1;
        if ((perScene[dim + "|" + direction + "|" + obs.scene] || 0.0) >= MIN_INDEPENDENT_WEIGHT) {
          scenes.add(obs.scene);
          frames.add(obs.frame);
        }
        const agrees = (direction > 0) === (st.value >= 0);
        (agrees ? st.supporting : st.contradicting).push(obs.id);
      }
      st.n_independent = scenes.size;
      st.n_frames = frames.size;
      const cap = st.n_independent in CONFIDENCE_CAP ? CONFIDENCE_CAP[st.n_independent] : CONFIDENCE_CAP_DEFAULT;
      st.confidence = Math.min(directionConfidence, cap);
      const lo = Math.min(st.support, st.against), hi = Math.max(st.support, st.against);
      const contested = lo >= CONTESTED_MASS && hi > 0 && lo / hi >= CONTESTED_RATIO;
      if (massOf(st) < UNKNOWN_MASS) st.status = "unknown";
      else if (contested) st.status = "contested";
      else if (st.confidence >= ESTABLISHED_CONFIDENCE && st.n_independent >= 3) st.status = "established";
      else if (st.confidence >= LEANING_CONFIDENCE) st.status = "leaning";
      else st.status = "faint";
      states[dim] = st;
    }
    this._states = states;
    return states;
  }

  state(dim) { return this.compute()[dim]; }

  ambiguities() {
    this.compute();
    const out = [];
    for (const obs of this.observations) {
      const hs = obs.hypotheses;
      if (!(hs.length >= 2 && new Set(hs.map((h) => h.dim)).size >= 2 &&
            Math.max(...hs.map((h) => h.share)) <= AMBIGUOUS_TOP_SHARE)) continue;
      const total = pySum(hs.map((h) => h.share)) || 1.0;
      const posts = hs.map((h) => h.posterior || h.share).sort((a, b) => b - a);
      const topPosterior = posts[0] / total;
      const runnerUp = posts[0] ? posts[1] / posts[0] : 0.0;
      out.push({ observation: obs.id, turn: obs.turn, scene: obs.scene, action: obs.action,
                 candidates: hs.map((h) => ({ dim: h.dim, dir: h.dir })),
                 open: topPosterior < 0.55 && runnerUp > 0.6 });
    }
    return out;
  }

  ranked(families, minStatus = true) {
    const dims = this.registry.dims;
    const states = Object.values(this.compute()).filter((s) =>
      (!families || families.includes(dims[s.id].family)) && (!minStatus || s.status !== "unknown"));
    return states.sort((a, b) => salience(b, dims[b.id].importance) - salience(a, dims[a.id].importance));
  }

  evidence(dim, limit = 4) {
    const st = this.state(dim);
    const byId = {};
    for (const o of this.observations) byId[o.id] = o;
    return [st.supporting.slice(-limit).map((i) => byId[i].action), st.contradicting.slice(-limit).map((i) => byId[i].action)];
  }
}

// ---------------------------------------------------------------------------
// Choosing what the house deals next (probes.py)
// ---------------------------------------------------------------------------

const INTENSITY = { hazard: 2, pursuit: 2, skill: 2, chance: 2, power: 2, spectacle: 2,
                    quiet: 0, make: 0, collect: 0, long: 0, explore: 0, plan: 0 };
const KNOWN_ENOUGH = 0.75, SHORTLIST = 5, TEMPERATURE = 0.3;
let trace = null;                                             // set by a test to see why a room was dealt
const parseSigned = (token) => [token.slice(0, -1), token.endsWith("+") ? 1 : -1];
const chamberSeeds = (registry) => Object.values(registry.seeds).filter((s) => !s.role || s.role === "callback");
const openerSeed = (registry) => Object.values(registry.seeds).find((s) => s.role === "opener");
const finaleSeed = (registry) => Object.values(registry.seeds).find((s) => s.role === "finale");

function need(registry, model, dim) {
  const st = model.state(dim), d = registry.dims[dim];
  if (st.confidence >= KNOWN_ENOUGH && st.n_independent >= 3 && st.status !== "contested") return 0.0;
  let value = d.importance * (1.0 - st.confidence);
  if (st.status === "contested") value *= 1.3;
  else if (st.status !== "unknown" && st.n_independent < 3) value *= 1.5;
  return value;
}

function eligible(seed, nextChamber, world) {
  const req = seed.requires || {};
  if (req.joker && world.joker !== "kept") return false;
  if ("min_chamber" in req && nextChamber < req.min_chamber) return false;
  if ("max_chamber" in req && nextChamber > req.max_chamber) return false;
  if (req.threads && !world.threads.length) return false;
  return true;
}

function disambiguation(seed, ambiguities) {
  let bonus = 0.0;
  const pairs = (seed.separates || []).map(([a, b]) => [parseSigned(a), parseSigned(b)]);
  for (const amb of ambiguities) {
    if (!amb.open) continue;
    const cands = new Set(amb.candidates.map((c) => c.dim + "|" + c.dir));
    const candDims = new Set(amb.candidates.map((c) => c.dim));
    for (const [left, right] of pairs) {
      if (cands.has(left[0] + "|" + left[1]) && cands.has(right[0] + "|" + right[1])) bonus += 0.6;
      else if (candDims.has(left[0]) && candDims.has(right[0])) bonus += 0.3;
    }
  }
  return Math.min(bonus, 1.2);
}

function selectSeed(registry, model, { used, nextChamber, chamberTarget, world, rng }) {
  const ambiguities = model.ambiguities();
  const kindsUsed = used.filter((s) => s in registry.seeds).map((s) => registry.seeds[s].kind);
  const lastKind = kindsUsed.length ? kindsUsed[kindsUsed.length - 1] : null;
  const candidates = [];
  for (const seed of chamberSeeds(registry)) {
    if (used.includes(seed.id) || !eligible(seed, nextChamber, world)) continue;
    const contributions = Object.entries(seed.targets).map(([dim, power]) => power * need(registry, model, dim));
    const info = pySum(contributions) / Math.sqrt(contributions.length);
    const disamb = disambiguation(seed, ambiguities);
    let variety = 0.0;
    const kind = seed.kind;
    if (kind === lastKind) variety -= 0.5;
    else if (kindsUsed.slice(-3).includes(kind)) variety -= 0.25;
    if (!kindsUsed.includes(kind)) variety += 0.2;
    if (lastKind !== null) {
      const a = kind in INTENSITY ? INTENSITY[kind] : 1, b = lastKind in INTENSITY ? INTENSITY[lastKind] : 1;
      if (a === b && a !== 1) variety -= 0.2;
    }
    let timing = 0.0;
    if (seed.role === "callback") timing = nextChamber >= chamberTarget - 1 ? 0.8 : -0.5;
    const jitter = rng.uniform(0.0, 0.15);
    const score = info + disamb + variety + timing + jitter;
    candidates.push({ seed: seed.id, kind, score: pyRound(score, 3), raw: score });
  }
  if (!candidates.length) throw new Error("no eligible chamber seeds remain");
  candidates.sort((a, b) => b.score - a.score);
  const shortlist = candidates.slice(0, SHORTLIST);
  const weights = shortlist.map((c) => Math.exp((c.score - shortlist[0].score) / TEMPERATURE));
  const chosen = rng.choices(shortlist, weights).seed;
  if (trace) trace({ what: "seed", nextChamber, shortlist, weights, chosen });
  return chosen;
}

function selectSkins(registry, model, { taken, offered, rng, count = 3 }) {
  const recent = new Set(offered.slice(-2).flat());
  const all = Object.values(registry.skins);
  let pool = all.filter((s) => !taken.includes(s.id));
  if (!pool.length) pool = all;
  const scored = {};
  for (const skin of pool) {
    let score = pySum(Object.keys(skin.aesthetic).map((axis) => need(registry, model, axis)));
    score += 0.5 * pySum(Object.keys(skin.tone).map((t) => need(registry, model, "tone." + t)));
    if (recent.has(skin.id)) score -= 0.8;
    scored[skin.id] = score + rng.uniform(0.0, 0.2);
  }
  const picked = [];
  while (picked.length < Math.min(count, pool.length)) {
    let best = null, bestScore = -1e9;
    for (const skin of pool) {
      if (picked.includes(skin.id)) continue;
      let contrast = 0.0;
      for (const otherId of picked) {
        const other = registry.skins[otherId];
        for (const [axis, direction] of Object.entries(skin.aesthetic)) {
          if (axis in other.aesthetic) {
            if (other.aesthetic[axis] !== direction) contrast += need(registry, model, axis);
            else contrast -= 0.4;
          }
        }
        contrast -= 0.3 * Object.keys(skin.tone).filter((t) => t in other.tone).length;
      }
      const total = scored[skin.id] + contrast;
      if (total > bestScore) { best = skin.id; bestScore = total; }
    }
    picked.push(best);
  }
  rng.shuffle(picked);
  return picked;
}

function skinEvidence(registry, chosen, offered) {
  const skin = registry.skins[chosen];
  const others = offered.filter((s) => s !== chosen && s in registry.skins).map((s) => registry.skins[s]);
  const raw = [];
  for (const [axis, direction] of Object.entries(skin.aesthetic)) {
    const opposed = others.filter((o) => o.aesthetic[axis] === -direction).length;
    raw.push([axis, direction, 1.0 + opposed]);
  }
  const total = pySum(raw.map((r) => r[2])) || 1.0;
  const out = [];
  if (raw.length) {
    out.push({
      action: "took the way of " + skin.threshold.split(",")[0].split(";")[0],
      context: others.length ? "chosen over " + others.map((o) => o.id).join("; ") : "the only way offered",
      kind: "behavioral", strength: "moderate",
      hypotheses: raw.map(([axis, direction, weight]) => ({ dim: axis, dir: direction, share: weight / total,
                                                            why: "one quality of the way they took" })),
    });
  }
  let tones = Object.keys(skin.tone).filter((t) => !others.some((o) => t in o.tone));
  if (!tones.length) tones = Object.keys(skin.tone);
  if (tones.length) {
    out.push({
      action: "took the " + chosen + " way", context: "the mood of the way they took",
      kind: "behavioral", strength: "weak",
      hypotheses: tones.map((t) => ({ dim: "tone." + t, dir: 1, share: 1.0 / tones.length,
                                      why: "the mood of the way they took" })),
    });
  }
  return out;
}

// ---------------------------------------------------------------------------
// The house as authored (offline.py)
// ---------------------------------------------------------------------------

const GENERIC = new Set(["look", "examine", "inspect", "search", "ask", "?", "go", "take", "no", "yes", "open", "leave",
                         "wait", "read", "why", "where", "around", "room", "play", "nothing", "again", "up", "down"]);
const CARD_LINES = ["Inside your coat, one of the cards has grown warm.",
                    "Against your ribs, a card shifts, like something settling.",
                    "One card in the deck is warm now. You can tell which without looking."];
const LAST_STAIR = "A last narrow stair goes up from here, to a door with lamplight under it. You climb.";
const HIDDEN_TAGS = new Set(["exploit", "transgress", "trick"]);
const FILLER = new Set(["me", "please", "a", "an", "any", "some", "i", "am", "im", "i'm", "need", "want", "give", "more"]);
const NOT_ENOUGH_MATCHES = "You count your matches, twice. Not enough for that. The house does not give credit. " +
                           "It waits to see what you will do instead.";
const JOKER_ANYWHERE = "You lay the Joker down and say what you want. For the length of one breath the house is " +
                       "silent. Then it is so. What you said, goes: the room gives way before you as if it had " +
                       "only been waiting to be told. The Joker is gone from your hand, and the air smells of a " +
                       "struck match.";
const PENCILLED = "A blank card has worked a little way out of the deck. Pencilled on it, and fading as you read: ";

const containsCache = new Map();
const PLAIN_KEYWORD = new RegExp("^[\\p{L}\\p{N}_' -]+$", "u");
function contains(text, keyword) {
  keyword = lower(keyword);
  if (keyword === "?") return text.includes("?");
  let test = containsCache.get(keyword);
  if (test === undefined) {
    test = PLAIN_KEYWORD.test(keyword)
      ? new RegExp("(?<!" + WORD + ")" + escapeRegExp(keyword) + "(?!" + WORD + ")", "u") : null;
    containsCache.set(keyword, test);
  }
  return test ? test.test(text) : text.includes(keyword);
}

function shortWay(skin) {
  const head = strip(skin.threshold.split(/[,;]/)[0]);
  if (head.startsWith("an ")) return "the " + head.slice(3);
  if (head.startsWith("a ")) return "the " + head.slice(2);
  return head;
}

function thresholdsText(registry, skinIds) {
  const places = skinIds.length >= 3 ? ["To the left, ", "Ahead, ", "To the right, "] : ["To the left, ", "To the right, "];
  return "The way on divides. " + skinIds.slice(0, 3).map((s, i) => places[i] + registry.skins[s].threshold + ".").join(" ");
}

function stageText(registry, seed, skin, world, houseChose) {
  const parts = [];
  if (skin) {
    const manner = skin.manner[0].toLowerCase() + skin.manner.slice(1);
    if (houseChose) {
      parts.push("While you consider, " + shortWay(skin) + " opens of its own accord, and the house, " +
                 "tired of waiting, takes you through. On this side, the house is " + manner);
    } else {
      parts.push("You take " + shortWay(skin) + ". On this side, the house is " + manner);
    }
  }
  let intro = seed.intro;
  if (seed.role === "callback" && world.threads.length) intro += " What the glass holds, exactly as you left it: " + world.threads[0] + ".";
  parts.push(intro);
  return parts.join("\n\n");
}

function describe(seed, option, outcome) {
  const text = strip(outcome);
  const at = text.search(/(?<=[.!?])\s/);
  const first = (at < 0 ? text : text.slice(0, at)).replace(/[.!?]+$/, "");
  if (first.startsWith("You ") && points(first).length <= 150) return "at " + seed.title + ": " + first.slice(4);
  return "at " + seed.title + ": " + replaceAll(option.id, "_", " ");
}

function whenOk(option, flags) {
  const when = option.when || {};
  if ("flag" in when && !flags[when.flag]) return false;
  if ("not_flag" in when && flags[when.not_flag]) return false;
  return true;
}

const availableOptions = (seed, flags) => seed.options.filter((o) => whenOk(o, flags));

function matchOption(seed, flags, text) {
  const low = strip(lower(text));
  if (low.startsWith("@")) {
    const wanted = strip(low.slice(1));
    const found = availableOptions(seed, flags).find((o) => o.id === wanted);
    return found ? [found, 99.0] : [null, 0.0];
  }
  let best = null, bestScore = 0.0;
  for (const option of availableOptions(seed, flags)) {
    let score = 0.0;
    for (const keyword of option.match) {
      if (contains(low, keyword)) {
        const kw = lower(keyword);
        score += GENERIC.has(kw) ? 0.6 : 1.0 + 0.5 * (kw.split(" ").length - 1) + 0.02 * points(kw).length;
      }
    }
    if (score > bestScore) { best = option; bestScore = score; }
  }
  return [best, bestScore];
}

function hintWords(seed, flags) {
  const out = [];
  for (const option of availableOptions(seed, flags)) {
    if ((option.tags || []).some((t) => HIDDEN_TAGS.has(t))) continue;
    const candidates = (option.word ? [option.word] : []).concat(option.match);
    const word = candidates.find((w) => matchOption(seed, flags, w)[0] === option);
    if (word && !out.includes(word)) out.push(word);
  }
  return out;
}

function pencilled(seed, flags) {
  const found = hintWords(seed, flags);
  return found.length ? PENCILLED + found.map((w) => w.toUpperCase()).join(" / ") + "." : "";
}

function matchThreshold(registry, skinIds, text) {
  const low = strip(lower(text));
  if (low.startsWith("@")) {
    const at = skinIds.indexOf(strip(low.slice(1)));
    return at < 0 ? null : at;
  }
  const scores = skinIds.map((sid) => registry.skins[sid].keywords.filter((kw) => contains(low, kw)).length);
  const top = scores.length ? Math.max(...scores) : 0;
  if (top > 0 && scores.filter((s) => s === top).length === 1) return scores.indexOf(top);
  const n = skinIds.length, last = n - 1;
  const bare = { a: 0, "1": 0, b: 1, "2": 1, c: 2, "3": 2 };
  if (Object.prototype.hasOwnProperty.call(bare, low) && bare[low] < n) return bare[low];
  const positional = [["left", 0], ["first", 0], ["right", last], ["last", last], ["third", 2], ["ahead", 1],
                      ["middle", 1], ["second", 1], ["centre", 1], ["center", 1], ["straight", 1]];
  for (const [word, index] of positional) {
    if (contains(low, word) && index < n) {
      if (n === 2 && ["ahead", "middle", "centre", "center", "straight"].includes(word)) continue;
      return index;
    }
  }
  return null;
}

const withExtra = (narration, extra) => (extra ? narration + "\n\n" + extra : narration);
const hypothesesOf = (triples) => triples.map(([dim, dir, share]) => ({ dim, dir, share }));

function turnResult(fields) {
  return Object.assign({ narration: "", status: "open", threshold_choice: null, house_chose: false, summary: "",
                         state: {}, observations: [], focus: [], ignored: [], attempted: null, card: null,
                         moment: null, source: "offline", option: null, addendum: "" }, fields);
}

class OfflineNarrator {
  constructor(registry) { this.registry = registry; }

  chamber(session, text, { soft, mustClose, lastChamber, finale }) {
    const scene = session.scene, world = session.world;
    const seed = this.registry.seeds[scene.seed];
    const flags = scene.flags;
    const asked = this.asksForHelp(text);
    let [option, score] = asked ? [null, 0.0] : matchOption(seed, flags, text);
    if (option !== null && score < 1.0 && this._plainSignal(text) !== null) option = null;
    let result;
    if (asked) {
      result = this._unmatched(seed, scene, text, world, true);
    } else if (option === null && contains(lower(text), "joker") && world.joker === "kept" && !finale) {
      result = turnResult({
        narration: JOKER_ANYWHERE, status: "resolved", option: "joker_anywhere", state: { joker: "played" },
        moment: "played the Joker in " + seed.title,
        observations: [{ action: "played the Joker in " + seed.title, kind: "behavioral", strength: "moderate",
                         context: "a single-use power, spent to end a room",
                         hypotheses: [{ dim: "reward.power", dir: 1, share: 0.4 }, { dim: "risk", dir: 1, share: 0.3 },
                                      { dim: "friction", dir: -1, share: 0.2 }] }] });
    } else if (option !== null) {
      const cost = (option.effects || {}).matches || 0;
      if (cost < 0 && world.matches + cost < 0) result = turnResult({ narration: NOT_ENOUGH_MATCHES, option: null });
      else result = this._take(seed, scene, option);
    } else {
      result = this._unmatched(seed, scene, text, world, false);
    }

    if (finale && option === null && result.option === null && !asked) result.status = "resolved";
    if (result.status !== "resolved") {
      if (mustClose) { result.narration += "\n\n" + seed.close; result.status = "resolved"; }
      else if (soft) result.narration += "\n\n" + seed.nudge;
    }
    if (result.card) result.narration += "\n\n" + CARD_LINES[world.cards.length % CARD_LINES.length];
    if (result.status === "resolved" && !finale) {
      if (lastChamber) result.narration += "\n\n" + LAST_STAIR;
      else if (scene.thresholds && scene.thresholds.length) result.narration += "\n\n" + thresholdsText(this.registry, scene.thresholds);
    }
    return result;
  }

  _take(seed, scene, option) {
    let outcome;
    if ("outcomes" in option) {
      scene.counters = scene.counters || {};
      const n = scene.counters[option.counter] || 0;
      outcome = option.outcomes[Math.min(n, option.outcomes.length - 1)];
      scene.counters[option.counter] = n + 1;
    } else {
      outcome = option.outcome;
    }
    const action = option.moment || option.did || describe(seed, option, outcome);
    const observations = [];
    if (option.obs && option.obs.length) {
      observations.push({ action, kind: "behavioral", strength: option.strength || "moderate", context: seed.title,
                          hypotheses: hypothesesOf(option.obs) });
    }
    const effects = option.effects || {};
    const state = {};
    for (const [k, v] of Object.entries(effects)) if (k !== "matches") state[k] = v;
    if ("matches" in effects) state.matches_delta = effects.matches;
    return turnResult({ narration: outcome, status: option.resolves ? "resolved" : "open", state, observations,
                        card: option.card || null, moment: option.moment || null, option: option.id,
                        focus: [option.id], summary: option.moment || replaceAll(option.id, "_", " ") });
  }

  _plainSignal(text) {
    const low = lower(text);
    for (const signal of Object.values(this.registry.signals)) {
      if (signal.obs.length && (signal.detect || []).some((kw) => kw.includes(" ") && contains(low, kw))) return signal;
    }
    return null;
  }

  _detected(low) {
    let best = null, bestLen = 0;
    for (const signal of Object.values(this.registry.signals)) {
      if (!signal.obs.length) continue;
      for (const keyword of signal.detect || []) {
        const size = points(keyword).length;
        if (size > bestLen && contains(low, keyword)) { best = signal; bestLen = size; }
      }
    }
    return best;
  }

  asksForHelp(text) {
    const low = squash(lower(text).replace(/[?!.,]/g, " "));
    if (!low) return false;
    const list = low.split(" ");
    if (list.includes("hint") || list.includes("hints")) return true;
    const bare = list.filter((w) => !FILLER.has(w)).join(" ");
    for (const keyword of this.registry.signals.asks_what_to_do.detect || []) {
      if (keyword.includes(" ")) { if (contains(low, keyword)) return true; }
      else if (bare === keyword) return true;
    }
    return false;
  }

  _unmatched(seed, scene, text, world, asked) {
    const low = lower(text);
    scene.unmatched = (scene.unmatched || 0) + 1;
    const signal = asked ? this.registry.signals.asks_what_to_do : this._detected(low);
    asked = asked || (signal !== null && signal.id === "asks_what_to_do");
    const helpNow = asked || (scene.unmatched >= 2 && !scene.helped);
    if (helpNow) scene.helped = true;
    if (signal !== null) {
      let narration = signal.generic_outcome || seed.fallback;
      if (signal.id === "checks_inventory" && world) narration = "You take stock. You are carrying: " + carrying(world) + ".";
      else if (helpNow) narration += " " + seed.hint;
      if (helpNow) narration = withExtra(narration, pencilled(seed, scene.flags));
      return turnResult({ narration, option: null,
        observations: [{ action: signal.seen || signal.desc, kind: signal.kind || "behavioral",
                         strength: signal.strength || "weak", context: seed.title, signal: signal.id,
                         hypotheses: hypothesesOf(signal.obs) }] });
    }
    let narration = seed.fallback;
    if (helpNow) narration = withExtra(narration + " " + seed.hint, pencilled(seed, scene.flags));
    const result = turnResult({ narration, option: null });
    if (splitWords(text).length >= 3) {
      result.attempted = cut(squash(text), 90);
      result.observations.push({
        action: 'tried something the room had not offered: "' + cut(result.attempted, 60) + '"',
        kind: "behavioral", strength: "weak", context: seed.title, signal: "novel_command",
        hypotheses: hypothesesOf(this.registry.signals.novel_command.obs) });
    }
    return result;
  }

  threshold(session, text, { force, nextSeed }) {
    const scene = session.scene, world = session.world;
    const skins = scene.thresholds;
    let index = matchThreshold(this.registry, skins, text);
    let houseChose = false;
    if (index === null) {
      if (!force) {
        return turnResult({ narration: "The ways wait, each as it was. " +
                              thresholdsText(this.registry, skins).replace("The way on divides. ", ""),
                            status: "threshold" });
      }
      index = sessionRng(session, "house-picks").randrange(skins.length);
      houseChose = true;
    }
    const skin = this.registry.skins[skins[index]];
    return turnResult({ narration: stageText(this.registry, nextSeed, skin, world, houseChose), status: "open",
                        threshold_choice: index, house_chose: houseChose, summary: "took " + shortWay(skin) });
  }
}

// ---------------------------------------------------------------------------
// One night: its state (session.py) and its turn loop (engine.py)
// ---------------------------------------------------------------------------

const LENGTHS = { short: 4, standard: 6, long: 8 };
const SOFT_CAP = 3, HARD_CAP = 5, READING_SOFT_CAP = 1, READING_HARD_CAP = 2;

function newWorld() {
  return { matches: 3, joker: "kept", joker_chamber: null, ribbon_untied: false, inventory: [], companion: null,
           npcs: [], flags: {}, threads: [], threads_resolved: [], failures: 0, cards: [], moments: [], focus: {},
           ignored: [], attempted: [], summaries: [], signals: {} };
}

function carrying(world) {
  const deck = world.ribbon_untied ? "the deck of blank cards (ribbon untied)" : "the deck of blank cards, tied in ribbon";
  const joker = world.joker === "kept" ? "the Joker (unplayed)" : "";
  const matches = world.matches === 0 ? "no matches" : world.matches === 1 ? "1 match" : world.matches + " matches";
  return [deck, joker, matches].concat(world.inventory).filter(Boolean).join("; ");
}

function newSession(config, seed) {
  const now = Date.now() / 1000;
  if (seed === undefined || seed === null) {
    const box = new Uint32Array(1);
    if (typeof crypto !== "undefined" && crypto.getRandomValues) crypto.getRandomValues(box);
    else box[0] = Math.floor(Math.random() * 4294967296);
    seed = 1 + (box[0] % 2147483647);
  }
  const d = new Date(now * 1000), two = (n) => String(n).padStart(2, "0");
  const id = "" + d.getFullYear() + two(d.getMonth() + 1) + two(d.getDate()) + "-" + two(d.getHours()) +
             two(d.getMinutes()) + two(d.getSeconds()) + "-" + String(seed % 10000).padStart(4, "0");
  const length = (config && config.length) || "standard";
  return { id, created: now, updated: now, config: Object.assign({}, config), rng_seed: seed, turn: 0, phase: "new",
           chamber_index: 0, chamber_target: LENGTHS[length] || LENGTHS.standard, scene: {}, seeds_used: [],
           skins_taken: [], skins_offered: [], world: newWorld(), transcript: [], observations: [],
           guard_events: [], synthesis: null, prompt: null };
}

const sessionRng = (s, salt) => new PyRandom(s.rng_seed + ":" + s.turn + ":" + s.chamber_index + ":" + (salt || ""));

function strings(value, limit = 8) {
  if (typeof value === "string") value = [value];
  if (!Array.isArray(value)) return [];
  return value.filter((v) => (typeof v === "string" || typeof v === "number") && strip(String(v)))
              .map((v) => strip(String(v))).slice(0, limit);
}

class Engine {
  /** ui: an object with narrate(text) and note(text); everything the player reads goes through it. */
  constructor(session, registry, ui) {
    this.s = session;
    this.r = registry;
    this.ui = ui;
    this.model = new PlayerModel(registry, session.observations);
    session.observations = this.model.observations;          // one list: what is kept is what is weighed
    this.offline = new OfflineNarrator(registry);
  }

  get finished() { return this.s.phase === "reveal" || this.s.phase === "done"; }

  say(role, text, extra) {
    this.s.transcript.push(Object.assign({ turn: this.s.turn, role, text, scene: this.s.scene.key || "" }, extra || {}));
  }

  begin() {
    const s = this.s;
    if (s.phase === "new") {
      const opener = openerSeed(this.r);
      this._startScene(opener.id, null);
      s.phase = "chamber";
      this.ui.narrate(opener.intro);
      this.say("house", opener.intro, { source: "page" });
      return;
    }
    const last = s.transcript.filter((t) => t.role === "house").pop();
    this.ui.note("The house has kept your place.");
    if (last) this.ui.narrate(last.text);
  }

  turn(text) {
    const s = this.s;
    s.turn += 1;
    this.say("player", text);
    if (s.phase === "chamber" || s.phase === "reading") this._chamberTurn(text);
    else if (s.phase === "threshold") this._thresholdTurn(text);
    s.updated = Date.now() / 1000;
  }

  _startScene(seedId, skinId) {
    const s = this.s, seed = this.r.seeds[seedId], index = s.chamber_index;
    const scene = { key: "c" + index + ":" + seedId, n: index, seed: seedId, skin: skinId, turns: 0, flags: {},
                    counters: {}, thresholds: [], card_given: false, unmatched: 0, threshold_tries: 0, next_seed: null };
    const finale = seed.role === "finale";
    if (!finale && index < s.chamber_target) {
      const skins = selectSkins(this.r, this.model, { taken: s.skins_taken, offered: s.skins_offered,
                                                      rng: sessionRng(s, "skins") });
      scene.thresholds = skins;
      s.skins_offered.push(skins);
    }
    if (s.world.joker !== "kept") scene.flags.joker_gone = true;
    s.scene = scene;
    if (!s.seeds_used.includes(seedId)) s.seeds_used.push(seedId);
  }

  _chamberTurn(text) {
    const s = this.s, scene = s.scene;
    scene.turns += 1;
    const seed = this.r.seeds[scene.seed];
    const finale = seed.role === "finale";
    const softCap = finale ? READING_SOFT_CAP : SOFT_CAP, hardCap = finale ? READING_HARD_CAP : HARD_CAP;
    const result = this.offline.chamber(s, text, { soft: scene.turns >= softCap, mustClose: scene.turns >= hardCap,
      lastChamber: !finale && s.chamber_index >= s.chamber_target, finale });
    this._apply(result, text, seed.kind, seed.id, scene.key);
    if (result.status === "resolved") this._closeChamber(result);
  }

  _closeChamber(result) {
    const s = this.s, w = s.world, scene = s.scene, seed = this.r.seeds[scene.seed];
    const line = result.summary || scene.last_summary || "passed through";
    w.summaries.push({ n: scene.n, seed: seed.id, title: seed.title, skin: scene.skin || null, line, turns: scene.turns });
    if (seed.role === "finale") { s.phase = "reveal"; return; }
    if (s.chamber_index >= s.chamber_target) {
      const finale = finaleSeed(this.r);
      s.chamber_index += 1;
      this._startScene(finale.id, null);
      s.phase = "reading";
      this.ui.narrate(finale.intro);
      this.say("house", finale.intro, { source: "page" });
      return;
    }
    scene.next_seed = selectSeed(this.r, this.model, { used: s.seeds_used, nextChamber: s.chamber_index + 1,
      chamberTarget: s.chamber_target, world: w, rng: sessionRng(s, "seed") });
    scene.threshold_tries = 0;
    s.phase = "threshold";
  }

  _thresholdTurn(text) {
    const s = this.s, scene = s.scene;
    const nextSeed = this.r.seeds[scene.next_seed];
    const skins = scene.thresholds;
    const tries = scene.threshold_tries || 0;
    const key = "t" + scene.n;
    const result = this.offline.threshold(s, text, { force: tries >= 1, nextSeed });
    this._apply(result, text, "threshold", scene.seed, key);
    if (result.threshold_choice === null) { scene.threshold_tries = tries + 1; return; }
    const chosen = skins[result.threshold_choice];
    if (!result.house_chose) {
      for (const obs of skinEvidence(this.r, chosen, skins)) {
        this.model.add(Object.assign({ turn: s.turn, scene: key, seed: chosen, frame: "threshold", source: "rule" }, obs));
      }
    }
    s.skins_taken.push(chosen);
    s.chamber_index += 1;
    this._startScene(nextSeed.id, chosen);
    s.phase = "chamber";
  }

  _apply(result, text, frame, seedId, sceneKey) {
    const s = this.s, w = s.world, scene = s.scene, log = s.guard_events;
    this.ui.narrate(result.narration);
    if (result.addendum) this.ui.narrate(result.addendum);
    const full = result.narration + (result.addendum ? "\n\n" + result.addendum : "");
    this.say("house", full, { source: result.source, option: result.option });
    this._applyState(result.state);

    const recorded = [];
    for (const o of result.observations) {
      const hyps = (o.hypotheses || []).filter((h) => h && typeof h === "object").map((h) =>
        Object.assign({}, h, { why: guard.scrub(cut(String(h.why === undefined ? "" : h.why), 160), log, "hypothesis", s.turn) }));
      const signal = String(o.signal === undefined ? "" : o.signal);
      const obs = this.model.add({
        turn: s.turn, scene: sceneKey, seed: seedId, frame,
        action: guard.scrub(cut(String(o.action === undefined ? "" : o.action), 200), log, "observation", s.turn),
        context: guard.scrub(cut(String(o.context === undefined ? "" : o.context), 200), log, "observation", s.turn),
        hypotheses: hyps, kind: String(o.kind === undefined ? "behavioral" : o.kind),
        strength: String(o.strength === undefined ? "weak" : o.strength), source: result.source,
        signal: signal in this.r.signals ? signal : "" });
      if (obs !== null) {
        recorded.push(obs);
        if (obs.signal) w.signals[obs.signal] = (w.signals[obs.signal] || 0) + 1;
      }
    }
    if (result.card && !scene.card_given) {
      const title = guard.scrub(cut(String(result.card.title || ""), 60), log, "card", s.turn);
      const image = guard.scrub(cut(String(result.card.image || ""), 160), log, "card", s.turn);
      if (!guard.removed(title) && !guard.removed(image)) {
        const dims = [];
        for (const obs of recorded) for (const h of obs.hypotheses) dims.push(h.dim + (h.dir > 0 ? "+" : "-"));
        w.cards.push({ title, image, turn: s.turn, seed: seedId, dims: dims.slice(0, 5) });
        scene.card_given = true;
        if (this.ui.card) this.ui.card(title, image);
      }
    }
    if (result.moment) {
      const moment = guard.scrub(cut(String(result.moment), 180), log, "moment", s.turn);
      if (!guard.removed(moment)) w.moments.push({ text: moment, turn: s.turn, seed: seedId });
    }
    for (const item of result.focus) w.focus[item] = (w.focus[item] || 0) + 1;
    if (result.attempted) {
      const attempted = guard.scrub(result.attempted, log, "attempted", s.turn);
      if (!guard.removed(attempted)) w.attempted.push(attempted);
    }
    if (result.summary) scene.last_summary = guard.scrub(result.summary, log, "summary", s.turn);
  }

  _applyState(state) {
    if (!state || typeof state !== "object" || !Object.keys(state).length) return;
    const s = this.s, w = s.world, scene = s.scene, log = s.guard_events;
    for (let item of strings(state.inventory_add)) {
      item = guard.scrub(cut(item, 90), log, "inventory", s.turn);
      if (!w.inventory.includes(item) && !guard.removed(item)) w.inventory.push(item);
    }
    for (const item of strings(state.inventory_remove)) {
      const low = lower(item);
      const at = w.inventory.findIndex((x) => lower(x) === low || lower(x).includes(low) || low.includes(lower(x)));
      if (at >= 0) w.inventory.splice(at, 1);
    }
    const delta = "matches_delta" in state ? state.matches_delta : state.matches;
    if (typeof delta === "number" && delta) {
      w.matches = Math.max(0, Math.min(12, w.matches + Math.trunc(Math.max(-3, Math.min(3, delta)))));
    }
    if ((state.joker === "played" || state.joker === "spent") && w.joker === "kept") {
      w.joker = state.joker;
      w.joker_chamber = s.chamber_index;
      scene.flags.joker_gone = true;
    }
    const comp = state.companion;
    if (comp && typeof comp === "object" && comp.name) {
      w.companion = { name: guard.scrub(cut(String(comp.name), 40), log, "companion", s.turn),
                      kind: guard.scrub(cut(String(comp.kind || ""), 90), log, "companion", s.turn),
                      since: s.chamber_index };
    } else if (["gone", "lost", "left", false].includes(comp) && w.companion) {
      w.flags.companion_lost = w.companion.name || true;
      w.companion = null;
    }
    for (const npc of state.npcs || []) {
      if (!(npc && typeof npc === "object" && npc.name)) continue;
      const entry = { name: guard.scrub(cut(String(npc.name), 40), log, "npc", s.turn),
                      attitude: guard.scrub(cut(String(npc.attitude || ""), 40), log, "npc", s.turn),
                      note: guard.scrub(cut(String(npc.note || ""), 140), log, "npc", s.turn) };
      const existing = w.npcs.find((n) => lower(n.name) === lower(entry.name));
      if (existing) Object.assign(existing, entry); else w.npcs.push(entry);
    }
    const flags = state.flags;
    if (flags && typeof flags === "object" && !Array.isArray(flags)) {
      for (const [key, raw] of Object.entries(flags).slice(0, 8)) {
        if (["boolean", "number", "string"].includes(typeof raw)) {
          const value = typeof raw === "string" ? cut(raw, 60) : raw;
          scene.flags[cut(key, 40)] = value;
          w.flags[cut(key, 40)] = value;
        }
      }
      if (Object.entries(flags).some(([key, value]) => value && (lower(key).includes("ribbon") || lower(key).includes("shuffl")))) {
        w.ribbon_untied = true;
      }
    }
    for (let thread of strings(state.threads_add)) {
      thread = guard.scrub(cut(thread, 160), log, "thread", s.turn);
      if (!w.threads.includes(thread) && !guard.removed(thread)) w.threads.push(thread);
    }
    for (const thread of strings(state.threads_resolve)) {
      const low = lower(thread);
      const at = thread === "*first*" ? (w.threads.length ? 0 : -1)
        : w.threads.findIndex((x) => lower(x) === low || lower(x).includes(low) || low.includes(lower(x)));
      if (at >= 0) w.threads_resolved.push(w.threads.splice(at, 1)[0]);
    }
    const failures = state.failures;
    if (typeof failures === "number" && failures > 0) {
      w.failures += Math.trunc(Math.min(failures, 3));
      scene.failed = true;
    }
  }

  /** Evidence that only exists once the whole night can be seen. */
  closeNight() {
    const s = this.s, w = s.world;
    if (w.flags._night_closed) return;
    const add = (tag, action, hypotheses, strength = "moderate", context = "the whole night") => {
      this.model.add({ turn: s.turn, scene: "night:" + tag, seed: "night", frame: "aggregate", action, context,
                       hypotheses, strength, source: "aggregate" });
    };
    if (w.joker === "kept") {
      add("joker", "kept the Joker unplayed to the end of the night", [["solve.resource", 1, 0.5], ["risk", -1, 0.2]],
          "weak", "a power that could have ended any room, never spent");
    } else if (w.joker === "played" && (w.joker_chamber || 0) <= 2) {
      add("joker", "played the Joker early in the night", [["risk", 1, 0.4], ["reward.power", 1, 0.3], ["pacing", 1, 0.2]]);
    }
    if (w.matches >= 3) {
      add("matches", "finished the night with " + w.matches + " matches unspent", [["solve.resource", 1, 0.4], ["risk", -1, 0.2]], "weak");
    } else if (w.matches === 0) {
      add("matches", "spent every match", [["risk", 1, 0.3], ["solve.resource", -1, 0.3], ["friction", -1, 0.2]], "weak");
    }
    if (w.inventory.some((item) => lower(item).includes("doorknob"))) {
      add("doorknob", "carried a useless doorknob all night", [["reward.collection", 1, 0.4], ["optimization_expression", 1, 0.3]], "weak");
    }
    if (w.companion) {
      add("companion", "kept " + (w.companion.name || "a companion") + " with them to the end",
          [["soc.companions", 1, 0.6], ["reward.cooperation", 1, 0.3]]);
    }
    if (w.flags.seedling) {
      add("seedling", "carried a seedling to the Reading Room", [["session_rhythm", 1, 0.5], ["reward.cooperation", 1, 0.3]]);
    }
    if (w.flags.wearing) {
      add("costume", "wore the " + w.flags.wearing + " for the rest of the night",
          [["reward.expression", 1, 0.5], ["story.character", 1, 0.3]], "weak");
    }
    if (w.threads.length >= 3) {
      add("threads", "left " + w.threads.length + " things unopened or unresolved",
          [["reward.completion", -1, 0.4], ["exploration", -1, 0.2]], "weak");
    } else if (!w.threads.length && w.threads_resolved.length) {
      add("threads", "left nothing unresolved behind them", [["reward.completion", 1, 0.4]], "weak");
    }
    w.flags._night_closed = true;
  }
}

// ---------------------------------------------------------------------------
// From how someone played to the game they should be given (synthesis.py, rules only)
// ---------------------------------------------------------------------------

const PRONOUNCEMENT = "I HAVE SEEN WHAT YOU WILL PLAY.";
const MIN_SIGNAL_VALUE = 0.08;
const pole = (d, value) => (value >= 0 ? d.pos : d.neg);

function nightContext(session) {
  const w = session.world;
  return { companion: (w.companion || {}).name || "", attempted: w.attempted.length ? w.attempted[0] : "",
           joker: w.joker, inventory: w.inventory.map(lower), thread: w.threads.length ? w.threads[0] : "",
           threads: w.threads.length + w.threads_resolved.length, flags: w.flags, failures: w.failures,
           signals: w.signals, moment: w.moments.length ? w.moments[0].text : "", matches: w.matches,
           wearing: w.flags.wearing || "" };
}

function holds(when, ctx) {
  for (const [key, want] of Object.entries(when)) {
    if (key === "always") continue;
    if (key === "companion" && Boolean(ctx.companion) !== Boolean(want)) return false;
    if (key === "attempted" && Boolean(ctx.attempted) !== Boolean(want)) return false;
    if (key === "joker" && ctx.joker !== want) return false;
    if (key === "inventory" && !ctx.inventory.some((item) => item.includes(lower(String(want))))) return false;
    if (key === "thread" && Boolean(ctx.thread) !== Boolean(want)) return false;
    if (key === "threads" && ctx.threads < want) return false;
    if (key === "flag" && !ctx.flags[want]) return false;
    if (key === "failures" && ctx.failures < want) return false;
    if (key === "signal" && !ctx.signals[want]) return false;
    if (key === "moment" && Boolean(ctx.moment) !== Boolean(want)) return false;
    if (key === "matches_min" && ctx.matches < want) return false;
    if (key === "matches_max" && ctx.matches > want) return false;
  }
  return true;
}

function fill(text, ctx) {
  for (const key of ["companion", "attempted", "thread", "wearing", "moment"]) {
    text = replaceAll(text, "{" + key + "}", String(ctx[key] === undefined ? "" : ctx[key]));
  }
  return text;
}

function secondPerson(moment) {
  let text = strip(moment).replace(/\.+$/, "");
  text = text.replace(/^was\b/, "were").replace(/\band was\b/g, "and were");
  for (const [old, value] of [[/\bthemselves\b/g, "yourself"], [/\btheir\b/g, "your"], [/\bthem\b/g, "you"],
                              [/\bthey\b/g, "you"], [/\bthe bearer\b/g, "you"], [/\bthe player\b/g, "you"]]) {
    text = text.replace(old, value);
  }
  return "You " + text[0].toLowerCase() + text.slice(1) + ".";
}

function firstSentence(text) {
  const at = text.indexOf(". ");
  return at < 0 ? text : text.slice(0, at + 1);
}

function clean(items, limit) {
  const out = [];
  for (const item of items) if (item && !guard.removed(item) && !out.includes(item)) out.push(item);
  return out.slice(0, limit);
}

function findSignals(registry, model) {
  const imp = registry.implications, out = [];
  for (const st of Object.values(model.compute())) {
    const d = registry.dims[st.id];
    if (st.status === "unknown" || st.status === "contested" || Math.abs(st.value) < MIN_SIGNAL_VALUE) continue;
    if (d.family === "aesthetic") continue;
    const direction = st.value >= 0 ? 1 : -1;
    let rule;
    if (d.family === "axis") {
      rule = imp.axis_rules[st.id][direction > 0 ? "pos" : "neg"];
    } else {
      if (direction < 0) continue;
      rule = (imp.weight_rules[st.id] || {}).high;
      if (!rule) continue;
      const extra = (registry.reading.weight_visions || {})[st.id];
      if (!(rule.visions && rule.visions.length) && extra) rule = Object.assign({}, rule, { visions: extra });
    }
    out.push({ token: st.id + (direction > 0 ? "+" : "-"), dim: st.id, dir: direction,
               salience: salience(st, d.importance), value: st.value, confidence: st.confidence, status: st.status,
               rule, evidence: clean(model.evidence(st.id, 3)[0], 3), merged: [] });
  }
  return out.sort((a, b) => b.salience - a.salience);
}

const signalEntry = (sig) => ({ signal: sig.rule.signal, dims: [sig.dim].concat(sig.merged.map((m) => parseSigned(m)[0])),
                                evidence: sig.evidence, design_consequence: sig.rule.implication });

function chooseSignals(registry, signals) {
  const groups = registry.reading.related;
  const chosen = [], rest = [];
  for (const sig of signals) {
    if (!sig.rule.implication) { rest.push(sig); continue; }
    const partner = chosen.find((c) => groups.some((g) => g.includes(sig.token) && g.includes(c.token)));
    if (partner) {
      partner.merged.push(sig.token);
      for (const e of sig.evidence) if (!partner.evidence.includes(e) && partner.evidence.length < 4) partner.evidence.push(e);
      rest.push(sig);
    } else if (chosen.length < 5) {
      chosen.push(sig);
    } else {
      rest.push(sig);
    }
  }
  return [chosen.slice(0, 3), chosen.slice(3, 5), rest];
}

function findContradiction(registry, model) {
  const strength = (token) => {
    const [dim, direction] = parseSigned(token);
    const st = model.state(dim), d = registry.dims[dim];
    if (st.status === "unknown") return 0.0;
    if (st.status === "contested") return 0.1 * d.importance;
    if ((st.value >= 0) !== (direction > 0) || Math.abs(st.value) < MIN_SIGNAL_VALUE) return 0.0;
    return Math.abs(st.value) * Math.max(st.confidence, 0.1) * d.importance;
  };
  let best = null, bestScore = 0.0;
  for (const c of registry.implications.contradictions) {
    const score = Math.min(strength(c.a), strength(c.b));
    if (score > bestScore) { best = c; bestScore = score; }
  }
  if (best) {
    const sides = [];
    let evidence = [];
    for (const token of [best.a, best.b]) {
      const [dim, direction] = parseSigned(token);
      const d = registry.dims[dim];
      sides.push(d.bipolar ? pole(d, direction) : d.desc);
      evidence = evidence.concat(model.evidence(dim, 1)[0]);
    }
    return { id: best.id, between: sides, dims: [best.a, best.b], evidence: clean(evidence, 3),
             resolution: best.resolution, vision: best.vision, observed: true };
  }
  const contested = Object.values(model.compute()).filter((st) => st.status === "contested" && registry.dims[st.id].family === "axis");
  if (contested.length) {
    let st = contested[0], top = -Infinity;
    for (const c of contested) {
      const v = Math.min(c.support, c.against) * registry.dims[c.id].importance;
      if (v > top) { st = c; top = v; }
    }
    const d = registry.dims[st.id];
    const [support, against] = model.evidence(st.id, 1);
    return { id: "contested_" + st.id, between: [d.neg, d.pos], dims: [st.id + "-", st.id + "+"],
             evidence: clean(support.concat(against), 2),
             resolution: "The player went both ways on this in different rooms. Offer both: every situation " +
                         "has a " + d.neg + " way through and a " + d.pos + " way through, chosen in the moment and " +
                         "never locked in at the start.",
             vision: "I see two ways through every room, and you taking each of them, on different days.",
             observed: true };
  }
  return null;
}

function mood(registry, model) {
  const looks = [];
  for (const st of model.ranked(["aesthetic"])) {
    if (st.confidence >= 0.15 && Math.abs(st.value) >= MIN_SIGNAL_VALUE && st.status !== "contested") {
      looks.push(pole(registry.dims[st.id], st.value));
    }
  }
  const tones = model.ranked(["tone"]).filter((st) => st.value > MIN_SIGNAL_VALUE && st.confidence >= 0.15)
                     .map((st) => st.id).slice(0, 3);
  if (!looks.length && !tones.length) return null;
  const parts = [];
  if (tones.length) {
    const rule = (registry.implications.weight_rules[tones[0]] || {}).high || {};
    parts.push((rule.gdv || {}).audiovisual_mood || tones[0].split(".").slice(1).join("."));
    if (tones.length > 1) parts.push("with notes of " + tones.slice(1).map((t) => t.split(".").slice(1).join(".")).join(" and "));
  }
  if (looks.length) parts.push("look: " + looks.slice(0, 4).join(", "));
  return parts.join("; ");
}

function bestKeyed(registry, model, table, axisField) {
  let best = null, bestScore = 0.0;
  for (const [dim, text] of Object.entries(table)) {
    const st = model.state(dim);
    if (st.status === "unknown" || st.value <= MIN_SIGNAL_VALUE) continue;
    const score = salience(st, registry.dims[dim].importance);
    if (score > bestScore) { best = [dim, text]; bestScore = score; }
  }
  for (const [token, entry] of Object.entries(registry.reading.axis_keyed)) {
    const [dim, direction] = parseSigned(token);
    const st = model.state(dim);
    if (st.status === "unknown" || st.status === "contested" || Math.abs(st.value) < MIN_SIGNAL_VALUE) continue;
    if ((st.value > 0) !== (direction > 0)) continue;
    const score = salience(st, registry.dims[dim].importance);
    if (score > bestScore) { best = [token, entry[axisField]]; bestScore = score; }
  }
  return best;
}

function sameEvent(when, effects) {
  if ("flag" in when && when.flag in (effects.flags || {})) return true;
  if (when.companion && effects.companion) return true;
  if ("joker" in when && effects.joker === when.joker) return true;
  if ("inventory" in when && (effects.inventory_add || []).some((item) => lower(String(item)).includes(lower(String(when.inventory))))) return true;
  if ("failures" in when && effects.failures) return true;
  if (when.thread && effects.threads_add && effects.threads_add.length) return true;
  return false;
}

function freshMoment(registry, world, told) {
  const effectsOf = {};
  for (const seed of Object.values(registry.seeds)) {
    for (const option of seed.options) if (option.moment) effectsOf[option.moment] = option.effects || {};
  }
  for (const moment of world.moments) {
    const effects = effectsOf[moment.text];
    if (effects === undefined || !told.some((when) => sameEvent(when, effects))) return moment.text;
  }
  return null;
}

function buildDraft(registry, model, session) {
  const imp = registry.implications, reading = registry.reading, w = session.world;
  const rng = new PyRandom(session.rng_seed + ":reading");
  const ctx = nightContext(session);
  const signals = findSignals(registry, model);
  const [dominant, secondary, rest] = chooseSignals(registry, signals);
  const contradiction = findContradiction(registry, model);

  let gdv = {};
  const sources = {};
  for (const sig of dominant.concat(secondary, rest)) {
    for (const [key, value] of Object.entries(sig.rule.gdv || {})) {
      if (!(key in gdv)) { gdv[key] = value; sources[key] = sig.token; }
    }
  }
  const fantasy = bestKeyed(registry, model, imp.fantasies, "fantasy");
  if (fantasy) { gdv.central_fantasy = fantasy[1]; sources.central_fantasy = fantasy[0]; }
  const verb = bestKeyed(registry, model, imp.core_verbs, "verb");
  if (verb) {
    gdv.core_verb = verb[1];
    sources.core_verb = verb[0];
    if (!("primary_loop" in gdv)) {
      gdv.primary_loop = "meet a situation; " + verb[1] + "; see what the world does in answer; carry what that taught into the next";
    }
    if (!("primary_loop" in sources)) sources.primary_loop = verb[0];
  }
  const feel = mood(registry, model);
  if (feel) { gdv.audiovisual_mood = feel; sources.audiovisual_mood = "thresholds taken"; }
  for (const f of imp.gdv_fields) if (!(f.id in gdv)) { gdv[f.id] = f.default; sources[f.id] = "default"; }
  const ordered = {};
  for (const f of imp.gdv_fields) ordered[f.id] = gdv[f.id];
  gdv = ordered;

  const implications = dominant.concat(secondary).map((s) => s.rule.implication);
  if (contradiction) implications.push(contradiction.resolution);
  for (const sig of rest) {
    if (implications.length >= 12) break;
    const text = sig.rule.implication;
    if (text && !implications.includes(text)) implications.push(text);
  }
  let negatives = [];
  for (const sig of dominant.concat(secondary, rest)) negatives = negatives.concat(sig.rule.negative || []);
  for (const st of Object.values(model.compute())) {
    const low = (imp.weight_rules[st.id] || {}).low;
    if (low && st.value < -MIN_SIGNAL_VALUE && (st.status === "leaning" || st.status === "established")) {
      negatives = negatives.concat(low.negative || []);
    }
  }
  negatives = clean(negatives, 10);

  const callbacks = [], told = [];
  for (const cb of reading.callbacks) {
    if (!holds(cb.when, ctx) || callbacks.length >= 4) continue;
    let local = ctx;
    if (cb.from.includes("{moment}")) {
      const fresh = freshMoment(registry, w, told);
      if (fresh === null) continue;
      local = Object.assign({}, ctx, { moment: fresh });
    }
    told.push(cb.when);
    callbacks.push({ id: cb.id, card: cb.card, from: fill(cb.from, local), becomes: fill(cb.becomes, local),
                     vision: fill(cb.vision, local) });
  }
  const unrequested = reading.unrequested.find((u) => holds(u.when, ctx));

  const states = Object.values(model.compute());
  const unknownAxes = states.filter((st) => st.status === "unknown" && registry.dims[st.id].family === "axis")
    .sort((a, b) => registry.dims[b.id].importance - registry.dims[a.id].importance);
  const unknowns = unknownAxes.map((st) => "Whether this player wants " + registry.dims[st.id].neg + " or " +
    registry.dims[st.id].pos + " (" + st.id + ") was not observed. Nothing in the design depends on it.");
  if (feel === null) {
    unknowns.push("Visual and tonal taste was barely observed: the look of the game is the builder's " +
                  "choice within the scope constraints.");
  }
  const contradictionDims = new Set(((contradiction || {}).dims || []).map((token) => parseSigned(token)[0]));
  for (const st of states) {
    if (st.status === "contested" && !contradictionDims.has(st.id)) {
      const d = registry.dims[st.id];
      unknowns.push("The player went both ways on " + d.neg + " against " + d.pos + " (" + st.id + "); the design " +
                    "should allow both rather than choose.");
    }
  }

  const cardsMap = imp.cards;
  let title = null;
  if (w.cards.length) title = w.cards[0].title;
  else if (dominant.length) title = cardsMap[dominant[0].token] || cardsMap[dominant[0].dim];
  title = title || "The Blank Deck";
  const fantasyText = fantasy ? gdv.central_fantasy : "a small strange place that answers to how you play";
  const verbText = verb ? gdv.core_verb : "act and see what answers";
  let pitch = "A pocket game about " + fantasyText + ". You " + verbText + ".";
  if (contradiction && !contradiction.id.startsWith("contested_")) pitch += " " + contradiction.resolution;
  else if (dominant.length) pitch += " " + firstSentence(dominant[0].rule.implication);

  const design = {
    working_title: title, pitch,
    design_signals: {
      dominant: dominant.map(signalEntry), secondary: secondary.map(signalEntry),
      productive_contradiction: contradiction
        ? { between: contradiction.between, evidence: contradiction.evidence, resolution: contradiction.resolution }
        : { between: [], evidence: [], resolution: "No real tension was observed tonight; nothing in the design depends on one." },
    },
    design_implications: implications, game_design_vector: gdv, negative_constraints: negatives,
    personal_callbacks: callbacks.map((c) => ({ from: c.from, becomes: c.becomes })),
    unrequested_feature: { feature: unrequested.feature, follows_from: unrequested.follows_from },
    unknowns,
  };

  const used = new Set();
  const cardFor = (sig) => {
    for (const c of w.cards) {
      if (!used.has(c.title) && (c.dims || []).includes(sig.token)) { used.add(c.title); return c.title; }
    }
    let name = cardsMap[sig.token] || cardsMap[sig.dim];
    if (!name || used.has(name)) {
      name = "The " + sig.dim.split(".").pop().replace(/_/g, " ").replace(/(^|\s)\S/g, (ch) => ch.toUpperCase());
    }
    used.add(name);
    return name;
  };
  const visionFor = (sig) => {
    const options = sig.rule.visions && sig.rule.visions.length ? sig.rule.visions : ["I see a game that fits your hand."];
    return { card: cardFor(sig), text: rng.choice(options), fulfils: firstSentence(sig.rule.implication),
             echo: sig.evidence.length ? sig.evidence[0] : null };
  };
  const callbackVision = (cb) => {
    const name = used.has(cb.card) ? cb.card + ", Again" : cb.card;
    used.add(name);
    return { card: name, text: cb.vision, fulfils: cb.becomes, echo: cb.from };
  };

  let visions = [];
  if (dominant.length) visions.push(visionFor(dominant[0]));
  if (callbacks.length) visions.push(callbackVision(callbacks[0]));
  for (const s of dominant.slice(1)) visions.push(visionFor(s));
  if (contradiction) visions.push({ card: imp.contradiction_card, text: contradiction.vision, fulfils: contradiction.resolution, echo: null });
  for (const s of secondary) visions.push(visionFor(s));
  if (callbacks.length > 1) visions.push(callbackVision(callbacks[1]));
  const absence = negatives.find((n) => n.startsWith("No "));
  if (absence && !visions.some((v) => v.text.startsWith("I see no"))) {
    visions.push({ card: reading.no_vision.card, text: reading.no_vision.text.replace("{absence}", "no " + absence.slice(3)),
                   fulfils: absence, echo: null });
  }
  if (visions.length < 5) {
    for (const cb of callbacks.slice(2)) if (visions.length < 5) visions.push(callbackVision(cb));
  }
  if (visions.length < 5 || signals.length < 3) {
    visions.push({ card: reading.blank_card.card, text: reading.blank_card.text,
                   fulfils: "Where the profile is unknown, the builder chooses and records the default.", echo: null });
  }
  visions = visions.slice(0, 9);

  const recollections = [];
  const seenSeeds = new Set();
  for (const m of w.moments) {
    if (seenSeeds.has(m.seed) || recollections.length >= 4) continue;
    seenSeeds.add(m.seed);
    recollections.push(secondPerson(m.text));
  }
  for (const fact of reading.facts) {
    if (recollections.length >= 3) break;
    if (holds(fact.when, ctx) && !recollections.includes(fact.text)) recollections.push(fact.text);
  }

  const prophecy = { address: rng.choice(reading.addresses), recollections, visions, pronouncement: PRONOUNCEMENT,
                     final_line: imp.final_lines.join(" ") };
  return { design, prophecy, gdv_sources: sources, contradiction, callbacks, thin_evidence: dominant.length < 3 };
}

function synthesize(registry, model, session) {
  const draft = buildDraft(registry, model, session);
  return { design: draft.design, prophecy: draft.prophecy, draft, source: { design: "rules", prophecy: "rules" } };
}

// ---------------------------------------------------------------------------
// The build prompt (prompt.py)
// ---------------------------------------------------------------------------

const BLANK = "nothing was seen here: these are the DEFAULT rows, where you choose and say so";
const AT_ROOM = /^at ([^:]+): (.+)$/;
const DIM_ID = / \([a-z_.]+\)/g;
const NOT_SEEN = /^Whether this player wants (.+) \(([a-z_.]+)\) was not observed\./;
const TAIL = " Nothing in the design depends on it.";

const cell = (value) => squash(replaceAll(String(value), "|", "/"));
const stop = (text) => { text = strip(String(text)); return /[.!?]$/.test(text) ? text : text + "."; };
const third = (text) => text.replace(/\byourself\b/gi, "themselves").replace(/\byours\b/gi, "theirs")
                            .replace(/\byour\b/gi, "their").replace(/\byou\b/gi, "they");
const plain = (text) => squash(replaceAll(String(text), "`", "'")).replace(/\.+$/, "");

function seen(evidence, limit = 3) {
  const told = [], turned = [], bare = [];
  for (const item of evidence || []) {
    const text = plain(item);
    if (!text) continue;
    const found = AT_ROOM.exec(text);
    if (!found) { told.push(text); continue; }
    const room = found[1], act = third(found[2]);
    const negative = /^(?:do not|don't) (.+)/i.exec(act);
    if (negative) turned.push("chose not to " + negative[1] + " (" + room + ")");
    else if (splitWords(act).length >= 3) turned.push("chose to " + act + " (" + room + ")");
    else bare.push(act + ", at " + room);
  }
  const first = told.concat(turned);
  return (first.length ? first : bare).slice(0, limit).join("; ");
}

function promptSignals(design) {
  const sig = design.design_signals;
  const lines = [], byDim = {}, byText = {};
  let n = 0;
  for (const rank of ["dominant", "secondary"]) {
    for (const entry of sig[rank] || []) {
      n += 1;
      const label = "S" + n;
      for (const dim of entry.dims || []) if (!(dim in byDim)) byDim[dim] = label;
      const consequence = strip(String(entry.design_consequence || ""));
      byText[consequence] = label;
      byText[firstSentence(consequence)] = label;
      lines.push("**" + label + " (" + rank + "): the player " + stop(entry.signal || "") + "**");
      const was = seen(entry.evidence, rank === "dominant" ? 3 : 2);
      if (was) lines.push("- Seen when they: " + stop(was));
      lines.push("- So: " + consequence);
      lines.push("");
    }
  }
  if (!n) {
    lines.push("The night gave too little evidence for any signal. Say so in your first report, build from " +
               "the defaults below, and let the first play decide.", "");
  }
  const pc = sig.productive_contradiction || {};
  const resolution = strip(String(pc.resolution || ""));
  if (pc.between && pc.between.length) {
    byText[resolution] = "X";
    lines.push("**X (the productive contradiction): " + pc.between[0] + ", against " + pc.between[pc.between.length - 1] + ".**");
    const was = seen(pc.evidence);
    if (was) lines.push("- Seen when they: " + stop(was));
    lines.push("- So: " + resolution);
  } else {
    lines.push("**X (the productive contradiction):** none was seen. " + resolution);
  }
  return [lines.join("\n"), byDim, byText];
}

function promptVector(registry, design, synthesis, byDim) {
  const fields = {};
  for (const f of registry.implications.gdv_fields) fields[f.id] = f;
  const byRules = String(synthesis.source.design).startsWith("rules");
  const sources = byRules ? (synthesis.draft || {}).gdv_sources || {} : {};
  const rows = ["| Field | Value | Basis |", "|---|---|---|"];
  for (const [key, value] of Object.entries(design.game_design_vector)) {
    const info = fields[key] || { label: key, default: "" };
    const text = strip(String(value));
    let basis;
    if (text === strip(info.default) || lower(text).startsWith("unknown")) {
      basis = info.scope ? "SCOPE" : "DEFAULT";
    } else {
      const source = sources[key] || "";
      const label = byDim[source.replace(/[+-]+$/, "")];
      if (label) basis = "FROM PLAY (" + label + ")";
      else if (source === "thresholds taken") basis = "FROM PLAY (the ways taken between rooms)";
      else if (byRules) basis = "FAINT";
      else basis = "FROM PLAY";
    }
    rows.push("| " + info.label + " | " + cell(text) + " | " + basis + " |");
  }
  return rows.join("\n");
}

function unknownLines(design) {
  const items = [];
  for (const item of design.unknowns || []) {
    const text = strip(String(item));
    const pair = NOT_SEEN.exec(text);
    if (pair) items.push("- " + replaceAll(pair[2], "_", " ") + ": " + pair[1]);
    else items.push("- " + stop(strip(replaceAll(text, TAIL, "").replace(DIM_ID, ""))));
  }
  return items.length ? items.join("\n") : "- Nothing material.";
}

function buildPrompt(registry, model, session, synthesis, when) {
  const design = synthesis.design, prophecy = synthesis.prophecy, scope = registry.implications.scope;
  const [signals, byDim, said] = promptSignals(design);

  const laws = (design.negative_constraints || []).map((n) => strip(String(n)));
  const saidAll = Object.assign({}, said);
  laws.forEach((law, i) => { saidAll[law] = "L" + (i + 1); });
  const lawText = laws.length ? laws.map((law, i) => "- **L" + (i + 1) + ".** " + law).join("\n") : "- (none were evidenced)";

  const echoLines = [];
  let n = 0;
  for (const cb of design.personal_callbacks || []) {
    n += 1;
    const becomes = strip(String(cb.becomes || ""));
    saidAll[becomes] = "E" + n;
    echoLines.push("- **E" + n + ".** They " + stop(plain(cb.from || "")) + " In the game: " + stop(becomes));
  }
  const un = design.unrequested_feature || {};
  if (un.feature) {
    n += 1;
    echoLines.push("- **E" + n + ", the feature nobody asked for.** " + stop(un.feature) +
                   " It follows from what they did: " + stop(un.follows_from || ""));
  }

  const quiet = (design.design_implications || []).map((i) => strip(String(i))).filter((i) => !(i in said));
  const visionRows = ["| Card | The player was told | Comes true through |", "|---|---|---|"];
  for (const v of prophecy.visions) {
    const fulfils = strip(String(v.fulfils || ""));
    let through;
    if (v.card === "The Blank Card" || fulfils.startsWith("Where the profile is unknown")) through = BLANK;
    else through = saidAll[fulfils] || saidAll[firstSentence(fulfils)] || fulfils || "the design as a whole";
    visionRows.push("| " + cell(v.card) + " | " + cell(v.text) + " | " + cell(through) + " |");
  }

  const axes = Object.values(model.compute()).filter((st) => registry.dims[st.id].family === "axis");
  const observed = axes.filter((st) => st.status !== "unknown").length;
  const d = new Date((when === undefined || when === null ? Date.now() / 1000 : when) * 1000);
  const made = d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
  const source = String(synthesis.source.design);
  const how = source.startsWith("rules") ? "No model was involved: the design follows authored rules."
    : "The design was composed by a model (" + source + ") from the same evidence, and checked.";
  const parts = {
    TITLE: strip(design.working_title), PITCH: strip(design.pitch),
    NIGHT: session.turn + " turns in " + session.world.summaries.length + " rooms",
    SIGNALS: signals, QUIET: quiet.length ? quiet.map((i) => "- " + i).join("\n") : "- (none)",
    VECTOR: promptVector(registry, design, synthesis, byDim), LAWS: lawText,
    ECHOES: echoLines.length ? echoLines.join("\n") : "- (none)", UNKNOWN: unknownLines(design),
    VISION_COUNT: String(prophecy.visions.length), VISIONS: visionRows.join("\n"),
    SCOPE: scope.summary + "\n\n" + scope.constraints.map((c) => "- " + c).join("\n") + "\n\n" + scope.fixed_summary +
           "\n\n" + scope.fixed.map((c) => "- " + c).join("\n"),
    FOOTER: "Written by THE BLANK DECK " + registry.version + " on " + made + " from one night of play: " +
            model.observations.length + " observations, " + observed + " of " + axes.length +
            " core dimensions observed. " + how,
  };
  const text = registry.texts.build_prompt.replace(/\{\{([A-Z_]+)\}\}/g, (mark, key) => (key in parts ? parts[key] : mark));
  return strip(replaceAll(text, "\r\n", "\n")) + "\n";
}

return { setTrace(fn) { trace = fn; }, pySum, PyRandom, sha512, utf8, pyRound, lgamma, betainc, guard, PlayerModel, Engine, newSession, sessionRng,
         synthesize, buildPrompt, hintWords, matchOption, shortWay, thresholdsText, carrying, need,
         LENGTHS, PRONOUNCEMENT, CARD_LINES };
});
