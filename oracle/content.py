"""Loads and validates the authored content in oracle/content/.

Content is data, and data with no checked shape rots. Every file is loaded by
this one strict loader, which refuses a wrong schema_version, an unknown
dimension id, a malformed evidence triple or an unknown Game Design Vector
field. A typo in the data fails loudly here, at load, not as a silently
ignored observation in the middle of someone's night.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

CONTENT_DIR = Path(__file__).resolve().parent / "content"
SCHEMA_VERSION = 1
STRENGTHS = ("weak", "moderate", "strong")
SEED_FILES = ("seeds_core.json", "seeds_more.json", "seeds_last.json")


class ContentError(Exception):
    """Raised when authored content does not match its contract."""


@dataclass(frozen=True)
class Dim:
    id: str
    family: str          # axis | aesthetic | reward | solve | conflict | soc | tone | story | arc
    neg: str             # label of the -1 pole ("declined" for weights)
    pos: str             # label of the +1 pole ("drawn to" for weights)
    importance: float
    desc: str
    bipolar: bool

    def pole(self, value: float) -> str:
        return self.pos if value >= 0 else self.neg


@dataclass
class Registry:
    dims: dict[str, Dim]
    seeds: dict[str, dict]
    skins: dict[str, dict]
    signals: dict[str, dict]
    implications: dict
    texts: dict[str, str] = field(default_factory=dict)
    reading: dict = field(default_factory=dict)

    # ---- convenience -------------------------------------------------
    def opener(self) -> dict:
        return next(s for s in self.seeds.values() if s.get("role") == "opener")

    def finale(self) -> dict:
        return next(s for s in self.seeds.values() if s.get("role") == "finale")

    def chamber_seeds(self) -> list[dict]:
        return [s for s in self.seeds.values() if s.get("role") in (None, "callback")]

    def gdv_field_ids(self) -> list[str]:
        return [f["id"] for f in self.implications["gdv_fields"]]

    def axis_ids(self) -> list[str]:
        return [d.id for d in self.dims.values() if d.family == "axis"]

    def dimension_prompt(self) -> str:
        """The dimension list as shown to the narrator model."""
        lines: list[str] = []
        for d in self.dims.values():
            if d.family == "axis":
                lines.append(f"- {d.id}: {d.neg} / {d.pos}. {d.desc}")
        lines.append("- Aesthetic axes (mostly evidenced by which threshold they take): "
                     + "; ".join(f"{d.id}: {d.neg} / {d.pos}"
                                 for d in self.dims.values() if d.family == "aesthetic"))
        fams: dict[str, list[Dim]] = {}
        for d in self.dims.values():
            if not d.bipolar:
                fams.setdefault(d.family, []).append(d)
        for fam, items in fams.items():
            head = self.implications["_weight_desc"].get(fam, "")
            lines.append(f"- Weights '{fam}.*' ({head}) "
                         + "; ".join(f"{d.id}: {d.desc}" for d in items))
        return "\n".join(lines)

    def signal_prompt(self) -> str:
        lines = []
        for s in self.signals.values():
            if s["obs"]:
                reading = ", ".join(f"{dim} {'+1' if d > 0 else '-1'}" for dim, d, _ in s["obs"])
            else:
                reading = "file under whatever they stated, kind explicit"
            lines.append(f"- {s['id']}: {s['desc']}: {reading}")
        return "\n".join(lines)


def _load_json(name: str) -> dict:
    path = CONTENT_DIR / name
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ContentError(f"content file missing: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ContentError(f"{name}: not valid JSON: {exc}") from exc
    if data.get("schema_version") != SCHEMA_VERSION:
        raise ContentError(f"{name}: schema_version {data.get('schema_version')!r}, "
                           f"this loader reads {SCHEMA_VERSION}")
    return data


def _check_triples(where: str, triples, dims: dict[str, Dim]) -> None:
    if not isinstance(triples, list):
        raise ContentError(f"{where}: obs must be a list")
    total = 0.0
    for t in triples:
        if not (isinstance(t, list) and len(t) == 3):
            raise ContentError(f"{where}: evidence must be [dimension, direction, share], got {t!r}")
        dim, direction, share = t
        if dim not in dims:
            raise ContentError(f"{where}: unknown dimension {dim!r}")
        if direction not in (1, -1):
            raise ContentError(f"{where}: direction must be 1 or -1, got {direction!r}")
        if not (isinstance(share, (int, float)) and 0 < share <= 1):
            raise ContentError(f"{where}: share must be in (0, 1], got {share!r}")
        total += share
    if total > 1.6:
        raise ContentError(f"{where}: shares add up to {total:.2f}; keep an option's evidence modest")


def _parse_signed(where: str, token: str, dims: dict[str, Dim]) -> tuple[str, int]:
    if not isinstance(token, str) or token[-1:] not in "+-":
        raise ContentError(f"{where}: expected a dimension id ending in + or -, got {token!r}")
    dim = token[:-1]
    if dim not in dims:
        raise ContentError(f"{where}: unknown dimension {dim!r}")
    return dim, (1 if token.endswith("+") else -1)


def parse_signed(token: str) -> tuple[str, int]:
    return token[:-1], (1 if token.endswith("+") else -1)


def _words(label: str) -> str:
    """Pole labels are written as identifiers in the data and shown as words."""
    return label.replace("_", " ")


def _load_dims() -> tuple[dict[str, Dim], dict[str, str]]:
    data = _load_json("dimensions.json")
    dims: dict[str, Dim] = {}
    for a in data["axes"]:
        dims[a["id"]] = Dim(a["id"], "axis", _words(a["neg"]), _words(a["pos"]), float(a["importance"]),
                            a["desc"], True)
    for a in data["aesthetic_axes"]:
        dims[a["id"]] = Dim(a["id"], "aesthetic", _words(a["neg"]), _words(a["pos"]), float(a["importance"]),
                            f"{_words(a['neg'])} or {_words(a['pos'])}", True)
    weight_desc: dict[str, str] = {}
    for fam, block in data["weights"].items():
        weight_desc[fam] = block["desc"]
        for key, desc in block["items"].items():
            did = f"{fam}.{key}"
            dims[did] = Dim(did, fam, "declined", "drawn to", float(block["importance"]), desc, False)
    if len(dims) != len(set(dims)):
        raise ContentError("dimensions.json: duplicate ids")
    return dims, weight_desc


def _load_seeds(dims: dict[str, Dim]) -> dict[str, dict]:
    seeds: dict[str, dict] = {}
    for name in SEED_FILES:
        for seed in _load_json(name)["seeds"]:
            sid = seed.get("id")
            where = f"{name}:{sid}"
            if not sid or sid in seeds:
                raise ContentError(f"{where}: missing or duplicate seed id")
            for key in ("title", "kind", "premise", "intro", "targets", "reads", "options",
                        "hint", "fallback", "nudge", "close"):
                if key not in seed:
                    raise ContentError(f"{where}: missing {key!r}")
            for dim, power in seed["targets"].items():
                if dim not in dims:
                    raise ContentError(f"{where}: target on unknown dimension {dim!r}")
                if not 0 < power <= 1:
                    raise ContentError(f"{where}: target power for {dim} must be in (0, 1]")
            for pair in seed.get("separates", []):
                if len(pair) != 2:
                    raise ContentError(f"{where}: separates entries are pairs")
                for token in pair:
                    _parse_signed(f"{where}.separates", token, dims)
            seen = set()
            for opt in seed["options"]:
                oid = opt.get("id")
                owhere = f"{where}.{oid}"
                if not oid or oid in seen:
                    raise ContentError(f"{owhere}: missing or duplicate option id")
                seen.add(oid)
                if not opt.get("match"):
                    raise ContentError(f"{owhere}: an option needs match keywords")
                if ("outcome" in opt) == ("outcomes" in opt):
                    raise ContentError(f"{owhere}: exactly one of outcome / outcomes")
                if "outcomes" in opt and not opt.get("counter"):
                    raise ContentError(f"{owhere}: outcomes needs a counter name")
                if opt.get("strength", "moderate") not in STRENGTHS:
                    raise ContentError(f"{owhere}: unknown strength {opt.get('strength')!r}")
                if not isinstance(opt.get("resolves"), bool):
                    raise ContentError(f"{owhere}: resolves must be true or false")
                when = opt.get("when", {})
                if set(when) - {"flag", "not_flag"}:
                    raise ContentError(f"{owhere}: when accepts flag / not_flag only")
                _check_triples(owhere, opt.get("obs", []), dims)
                card = opt.get("card")
                if card is not None and not (card.get("title") and card.get("image")):
                    raise ContentError(f"{owhere}: a card needs a title and an image")
            seeds[sid] = seed
    roles = [s.get("role") for s in seeds.values()]
    if roles.count("opener") != 1 or roles.count("finale") != 1:
        raise ContentError("seeds: exactly one opener and one finale are required")
    return seeds


def _load_skins(dims: dict[str, Dim]) -> dict[str, dict]:
    skins: dict[str, dict] = {}
    for skin in _load_json("skins.json")["skins"]:
        sid = skin["id"]
        for axis, direction in skin["aesthetic"].items():
            if axis not in dims or dims[axis].family != "aesthetic":
                raise ContentError(f"skins.json:{sid}: {axis!r} is not an aesthetic axis")
            if direction not in (1, -1):
                raise ContentError(f"skins.json:{sid}: direction must be 1 or -1")
        for tone in skin["tone"]:
            if f"tone.{tone}" not in dims:
                raise ContentError(f"skins.json:{sid}: unknown tone {tone!r}")
        if not skin.get("keywords"):
            raise ContentError(f"skins.json:{sid}: keywords are required for the offline matcher")
        skins[sid] = skin
    return skins


def _load_signals(dims: dict[str, Dim]) -> dict[str, dict]:
    signals: dict[str, dict] = {}
    for sig in _load_json("signals.json")["signals"]:
        _check_triples(f"signals.json:{sig['id']}", sig["obs"], dims)
        if sig.get("strength", "weak") not in STRENGTHS:
            raise ContentError(f"signals.json:{sig['id']}: unknown strength")
        signals[sig["id"]] = sig
    return signals


def _load_implications(dims: dict[str, Dim], weight_desc: dict[str, str]) -> dict:
    data = _load_json("implications.json")
    fields = {f["id"] for f in data["gdv_fields"]}

    def check_rule(where: str, rule: dict) -> None:
        for key in rule.get("gdv", {}):
            if key not in fields:
                raise ContentError(f"{where}: unknown Game Design Vector field {key!r}")

    for axis, poles in data["axis_rules"].items():
        if axis not in dims or dims[axis].family != "axis":
            raise ContentError(f"implications.json: {axis!r} is not an axis")
        for pole in ("neg", "pos"):
            rule = poles.get(pole)
            if not rule or not rule.get("signal") or not rule.get("implication"):
                raise ContentError(f"implications.json:{axis}.{pole}: signal and implication required")
            check_rule(f"implications.json:{axis}.{pole}", rule)
    missing = [d.id for d in dims.values() if d.family == "axis" and d.id not in data["axis_rules"]]
    if missing:
        raise ContentError(f"implications.json: axes without design rules: {missing}")
    for wid, rule in data["weight_rules"].items():
        if wid not in dims or dims[wid].bipolar:
            raise ContentError(f"implications.json: {wid!r} is not a weight")
        if "high" in rule:
            check_rule(f"implications.json:{wid}.high", rule["high"])
    for c in data["contradictions"]:
        for side in ("a", "b"):
            _parse_signed(f"implications.json:contradiction {c.get('id')}", c[side], dims)
        if not c.get("resolution"):
            raise ContentError(f"implications.json:contradiction {c.get('id')}: resolution required")
    for key in list(data["fantasies"]) + list(data["core_verbs"]):
        if key not in dims:
            raise ContentError(f"implications.json: fantasy or core verb on unknown dimension {key!r}")
    for key in data.get("cards", {}):
        dim = key[:-1] if key[-1:] in "+-" else key
        if dim not in dims:
            raise ContentError(f"implications.json: card title on unknown dimension {key!r}")
    data["_weight_desc"] = weight_desc
    return data


WHEN_KEYS = {"always", "companion", "attempted", "joker", "inventory", "thread", "threads", "flag",
             "failures", "signal", "moment", "matches_min", "matches_max"}


def _load_reading(dims: dict[str, Dim], signals: dict[str, dict]) -> dict:
    data = _load_json("reading.json")

    def check_when(where: str, when) -> None:
        if not isinstance(when, dict) or not when:
            raise ContentError(f"{where}: a when condition is required")
        unknown = set(when) - WHEN_KEYS
        if unknown:
            raise ContentError(f"{where}: unknown condition {sorted(unknown)}")
        if "signal" in when and when["signal"] not in signals:
            raise ContentError(f"{where}: unknown signal {when['signal']!r}")

    for group in data["related"]:
        for token in group:
            _parse_signed("reading.json:related", token, dims)
    seen = set()
    for cb in data["callbacks"]:
        where = f"reading.json:callback {cb.get('id')}"
        if not cb.get("id") or cb["id"] in seen:
            raise ContentError(f"{where}: missing or duplicate id")
        seen.add(cb["id"])
        check_when(where, cb.get("when"))
        for key in ("from", "becomes", "vision"):
            if not cb.get(key):
                raise ContentError(f"{where}: {key!r} is required")
    for i, item in enumerate(data["unrequested"]):
        check_when(f"reading.json:unrequested[{i}]", item.get("when"))
        if not item.get("feature") or not item.get("follows_from"):
            raise ContentError(f"reading.json:unrequested[{i}]: feature and follows_from are required")
    if not data["unrequested"] or "always" not in data["unrequested"][-1]["when"]:
        raise ContentError("reading.json: the last unrequested feature must be the always-true default")
    for i, item in enumerate(data["facts"]):
        check_when(f"reading.json:facts[{i}]", item.get("when"))
        if not item.get("text"):
            raise ContentError(f"reading.json:facts[{i}]: text is required")
    for d in dims.values():
        if d.family != "axis":
            continue
        for token in (f"{d.id}-", f"{d.id}+"):
            entry = data.get("axis_keyed", {}).get(token)
            if not (entry and entry.get("fantasy") and entry.get("verb")):
                raise ContentError(f"reading.json: axis_keyed needs a fantasy and a verb for {token}")
    for key, lines in data.get("weight_visions", {}).items():
        if key not in dims or dims[key].bipolar or not lines:
            raise ContentError(f"reading.json: weight_visions on unknown weight {key!r}")
    if not data.get("addresses") or not data.get("handoff_line"):
        raise ContentError("reading.json: addresses and handoff_line are required")
    return data


_CACHE: Registry | None = None


def load_registry(force: bool = False) -> Registry:
    """Load every content file once, validated."""
    global _CACHE
    if _CACHE is not None and not force:
        return _CACHE
    dims, weight_desc = _load_dims()
    registry = Registry(
        dims=dims,
        seeds=_load_seeds(dims),
        skins=_load_skins(dims),
        signals=_load_signals(dims),
        implications=_load_implications(dims, weight_desc),
    )
    registry.reading = _load_reading(dims, registry.signals)
    for name in ("setting", "narrator_system", "synthesis_design", "synthesis_prophecy", "builder_prompt"):
        path = CONTENT_DIR / f"{name}.md"
        if not path.is_file():
            raise ContentError(f"content file missing: {path}")
        registry.texts[name] = path.read_text(encoding="utf-8")
    _CACHE = registry
    return registry


def coverage_report(registry: Registry) -> dict[str, dict]:
    """Per dimension: which seeds probe it and through how many different kinds
    of encounter. The oracle may only become confident from several differently
    framed observations, so a dimension probed by one kind of scene is a gap."""
    report: dict[str, dict] = {}
    for dim in registry.dims.values():
        seeds = [s for s in registry.chamber_seeds() if dim.id in s["targets"]]
        report[dim.id] = {
            "seeds": [s["id"] for s in seeds],
            "kinds": sorted({s["kind"] for s in seeds}),
            "max_power": max((s["targets"][dim.id] for s in seeds), default=0.0),
        }
    return report
