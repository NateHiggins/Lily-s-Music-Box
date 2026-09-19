"""Deterministic priority from structured critiques plus repository facts.

The critique for a specimen is a JSON object written by the review pass:

    {"specimen": "WH_fridge_07", "axes": {"object_class": 0-5, "proportion": 0-5,
     "silhouette": 0-5, "detail": 0-5, "material": 0-5, "wear": 0-5, "mount": 0-5},
     "effort_hours": float, "summary": str, "modelling": [str], "texturing": [str],
     "references_used": [str], "confidence": "high|medium|low"}

Axis severities are how far we are from the reference on that axis (0 = no
gap). The score is not a judgement of taste: it multiplies how often the
object is met (installed count), how much play it carries (tier), and how
large the measured gap is, then lowers families a completed review already
served unless their gap is still large.
"""

from __future__ import annotations

import json
from pathlib import Path

from .manifest import installed_factor

AXES = ("object_class", "proportion", "silhouette", "detail", "material", "wear", "mount")
AXIS_WEIGHT = {"object_class": 1.6, "proportion": 1.3, "silhouette": 1.2, "detail": 0.9,
               "material": 1.1, "wear": 0.7, "mount": 0.8}


def gap(critique: dict) -> float:
    axes = critique.get("axes") or {}
    total = sum(AXIS_WEIGHT[a] * float(axes.get(a, 0)) for a in AXES)
    return total / sum(AXIS_WEIGHT.values())


def score(facts: dict, critique: dict | None) -> dict:
    """Priority = tier weight x installed factor x (0.35 + gap/5 x 1.65) x review discount."""
    g = gap(critique) if critique else 0.0
    tier_w = float(facts.get("tier_weight", 1.0))
    inst = installed_factor(int(facts.get("installed_count", 0)))
    flat = float(facts.get("flat_colour_share", 1.0))
    base = tier_w * inst * (0.35 + (g / 5.0) * 1.65)
    # A reviewed family with a small remaining gap has had its turn.
    discount = 0.6 if facts.get("reviewed_before") and g < 1.5 else 1.0
    # Wholly flat-coloured specimens are a texturing brief by construction.
    flat_bonus = 0.25 * flat if flat > 0.85 else 0.0
    value = base * discount + flat_bonus
    not_assessable = not facts.get("has_geometry", True)
    if not_assessable:
        # The shed drew nothing, so nothing here was compared to a reference.
        # That is a finding about the shed's registration, not a modelling
        # priority; the brief lists these apart rather than ranking them.
        value = 0.0
    return {"priority": round(value, 3), "gap": round(g, 3), "tier_weight": tier_w,
            "installed_factor": round(inst, 3), "review_discount": discount,
            "flat_bonus": round(flat_bonus, 3), "has_critique": critique is not None,
            "not_assessable": not_assessable}


def rank(entries: list[dict], critiques: dict[str, dict]) -> list[dict]:
    ranked = []
    for facts in entries:
        critique = critiques.get(facts["id"])
        row = dict(facts)
        row["critique"] = critique or {}
        row["score"] = score(facts, critique)
        ranked.append(row)
    ranked.sort(key=lambda r: (r["score"]["not_assessable"], -r["score"]["priority"], r["kind"], r["id"]))
    for i, row in enumerate(ranked, 1):
        row["rank"] = i
    return ranked


def load_critiques(directory: Path) -> dict[str, dict]:
    out: dict[str, dict] = {}
    if not directory.exists():
        return out
    for path in sorted(directory.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
        specimen = data.get("specimen") or path.stem
        out[specimen] = data
    return out
