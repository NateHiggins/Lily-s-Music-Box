#!/usr/bin/env python3
"""One material registry; the catalogues and the mapping are generated from it.

Step 1 of the registry in design/TEXTURE_LIBRARY_OPTIMIZATION_PLAN_2026-11-09.md.
`art/data/material_registry.json` holds one record per material id. These files
are generated from it and must stay byte-identical (LF-normalized) to what the
registry writes, because dozens of fixtures pin them by hash:

    art/data/material_catalog.json      every record's catalogue values
    game/data/material_catalog.json     the records marked in_game_catalog
    art/textures/catalog_mapping.json   every record's source_set

Edit the registry, then run --write. --check fails when a generated file has
drifted from the registry (someone edited a catalogue by hand).

    python art/tools/material_registry.py --check
    python art/tools/material_registry.py --write
    python art/tools/material_registry.py --import-legacy [--trace sorted.json]

texture_status records what the phase 0 load trace saw for the record's own
canonical maps (the names generate_runtime_materials.py derives): live (V2,
city or dream), v1_only, unloaded (shipped, never loaded), or no_maps.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = "art/data/material_registry.json"
ART_CATALOG = "art/data/material_catalog.json"
GAME_CATALOG = "game/data/material_catalog.json"
MAPPING = "art/textures/catalog_mapping.json"
SCHEMA = "orison.material-registry.v1"
TEXTURE_STATUS = ("live", "v1_only", "unloaded", "no_maps")
IMPORT_TIERS = ("surface", "surface_normal", "hero", "sky", "ui", "data")
RECORD_KEYS = ("id", "catalog", "source_set", "in_game_catalog", "texture_status",
               "import_tier")


def _read(root: Path, rel: str) -> dict:
    return json.loads((root / rel).read_text(encoding="utf8"))


def _dump(data: dict, trailing_newline: bool) -> str:
    return json.dumps(data, indent=1) + ("\n" if trailing_newline else "")


def canonical_stem(material_id: str, source_set: str | None) -> str:
    """The game texture stem generate_runtime_materials._canonical_files derives."""
    if source_set and source_set.startswith("library/"):
        return "T_" + source_set.replace("/", "_")
    return "T_ai_materials_" + material_id


def texture_status(material_id: str, source_set: str | None, sort: dict[str, str]) -> str:
    stem = canonical_stem(material_id, source_set)
    seen = [sort[p] for p in (f"assets/building/textures/{stem}_{c}.png"
                              for c in ("albedo", "rough", "normal")) if p in sort]
    if not seen:
        return "no_maps"
    if any(s in ("v2_live", "dream") for s in seen):
        return "live"
    if "v1_only" in seen:
        return "v1_only"
    return "unloaded"


def import_legacy(root: Path, trace: Path | None) -> dict:
    catalog = _read(root, ART_CATALOG)
    game = _read(root, GAME_CATALOG)
    mapping = _read(root, MAPPING)
    sort = {}
    if trace:
        sort = {row["path"]: row["sort"] for row in json.loads(trace.read_text(encoding="utf8"))}
    ids = list(catalog) + [k for k in mapping if k not in catalog]
    records = []
    for material_id in ids:
        source_set = mapping.get(material_id)
        records.append({
            "id": material_id,
            "catalog": catalog.get(material_id),
            "source_set": source_set,
            "in_game_catalog": material_id in game,
            "texture_status": texture_status(material_id, source_set, sort) if sort else "no_maps",
            "import_tier": "surface",
        })
    return {
        "schema": SCHEMA,
        "about": "One record per material id. art/data/material_catalog.json, "
                 "game/data/material_catalog.json and art/textures/catalog_mapping.json "
                 "are generated from this file by art/tools/material_registry.py --write.",
        "legacy_order": {
            "catalog_mapping": list(mapping),
            "about": "Key order of catalog_mapping.json, kept only so the generated file "
                     "stays byte-identical while fixtures pin it. Removed at the renewal pass.",
        },
        "materials": records,
    }


def validate(registry: dict) -> list[str]:
    errors = []
    if registry.get("schema") != SCHEMA:
        errors.append("schema must be " + SCHEMA)
    seen = set()
    for record in registry.get("materials", []):
        material_id = record.get("id")
        if tuple(record) != RECORD_KEYS:
            errors.append(f"{material_id}: record keys must be {RECORD_KEYS}")
        if material_id in seen:
            errors.append(f"{material_id}: duplicate id")
        seen.add(material_id)
        if record.get("catalog") is None and record.get("in_game_catalog"):
            errors.append(f"{material_id}: in_game_catalog needs catalogue values")
        if record.get("catalog") is None and material_id not in registry.get("legacy_order", {}).get("catalog_mapping", []):
            errors.append(f"{material_id}: neither catalogue values nor a source set")
        if record.get("texture_status") not in TEXTURE_STATUS:
            errors.append(f"{material_id}: texture_status must be one of {TEXTURE_STATUS}")
        if record.get("import_tier") not in IMPORT_TIERS:
            errors.append(f"{material_id}: import_tier must be one of {IMPORT_TIERS}")
    order = registry.get("legacy_order", {}).get("catalog_mapping", [])
    # The mapping also carries explicit nulls (materials with no texture set),
    # so the order list, not the source_set value, decides mapping membership.
    mapped = {r["id"] for r in registry.get("materials", []) if r.get("source_set") is not None}
    if len(order) != len(set(order)) or not set(order) <= seen or not mapped <= set(order):
        errors.append("legacy_order.catalog_mapping must list every mapped id once")
    return errors


def render(registry: dict) -> dict[str, str]:
    records = registry["materials"]
    by_id = {r["id"]: r for r in records}
    catalog = {r["id"]: r["catalog"] for r in records if r["catalog"] is not None}
    game = {r["id"]: r["catalog"] for r in records if r["in_game_catalog"]}
    mapping = {i: by_id[i]["source_set"] for i in registry["legacy_order"]["catalog_mapping"]}
    return {ART_CATALOG: _dump(catalog, True), GAME_CATALOG: _dump(game, False),
            MAPPING: _dump(mapping, True)}


def check(root: Path, registry: dict) -> list[str]:
    errors = validate(registry)
    if errors:
        return errors
    for rel, text in render(registry).items():
        current = (root / rel).read_bytes().replace(b"\r\n", b"\n")
        if current != text.encode("utf8"):
            errors.append(f"{rel} differs from the registry; edit {REGISTRY} and run --write")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--write", action="store_true")
    group.add_argument("--import-legacy", action="store_true")
    parser.add_argument("--trace", help="phase 0 sorted.json, for --import-legacy")
    parser.add_argument("--root", default=str(ROOT))
    args = parser.parse_args(argv)
    root = Path(args.root)
    if args.import_legacy:
        registry = import_legacy(root, Path(args.trace) if args.trace else None)
        (root / REGISTRY).write_text(_dump(registry, True), encoding="utf8", newline="\n")
        print(f"wrote {REGISTRY}: {len(registry['materials'])} materials")
        return 0
    registry = _read(root, REGISTRY)
    if args.write:
        errors = validate(registry)
        if errors:
            print("\n".join(errors)); return 1
        for rel, text in render(registry).items():
            (root / rel).write_text(text, encoding="utf8", newline="\n")
        print("wrote", ", ".join(render(registry)))
        return 0
    errors = check(root, registry)
    print("\n".join(errors) if errors else f"{REGISTRY}: generated tables match")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
