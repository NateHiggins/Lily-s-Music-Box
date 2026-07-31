#!/usr/bin/env python3
"""Pre-composite stain/wear overlays onto texture sets, export-safely.

Blender's glTF exporter only serializes plain Principled inputs — it
cannot bake Mix-node graphs — so overlay layering happens here instead:
mask-weighted albedo tinting and roughness shifts are composited into
`art/textures/generated/_overlaid/<material>/`, which the build script
prefers over the clean set when present. Masks are tileable library
assets (white = stronger influence), aligned by physical scale.

Config lives in OVERLAYS below: restrained by design — the building is
worn, not filthy. Run: python tools/compose_overlays.py
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / "art" / "textures"

# material -> (base set dir, [overlay passes])
# each pass: mask asset, tint RGB, albedo strength 0-1, roughness delta
# (-1..1 scaled by mask), mask uv scale multiplier
OVERLAYS = {
    "plaster": ("generated/plaster", [
        ("wear/scuff_marks", (74, 70, 62), 0.16, 0.06, 1.0),
        ("wear/chipped_paint", (168, 160, 142), 0.10, 0.04, 1.4),
    ]),
    "concrete": ("generated/concrete", [
        ("stains/water_bloom", (70, 74, 70), 0.20, 0.10, 1.0),
    ]),
    "soot": ("library/damage/charred_surface", [
        ("stains/soot_haze", (8, 8, 9), 0.45, 0.12, 0.8),
    ]),
    "enamel": ("library/appliances/aged_enamel", [
        ("stains/grease_speckle", (96, 82, 52), 0.08, 0.10, 1.2),
    ]),
    "appliance": ("library/appliances/aged_enamel", [
        ("stains/grease_speckle", (96, 82, 52), 0.06, 0.08, 1.2),
    ]),
    "metal": ("library/appliances/galvanized_metal", [
        ("stains/rust_run", (108, 52, 30), 0.14, 0.14, 1.0),
    ]),
    "wainscot": ("generated/wainscot", [
        ("wear/chipped_paint", (188, 182, 166), 0.12, 0.05, 1.2),
        ("wear/scuff_marks", (52, 56, 50), 0.10, 0.05, 0.8),
    ]),
}


def tiled_mask(asset: str, size: tuple[int, int], scale: float,
               base_mpt: float) -> Image.Image:
    d = TEX / "library" / asset
    mask = Image.open(d / "mask.png").convert("L")
    meta = {}
    mj = d / "asset.json"
    if mj.exists():
        meta = json.loads(mj.read_text(encoding="utf-8"))
    mask_mpt = float(meta.get("meters_per_tile", 1.5))
    # one base tile spans base_mpt meters; the mask tile spans mask_mpt.
    rel = max(0.1, (base_mpt / mask_mpt) * scale)
    tile_px = max(64, int(size[0] / rel))
    mask = mask.resize((tile_px, tile_px), Image.Resampling.LANCZOS)
    out = Image.new("L", size)
    for y in range(0, size[1], tile_px):
        for x in range(0, size[0], tile_px):
            out.paste(mask, (x, y))
    return out


def compose(key: str, base_rel: str, passes) -> None:
    base = TEX / base_rel
    meta_file = base / ("material.json" if (base / "material.json").exists()
                        else "asset.json")
    base_mpt = float(json.loads(meta_file.read_text(
        encoding="utf-8")).get("meters_per_tile", 2.0))
    albedo = Image.open(base / "albedo.png").convert("RGB")
    rough = Image.open(base / "roughness.png").convert("L")
    for asset, tint, strength, rough_d, scale in passes:
        mask = tiled_mask(asset, albedo.size, scale, base_mpt)
        weighted = mask.point(lambda v: int(v * strength))
        albedo = Image.composite(Image.new("RGB", albedo.size, tint),
                                 albedo, weighted)
        if rough_d:
            shift = mask.point(lambda v: int(abs(rough_d) * v))
            rough = (ImageChops.add(rough, shift) if rough_d > 0
                     else ImageChops.subtract(rough, shift))
    out = TEX / "generated" / "_overlaid" / key
    out.mkdir(parents=True, exist_ok=True)
    albedo.save(out / "albedo.png", optimize=True)
    rough.save(out / "roughness.png", optimize=True)
    (out / "material.json").write_text(json.dumps(
        {"material": key, "base": base_rel, "meters_per_tile": base_mpt,
         "passes": [p[0] for p in passes]}, indent=2) + "\n",
        encoding="utf-8")
    print("overlaid:", key, "<-", ", ".join(p[0] for p in passes))


def main() -> None:
    for key, (base_rel, passes) in OVERLAYS.items():
        compose(key, base_rel, passes)


if __name__ == "__main__":
    main()
