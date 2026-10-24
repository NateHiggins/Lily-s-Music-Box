"""From how someone played to the game they should be given.

Two stages. The first is rules: the player model is ranked, three dominant
signals, two secondary signals and one productive contradiction are chosen, and
authored design rules turn them into design implications, a Game Design Vector,
negative constraints, personal callbacks, one unrequested feature, a list of
what is not known, and a prophecy. That draft is complete on its own; it is
what an offline night produces.

The second stage, when a model is available, hands the evidence and the draft
to the model twice: once as a designer, to make one coherent game of it, and
once as the Proprietor, to write the reading. Each answer is validated. A bad
answer gets one chance to be repaired and is then discarded in favour of the
draft, so the night always ends with a usable game description.

Nothing here matches the player to a genre. The inputs are pleasures and
aversions with evidence; the output is a design built from them.
"""

from __future__ import annotations

import json
import random
import re
from dataclasses import dataclass, field

from . import guard
from .backends import Backend, BackendError
from .content import Registry, parse_signed
from .model import PlayerModel
from .narrator import parse_json_reply
from .session import Session

PRONOUNCEMENT = "I HAVE SEEN WHAT YOU WILL PLAY."
MIN_SIGNAL_VALUE = 0.08


@dataclass
class Signal:
    token: str              # "risk+" or "reward.discovery+"
    dim: str
    dir: int
    salience: float
    value: float
    confidence: float
    status: str
    rule: dict
    evidence: list[str] = field(default_factory=list)
    merged: list[str] = field(default_factory=list)

    def entry(self) -> dict:
        return {"signal": self.rule["signal"], "dims": [self.dim] + [parse_signed(m)[0] for m in self.merged],
                "evidence": self.evidence, "design_consequence": self.rule["implication"]}


# ---------------------------------------------------------------------------
# The night as conditions
# ---------------------------------------------------------------------------

def night_context(session: Session) -> dict:
    w = session.world
    moment = w.moments[0]["text"] if w.moments else ""
    return {
        "companion": (w.companion or {}).get("name", ""), "attempted": w.attempted[0] if w.attempted else "",
        "joker": w.joker, "inventory": [i.lower() for i in w.inventory], "thread": w.threads[0] if w.threads else "",
        "threads": len(w.threads) + len(w.threads_resolved), "flags": w.flags, "failures": w.failures,
        "signals": w.signals, "moment": moment, "matches": w.matches, "wearing": w.flags.get("wearing", ""),
    }


def holds(when: dict, ctx: dict) -> bool:
    for key, want in when.items():
        if key == "always":
            continue
        if key == "companion" and bool(ctx["companion"]) != bool(want):
            return False
        if key == "attempted" and bool(ctx["attempted"]) != bool(want):
            return False
        if key == "joker" and ctx["joker"] != want:
            return False
        if key == "inventory" and not any(str(want).lower() in item for item in ctx["inventory"]):
            return False
        if key == "thread" and bool(ctx["thread"]) != bool(want):
            return False
        if key == "threads" and ctx["threads"] < want:
            return False
        if key == "flag" and not ctx["flags"].get(want):
            return False
        if key == "failures" and ctx["failures"] < want:
            return False
        if key == "signal" and not ctx["signals"].get(want):
            return False
        if key == "moment" and bool(ctx["moment"]) != bool(want):
            return False
        if key == "matches_min" and ctx["matches"] < want:
            return False
        if key == "matches_max" and ctx["matches"] > want:
            return False
    return True


def _same_event(when: dict, effects: dict) -> bool:
    """Is an echo keyed on `when` about the thing these option effects did?"""
    if "flag" in when and when["flag"] in (effects.get("flags") or {}):
        return True
    if when.get("companion") and effects.get("companion"):
        return True
    if "joker" in when and effects.get("joker") == when["joker"]:
        return True
    if "inventory" in when and any(str(when["inventory"]).lower() in str(item).lower()
                                   for item in effects.get("inventory_add") or []):
        return True
    if "failures" in when and effects.get("failures"):
        return True
    if when.get("thread") and effects.get("threads_add"):
        return True
    return False


def fresh_moment(registry: Registry, world, told: list[dict]) -> str | None:
    """The first remembered moment that no echo already chosen is about.

    An authored moment comes from an option, and an option's effects are what the other
    echoes are keyed on. A moment whose option set the flag (or gave the companion, or cost
    the failure) that another echo already tells is the same event, and is not told twice.
    A moment a model wrote has no option behind it and is always fresh."""
    effects_of = {option["moment"]: option.get("effects") or {}
                  for seed in registry.seeds.values() for option in seed["options"] if option.get("moment")}
    for moment in world.moments:
        effects = effects_of.get(moment["text"])
        if effects is None or not any(_same_event(when, effects) for when in told):
            return moment["text"]
    return None


