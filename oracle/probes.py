"""Choosing what the house deals next.

The house does not run a fixed questionnaire. After every chamber it looks at
what the player model still does not know and deals the room most likely to
find it out:

- a dimension that is already confidently known stops being tested;
- a dimension with a signal seen in only one or two scenes is worth most: one
  choice is never definitive, so the house looks again in a different frame;
- an action that was recorded with competing readings pulls in a room whose
  options tell those readings apart;
- two rooms of the same kind are not dealt in a row.

Every decision is recorded with its score parts, so the developer view can show
why each room was dealt.
"""

from __future__ import annotations

import math
import random

from .content import Registry, parse_signed
from .model import PlayerModel

INTENSITY = {
    "hazard": 2, "pursuit": 2, "skill": 2, "chance": 2, "power": 2, "spectacle": 2,
    "quiet": 0, "make": 0, "collect": 0, "long": 0, "explore": 0, "plan": 0,
}
KNOWN_ENOUGH = 0.75      # above this confidence a dimension no longer attracts probes
SHORTLIST = 5            # the next room is dealt from the best few candidates...
TEMPERATURE = 0.3        # ...weighted by exp(score / temperature)


def need(registry: Registry, model: PlayerModel, dim: str) -> float:
    """How much another look at this dimension is worth."""
    st, d = model.state(dim), registry.dims[dim]
    if st.confidence >= KNOWN_ENOUGH and st.n_independent >= 3 and st.status != "contested":
        return 0.0
    value = d.importance * (1.0 - st.confidence)
    if st.status == "contested":
        value *= 1.3                 # went both ways: one more differently framed look
    elif st.status != "unknown" and st.n_independent < 3:
        value *= 1.5                 # a signal seen once or twice: confirming it is worth most
    return value


def top_needs(registry: Registry, model: PlayerModel, families: tuple[str, ...] | None = None,
              limit: int = 6) -> list[tuple[str, float]]:
    dims = [d for d in registry.dims.values() if families is None or d.family in families]
    scored = sorted(((d.id, need(registry, model, d.id)) for d in dims), key=lambda t: t[1], reverse=True)
    return [(d, round(n, 3)) for d, n in scored[:limit]]


def eligible(seed: dict, *, next_chamber: int, world) -> bool:
    req = seed.get("requires") or {}
    if req.get("joker") and world.joker != "kept":
        return False
    if "min_chamber" in req and next_chamber < req["min_chamber"]:
        return False
    if "max_chamber" in req and next_chamber > req["max_chamber"]:
        return False
    if req.get("threads") and not world.threads:
        return False
    return True


def _disambiguation(seed: dict, ambiguities: list[dict]) -> tuple[float, list[int]]:
    """Bonus when the seed's options separate readings that an earlier action left open."""
    bonus, hits = 0.0, []
    pairs = [(parse_signed(a), parse_signed(b)) for a, b in seed.get("separates", [])]
    for amb in ambiguities:
        if not amb["open"]:
            continue
        cands = {(c["dim"], c["dir"]) for c in amb["candidates"]}
        cand_dims = {c["dim"] for c in amb["candidates"]}
        for left, right in pairs:
            if left in cands and right in cands:
                bonus += 0.6
                hits.append(amb["observation"])
            elif left[0] in cand_dims and right[0] in cand_dims:
                bonus += 0.3
                hits.append(amb["observation"])
    return min(bonus, 1.2), hits


def select_seed(registry: Registry, model: PlayerModel, *, used: list[str], next_chamber: int,
                chamber_target: int, world, rng: random.Random) -> tuple[str, dict]:
    """Pick the next chamber. Returns the seed id and a record of why."""
    ambiguities = model.ambiguities()
    kinds_used = [registry.seeds[s]["kind"] for s in used if s in registry.seeds]
    last_kind = kinds_used[-1] if kinds_used else None
    candidates = []
    for seed in registry.chamber_seeds():
        if seed["id"] in used or not eligible(seed, next_chamber=next_chamber, world=world):
            continue
        targets = seed["targets"]
        contributions = {dim: power * need(registry, model, dim) for dim, power in targets.items()}
        info = sum(contributions.values()) / math.sqrt(len(targets))
        disamb, hits = _disambiguation(seed, ambiguities)
        variety = 0.0
        kind = seed["kind"]
        if kind == last_kind:
            variety -= 0.5
        elif kind in kinds_used[-3:]:
            variety -= 0.25
        if kind not in kinds_used:
            variety += 0.2
        if last_kind is not None:
            a, b = INTENSITY.get(kind, 1), INTENSITY.get(last_kind, 1)
            if a == b and a != 1:
                variety -= 0.2
        timing = 0.0
        if seed.get("role") == "callback":
            timing = 0.8 if next_chamber >= chamber_target - 1 else -0.5
        jitter = rng.uniform(0.0, 0.15)
        score = info + disamb + variety + timing + jitter
        top = sorted(contributions.items(), key=lambda t: t[1], reverse=True)[:3]
        candidates.append({
            "seed": seed["id"], "kind": kind, "score": round(score, 3),
            "parts": {"information": round(info, 3), "disambiguation": round(disamb, 3),
                      "variety": round(variety, 3), "timing": round(timing, 3), "jitter": round(jitter, 3)},
            "probes": [[d, round(v, 3)] for d, v in top],
            "separates_observations": hits,
        })
    if not candidates:      # every seed used: should not happen with 31 chamber seeds
        raise RuntimeError("no eligible chamber seeds remain")
    candidates.sort(key=lambda c: c["score"], reverse=True)
    # Deal from the best few, weighted by score, so two nights do not open with the same rooms
    # and a strong candidate is still much the likeliest.
    shortlist = candidates[:SHORTLIST]
    weights = [math.exp((c["score"] - shortlist[0]["score"]) / TEMPERATURE) for c in shortlist]
    chosen = rng.choices(shortlist, weights=weights, k=1)[0]
    for c, weight in zip(shortlist, weights):
        c["chance"] = round(weight / sum(weights), 3)
    record = {
        "kind": "seed", "for_chamber": next_chamber, "chosen": chosen["seed"],
        "why": _why(registry, model, chosen),
        "candidates": shortlist,
        "open_ambiguities": [a["observation"] for a in ambiguities if a["open"]],
        "least_known": top_needs(registry, model, limit=5),
    }
    return chosen["seed"], record


