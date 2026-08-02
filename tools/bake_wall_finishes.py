"""Bake one unique PBR finish set for every room-facing masonry wall.

The expensive visual information comes from three authored 2:1 masters.
This tool makes deterministic wall-specific crops, mirrors, grading and
microdetail, then derives conservative GL-compatible normal/roughness maps.
"""
from pathlib import Path
import hashlib
import json
import math

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
LAYOUT = ROOT / "game/data/building_layout.json"
MASTER_DIR = ROOT / "art/textures/wall_finish_masters"
OUT = ROOT / "art/textures/wall_finishes"
MASTERS = ("moisture.png", "renovation.png", "structural.png")
SIZE = (1024, 512)


def slug(fid, index):
    return f"{fid.lower()}_wall_{index:02d}"


def rng_for(name):
    seed = int.from_bytes(hashlib.sha256(name.encode()).digest()[:8], "little")
    return np.random.default_rng(seed)


def variant(master, name):
    rng = rng_for(name)
    im = master.convert("RGB")
    # Overscan permits a different composition for every wall without seams.
    scale = float(rng.uniform(1.03, 1.24))
    cw, ch = int(im.width / scale), int(im.height / scale)
    x = int(rng.uniform(0, max(1, im.width - cw)))
    y = int(rng.uniform(0, max(1, im.height - ch)))
    im = im.crop((x, y, x + cw, y + ch))
    if rng.random() < .5:
        im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    im = im.resize(SIZE, Image.Resampling.LANCZOS)
    im = ImageEnhance.Color(im).enhance(float(rng.uniform(.84, 1.03)))
    im = ImageEnhance.Contrast(im).enhance(float(rng.uniform(.94, 1.08)))
    im = ImageEnhance.Brightness(im).enhance(float(rng.uniform(.88, 1.02)))

    a = np.asarray(im, dtype=np.float32)
    yy, xx = np.mgrid[0:SIZE[1], 0:SIZE[0]]
    low = (np.sin(xx / rng.uniform(100, 210) + rng.uniform(0, 6.28)) +
           np.sin(yy / rng.uniform(55, 130) + rng.uniform(0, 6.28))) * .5
    grain = rng.normal(0, 1.3, (SIZE[1], SIZE[0]))
    age = low * rng.uniform(2.0, 5.5) + grain
    # Slightly warmer/darker unique age cast, without baking scene light.
    a[..., 0] += age * 1.05
    a[..., 1] += age * .76
    a[..., 2] += age * .48
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)), "RGB")


def maps(albedo):
    gray = np.asarray(albedo.convert("L").filter(ImageFilter.GaussianBlur(.85)),
                      dtype=np.float32) / 255.0
    gy, gx = np.gradient(gray)
    strength = 2.1
    nx, ny = -gx * strength, -gy * strength
    nz = np.ones_like(nx)
    mag = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.dstack(((nx / mag * .5 + .5) * 255,
                        (ny / mag * .5 + .5) * 255,
                        (nz / mag * .5 + .5) * 255))
    # Old porous finishes are broadly matte; luminance variation gives brick,
    # salts and damp regions subtly different response without false gloss.
    rough = np.clip(222 - (gray - .45) * 32, 176, 242)
    return (Image.fromarray(np.uint8(normal), "RGB"),
            Image.fromarray(np.uint8(rough), "L"))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    masters = [Image.open(MASTER_DIR / p) for p in MASTERS]
    data = json.loads(LAYOUT.read_text(encoding="utf-8"))
    manifest = {}
    for floor in data["floors"]:
        affected = [w for w in floor["walls"] if w.get("in_side")]
        for i, wall in enumerate(affected):
            name = slug(floor["id"], i)
            rng = rng_for(name)
            family = int(rng.integers(0, len(masters)))
            albedo = variant(masters[family], name)
            normal, rough = maps(albedo)
            target = OUT / name
            target.mkdir(exist_ok=True)
            albedo.save(target / "albedo.png", optimize=True)
            normal.save(target / "normal.png", optimize=True)
            rough.save(target / "roughness.png", optimize=True)
            wall["finish_texture"] = name
            manifest[name] = {
                "floor": floor["id"], "wall_index": i,
                "family": MASTERS[family], "resolution": list(SIZE),
                "exposed_brick_target": 0.40,
            }
    # Both generators consume equivalent layout copies; finish ids are visual
    # metadata and must stay synchronized across rebuilds.
    for path in (ROOT / "game/data/building_layout.json",
                 ROOT / "art/data/building_layout.json"):
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    (OUT / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"baked {len(manifest)} unique wall finish sets at {SIZE[0]}x{SIZE[1]}")


if __name__ == "__main__":
    main()