def fill(text: str, ctx: dict) -> str:
    for key in ("companion", "attempted", "thread", "wearing", "moment"):
        text = text.replace("{" + key + "}", str(ctx.get(key, "")))
    return text


def second_person(moment: str) -> str:
    """'was offered the thing they had walked past' -> 'You were offered the thing you had walked past.'"""
    text = moment.strip().rstrip(".")
    text = re.sub(r"^was\b", "were", text)
    text = re.sub(r"\band was\b", "and were", text)
    for old, new in ((r"\bthemselves\b", "yourself"), (r"\btheir\b", "your"), (r"\bthem\b", "you"),
                     (r"\bthey\b", "you"), (r"\bthe bearer\b", "you"), (r"\bthe player\b", "you")):
        text = re.sub(old, new, text)
    return "You " + text[0].lower() + text[1:] + "."


def _first_sentence(text: str) -> str:
    cut = text.find(". ")
    return text if cut < 0 else text[:cut + 1]


def _clean(items: list[str], limit: int) -> list[str]:
    out: list[str] = []
    for item in items:
        if item and not guard.removed(item) and item not in out:
            out.append(item)
    return out[:limit]


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

def find_signals(registry: Registry, model: PlayerModel) -> list[Signal]:
    """Every dimension with enough evidence to say something, ranked by how much
    it should shape the design."""
    imp = registry.implications
    out: list[Signal] = []
    for st in model.compute().values():
        d = registry.dims[st.id]
        if st.status in ("unknown", "contested") or abs(st.value) < MIN_SIGNAL_VALUE:
            continue
        if d.family == "aesthetic":
            continue
        direction = 1 if st.value >= 0 else -1
        if d.family == "axis":
            rule = imp["axis_rules"][st.id]["pos" if direction > 0 else "neg"]
        else:
            if direction < 0:
                continue                      # an aversion makes a constraint, not a signal
            rule = (imp["weight_rules"].get(st.id) or {}).get("high")
            if not rule:
                continue
            if not rule.get("visions") and st.id in registry.reading.get("weight_visions", {}):
                rule = dict(rule, visions=registry.reading["weight_visions"][st.id])
        support, _ = model.evidence(st.id, limit=3)
        out.append(Signal(token=f"{st.id}{'+' if direction > 0 else '-'}", dim=st.id, dir=direction,
                          salience=st.salience(d.importance), value=st.value, confidence=st.confidence,
                          status=st.status, rule=rule, evidence=_clean(support, 3)))
    return sorted(out, key=lambda s: s.salience, reverse=True)


def choose_signals(registry: Registry, signals: list[Signal]) -> tuple[list[Signal], list[Signal], list[Signal]]:
    """Three dominant, two secondary. Signals that say nearly the same thing are
    folded together, so the design is not one pleasure counted three times."""
    groups = [set(g) for g in registry.reading["related"]]
    chosen: list[Signal] = []
    rest: list[Signal] = []
    for sig in signals:
        if not sig.rule.get("implication"):
            rest.append(sig)          # a flavour (tone, story delivery, power arc): it sets fields, not the design
            continue
        partner = next((c for c in chosen
                        if any(sig.token in g and c.token in g for g in groups)), None)
        if partner is not None:
            partner.merged.append(sig.token)
            for e in sig.evidence:
                if e not in partner.evidence and len(partner.evidence) < 4:
                    partner.evidence.append(e)
            rest.append(sig)
        elif len(chosen) < 5:
            chosen.append(sig)
        else:
            rest.append(sig)
    return chosen[:3], chosen[3:5], rest


def find_contradiction(registry: Registry, model: PlayerModel) -> dict | None:
    """The tension to build on: two things this player wants that pull against
    each other, or one thing they went both ways on."""

    def strength(token: str) -> float:
        dim, direction = parse_signed(token)
        st, d = model.state(dim), registry.dims[dim]
        if st.status == "unknown":
            return 0.0
        if st.status == "contested":
            return 0.1 * d.importance
        if (st.value >= 0) != (direction > 0) or abs(st.value) < MIN_SIGNAL_VALUE:
            return 0.0
        return abs(st.value) * max(st.confidence, 0.1) * d.importance

    best, best_score = None, 0.0
    for c in registry.implications["contradictions"]:
        score = min(strength(c["a"]), strength(c["b"]))
        if score > best_score:
            best, best_score = c, score
    if best is not None:
        sides = []
        evidence: list[str] = []
        for token in (best["a"], best["b"]):
            dim, direction = parse_signed(token)
            d = registry.dims[dim]
            sides.append(d.pole(direction) if d.bipolar else d.desc)
            evidence.extend(model.evidence(dim, limit=1)[0])
        return {"id": best["id"], "between": sides, "dims": [best["a"], best["b"]],
                "evidence": _clean(evidence, 3), "resolution": best["resolution"], "vision": best["vision"],
                "observed": True}
    contested = [st for st in model.compute().values() if st.status == "contested"
                 and registry.dims[st.id].family == "axis"]
    if contested:
        st = max(contested, key=lambda s: min(s.support, s.against) * registry.dims[s.id].importance)
        d = registry.dims[st.id]
        support, against = model.evidence(st.id, limit=1)
        return {"id": f"contested_{st.id}", "between": [d.neg, d.pos], "dims": [f"{st.id}-", f"{st.id}+"],
                "evidence": _clean(support + against, 2),
                "resolution": (f"The player went both ways on this in different rooms. Offer both: every situation "
                               f"has a {d.neg} way through and a {d.pos} way through, chosen in the moment and "
                               f"never locked in at the start."),
                "vision": "I see two ways through every room, and you taking each of them, on different days.",
                "observed": True}
    return None


