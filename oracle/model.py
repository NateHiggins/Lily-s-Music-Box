"""The hidden player model.

A model of PLAY PREFERENCES and nothing else. It is rebuilt from the
observation log every time it is asked for, so the profile is a pure function
of the evidence: reproducible, inspectable, and never drifting away from what
was actually seen.

Each dimension is a Beta belief over "leans toward the +1 pole":

    alpha = 1 + mass of evidence toward +1
    beta  = 1 + mass of evidence toward -1
    value = 2 * mean - 1                      (-1 .. +1)
    confidence = 2 * |P(p > 0.5) - 0.5|       (0 .. 1), then capped

One choice is never definitive: confidence is capped until the evidence comes
from several independent scenes. Repeating a behaviour inside one scene adds
less each time. Evidence both ways is kept, not averaged away: a dimension with
real mass on both poles is marked "contested", which is information.

An action that can be read several ways is recorded with competing hypotheses.
When later scenes corroborate one reading, that reading's share of the original
observation grows (see `PlayerModel.compute`).
"""

from __future__ import annotations

import math
from collections import defaultdict
from dataclasses import dataclass, field

from .content import Registry

STRENGTH_WEIGHT = {"weak": 0.3, "moderate": 0.6, "strong": 1.0}
KIND_FACTOR = {"behavioral": 1.0, "explicit": 0.7}   # a statement is useful, never privileged
PRIOR = 1.0
SAME_SCENE_DISCOUNT = 0.5        # the k-th same-direction observation in one scene counts 0.5**k
MIN_INDEPENDENT_WEIGHT = 0.08    # a scene counts as an independent context above this mass
CONFIDENCE_CAP = {0: 0.0, 1: 0.35, 2: 0.70}
CONFIDENCE_CAP_DEFAULT = 0.97
UNKNOWN_MASS = 0.15           # below this there is nothing to say: "we do not know"
CONTESTED_MASS = 0.6
CONTESTED_RATIO = 0.5
AMBIGUOUS_TOP_SHARE = 0.6
ESTABLISHED_CONFIDENCE = 0.6
LEANING_CONFIDENCE = 0.3


# ---------------------------------------------------------------------------
# Regularised incomplete beta function (standard library only)
# ---------------------------------------------------------------------------

def _betacf(a: float, b: float, x: float) -> float:
    tiny = 1e-300
    qab, qap, qam = a + b, a + 1.0, a - 1.0
    c = 1.0
    d = 1.0 - qab * x / qap
    if abs(d) < tiny:
        d = tiny
    d = 1.0 / d
    h = d
    for m in range(1, 300):
        m2 = 2 * m
        aa = m * (b - m) * x / ((qam + m2) * (a + m2))
        d = 1.0 + aa * d
        if abs(d) < tiny:
            d = tiny
        c = 1.0 + aa / c
        if abs(c) < tiny:
            c = tiny
        d = 1.0 / d
        h *= d * c
        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))
        d = 1.0 + aa * d
        if abs(d) < tiny:
            d = tiny
        c = 1.0 + aa / c
        if abs(c) < tiny:
            c = tiny
        d = 1.0 / d
        delta = d * c
        h *= delta
        if abs(delta - 1.0) < 3e-12:
            break
    return h


def betainc(a: float, b: float, x: float) -> float:
    """I_x(a, b): the probability that a Beta(a, b) variable is at most x."""
    if x <= 0.0:
        return 0.0
    if x >= 1.0:
        return 1.0
    ln_bt = (math.lgamma(a + b) - math.lgamma(a) - math.lgamma(b)
             + a * math.log(x) + b * math.log(1.0 - x))
    bt = math.exp(ln_bt)
    if x < (a + 1.0) / (a + b + 2.0):
        return bt * _betacf(a, b, x) / a
    return 1.0 - bt * _betacf(b, a, 1.0 - x) / b


# ---------------------------------------------------------------------------
# Records
# ---------------------------------------------------------------------------

