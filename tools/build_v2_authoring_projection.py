#!/usr/bin/env python3
"""Emit V2 runtime data and test proofs from complete household authoring inputs.

The sources preserve the pre-projection data, including attribution and planning
notes. Runtime projections omit only the explicitly named authoring/proof fields;
all other values, record order, geometry and ownership pass through unchanged.
"""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# Relative name: (record collection, identity key, fields belonging to authoring).
PROJECTIONS = {
    "domestic_furniture": ("furniture", "id", ("source_component", "support_source")),
    "domestic_radios": ("receivers", "id", ("bounds",)),
    "heating": ("network", "id", ("yaw_deg",)),
    "household_accessories": ("accessories", "id", ("bounds", "motion_bounds", "stance")),
    "upper_floor_programs": ("programs", "unit", ("stage", "pending")),
    "exterior/construction_shed": (None, None, ("intent",)),
}
PROOF_GROUPS = {"domestic_furniture": "furniture", "domestic_radios": "receivers",
                "household_accessories": "accessories"}
PROOF_PATH = "game/tests/data/v2_authoring_proof.json"


def source_path(name: str) -> str:
    return f"art/data/orison_v2/{name}_source.json"


def runtime_path(name: str) -> str:
    return f"game/data/orison_v2/{name}.json"


def project(name: str, source: dict) -> tuple[dict, dict]:
    if not isinstance(source, dict) or type(source.get("schema_version")) is not int or source["schema_version"] != 1:
        raise ValueError(f"{name}: expected schema_version 1 authoring object")
    collection, identity_key, fields = PROJECTIONS[name]
    runtime = copy.deepcopy(source)
    metadata = {}
    if collection is None:
        for field in fields:
            if field not in runtime:
                raise ValueError(f"{name}: missing authoring field {field}")
            metadata[field] = runtime.pop(field)
        return runtime, metadata
    if not isinstance(runtime.get(collection), list) or not runtime[collection]:
        raise ValueError(f"{name}: missing {collection} records")
    seen = set()
    for record in runtime[collection]:
        if not isinstance(record, dict):
            raise ValueError(f"{name}: malformed record")
        identity = record.get(identity_key)
        if not isinstance(identity, str) or not identity or identity in seen:
            raise ValueError(f"{name}: missing or duplicate {identity_key}")
        seen.add(identity)
        removed = {field: record.pop(field) for field in fields if field in record}
        if removed:
            metadata[identity] = removed
    return runtime, metadata


def render(value: dict, *, compact: bool = False) -> str:
    if compact:
        return json.dumps(value, separators=(",", ":"), ensure_ascii=False, allow_nan=False) + "\n"
    return json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n"


def outputs(root: Path) -> dict[str, str]:
    generated = {}
    proofs = {"schema_version": 1}
    for name in PROJECTIONS:
        source = json.loads((root / source_path(name)).read_text(encoding="utf-8"))
        runtime, metadata = project(name, source)
        generated[runtime_path(name)] = render(runtime, compact=name == "domestic_furniture")
        if name in PROOF_GROUPS:
            proofs[PROOF_GROUPS[name]] = metadata
    generated[PROOF_PATH] = render(proofs)
    return generated


def stale_outputs(root: Path, generated: dict[str, str]) -> list[str]:
    # read_text normalizes checkout CRLF; numeric values are never rounded.
    return [name for name, expected in generated.items()
            if not (root / name).is_file() or (root / name).read_text(encoding="utf-8") != expected]


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--check", action="store_true", help="refuse stale runtime data or test proofs")
    args = parser.parse_args(argv)
    generated = outputs(args.root)
    stale = stale_outputs(args.root, generated)
    if args.check:
        if stale:
            print("STALE V2 projections: " + ", ".join(stale))
            return 1
        print(f"V2 authoring projections match ({len(generated)} outputs)")
        return 0
    for name in stale:
        path = args.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(generated[name], encoding="utf-8", newline="\n")
    print(f"V2 authoring projections: {len(stale)} updated, {len(generated)} checked")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