# ---------------------------------------------------------------------------
# The draft
# ---------------------------------------------------------------------------

def _mood(registry: Registry, model: PlayerModel) -> str | None:
    """Audiovisual mood from the ways the bearer took and the tones they leaned into."""
    looks = []
    for st in model.ranked(("aesthetic",)):
        if st.confidence >= 0.15 and abs(st.value) >= MIN_SIGNAL_VALUE and st.status != "contested":
            looks.append(registry.dims[st.id].pole(st.value))
    tones = [st.id for st in model.ranked(("tone",))
             if st.value > MIN_SIGNAL_VALUE and st.confidence >= 0.15][:3]
    if not looks and not tones:
        return None
    parts = []
    if tones:
        rule = (registry.implications["weight_rules"].get(tones[0]) or {}).get("high") or {}
        lead = (rule.get("gdv") or {}).get("audiovisual_mood") or tones[0].split(".", 1)[1]
        parts.append(lead)
        if len(tones) > 1:
            parts.append("with notes of " + " and ".join(t.split(".", 1)[1] for t in tones[1:]))
    if looks:
        parts.append("look: " + ", ".join(looks[:4]))
    return "; ".join(parts)


def _best_keyed(registry: Registry, model: PlayerModel, table: dict, axis_field: str) -> tuple[str, str] | None:
    """The entry whose dimension should shape the design most: a weight the player is
    drawn to, or the pole of an axis they lean toward, whichever is stronger."""
    best, best_score = None, 0.0
    for dim, text in table.items():
        st = model.state(dim)
        if st.status == "unknown" or st.value <= MIN_SIGNAL_VALUE:
            continue
        score = st.salience(registry.dims[dim].importance)
        if score > best_score:
            best, best_score = (dim, text), score
    for token, entry in registry.reading["axis_keyed"].items():
        dim, direction = parse_signed(token)
        st = model.state(dim)
        if st.status in ("unknown", "contested") or abs(st.value) < MIN_SIGNAL_VALUE:
            continue
        if (st.value > 0) != (direction > 0):
            continue
        score = st.salience(registry.dims[dim].importance)
        if score > best_score:
            best, best_score = (token, entry[axis_field]), score
    return best


