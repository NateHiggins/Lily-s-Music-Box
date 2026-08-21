"""Ingest case-specific dream substance and reflected-world plates.

Sources remain in art/textures/ai_sources and never ship. Each source needs a
matching ``<key>.source.md`` containing generator, date and the exact prompt.
Accepted derivatives land under game/assets/dream/incarnations and are the only
artifacts the runtime loads.

    python art/tools/ingest_dream_material_sources.py --check
    python art/tools/ingest_dream_material_sources.py --case mina
    python art/tools/ingest_dream_material_sources.py --key T_ai_dream_mina_ink_fiber
"""
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

from ingest_material_sources import blur, flatten_lighting, make_tileable

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/textures/ai_sources"
MANIFEST = ROOT / "design/dream_plate_manifest.json"
CATALOG = ROOT / "game/data/dream_plate_catalog.json"
OUT = ROOT / "game/assets/dream/incarnations"
CHANNELS = ("albedo", "height", "normal", "roughness")


def records(manifest: dict) -> dict[str, dict]:
    found: dict[str, dict] = {}
    for case_id, case in manifest["cases"].items():
        for key, metres, rough_base, rough_span, strength in case["substances"]:
            found[key] = {"case": case_id, "kind": "substance",
                          "metres": metres, "rough_base": rough_base,
                          "rough_span": rough_span, "strength": strength}
        key = case["reflection"]
        found[key] = {"case": case_id, "kind": "reflection"}
    return found


def provenance(key: str) -> Path:
    return SOURCE / (key + ".source.md")


def source_image(key: str) -> Path | None:
    for suffix in (".png", ".jpg", ".jpeg"):
        candidate = SOURCE / (key + suffix)
        if candidate.is_file():
            return candidate
    return None


def output_dir(record: dict, key: str) -> Path:
    return OUT / record["case"] / key


def prepare_substance(path: Path, size: int) -> np.ndarray:
    image = Image.open(path).convert("RGB")
    side = min(image.size)
    left = (image.width - side) // 2
    top = (image.height - side) // 2
    image = image.crop((left, top, left + side, top + side))
    data = np.asarray(image, dtype=np.float32) / 255.0
    data = make_tileable(flatten_lighting(data))
    image = Image.fromarray((np.clip(data, 0, 1) * 255).astype(np.uint8), "RGB")
    return np.asarray(image.resize((size, size), Image.Resampling.LANCZOS),
                      dtype=np.float32) / 255.0


def ingest_substance(path: Path, target: Path, record: dict, size: int) -> None:
    albedo = prepare_substance(path, size)
    lum = albedo.mean(axis=-1)
    height = np.clip(0.5 + (blur(lum, 2.0) - blur(lum, 24.0)) * 1.6, 0, 1)
    gy, gx = np.gradient(height)
    nx = -gx * float(record["strength"])
    ny = gy * float(record["strength"])
    nz = np.ones_like(height)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack((nx / norm * 0.5 + 0.5, ny / norm * 0.5 + 0.5,
                       nz / norm * 0.5 + 0.5), axis=-1)
    rough = np.clip(float(record["rough_base"])
                    + (0.5 - height) * float(record["rough_span"]) * 2.0,
                    0.05, 1.0)
    target.mkdir(parents=True, exist_ok=True)
    # Keep the independently auditable R8 maps below, while also packing the
    # two scalar channels into already-budgeted alpha bytes for the shader.
    # Four RGBA albedos + four RGBA normals need eight samplers rather than
    # sixteen; the active-case cache still owns and accounts for all 17 maps.
    albedo_packed = np.concatenate((albedo, rough[..., None]), axis=-1)
    normal_packed = np.concatenate((normal, height[..., None]), axis=-1)
    Image.fromarray((albedo_packed * 255).astype(np.uint8), "RGBA").save(
        target / "albedo.png", optimize=True)
    Image.fromarray((height * 255).astype(np.uint8), "L").save(
        target / "height.png", optimize=True)
    Image.fromarray((normal_packed * 255).astype(np.uint8), "RGBA").save(
        target / "normal.png", optimize=True)
    Image.fromarray((rough * 255).astype(np.uint8), "L").save(
        target / "roughness.png", optimize=True)


