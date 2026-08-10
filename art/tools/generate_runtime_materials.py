"""Generate Godot's prop-material contract from the shared material catalog.

The catalog mapping and each texture set's metadata own physical scale and
texture identity.  This file owns only runtime optical behaviour, plus a
small, named set of temporary visual locks that preserve the approved prop
appearance while those old library plates are reviewed one family at a time.
"""
from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "art/data/material_catalog.json"
MAPPING = ROOT / "art/textures/catalog_mapping.json"
MANIFESTS = (ROOT / "art/data/runtime_material_sets.json",
             ROOT / "game/data/runtime_material_sets.json")
GDSCRIPT = ROOT / "game/scripts/generated/material_sets.gd"
GODOT_TEXTURES = ROOT / "game/assets/building/textures"

# Runtime users, and only runtime-specific optical policy.  Metallic defaults
# to the catalog. Roughness defaults to 1.0 because StandardMaterial multiplies
# its authored roughness map by this value; selected finishes deliberately cap
# that response. No texture path or physical scale is authored here.
RUNTIME_POLICY = {
    "enamel": {}, "enamel_appliance": {}, "appliance": {},
    "metal": {}, "chrome": {},
    "bakelite": {}, "cast_iron": {"roughness_multiplier": 0.60},
    "soot": {"roughness_multiplier": 0.90},
    "fx_grease": {"roughness_multiplier": 0.78, "alpha": True,
                  "generated": True, "meters_per_tile": 0.70},
    "brass": {},
    "brass_dull": {"roughness_multiplier": 0.52},
    "nickel_plated": {"roughness_multiplier": 0.82},
    "mirror_aged": {"roughness_multiplier": 0.18},
    "mica_heater": {}, "rubber_aged": {"roughness_multiplier": 0.82},
    "zinc_liner": {"roughness_multiplier": 0.82},
    "copper_aged": {"roughness_multiplier": 0.58},
    "porcelain": {}, "porcelain_fixture": {},
    "wood_dark": {}, "fabric_warm": {}, "linen": {},
    # Deliberate semantic alias, not a visual lock: rubberized duck keeps the
    # approved clean linen weave but has its own tint and waxed optical policy.
    # The rejected linen_aged AI plate carried a fixture-sized horizontal fold.
    "shower_duck": {"roughness_multiplier": 0.62,
                    "runtime_alias": "linen"},
    "paper": {}, "trim": {}, "plant": {}, "brass_bright": {},
    "bronze": {}, "car_paint": {}, "oak_quartered": {},
    "milk_glass": {}, "bakelite_black": {}, "terrazzo_dark": {},
    "brass_mesh": {}, "indicator_enamel": {},
}

# These are compatibility locks, not a second silent material catalog. They
# name the old approved runtime plate and scale explicitly, are emitted into
# the manifest, and are expected to disappear at the visual approval gates in
# TEXTURE_REPAIR_AND_PERFORMANCE_PLAN.md. New keys may not be added here.
VISUAL_LOCKS = {
    "enamel": ("T_library_appliances_aged_enamel_worn_enamel", 1.00),
    "appliance": ("T_library_appliances_aged_enamel_worn_appliance", 1.00),
    "metal": ("T_library_appliances_galvanized_metal_worn_metal", 0.90),
    "chrome": ("T_library_appliances_brushed_steel", 0.80),
    "bakelite": ("T_library_appliances_bakelite", 0.35),
    "brass": ("T_library_metals_aged_brass", 0.50),
    "brass_dull": ("T_ai_materials_brass_dull", 0.50),
    "porcelain": ("T_library_furniture_porcelain", 0.90),
    "wood_dark": ("T_library_furniture_walnut", 1.20),
    "fabric_warm": ("T_library_furniture_upholstery_rust", 0.70),
    "linen": ("T_library_furniture_linen", 0.60),
    "paper": ("T_library_furniture_aged_paper", 0.50),
    "trim": ("T_library_architectural_painted_trim", 1.20),
    "plant": ("T_library_organic_leaf_surface", 0.50),
    # Soot already uses the canonical plate, but its prop scale is awaiting
    # the hand-scale soot-deposit split and therefore remains visually locked.
    "soot": ("T_ai_materials_soot_worn_soot", 0.55),
}


def _read_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def _metadata_for(mapped: str) -> dict:
    base = ROOT / "art/textures" / mapped
    for name in ("material.json", "asset.json"):
        path = base / name
        if path.is_file():
            return _read_json(path)
    raise RuntimeError("material metadata missing: %s" % mapped)


def _canonical_files(key: str) -> list[str]:
    return ["T_ai_materials_%s_%s.png" % (key, suffix)
            for suffix in ("albedo", "rough", "normal")]


def _runtime_alias_files(key: str) -> tuple[list[str], float]:
    """Reuse one approved plate without pretending two finishes are one key."""
    if key in VISUAL_LOCKS:
        stem, runtime_mpt = VISUAL_LOCKS[key]
        normal_stem = re.sub(r"_worn_[^_]+$", "", stem)
        return ([stem + "_albedo.png", stem + "_rough.png",
                 normal_stem + "_normal.png"], runtime_mpt)
    mapped = _read_json(MAPPING).get(key)
    if not mapped:
        raise RuntimeError("runtime alias has no catalog mapping: %s" % key)
    return _canonical_files(key), float(_metadata_for(mapped)["meters_per_tile"])