def build_draft(registry: Registry, model: PlayerModel, session: Session) -> dict:
    imp, reading, w = registry.implications, registry.reading, session.world
    rng = random.Random(f"{session.rng_seed}:reading")
    ctx = night_context(session)
    signals = find_signals(registry, model)
    dominant, secondary, rest = choose_signals(registry, signals)
    contradiction = find_contradiction(registry, model)

    # ---- Game Design Vector: the strongest signal that speaks to a field sets it
    gdv: dict[str, str] = {}
    sources: dict[str, str] = {}
    for sig in dominant + secondary + rest:
        for key, value in (sig.rule.get("gdv") or {}).items():
            if key not in gdv:
                gdv[key], sources[key] = value, sig.token
    fantasy = _best_keyed(registry, model, imp["fantasies"], "fantasy")
    if fantasy:
        gdv["central_fantasy"], sources["central_fantasy"] = fantasy[1], fantasy[0]
    verb = _best_keyed(registry, model, imp["core_verbs"], "verb")
    if verb:
        gdv["core_verb"], sources["core_verb"] = verb[1], verb[0]
        gdv.setdefault("primary_loop", f"meet a situation; {verb[1]}; see what the world does in answer; "
                                       f"carry what that taught into the next")
        sources.setdefault("primary_loop", verb[0])
    mood = _mood(registry, model)
    if mood:
        gdv["audiovisual_mood"], sources["audiovisual_mood"] = mood, "thresholds taken"
    for f in imp["gdv_fields"]:
        if f["id"] not in gdv:
            gdv[f["id"]], sources[f["id"]] = f["default"], "default"
    gdv = {f["id"]: gdv[f["id"]] for f in imp["gdv_fields"]}

    # ---- implications and constraints
    implications = [s.rule["implication"] for s in dominant + secondary]
    if contradiction:
        implications.append(contradiction["resolution"])
    for sig in rest:
        if len(implications) >= 12:
            break
        text = sig.rule.get("implication")
        if text and text not in implications:
            implications.append(text)
    negatives: list[str] = []
    for sig in dominant + secondary + rest:
        negatives.extend(sig.rule.get("negative") or [])
    for st in model.compute().values():
        low = (imp["weight_rules"].get(st.id) or {}).get("low")
        if low and st.value < -MIN_SIGNAL_VALUE and st.status in ("leaning", "established"):
            negatives.extend(low.get("negative") or [])
    negatives = _clean(negatives, 10)

    # ---- what the night gives back
    callbacks = []
    told: list[dict] = []                       # the conditions of the echoes already chosen
    for cb in reading["callbacks"]:
        if not holds(cb["when"], ctx) or len(callbacks) >= 4:
            continue
        local = ctx
        if "{moment}" in cb["from"]:
            fresh = fresh_moment(registry, w, told)
            if fresh is None:
                continue                        # every remembered moment is already an echo
            local = dict(ctx, moment=fresh)
        told.append(cb["when"])
        callbacks.append({"id": cb["id"], "card": cb["card"], "from": fill(cb["from"], local),
                          "becomes": fill(cb["becomes"], local), "vision": fill(cb["vision"], local)})
    unrequested = next(u for u in reading["unrequested"] if holds(u["when"], ctx))

    unknown_axes = sorted((st for st in model.compute().values()
                           if st.status == "unknown" and registry.dims[st.id].family == "axis"),
                          key=lambda s: registry.dims[s.id].importance, reverse=True)
    unknowns = [f"Whether this player wants {registry.dims[st.id].neg} or {registry.dims[st.id].pos} "
                f"({st.id}) was not observed. Nothing in the design depends on it." for st in unknown_axes]
    if mood is None:
        unknowns.append("Visual and tonal taste was barely observed: the look of the game is the builder's "
                        "choice within the scope constraints.")
    contradiction_dims = {parse_signed(tok)[0] for tok in (contradiction or {}).get("dims", [])}
    for st in model.compute().values():
        if st.status == "contested" and st.id not in contradiction_dims:
            d = registry.dims[st.id]
            unknowns.append(f"The player went both ways on {d.neg} against {d.pos} ({st.id}); the design "
                            f"should allow both rather than choose.")

    # ---- title and pitch
    cards_map = imp["cards"]
    title = None
    if w.cards:
        title = w.cards[0]["title"]
    elif dominant:
        title = cards_map.get(dominant[0].token) or cards_map.get(dominant[0].dim)
    title = title or "The Blank Deck"
    fantasy_text = gdv["central_fantasy"] if fantasy else "a small strange place that answers to how you play"
    verb_text = gdv["core_verb"] if verb else "act and see what answers"
    pitch = f"A pocket game about {fantasy_text}. You {verb_text}."
    if contradiction and not contradiction["id"].startswith("contested_"):
        pitch += " " + contradiction["resolution"]      # the tension is where the game stops being generic
    elif dominant:
        pitch += " " + _first_sentence(dominant[0].rule["implication"])

    design = {
        "working_title": title,
        "pitch": pitch,
        "design_signals": {
            "dominant": [s.entry() for s in dominant],
            "secondary": [s.entry() for s in secondary],
            "productive_contradiction": (
                {"between": contradiction["between"], "evidence": contradiction["evidence"],
                 "resolution": contradiction["resolution"]} if contradiction else
                {"between": [], "evidence": [], "resolution": "No real tension was observed tonight; nothing in "
                                                              "the design depends on one."}),
        },
        "design_implications": implications,
        "game_design_vector": gdv,
        "negative_constraints": negatives,
        "personal_callbacks": [{"from": c["from"], "becomes": c["becomes"]} for c in callbacks],
        "unrequested_feature": {"feature": unrequested["feature"], "follows_from": unrequested["follows_from"]},
        "unknowns": unknowns,
    }

    # ---- the reading
    used: set[str] = set()

    def card_for(sig: Signal) -> str:
        for c in w.cards:
            if c["title"] not in used and sig.token in (c.get("dims") or []):
                used.add(c["title"])
                return c["title"]
        name = cards_map.get(sig.token) or cards_map.get(sig.dim)
        if not name or name in used:
            name = "The " + sig.dim.split(".")[-1].replace("_", " ").title()
        used.add(name)
        return name

    def vision_for(sig: Signal) -> dict:
        options = sig.rule.get("visions") or ["I see a game that fits your hand."]
        return {"card": card_for(sig), "text": rng.choice(options),
                "fulfils": _first_sentence(sig.rule["implication"]),
                "echo": sig.evidence[0] if sig.evidence else None}

    def callback_vision(cb: dict) -> dict:
        name = cb["card"] if cb["card"] not in used else cb["card"] + ", Again"
        used.add(name)
        return {"card": name, "text": cb["vision"], "fulfils": cb["becomes"], "echo": cb["from"]}

    visions: list[dict] = []
    if dominant:
        visions.append(vision_for(dominant[0]))
    if callbacks:
        visions.append(callback_vision(callbacks[0]))
    visions.extend(vision_for(s) for s in dominant[1:])
    if contradiction:
        visions.append({"card": imp["contradiction_card"], "text": contradiction["vision"],
                        "fulfils": contradiction["resolution"], "echo": None})
    visions.extend(vision_for(s) for s in secondary)
    if len(callbacks) > 1:
        visions.append(callback_vision(callbacks[1]))
    absence = next((n for n in negatives if n.startswith("No ")), None)
    if absence and not any(v["text"].startswith("I see no") for v in visions):
        visions.append({"card": reading["no_vision"]["card"],
                        "text": reading["no_vision"]["text"].replace("{absence}", "no " + absence[3:]),
                        "fulfils": absence, "echo": None})
    if len(visions) < 5:
        for cb in callbacks[2:]:
            if len(visions) < 5:
                visions.append(callback_vision(cb))
    if len(visions) < 5 or len(signals) < 3:
        visions.append({"card": reading["blank_card"]["card"], "text": reading["blank_card"]["text"],
                        "fulfils": "Where the profile is unknown, the builder chooses and records the default.",
                        "echo": None})
    visions = visions[:9]

    recollections: list[str] = []
    seen_seeds: set[str] = set()
    for m in w.moments:
        if m["seed"] in seen_seeds or len(recollections) >= 4:
            continue
        seen_seeds.add(m["seed"])
        recollections.append(second_person(m["text"]))
    for fact in reading["facts"]:
        if len(recollections) >= 3:
            break
        if holds(fact["when"], ctx) and fact["text"] not in recollections:
            recollections.append(fact["text"])

    prophecy = {
        "address": rng.choice(reading["addresses"]),
        "recollections": recollections,
        "visions": visions,
        "pronouncement": PRONOUNCEMENT,
        "final_line": " ".join(imp["final_lines"]),
    }
    return {
        "design": design, "prophecy": prophecy, "gdv_sources": sources,
        "signals": [{"token": s.token, "salience": round(s.salience, 3), "value": round(s.value, 3),
                     "confidence": round(s.confidence, 3), "status": s.status, "merged": s.merged}
                    for s in signals],
        "contradiction": contradiction, "callbacks": callbacks,
        "thin_evidence": len(dominant) < 3,
    }