@dataclass
class Hypothesis:
    dim: str
    dir: int
    share: float
    why: str = ""
    posterior: float | None = None     # share after later evidence was weighed

    def to_dict(self) -> dict:
        out = {"dim": self.dim, "dir": self.dir, "share": round(self.share, 3)}
        if self.why:
            out["why"] = self.why
        if self.posterior is not None and abs(self.posterior - self.share) > 1e-6:
            out["posterior"] = round(self.posterior, 3)
        return out


@dataclass
class Observation:
    id: int
    turn: int
    scene: str          # independence key, for example "c3:bridge"
    seed: str
    frame: str          # encounter kind; differently framed evidence is worth more
    kind: str           # behavioral | explicit
    strength: str       # weak | moderate | strong
    action: str
    context: str
    hypotheses: list[Hypothesis]
    source: str         # llm | offline | rule | aggregate
    signal: str = ""

    def to_dict(self) -> dict:
        return {"id": self.id, "turn": self.turn, "scene": self.scene, "seed": self.seed,
                "frame": self.frame, "kind": self.kind, "strength": self.strength,
                "action": self.action, "context": self.context, "source": self.source,
                "signal": self.signal, "hypotheses": [h.to_dict() for h in self.hypotheses]}

    @staticmethod
    def from_dict(d: dict) -> "Observation":
        return Observation(
            id=d["id"], turn=d["turn"], scene=d["scene"], seed=d["seed"], frame=d["frame"],
            kind=d["kind"], strength=d["strength"], action=d["action"], context=d.get("context", ""),
            source=d.get("source", "llm"), signal=d.get("signal", ""),
            hypotheses=[Hypothesis(h["dim"], int(h["dir"]), float(h["share"]), h.get("why", ""))
                        for h in d["hypotheses"]])


@dataclass
class DimState:
    id: str
    value: float = 0.0
    confidence: float = 0.0
    status: str = "unknown"            # unknown | faint | leaning | established | contested
    support: float = 0.0               # evidence mass toward +1
    against: float = 0.0               # evidence mass toward -1
    n_observations: int = 0
    n_independent: int = 0
    n_frames: int = 0
    last_turn: int | None = None
    explicit: int = 0
    behavioral: int = 0
    supporting: list[int] = field(default_factory=list)      # observation ids agreeing with the estimate
    contradicting: list[int] = field(default_factory=list)   # observation ids against it

    @property
    def mass(self) -> float:
        return self.support + self.against

    @property
    def sign(self) -> int:
        return 1 if self.value >= 0 else -1

    def salience(self, importance: float = 1.0) -> float:
        """How much this dimension should shape the design."""
        return abs(self.value) * self.confidence * importance

    def to_dict(self) -> dict:
        return {"value": round(self.value, 3), "confidence": round(self.confidence, 3),
                "status": self.status, "support": round(self.support, 3),
                "against": round(self.against, 3), "observations": self.n_observations,
                "independent_observations": self.n_independent, "frames": self.n_frames,
                "last_turn": self.last_turn, "explicit": self.explicit,
                "behavioral": self.behavioral}


# ---------------------------------------------------------------------------
# The model
# ---------------------------------------------------------------------------

