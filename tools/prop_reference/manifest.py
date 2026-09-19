"""Read the warehouse manifest, the layout's installed counts, tiers and queries."""

from __future__ import annotations

import collections
import json
import math
import re
from pathlib import Path

MANIFEST_SCHEMA = "orison.prop-warehouse-shot.v1"
HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[1]


def load_json(path: Path) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def load_manifest(path: Path) -> dict:
    data = load_json(path)
    if data.get("schema") != MANIFEST_SCHEMA:
        raise ValueError(f"not a warehouse manifest: {path} ({data.get('schema')!r})")
    if not isinstance(data.get("specimens"), list):
        raise ValueError(f"manifest has no specimens list: {path}")
    return data


def specimen_id(record: dict) -> str:
    """Stable across shed re-layouts: kind plus the plinth label (the variant).

    The shed's node index moves whenever any family earlier in the alphabet
    gains or loses a variant, so keying reference folders by node name would
    orphan every download the next time a prop grew a variant. Kind and label
    are what a specimen *is*; the node name is only where it stood today.
    """
    kind = re.sub(r"[^A-Za-z0-9]+", "_", str(record.get("kind", ""))).strip("_")
    label = str(record.get("label", "")).lower()
    label = re.sub(r"^" + re.escape(kind.lower()) + r"\s*[/·-]\s*", "", label)
    label = re.sub(r"[^a-z0-9]+", "_", label).strip("_")[:48]
    if label == kind.lower():
        label = ""  # "boiler" labelled "boiler" is one specimen, not "boiler__boiler"
    if not kind:
        return re.sub(r"[^A-Za-z0-9_.-]+", "_", str(record.get("node", "")))
    return f"{kind}__{label}" if label else kind


def assign_ids(specimens: list[dict]) -> list[str]:
    """Ids for a whole manifest, collision-aware.

    A family may register several variants under one plinth label (boxfan
    does). The shed only tells us the label, so the second and later
    specimens with the same id get a positional suffix in manifest order.
    Positional is the honest fallback: it is stable for as long as the family
    keeps its variant order, and it is visibly a fallback.
    """
    counts: collections.Counter = collections.Counter()
    base = [specimen_id(record) for record in specimens]
    totals = collections.Counter(base)
    out: list[str] = []
    for ident in base:
        if totals[ident] > 1:
            counts[ident] += 1
            out.append(f"{ident}__{counts[ident]}")
        else:
            out.append(ident)
    return out


def installed_counts(layout_path: Path) -> collections.Counter:
    """Count marker kinds in building_layout.json exactly as the audit does:
    a dict with a string ``kind`` and a placement field is one installed prop."""
    counts: collections.Counter = collections.Counter()

    def walk(node):
        if isinstance(node, dict):
            kind = node.get("kind")
            if isinstance(kind, str) and any(k in node for k in ("room", "pos", "position", "at")):
                counts[kind] += 1
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(load_json(layout_path))
    return counts


def load_tiers(path: Path | None = None) -> dict:
    return load_json(path or HERE / "tiers.json")


def tier_for(kind: str, tiers: dict) -> dict:
    entry = tiers["kinds"].get(kind)
    if entry is None:
        entry = {"tier": "unlisted", "note": "not in tiers.json"}
    weight = tiers["weights"].get(entry["tier"], tiers["weights"]["unlisted"])
    return {"tier": entry["tier"], "weight": weight, "note": entry.get("note", "")}


def reviewed_before(kind: str, tiers: dict) -> bool:
    return kind in set(tiers.get("reviewed_families", []))


def resolve_queries(record: dict, queries: dict) -> list[str]:
    """Variant queries first (matched on the plinth label), then the kind's."""
    kind = record.get("kind", "")
    entry = (queries.get("kinds") or {}).get(kind)
    if not entry:
        return []
    label = str(record.get("label", "")).lower()
    out: list[str] = []
    for variant in entry.get("variants", []):
        needle = str(variant.get("label_match", "")).lower()
        if needle == "*" or (needle and needle in label):
            out.extend(variant.get("queries", []))
    out.extend(entry.get("queries", []))
    seen: set[str] = set()
    unique = []
    for query in out:
        if query not in seen:
            seen.add(query)
            unique.append(query)
    return unique


def installed_factor(count: int) -> float:
    """Diminishing weight for how often the player meets the object."""
    return 1.0 + math.log2(1 + max(0, count)) / 3.0


def describe(record: dict, counts: collections.Counter, tiers: dict, queries: dict,
             ident: str | None = None) -> dict:
    kind = record.get("kind", "")
    size = record.get("bounds_size_m") or [0, 0, 0]
    materials = record.get("materials") or {}
    tier = tier_for(kind, tiers)
    return {
        "id": ident or specimen_id(record),
        "kind": kind,
        "label": record.get("label", ""),
        "mount": record.get("mount", ""),
        "has_geometry": bool(record.get("has_geometry", False)),
        "size_m": [round(float(v), 3) for v in size],
        "installed_count": int(counts.get(kind, 0)),
        "tier": tier["tier"],
        "tier_weight": tier["weight"],
        "tier_note": tier["note"],
        "reviewed_before": reviewed_before(kind, tiers),
        "triangles": int(materials.get("triangles", 0)),
        "surfaces": int(materials.get("surfaces", 0)),
        "textured_surfaces": int(materials.get("textured_surfaces", 0)),
        "flat_colour_share": float(materials.get("flat_colour_share", 1.0)),
        "material_names": materials.get("materials", {}),
        "frames": record.get("frames", {}),
        "queries": resolve_queries(record, queries),
        "real_object": ((queries.get("kinds") or {}).get(kind) or {}).get("real_object", ""),
    }