# ---------------------------------------------------------------------------
# Evidence, as text for the model
# ---------------------------------------------------------------------------

def evidence_text(registry: Registry, model: PlayerModel, session: Session, draft: dict) -> str:
    w = session.world
    lines = ["### What is known, most important first",
             "(value runs from -1, the first pole, to +1, the second pole; for weights +1 means drawn to it)"]
    for st in model.ranked()[:26]:
        d = registry.dims[st.id]
        support, against = model.evidence(st.id, limit=3)
        line = (f"- {st.id}: {model.label(st.id)} (value {st.value:+.2f}, confidence {st.confidence:.2f}, "
                f"{st.n_independent} independent scenes)")
        if d.bipolar:
            line += f" [{d.neg} / {d.pos}]"
        if _clean(support, 3):
            line += ". For: " + "; ".join(_clean(support, 3))
        if _clean(against, 2):
            line += ". Against: " + "; ".join(_clean(against, 2))
        lines.append(line)
    contested = [st.id for st in model.compute().values() if st.status == "contested"]
    unknown = [st.id for st in model.compute().values()
               if st.status == "unknown" and registry.dims[st.id].family in ("axis", "aesthetic")]
    lines.append("\n### Contested (the player went both ways)\n" + (", ".join(contested) or "none"))
    lines.append("\n### Unknown (not observed; do not guess)\n" + (", ".join(unknown) or "none"))
    explicit = [o.action for o in model.observations if o.kind == "explicit" and not guard.removed(o.action)]
    lines.append("\n### The night")
    lines.append("Chambers: " + "; ".join(f"{x['title']} ({x['line']})" for x in w.summaries))
    lines.append("Moments: " + ("; ".join(m["text"] for m in w.moments) or "none recorded"))
    lines.append("Cards that took a face: " + ("; ".join(f"{c['title']} ({c['image']})" for c in w.cards) or "none"))
    lines.append(f"Carried at the end: {w.carrying()}")
    if w.companion:
        lines.append(f"Companion: {w.companion.get('name')} ({w.companion.get('kind')})")
    if w.npcs:
        lines.append("People: " + "; ".join(f"{n['name']} ({n['attitude']}: {n['note']})" for n in w.npcs))
    lines.append("Left unresolved: " + ("; ".join(w.threads) or "nothing"))
    if w.threads_resolved:
        lines.append("Went back for: " + "; ".join(w.threads_resolved))
    if w.attempted:
        lines.append("Tried, and the house could only half allow: " + "; ".join(w.attempted[:6]))
    if w.ignored:
        lines.append("Passed over: " + "; ".join(w.ignored[:8]))
    if explicit:
        lines.append("Said outright: " + "; ".join(explicit[:5]))
    lines.append(f"Failures: {w.failures}. Ways taken between rooms: {', '.join(session.skins_taken) or 'none'}.")
    lines.append("\n### Rule-based first draft\n" + json.dumps(draft["design"], indent=1, ensure_ascii=False))
    return "\n".join(lines)