class PlayerModel:
    def __init__(self, registry: Registry, observations: list[Observation] | None = None):
        self.registry = registry
        self.observations: list[Observation] = list(observations or [])
        self._states: dict[str, DimState] | None = None

    # ---- recording ---------------------------------------------------
    def add(self, *, turn: int, scene: str, seed: str, frame: str, action: str,
            hypotheses: list, kind: str = "behavioral", strength: str = "weak",
            context: str = "", source: str = "llm", signal: str = "") -> Observation | None:
        """Record one observation. Malformed parts are dropped, never guessed at.
        Returns None when nothing valid remains."""
        kind = kind if kind in KIND_FACTOR else "behavioral"
        strength = strength if strength in STRENGTH_WEIGHT else "weak"
        clean: list[Hypothesis] = []
        for h in hypotheses or []:
            if isinstance(h, (list, tuple)) and len(h) >= 3:
                h = {"dim": h[0], "dir": h[1], "share": h[2]}
            if not isinstance(h, dict):
                continue
            dim = h.get("dim")
            if dim not in self.registry.dims:
                continue
            try:
                direction = float(h.get("dir", 0))
                share = float(h.get("share", 0))
            except (TypeError, ValueError):
                continue
            if direction == 0 or share <= 0:
                continue
            clean.append(Hypothesis(dim, 1 if direction > 0 else -1, min(share, 1.0),
                                    str(h.get("why", ""))[:160]))
        if not clean:
            return None
        total = sum(h.share for h in clean)
        if total > 1.0:
            for h in clean:
                h.share /= total
        obs = Observation(id=len(self.observations) + 1, turn=turn, scene=scene, seed=seed,
                          frame=frame, kind=kind, strength=strength, action=str(action)[:200],
                          context=str(context)[:200], hypotheses=clean, source=source, signal=signal)
        self.observations.append(obs)
        self._states = None
        return obs

    # ---- inference ---------------------------------------------------
    def _accumulate(self, use_posterior: bool):
        pos: dict[str, float] = defaultdict(float)
        neg: dict[str, float] = defaultdict(float)
        per_scene: dict[tuple, float] = defaultdict(float)
        seen: dict[tuple, int] = defaultdict(int)
        contributions: dict[str, list] = defaultdict(list)
        for obs in self.observations:
            base = STRENGTH_WEIGHT[obs.strength] * KIND_FACTOR[obs.kind]
            for h in obs.hypotheses:
                share = h.posterior if (use_posterior and h.posterior is not None) else h.share
                key = (h.dim, h.dir, obs.scene)
                weight = base * share * (SAME_SCENE_DISCOUNT ** seen[key])
                seen[key] += 1
                (pos if h.dir > 0 else neg)[h.dim] += weight
                per_scene[key] += weight
                contributions[h.dim].append((obs, h.dir, weight))
        return pos, neg, per_scene, contributions

    def compute(self) -> dict[str, DimState]:
        if self._states is not None:
            return self._states
        # Pass 1: take every hypothesis at its stated share.
        pos, neg, per_scene, _ = self._accumulate(use_posterior=False)
        # Disambiguation: an observation that could be read several ways gives more of
        # its weight to the readings that other scenes have since corroborated.
        for obs in self.observations:
            hs = obs.hypotheses
            ambiguous = (len(hs) >= 2 and len({h.dim for h in hs}) >= 2
                         and max(h.share for h in hs) <= AMBIGUOUS_TOP_SHARE)
            if not ambiguous:
                for h in hs:
                    h.posterior = h.share
                continue
            total = sum(h.share for h in hs)
            raw = []
            for h in hs:
                everywhere = (pos if h.dir > 0 else neg)[h.dim]
                here = per_scene[(h.dim, h.dir, obs.scene)]
                elsewhere = max(0.0, everywhere - here)
                raw.append(h.share * (0.5 + min(elsewhere, 2.0)))
            norm = sum(raw) or 1.0
            for h, r in zip(hs, raw):
                h.posterior = total * r / norm
        # Pass 2: recompute with the adjusted shares.
        pos, neg, per_scene, contributions = self._accumulate(use_posterior=True)

        states: dict[str, DimState] = {}
        for dim in self.registry.dims:
            st = DimState(dim)
            st.support, st.against = pos.get(dim, 0.0), neg.get(dim, 0.0)
            alpha, beta = PRIOR + st.support, PRIOR + st.against
            st.value = 2.0 * alpha / (alpha + beta) - 1.0
            p_positive = 1.0 - betainc(alpha, beta, 0.5)
            direction_confidence = 2.0 * abs(p_positive - 0.5)
            scenes, frames = set(), set()
            for obs, direction, weight in contributions.get(dim, []):
                st.n_observations += 1
                st.last_turn = obs.turn if st.last_turn is None else max(st.last_turn, obs.turn)
                if obs.kind == "explicit":
                    st.explicit += 1
                else:
                    st.behavioral += 1
                if per_scene[(dim, direction, obs.scene)] >= MIN_INDEPENDENT_WEIGHT:
                    scenes.add(obs.scene)
                    frames.add(obs.frame)
                agrees = (direction > 0) == (st.value >= 0)
                (st.supporting if agrees else st.contradicting).append(obs.id)
            st.n_independent, st.n_frames = len(scenes), len(frames)
            cap = CONFIDENCE_CAP.get(st.n_independent, CONFIDENCE_CAP_DEFAULT)
            st.confidence = min(direction_confidence, cap)
            lo, hi = sorted((st.support, st.against))
            contested = lo >= CONTESTED_MASS and hi > 0 and lo / hi >= CONTESTED_RATIO
            if st.mass < UNKNOWN_MASS:
                st.status = "unknown"
            elif contested:
                st.status = "contested"
            elif st.confidence >= ESTABLISHED_CONFIDENCE and st.n_independent >= 3:
                st.status = "established"
            elif st.confidence >= LEANING_CONFIDENCE:
                st.status = "leaning"
            else:
                st.status = "faint"
            states[dim] = st
        self._states = states
        return states

    def state(self, dim: str) -> DimState:
        return self.compute()[dim]

    # ---- views -------------------------------------------------------
    def snapshot(self) -> dict[str, list[float]]:
        """Compact value/confidence pairs for dimensions with any evidence."""
        return {d: [round(s.value, 3), round(s.confidence, 3)]
                for d, s in self.compute().items() if s.mass > 0}

    def ambiguities(self) -> list[dict]:
        """Observations recorded with competing readings, with how later evidence
        has shifted their shares. Open ones are what the next probe should separate."""
        self.compute()
        out = []
        for obs in self.observations:
            hs = obs.hypotheses
            if not (len(hs) >= 2 and len({h.dim for h in hs}) >= 2
                    and max(h.share for h in hs) <= AMBIGUOUS_TOP_SHARE):
                continue
            total = sum(h.share for h in hs) or 1.0
            posts = sorted(((h.posterior or h.share) for h in hs), reverse=True)
            top_posterior = posts[0] / total
            runner_up = posts[1] / posts[0] if posts[0] else 0.0
            out.append({
                "observation": obs.id, "turn": obs.turn, "scene": obs.scene, "action": obs.action,
                "candidates": [{"dim": h.dim, "dir": h.dir, "share": round(h.share, 3),
                                "posterior": round(h.posterior or h.share, 3)} for h in hs],
                # open: later evidence has not yet favoured one reading over the next
                "open": top_posterior < 0.55 and runner_up > 0.6,
            })
        return out

    def ranked(self, families: tuple[str, ...] | None = None, min_status: bool = True) -> list[DimState]:
        """Dimensions ordered by how much they should shape the design."""
        dims = self.registry.dims
        states = [s for s in self.compute().values()
                  if (families is None or dims[s.id].family in families)
                  and (not min_status or s.status != "unknown")]
        return sorted(states, key=lambda s: s.salience(dims[s.id].importance), reverse=True)

    def evidence(self, dim: str, limit: int = 4) -> tuple[list[str], list[str]]:
        """Short texts of the observations for and against the current estimate."""
        st = self.state(dim)
        by_id = {o.id: o for o in self.observations}
        return ([by_id[i].action for i in st.supporting[-limit:]],
                [by_id[i].action for i in st.contradicting[-limit:]])

    def label(self, dim: str) -> str:
        """Plain words for where a dimension stands."""
        st, d = self.state(dim), self.registry.dims[dim]
        if st.status == "unknown":
            return "unknown"
        if st.status == "contested":
            return f"contested between {d.neg} and {d.pos}"
        pole = d.pos if st.value >= 0 else d.neg
        if d.bipolar:
            return f"{st.status} toward {pole}"
        return f"{st.status}: {pole}"

    # ---- persistence -------------------------------------------------
    def to_list(self) -> list[dict]:
        return [o.to_dict() for o in self.observations]

    @staticmethod
    def from_list(registry: Registry, data: list[dict]) -> "PlayerModel":
        return PlayerModel(registry, [Observation.from_dict(d) for d in data])