def ingest_reflection(path: Path, target: Path, size: tuple[int, int]) -> None:
    image = Image.open(path).convert("RGB")
    if abs(image.width / image.height - 2.0) > 0.01:
        raise ValueError("reflected-world source must be 2:1 equirectangular")
    data = np.asarray(image, dtype=np.float32) / 255.0
    seam = float(np.abs(data[:, 0] - data[:, -1]).mean())
    if seam > 0.08:
        raise ValueError("reflected-world horizontal seam %.4f exceeds 0.08" % seam)
    target.mkdir(parents=True, exist_ok=True)
    image.resize(size, Image.Resampling.LANCZOS).save(
        target / "reflected_world.png", optimize=True)


def complete(record: dict, key: str, manifest: dict) -> bool:
    target = output_dir(record, key)
    names = CHANNELS if record["kind"] == "substance" else ("reflected_world",)
    expected = (manifest["substance_resolution"],) * 2 \
        if record["kind"] == "substance" \
        else tuple(manifest["reflection_resolution"])
    if not (target / "SOURCE.md").is_file():
        return False
    for name in names:
        path = target / (name + ".png")
        if not path.is_file() or Image.open(path).size != expected:
            return False
    return True


def update_available(catalog: dict, manifest: dict, all_records: dict) -> None:
    available = []
    for case_id, case in manifest["cases"].items():
        keys = [row[0] for row in case["substances"]] + [case["reflection"]]
        if all(complete(all_records[key], key, manifest) for key in keys):
            available.append(case_id)
    catalog["available_cases"] = available


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--case", action="append", default=[])
    parser.add_argument("--key", action="append", default=[])
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    all_records = records(manifest)
    unknown = sorted(set(args.key) - set(all_records))
    if unknown:
        print("unknown dream plate key(s):", ", ".join(unknown))
        return 1
    selected = [key for key, record in all_records.items()
                if (not args.key or key in args.key)
                and (not args.case or record["case"] in args.case)]
    if args.check:
        bad = []
        for key, record in all_records.items():
            target = output_dir(record, key)
            if target.exists() and not complete(record, key, manifest):
                bad.append(key)
        update_available(catalog, manifest, all_records)
        declared = sorted(json.loads(CATALOG.read_text(encoding="utf-8"))
                          .get("available_cases", []))
        actual = sorted(catalog["available_cases"])
        if declared != actual:
            bad.append("available_cases catalog %s != shipped %s" %
                       (declared, actual))
        print("dream plate definitions: %d" % len(all_records))
        print("complete cases: %s" % (", ".join(actual) if actual else "none"))
        print("check %s" % ("FAILED: " + ", ".join(bad) if bad else "passed"))
        return 1 if bad else 0
    changed = []
    for key in selected:
        record = all_records[key]
        source = source_image(key)
        note = provenance(key)
        if source is None:
            continue
        if not note.is_file():
            raise FileNotFoundError("missing provenance note %s" % note)
        target = output_dir(record, key)
        if record["kind"] == "substance":
            ingest_substance(source, target, record,
                             int(manifest["substance_resolution"]))
        else:
            ingest_reflection(source, target,
                              tuple(manifest["reflection_resolution"]))
        custody = note.read_text(encoding="utf-8").rstrip() + (
            "\n\n## Shipped derivative\n\n"
            "- Source intake: `art/textures/ai_sources/%s` (not shipped)\n"
            "- Pipeline: `art/tools/ingest_dream_material_sources.py`\n"
            "- Runtime key: `%s`\n" % (source.name, key))
        (target / "SOURCE.md").write_text(custody, encoding="utf-8", newline="\n")
        changed.append(key)
    update_available(catalog, manifest, all_records)
    CATALOG.write_text(json.dumps(catalog, indent=2) + "\n",
                       encoding="utf-8", newline="\n")
    print("ingested dream plates: %d" % len(changed))
    print("complete cases: %s" % (", ".join(catalog["available_cases"])
                                  if catalog["available_cases"] else "none"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