def night_text(session: Session) -> str:
    w = session.world
    lines = ["Chambers, in order: " + "; ".join(f"{x['title']}: {x['line']}" for x in w.summaries),
             "Moments: " + ("; ".join(m["text"] for m in w.moments) or "none recorded"),
             "Cards that took a face tonight: " + ("; ".join(f"{c['title']} ({c['image']})" for c in w.cards) or "none"),
             f"Carried at the end: {w.carrying()}"]
    if w.companion:
        lines.append(f"Companion: {w.companion.get('name')} ({w.companion.get('kind')})")
    if w.threads:
        lines.append("Walked past or left unresolved: " + "; ".join(w.threads))
    if w.attempted:
        lines.append("Tried, and the house could only half allow: " + "; ".join(w.attempted[:5]))
    if w.flags.get("wearing"):
        lines.append(f"Wearing: {w.flags['wearing']}")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

def _texts(value) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [t for v in value.values() for t in _texts(v)]
    if isinstance(value, list):
        return [t for v in value for t in _texts(v)]
    return []


def validate_design(design, registry: Registry) -> list[str]:
    problems: list[str] = []
    if not isinstance(design, dict):
        return ["the reply was not a JSON object"]
    for key in ("working_title", "pitch"):
        if not isinstance(design.get(key), str) or not design[key].strip():
            problems.append(f"{key} must be a non-empty string")
    sig = design.get("design_signals")
    if not isinstance(sig, dict):
        problems.append("design_signals must be an object")
    else:
        for name, count in (("dominant", 3), ("secondary", 2)):
            items = sig.get(name)
            if not isinstance(items, list) or len(items) != count:
                problems.append(f"design_signals.{name} must have exactly {count} entries")
            elif any(not (isinstance(i, dict) and i.get("signal") and i.get("design_consequence")) for i in items):
                problems.append(f"each design_signals.{name} entry needs signal and design_consequence")
        pc = sig.get("productive_contradiction")
        if not (isinstance(pc, dict) and pc.get("resolution")):
            problems.append("design_signals.productive_contradiction needs a resolution")
    imps = design.get("design_implications")
    if not (isinstance(imps, list) and len(imps) >= 6 and all(isinstance(i, str) for i in imps)):
        problems.append("design_implications must be a list of at least 6 sentences")
    vector = design.get("game_design_vector")
    if not isinstance(vector, dict):
        problems.append("game_design_vector must be an object")
    else:
        missing = [f for f in registry.gdv_field_ids()
                   if not (isinstance(vector.get(f), str) and vector[f].strip())]
        if missing:
            problems.append(f"game_design_vector is missing or empty for: {', '.join(missing)}")
    negs = design.get("negative_constraints")
    if not (isinstance(negs, list) and len(negs) >= 3):
        problems.append("negative_constraints must list at least 3")
    cbs = design.get("personal_callbacks")
    if not (isinstance(cbs, list) and cbs and all(isinstance(c, dict) and c.get("from") and c.get("becomes")
                                                  for c in cbs)):
        problems.append("personal_callbacks must be a non-empty list of {from, becomes}")
    un = design.get("unrequested_feature")
    if not (isinstance(un, dict) and un.get("feature") and un.get("follows_from")):
        problems.append("unrequested_feature needs feature and follows_from")
    if not isinstance(design.get("unknowns"), list):
        problems.append("unknowns must be a list")
    if any(guard.sensitive(t) for t in _texts(design)):
        problems.append("the design makes a claim about the person rather than about how they play; remove it")
    return problems