def _why(registry: Registry, model: PlayerModel, chosen: dict) -> str:
    parts = []
    for dim, _ in chosen["probes"]:
        parts.append(f"{dim} ({model.label(dim)})")
    text = "probes " + ", ".join(parts)
    if chosen["parts"]["disambiguation"] > 0:
        text += f"; separates readings left open by observation(s) {chosen['separates_observations']}"
    if chosen["parts"]["timing"] > 0:
        text += "; brings back something the bearer walked past"
    return text


# ---------------------------------------------------------------------------
# Thresholds
# ---------------------------------------------------------------------------

def select_skins(registry: Registry, model: PlayerModel, *, taken: list[str],
                 offered: list[list[str]], rng: random.Random, count: int = 3) -> tuple[list[str], dict]:
    """Pick the ways onward. They are chosen to disagree with each other on the
    aesthetic axes and tones the model knows least about, so that taking one is
    a comparison and not a coincidence."""
    recent = {s for group in offered[-2:] for s in group}
    pool = [s for s in registry.skins.values() if s["id"] not in taken] or list(registry.skins.values())

    def base(skin: dict) -> float:
        score = sum(need(registry, model, axis) for axis in skin["aesthetic"])
        score += 0.5 * sum(need(registry, model, f"tone.{t}") for t in skin["tone"])
        if skin["id"] in recent:
            score -= 0.8
        return score + rng.uniform(0.0, 0.2)

    scored = {s["id"]: base(s) for s in pool}
    picked: list[str] = []
    while len(picked) < min(count, len(pool)):
        best, best_score = None, -1e9
        for skin in pool:
            if skin["id"] in picked:
                continue
            contrast = 0.0
            for other_id in picked:
                other = registry.skins[other_id]
                for axis, direction in skin["aesthetic"].items():
                    if axis in other["aesthetic"]:
                        if other["aesthetic"][axis] != direction:
                            contrast += need(registry, model, axis)
                        else:
                            contrast -= 0.4
                contrast -= 0.3 * len(set(skin["tone"]) & set(other["tone"]))
            total = scored[skin["id"]] + contrast
            if total > best_score:
                best, best_score = skin["id"], total
        picked.append(best)
    rng.shuffle(picked)
    record = {"kind": "thresholds", "chosen": picked,
              "why": "contrast on " + ", ".join(d for d, _ in top_needs(registry, model, ("aesthetic",), 3)),
              "least_known_tones": top_needs(registry, model, ("tone",), 3)}
    return picked, record


def skin_evidence(registry: Registry, chosen: str, offered: list[str]) -> list[dict]:
    """What taking one way over the others says. Which quality of the threshold
    drew the bearer is not known, so each pick is recorded as competing
    hypotheses; an axis on which the rejected ways pointed the other way gets a
    larger share, because there the pick was a real comparison."""
    skin = registry.skins[chosen]
    others = [registry.skins[s] for s in offered if s != chosen and s in registry.skins]
    raw = {}
    for axis, direction in skin["aesthetic"].items():
        opposed = sum(1 for o in others if o["aesthetic"].get(axis) == -direction)
        raw[axis] = (direction, 1.0 + opposed)
    total = sum(w for _, w in raw.values()) or 1.0
    out = []
    if raw:
        out.append({
            "action": f"took the way of {skin['threshold'].split(',')[0].split(';')[0]}",
            "context": "chosen over " + "; ".join(o["id"] for o in others) if others else "the only way offered",
            "kind": "behavioral", "strength": "moderate",
            "hypotheses": [{"dim": axis, "dir": direction, "share": weight / total,
                            "why": "one quality of the way they took"} for axis, (direction, weight) in raw.items()],
        })
    tones = [t for t in skin["tone"] if not any(t in o["tone"] for o in others)] or list(skin["tone"])
    if tones:
        out.append({
            "action": f"took the {chosen} way",
            "context": "the mood of the way they took",
            "kind": "behavioral", "strength": "weak",
            "hypotheses": [{"dim": f"tone.{t}", "dir": 1, "share": 1.0 / len(tones),
                            "why": "the mood of the way they took"} for t in tones],
        })
    return out
