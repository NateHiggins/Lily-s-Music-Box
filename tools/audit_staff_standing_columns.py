"""Source-project gate and explicit compiled binding for sampled staff columns.
The binding is an export configuration seal, not new measurement/fit acceptance.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re

PROFILE = Path("game/data/characters/harukiya_staff_standing_columns.json")
BINDING = Path("game/scripts/characters/harukiya_staff_profile_binding.gd")
COMMON = (
    "scripts/characters/cast_model_presentation.gd", "scripts/characters/stand_pose.gd",
    "scripts/characters/pose_pipeline.gd", "scripts/characters/rig_profile.gd",
    "scripts/characters/resident_attention.gd", "scripts/characters/face_controller.gd",
    "scripts/characters/skirt_follow.gd", "scripts/characters/resident_wardrobe.gd",
    "scripts/characters/cast_hair_presentation.gd", "scripts/characters/head_hair_motion.gd",
    "data/characters/stand_poses.json", "data/characters/rig_profiles.json",
    "shaders/character_hair.gdshader", "shaders/stage_wisps.gdshader",
)
FAMILIES = (("work_top", "work_bottom", "work_feet"), ("p_top", "p_feet", "p_head"))
DECLARED_FAMILIES = {"stacy": FAMILIES, "lily": FAMILIES,
                     "adela_voss": (FAMILIES[1],)}
# Face tables drive measured morphs; this cast's optional hair-look document
# must remain the same accepted presentation input. Texture pixels do not move
# vertices in these pinned shaders and are not geometry-source bindings.
ADELA_COMMON = ("data/characters/face_performance.json",
                "assets/characters/cast/adela_voss/adela_voss_hair_look.json")
ROW_KEYS = {"person", "model", "parts", "stand_pose", "base_local", "radius", "height", "source_bindings"}

class Invalid(ValueError):
    pass

def require(ok, message):
    if not ok:
        raise Invalid(message)

def lf(raw: bytes) -> bytes:
    return raw.replace(b"\r\n", b"\n")

def finite(value):
    return type(value) in (int, float) and math.isfinite(value)

def resource(root: Path, name: str) -> Path:
    require(isinstance(name, str) and name.startswith("res://"), "non-resource source path")
    rel = PurePosixPath(name[6:])
    require(not rel.is_absolute() and all(x not in ("..", ".") for x in rel.parts)
            and str(rel) == name[6:] and "\\" not in name, "unsafe source path: " + name)
    base = (root / "game").resolve()
    path = (base / rel).resolve()
    require(path.is_relative_to(base), "source escapes game: " + name)
    return path

def source_digest(path: Path, kind: str) -> str:
    raw = path.read_bytes()
    if kind == "lf":
        raw = lf(raw)
    elif kind == "params_lf":
        raw = lf(raw)
        require(raw.count(b"[params]") == 1, "missing/ambiguous import params: " + str(path))
        raw = raw.split(b"[params]", 1)[1]
    else:
        require(kind == "raw", "unknown binding kind: " + str(kind))
    return hashlib.sha256(raw).hexdigest()

def model_stem(person: str) -> str:
    folder = "cast/" + person if person == "adela_voss" else person
    return "res://assets/characters/" + folder + "/" + person

def expected_sources(root: Path, person: str, parts: list[str]) -> dict[str, str]:
    expected = {"res://" + name: "lf" for name in COMMON}
    if person == "adela_voss":
        expected.update({"res://" + name: "lf" for name in ADELA_COMMON})
    for suffix in [""] + ["__" + part for part in parts]:
        stem = model_stem(person) + suffix
        gltf = stem + ".gltf"
        expected[gltf] = "lf"
        expected[stem + ".gltf.import"] = "params_lf"
        doc = json.loads(resource(root, gltf).read_text(encoding="utf-8"))
        buffers = doc.get("buffers")
        require(isinstance(buffers, list) and buffers, "missing glTF buffers: " + gltf)
        for buffer in buffers:
            require(isinstance(buffer, dict), "malformed glTF buffer")
            uri = buffer.get("uri")
            require(isinstance(uri, str) and uri and PurePosixPath(uri).name == uri
                    and ":" not in uri and "\\" not in uri, "unsupported/unsafe glTF buffer URI")
            expected[stem.rsplit("/", 1)[0] + "/" + uri] = "raw"
        if suffix:
            expected[stem + ".json"] = "lf"
    return expected

def validated_profile(root: Path) -> tuple[str, int]:
    raw = (root / PROFILE).read_bytes()
    doc = json.loads(raw.decode("utf-8"))
    require(isinstance(doc, dict) and set(doc) == {"schema_version", "units", "shape", "profiles"}, "invalid compact profile document")
    require(type(doc["schema_version"]) is int and doc["schema_version"] == 1
            and doc["units"] == "metres" and doc["shape"] == "standing_column", "unsupported profile schema/units/shape")
    require(isinstance(doc["profiles"], list) and len(doc["profiles"]) == 5, "exactly five declared staff families required")
    seen = set()
    all_bindings = {}
    for row in doc["profiles"]:
        require(isinstance(row, dict) and set(row) == ROW_KEYS, "invalid compact profile row")
        person, parts = row["person"], row["parts"]
        require(isinstance(person, str) and person in DECLARED_FAMILIES and isinstance(parts, list)
                and all(isinstance(x, str) for x in parts), "invalid person/parts")
        family = next((f for f in DECLARED_FAMILIES[person] if sorted(parts) == sorted(f)), None)
        require(family is not None and (person, family) not in seen, "unknown/duplicate staff family")
        seen.add((person, family))
        require(row["model"] == model_stem(person) + ".gltf", "model/person mismatch")
        require(row["stand_pose"] == ("at_ease" if person == "stacy" else "weight_on_one_leg"), "stand-pose mismatch")
        base = row["base_local"]
        require(isinstance(base, list) and len(base) == 3 and all(finite(x) for x in base), "invalid column base")
        require(finite(row["radius"]) and row["radius"] > 0 and finite(row["height"]) and row["height"] > 0, "invalid column dimensions")
        require(isinstance(row["source_bindings"], list), "source bindings must be an array")
        bindings = {}
        for binding in row["source_bindings"]:
            require(isinstance(binding, dict) and set(binding) == {"path", "kind", "sha256"}, "invalid source binding")
            name = binding["path"]
            resource(root, name)
            require(name not in bindings, "duplicate source binding: " + name)
            require(isinstance(binding["sha256"], str) and re.fullmatch(r"[0-9a-f]{64}", binding["sha256"]) is not None, "invalid source SHA256")
            bindings[name] = (binding["kind"], binding["sha256"])
        expected = expected_sources(root, person, parts)
        require(set(bindings) == set(expected), "source closure mismatch for " + person + "/" + str(family))
        for name, (kind, signature) in bindings.items():
            require(kind == expected[name], "wrong source binding kind: " + name)
            require(name not in all_bindings or all_bindings[name] == (kind, signature), "conflicting source binding: " + name)
            all_bindings[name] = (kind, signature)
    declared = {(person, family) for person, families in DECLARED_FAMILIES.items() for family in families}
    require(seen == declared, "missing or unexpected declared staff family")
    require(len(all_bindings) == 85, "expected 85 unique measured-source bindings")
    for name, (kind, signature) in all_bindings.items():
        require(source_digest(resource(root, name), kind) == signature, "source hash mismatch: " + name)
    return hashlib.sha256(lf(raw)).hexdigest(), len(all_bindings)

def binding_text(signature: str) -> str:
    return ('extends RefCounted\n'
            '## Generated by tools/audit_staff_standing_columns.py --generate-binding.\n'
            '## Source validation seal; no new native/pose/fit acceptance.\n'
            'const PROFILE_SHA256 := "' + signature + '"\n')

def check(root: Path) -> list[str]:
    try:
        signature, _ = validated_profile(root)
        require((root / BINDING).is_file(), "compiled profile binding is missing")
        require(lf((root / BINDING).read_bytes()) == binding_text(signature).encode("utf-8"), "compiled profile binding is stale or malformed")
        return []
    except (Invalid, OSError, ValueError, KeyError, TypeError) as exc:
        return [str(exc)]

def generate_binding(root: Path) -> tuple[str, int]:
    signature, count = validated_profile(root)
    target = root / BINDING
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(binding_text(signature).encode("utf-8"))
    return signature, count

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--generate-binding", action="store_true")
    args = ap.parse_args()
    if args.check:
        errors = check(args.root)
        if errors:
            print("STAFF COLUMN AUDIT FAIL: " + "; ".join(errors))
            return 1
        print("STAFF COLUMN AUDIT PASS: 5 families, 85 source bindings, compiled profile seal exact")
        return 0
    try:
        signature, count = generate_binding(args.root)
    except (Invalid, OSError, ValueError, KeyError, TypeError) as exc:
        print("STAFF COLUMN GENERATION REFUSED: " + str(exc))
        return 1
    print("STAFF COLUMN BINDING GENERATED: " + signature + " (" + str(count) + " sources)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