def validate_prophecy(prophecy) -> list[str]:
    problems: list[str] = []
    if not isinstance(prophecy, dict):
        return ["the reply was not a JSON object"]
    if not isinstance(prophecy.get("address"), str) or not prophecy["address"].strip():
        problems.append("address must be a non-empty string")
    rec = prophecy.get("recollections")
    if not (isinstance(rec, list) and 2 <= len(rec) <= 5 and all(isinstance(r, str) for r in rec)):
        problems.append("recollections must be 3 or 4 sentences")
    visions = prophecy.get("visions")
    if not (isinstance(visions, list) and 5 <= len(visions) <= 9):
        problems.append("visions must number between 5 and 9")
    elif any(not (isinstance(v, dict) and v.get("card") and v.get("text")) for v in visions):
        problems.append("every vision needs a card and a text")
    if not isinstance(prophecy.get("final_line"), str) or not prophecy["final_line"].strip():
        problems.append("final_line must be a non-empty string")
    spoken = _texts({k: prophecy.get(k) for k in ("address", "recollections", "final_line")})
    spoken += [v.get("text", "") for v in visions or [] if isinstance(v, dict)]
    words = guard.prophecy_problems(spoken)
    if words:
        problems.append(f"the reading uses the language of analysis ({', '.join(words)}); say it as the Proprietor")
    if any(guard.sensitive(t) for t in spoken):
        problems.append("the reading makes a claim about who the bearer is; it may only speak of how they played")
    return problems


# ---------------------------------------------------------------------------
# The model stage
# ---------------------------------------------------------------------------

def _ask(backend: Backend, session: Session, purpose: str, prompt: str, validate, ui, label: str):
    """One call, one repair attempt. Returns (data or None, problems)."""
    system = "You return exactly one JSON object and nothing else: no prose, no code fences."
    problems: list[str] = []
    attempt_prompt = prompt
    for attempt in (1, 2):
        entry = {"turn": session.turn, "purpose": purpose if attempt == 1 else "repair",
                 "backend": getattr(backend, "name", "?")}
        try:
            with ui.waiting(label):
                done = backend.complete(system, attempt_prompt, purpose=purpose if attempt == 1 else "repair")
        except BackendError as exc:
            entry.update({"error": exc.kind, "detail": str(exc)[:300]})
            session.backend_log.append(entry)
            return None, [f"backend {exc.kind}: {str(exc)[:160]}"]
        entry.update({"latency": round(done.latency, 2), "usage": done.usage, "model": done.model,
                      "prompt_chars": len(attempt_prompt), "reply_chars": len(done.text)})
        session.backend_log.append(entry)
        data = parse_json_reply(done.text)
        problems = validate(data)
        if not problems:
            return data, []
        attempt_prompt = (f"{prompt}\n\n## Your previous answer was rejected\n\nProblems:\n"
                          + "\n".join(f"- {p}" for p in problems)
                          + f"\n\nPrevious answer:\n{done.text[:6000]}\n\nReturn the corrected JSON object only.")
    return None, problems


def synthesize(registry: Registry, model: PlayerModel, session: Session, backend: Backend | None, ui) -> dict:
    """Run both stages and return everything the prompt and the reading need."""
    draft = build_draft(registry, model, session)
    result = {"design": draft["design"], "prophecy": draft["prophecy"], "draft": draft,
              "source": {"design": "rules", "prophecy": "rules"}, "problems": {}, "prompts": {}}
    if backend is None:
        return result
    imp = registry.implications
    scope = "\n".join(f"- {c}" for c in registry.scope_lines())
    fields = ",\n".join(f'    "{f["id"]}": "<{f["label"].lower()}>"' for f in imp["gdv_fields"])
    design_prompt = (registry.texts["synthesis_design"]
                     .replace("{{SCOPE}}", scope)
                     .replace("{{EVIDENCE}}", evidence_text(registry, model, session, draft))
                     .replace("{{GDV_FIELDS}}", fields))
    result["prompts"]["design"] = design_prompt
    design, problems = _ask(backend, session, "design", design_prompt,
                            lambda d: validate_design(d, registry), ui, "the cards are being laid out")
    if design is not None:
        result["design"], result["source"]["design"] = design, getattr(backend, "name", "model")
    else:
        result["problems"]["design"] = problems

    prophecy_prompt = (registry.texts["synthesis_prophecy"]
                       .replace("{{DESIGN}}", json.dumps(result["design"], indent=1, ensure_ascii=False))
                       .replace("{{NIGHT}}", night_text(session)))
    result["prompts"]["prophecy"] = prophecy_prompt
    prophecy, problems = _ask(backend, session, "prophecy", prophecy_prompt, validate_prophecy, ui,
                              "the Proprietor turns the first card")
    if prophecy is not None:
        prophecy["pronouncement"] = PRONOUNCEMENT
        result["prophecy"], result["source"]["prophecy"] = prophecy, getattr(backend, "name", "model")
    elif result["source"]["design"] != "rules":
        # The design changed but the reading could not be written to match it: keep the pair
        # consistent by falling back to the draft for both, which were made together.
        result["problems"]["prophecy"] = problems
        result["design"], result["source"]["design"] = draft["design"], "rules (reading could not be matched)"
    else:
        result["problems"]["prophecy"] = problems
    return result