def build_contract() -> dict:
    catalog = _read_json(CATALOG)
    mapping = _read_json(MAPPING)
    materials = {}
    for key, policy in RUNTIME_POLICY.items():
        entry = catalog.get(key)
        if entry is None:
            raise RuntimeError("runtime key absent from MATERIAL_CATALOG: %s" % key)
        mapped = mapping.get(key)
        if policy.get("generated"):
            canonical_mpt = float(policy["meters_per_tile"])
        else:
            if not mapped:
                raise RuntimeError("runtime key has no catalog mapping: %s" % key)
            canonical_mpt = float(_metadata_for(mapped)["meters_per_tile"])
        runtime_alias = policy.get("runtime_alias")
        if runtime_alias:
            files, _alias_mpt = _runtime_alias_files(str(runtime_alias))
            # The semantic key's catalog mapping remains scale authority.
            # Only the pixels are shared; aliases do not inherit a stale
            # visual-lock scale from the source key.
            runtime_mpt = canonical_mpt
            locked = False
        elif key in VISUAL_LOCKS:
            stem, runtime_mpt = VISUAL_LOCKS[key]
            normal_stem = re.sub(r"_worn_[^_]+$", "", stem)
            files = [stem + "_albedo.png", stem + "_rough.png",
                     normal_stem + "_normal.png"]
            locked = True
        else:
            files = _canonical_files(key)
            runtime_mpt = canonical_mpt
            locked = False
        spec = {
            "files": files,
            "meters_per_tile": runtime_mpt,
            "canonical_meters_per_tile": canonical_mpt,
            "metallic": float(entry.get("metallic", 0.0) or 0.0),
            "roughness_multiplier": float(policy.get(
                "roughness_multiplier", 1.0)),
            "alpha": bool(policy.get("alpha", False)),
            "visual_lock": locked,
            "catalog_mapping": mapped,
        }
        materials[key] = spec
    return {"schema": 1, "materials": materials,
            "visual_locks": sorted(VISUAL_LOCKS)}


def _gd_value(spec: dict) -> str:
    values = [json.dumps(x) for x in spec["files"]]
    values += ["%.6g" % spec["meters_per_tile"],
               "%.6g" % spec["metallic"]]
    if spec["roughness_multiplier"] != 1.0 or spec["alpha"]:
        values.append("%.6g" % spec["roughness_multiplier"])
    if spec["alpha"]:
        values.append("true")
    return "[%s]" % ", ".join(values)


def render_gd(contract: dict) -> str:
    lines = [
        "extends RefCounted",
        "## GENERATED by art/tools/generate_runtime_materials.py.",
        "## Edit the catalog, mapping or runtime optical policy; never this file.",
        "const SETS := {",
    ]
    for key, spec in contract["materials"].items():
        suffix = " # visual lock" if spec["visual_lock"] else ""
        lines.append('\t%r: %s,%s' % (key, _gd_value(spec), suffix))
    lines += ["}", ""]
    return "\n".join(lines)


def _json_bytes(contract: dict) -> bytes:
    return (json.dumps(contract, indent=2, sort_keys=True) + "\n").encode()


def _write_if_changed(path: Path, data: bytes) -> bool:
    if path.is_file() and path.read_bytes() == data:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return True


def validate(contract: dict, require_current: bool = True) -> list[str]:
    errors = []
    if set(contract["materials"]) != set(RUNTIME_POLICY):
        errors.append("runtime material key set does not match policy")
    for key, spec in contract["materials"].items():
        if not spec["visual_lock"] and spec["meters_per_tile"] != \
                spec["canonical_meters_per_tile"]:
            errors.append("unlocked scale drift: %s" % key)
        for filename in spec["files"]:
            if not (GODOT_TEXTURES / filename).is_file():
                errors.append("runtime texture missing: %s/%s" % (key, filename))
    if require_current:
        expected_json = _json_bytes(contract)
        for path in MANIFESTS:
            if not path.is_file() or path.read_bytes() != expected_json:
                errors.append("generated manifest stale: %s" % path)
        expected_gd = render_gd(contract).encode()
        if not GDSCRIPT.is_file() or GDSCRIPT.read_bytes() != expected_gd:
            errors.append("generated GDScript stale: %s" % GDSCRIPT)
    return errors


def generate() -> list[Path]:
    contract = build_contract()
    changed = []
    data = _json_bytes(contract)
    for path in MANIFESTS:
        if _write_if_changed(path, data):
            changed.append(path)
    if _write_if_changed(GDSCRIPT, render_gd(contract).encode()):
        changed.append(GDSCRIPT)
    errors = validate(contract)
    if errors:
        raise RuntimeError("\n".join(errors))
    return changed


if __name__ == "__main__":
    changed = generate()
    print("runtime material contract: %d material(s), %d visual lock(s), %d file(s) changed"
          % (len(RUNTIME_POLICY), len(VISUAL_LOCKS), len(changed)))
