"""Give the Orison's windows the two maps that make old glass look old.

Owner, 2026-08-18: "i want to replace the shader only textures with full ones."

`glassish` is the largest of the untextured materials -- 163 surface references
in game/data/building_layout.json, every window in the building and every
shopfront on the street -- and it carried no texture at all: one tinted colour,
one roughness value, one alpha. Flat glass is the giveaway that a window is a
polygon. Real glass in a building of this age is not flat in either sense.

WHAT THIS GENERATES, AND WHY THOSE TWO AND NOT THREE
----------------------------------------------------
NORMAL. Period window glass is drawn or cylinder glass, not float -- float
glass did not exist until 1959. Drawn glass carries faint vertical draw lines
from the ribbon being pulled, plus a slow large-scale waviness from uneven
cooling. You do not see the ripple itself; you see what it does to the
REFLECTION, which slides and bends as you walk past. That motion is most of
what reads as "old window" and it cannot be faked with a roughness value.

ROUGHNESS. Glass gets dirty unevenly, and it gets dirtiest where nobody
wipes: the perimeter, against the putty line, and in the corners. A uniform
0.06 says "cleaned this morning, edge to edge". The map keeps the centre near
that and lets the margins haze.

NO ALBEDO. The colour and alpha in build_orison.py's glassish branch are
hand-tuned, and the comment there records why: an earlier version asked for
physically-correct transmission, the exporter wrote KHR_materials_transmission,
and gl_compatibility does not implement it, so every window rendered as a flat
blue-grey panel. That tuning is load-bearing and this tool does not touch it.

Run:  python art/tools/build_glass_maps.py
"""
import os
import zlib

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "textures", "generated", "glass")
PX = 512

# Real-world size this sheet covers, so the ripple is the right size on a
# window rather than an arbitrary UV frequency. Drawn-glass waviness runs at
# roughly a hand's width; the draw lines are far finer.
TILE_M = 1.6

# How hard the glass deviates from flat. Held low on purpose: this is a pane,
# not hammered glass, and the moment the ripple is legible as a pattern it
# stops reading as glass and starts reading as a texture.
WAVE = 0.55
DRAW_LINES = 0.30

# Roughness at the centre of a pane and at its dirtiest margin.
CLEAN = 0.06
GRIMY = 0.34


def _noise(seed, size, octaves=4, aspect=1.0):
    """Value noise in 0..1. `aspect` stretches it vertically for draw lines."""
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size), dtype=np.float64)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = max(2, 2 ** (o + 2))
        h = max(2, int(n / aspect))
        grid = rng.random((h, n))
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize(
            (size, size), Image.BICUBIC)
        out += np.asarray(img, dtype=np.float64) / 255.0 * amp
        total += amp
        amp *= 0.5
    return out / total


def _normal_from_height(height, strength):
    """Tangent-space normal, OpenGL +Y -- the convention the rest of the
    project uses, confirmed across all 988 importers."""
    gy, gx = np.gradient(height.astype(np.float64))
    nx = -gx * strength
    ny = gy * strength
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.dstack([nx / length, ny / length, nz / length])


def build() -> None:
    os.makedirs(OUT, exist_ok=True)
    seed = zlib.crc32(b"glassish") % 9973

    # THE SURFACE. Two frequencies: a slow swell from uneven cooling, and the
    # fine vertical striation of the draw. Stretched 9:1 so the lines run with
    # the ribbon rather than reading as generic noise.
    swell = _noise(seed, PX, octaves=3)
    lines = _noise(seed + 17, PX, octaves=5, aspect=9.0)
    height = swell * WAVE + lines * DRAW_LINES
    # Blur once: the ripple is a form, and leaving the noise grain in it would
    # read as frosting rather than as waviness.
    height = np.asarray(
        Image.fromarray((np.clip(height, 0, 1) * 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(2.2)), dtype=np.float64) / 255.0
    n = _normal_from_height(height, 3.0)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(
        os.path.join(OUT, "normal.png"))

    # THE DIRT. Distance from the nearest edge of the sheet, so grime banks up
    # at the perimeter and in the corners the way it does against a putty line.
    y, x = np.mgrid[0:PX, 0:PX] / float(PX - 1)
    edge = np.minimum.reduce([x, 1.0 - x, y, 1.0 - y]) * 2.0
    margin = 1.0 - np.clip(edge / 0.35, 0.0, 1.0)
    # Blotches, so the haze is not a clean vignette.
    blotch = _noise(seed + 41, PX, octaves=4)
    grime = np.clip(margin * 0.85 + blotch * 0.45 - 0.15, 0.0, 1.0)
    rough = CLEAN + (GRIMY - CLEAN) * grime
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8), "L").save(
        os.path.join(OUT, "roughness.png"))

    print("glass maps -> %s" % os.path.relpath(OUT, ROOT))
    print("  normal.png     %dx%d  wave %.2f draw %.2f over %.2f m"
          % (PX, PX, WAVE, DRAW_LINES, TILE_M))
    print("  roughness.png  %dx%d  %.2f clean -> %.2f at the putty line"
          % (PX, PX, CLEAN, GRIMY))


if __name__ == "__main__":
    build()