# ---------------------------------------------------------------------------
# The machine-facing profile
# ---------------------------------------------------------------------------

def build_profile(registry: Registry, model: PlayerModel, session: Session, synthesis: dict) -> dict:
    from . import PROFILE_VERSION
    design, prophecy, w = synthesis["design"], synthesis["prophecy"], session.world

    def entry(st, with_poles: bool) -> dict:
        d = registry.dims[st.id]
        support, against = model.evidence(st.id, limit=4)
        out = {"value": round(st.value, 3), "confidence": round(st.confidence, 3), "status": st.status,
               "reading": model.label(st.id),
               "independent_observations": st.n_independent, "observations": st.n_observations,
               "behavioral": st.behavioral, "explicit": st.explicit, "last_turn": st.last_turn,
               "evidence": _clean(support, 4), "contradictions": _clean(against, 4)}
        if with_poles:
            out["poles"] = {"-1": d.neg, "+1": d.pos}
        return out

    states = model.compute()

    def family(*names: str, poles: bool = False) -> dict:
        return {st.id: entry(st, poles) for st in states.values() if registry.dims[st.id].family in names}

    contradictions = []
    pc = design["design_signals"].get("productive_contradiction") or {}
    if pc.get("between"):
        contradictions.append({"between": pc["between"], "evidence": pc.get("evidence", []),
                               "resolution": pc.get("resolution", "")})
    for st in states.values():
        if st.status == "contested":
            d = registry.dims[st.id]
            contradictions.append({"between": [d.neg, d.pos], "dimension": st.id,
                                   "note": "the player went both ways in different scenes"})
    anti = list(design.get("negative_constraints") or [])
    for st in states.values():
        d = registry.dims[st.id]
        if not d.bipolar and st.value < -MIN_SIGNAL_VALUE and st.status in ("leaning", "established"):
            anti.append(f"declined: {d.desc} ({st.id})")
    motifs = [f"{c['title']}: {c['image']}" for c in w.cards]
    motifs += [f"the way of {registry.skins[s]['threshold'].split(',')[0]}" for s in session.skins_taken
               if s in registry.skins]
    return {
        "version": PROFILE_VERSION,
        "session": {"id": session.id, "turns": session.turn, "chambers": len(w.summaries),
                    "narrator": session.config.get("backend_used", "offline"),
                    "design_by": synthesis["source"]["design"], "reading_by": synthesis["source"]["prophecy"]},
        "conventions": {
            "scope": "play preferences only; nothing here describes the person",
            "value": "-1 to +1. For a two-poled dimension -1 is the first pole and +1 the second. "
                     "For a weight, +1 is drawn to it and -1 is declined.",
            "confidence": "0 to 1; capped until the evidence comes from at least three independent scenes",
            "status": "unknown | faint | leaning | established | contested",
        },
        "dimensions": family("axis", poles=True),
        "motivations": family("reward"),
        "problem_solving_weights": family("solve"),
        "conflict_weights": family("conflict"),
        "social_weights": family("soc"),
        "narrative_weights": family("story"),
        "power_arc_weights": family("arc"),
        "tone_weights": family("tone"),
        "aesthetic_weights": family("aesthetic", poles=True),
        "strong_signals": design["design_signals"]["dominant"] + design["design_signals"]["secondary"],
        "anti_preferences": _clean(anti, 16),
        "interesting_contradictions": contradictions,
        "unknowns": design.get("unknowns", []),
        "memorable_player_moments": [m["text"] for m in w.moments],
        "prophetic_motifs": motifs,
        "design_implications": design["design_implications"],
        "generated_prophecy": [f"{v['card']}: {v['text']}" for v in prophecy["visions"]],
        "working_title": design["working_title"],
        "pitch": design["pitch"],
        "game_design_vector": design["game_design_vector"],
        "negative_constraints": design["negative_constraints"],
        "personal_callbacks": design["personal_callbacks"],
        "unrequested_feature": design["unrequested_feature"],
        "scope_constraints": registry.scope_lines(),
        "prophecy": prophecy,
    }
