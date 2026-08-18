"""Worn white road marking, because the crossing was painted in linen.

Owner, 2026-08-18: "the crosswalk pattern is 90 deg off."

The geometry was never off. The zebra bars run across the carriageway and
repeat along it, which is correct: a pedestrian walks the LENGTH of a stripe.
What is 90 degrees out is the pattern INSIDE each bar, because the bars were
given `linen` — an actual woven fabric — and at six metres across you can read
the twill. The weave's chevrons run across each stripe, so the crossing wears a
herringbone perpendicular to itself. A tablecloth on the road.

So the fix is a material that is road paint, and the design rule that follows
from the complaint is: THIS TEXTURE MUST HAVE NO GRAIN. Anything with a
direction can be applied 90 degrees out. Everything here is isotropic blotch
and speckle, so there is no orientation to get wrong, on a bar that runs one
way, a stop line that runs the other, and a kerb that curves.

What it carries:
  ALBEDO     off-white lead paint, never pure: grey where the wheels have
             polished it, dark where the asphalt shows through the thin spots
  ROUGHNESS  fresh paint is smoother than the road, worn paint is rougher than
             either, so the map runs both ways around a mid value
  NORMAL     thermoplastic sits a few millimetres proud, and the edge of that
             film is the thing that catches a headlight at a grazing angle

Run:  python art/tools/build_road_paint.py
"""
import json
import os
import zlib

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "textures", "generated", "road_paint")
PX = 1024

# One tile covers 2 m. A zebra bar is 0.42 m wide and 8.9 m long, so the sheet
# repeats about four times down a bar and never across it -- and because the
# pattern has no direction, the repeat does not announce itself.
TILE_M = 2.0

PAINT = np.array([0.86, 0.85, 0.80])     # lead white, already yellowed
ASPHALT = np.array([0.16, 0.155, 0.15])  # what shows through where it is gone
WEAR = 0.55        # how much of the bar has been walked and driven off it
GRIME = 0.30       # traffic film over what survives


def _noise(seed, size, octaves=5):
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size), dtype=np.float64)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = max(2, 2 ** (o + 2))
        grid = rng.random((n, n))
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize(
            (size, size), Image.BICUBIC)
        out += np.asarray(img, dtype=np.float64) / 255.0 * amp
        total += amp
        amp *= 0.5
    return out / total


def _normal_from_height(height, strength):
    """OpenGL +Y, matching every other normal map in the project."""
    gy, gx = np.gradient(height.astype(np.float64))
    nx = -gx * strength
    ny = gy * strength
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.dstack([nx / length, ny / length, nz / length])


def build() -> None:
    os.makedirs(OUT, exist_ok=True)
    seed = zlib.crc32(b"road_paint") % 9973

    # COVERAGE: how much paint is left. Two scales, because paint fails both in
    # broad bald patches and in fine pinholes, and only having one reads as fog.
    broad = _noise(seed, PX, octaves=4)
    fine = _noise(seed + 31, PX, octaves=6)
    # Normalise the mix to a known 0..1 spread before using it. Left as raw
    # fbm the first version had a mean near 0.5, the contrast push below sent
    # it past 1.0, and the whole sheet clipped to unworn paint -- coverage mean
    # 0.98, which is a brand new crossing rather than a century-old one.
    mix = broad * 0.6 + fine * 0.4
    mix = (mix - mix.min()) / max(1e-6, mix.max() - mix.min())
    coverage = 1.0 - WEAR * mix
    # Hard edges: paint does not fade out, it flakes. Push the midtones apart
    # about the field's OWN median so the boundary between paint and bare road
    # is a line rather than a gradient, without saturating.
    mid = float(np.median(coverage))
    coverage = np.clip((coverage - mid) * 1.9 + mid, 0.0, 1.0)

    grime = _noise(seed + 77, PX, octaves=5)
    paint = PAINT[None, None, :] * (1.0 - GRIME * grime[:, :, None] * 0.7)
    albedo = ASPHALT[None, None, :] + (paint - ASPHALT[None, None, :]) \
        * coverage[:, :, None]
    Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8), "RGB").save(
        os.path.join(OUT, "albedo.png"))

    # ROUGHNESS. Surviving paint is smoother than the road it sits on; where it
    # has worn to a scab it is rougher than either. So both directions from a
    # mid value, keyed off the same coverage field.
    rough = 0.78 - 0.34 * coverage + 0.22 * (1.0 - coverage) * fine
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8), "L").save(
        os.path.join(OUT, "roughness.png"))

    # HEIGHT and NORMAL. The film is a few millimetres proud, so the edge of
    # every surviving flake is a tiny cliff -- which is the whole reason a worn
    # marking still reads at night under a headlight.
    height = np.asarray(
        Image.fromarray((coverage * 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(1.1)), dtype=np.float64) / 255.0
    Image.fromarray((height * 255).astype(np.uint8), "L").save(
        os.path.join(OUT, "height.png"))
    n = _normal_from_height(height, 6.0)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(
        os.path.join(OUT, "normal.png"))

    with open(os.path.join(OUT, "material.json"), "w", encoding="utf-8") as fh:
        json.dump({
            "name": "road_paint",
            "meters_per_tile": TILE_M,
            "note": "Generated by art/tools/build_road_paint.py. Isotropic on "
                    "purpose: a marking material with a grain can be applied "
                    "90 degrees out, which is how the crossing came to be "
                    "wearing a linen twill.",
        }, fh, indent=2)
        fh.write("\n")

    print("road paint -> %s" % os.path.relpath(OUT, ROOT))
    print("  albedo/roughness/normal/height at %dpx, %.1f m per tile" % (PX, TILE_M))
    print("  coverage mean %.2f (wear %.2f, grime %.2f)"
          % (coverage.mean(), WEAR, GRIME))


if __name__ == "__main__":
    build()
