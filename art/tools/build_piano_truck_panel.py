"""Compose the signwritten panel for the We Tuna Pianos truck.

The Meshy export arrives with its lettering baked into a shattered
photogrammetry atlas — hundreds of disconnected islands with fragments of
words scattered across a 8192px sheet. Decimating that mesh from 1.96 M
triangles to 12 k collapses vertices across island seams, and on the one large
flat surface of the whole model, the box body side, the result is a smear of
teal, cream and red diagonals where the sign used to be. The cab, mudguards,
running board and spoked wheels all survive decimation intact; only the big
panel fails, because only the big panel was one broad area of many small
islands.

That cannot be repaired by painting into the atlas — there is no contiguous
region in UV space that corresponds to the side of the truck.

So the panel gets its own material instead, mapped with a plain planar
projection, and this file draws what goes on it: the approved sign plate on
painted coachwork. Which is also how the real thing worked. A signwritten
truck is not a printed wrap; it is a painted body with a plate or a
hand-lettered panel on it, and the join between the two is visible.

Run:  python art/tools/build_piano_truck_panel.py
"""
import os
import zlib

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SIGN = os.path.join(ROOT, "game", "assets", "building", "textures", "traffic",
                    "we_tuna_pianos_sign.png")
OUT = os.path.join(ROOT, "game", "assets", "building", "textures", "traffic")

# The box side measured off the decimated mesh: x -0.90..2.70, z 1.00..2.05.
PANEL_M = (3.60, 1.05)
PX_PER_M = 560
# Read off the CAB so the panel belongs to the truck it is bolted to. Measured
# in the render rather than guessed: the cab bonnet sits at (48, 57, 58) and the
# first panel came out at (5, 8, 9). Half of that gap was the double-gamma bug
# fixed below; the rest was this value simply being too dark.
COACH = (0.310, 0.400, 0.415)
# The plate is mounted proud of the body and does not fill it; a 1920s trade
# truck carries its sign on the upper two thirds with the body colour showing
# below, where the road throws dirt.
SIGN_HEIGHT_FRAC = 0.78


def _noise(seed, w, h, octaves=5):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), dtype=np.float64)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = max(2, 2 ** (o + 2))
        grid = rng.random((max(2, n // 2), n))
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize(
            (w, h), Image.BICUBIC)
        out += np.asarray(img, dtype=np.float64) / 255.0 * amp
        total += amp
        amp *= 0.5
    return out / total


def build() -> None:
    w = int(PANEL_M[0] * PX_PER_M)
    h = int(PANEL_M[1] * PX_PER_M)
    seed = zlib.crc32(b"piano_truck_panel") % 9973

    # PAINTED COACHWORK. Never one flat value: a brush-painted body of this age
    # has tonal drift across a panel, and the lower third is permanently dirty.
    drift = _noise(seed, w, h, octaves=4)
    base = np.array(COACH)[None, None, :] * (0.80 + 0.40 * drift[:, :, None])
    yy = np.linspace(0.0, 1.0, h)[:, None, None]
    road_dirt = np.clip((yy - 0.55) / 0.45, 0.0, 1.0) ** 1.6
    base = base * (1.0 - 0.42 * road_dirt) + np.array(
        [0.10, 0.095, 0.088])[None, None, :] * road_dirt * 0.55
    # ENCODE TO sRGB BEFORE WRITING. COACH and the shading above are LINEAR
    # reflectances; a PNG albedo is read back as sRGB and linearised again, so
    # writing linear values straight out applies the transfer curve twice. The
    # first version did exactly that and the panel rendered at (5, 8, 9)
    # against a cab of (48, 57, 58) -- a box side seven times darker than the
    # bonnet it is bolted to, which is not a taste problem, it is a bug.
    panel = Image.fromarray(
        (np.clip(base, 0, 1) ** (1.0 / 2.2) * 255).astype(np.uint8), "RGB")

    # THE PLATE, at its own aspect ratio. Stretching a piece of authored art to
    # fit a panel is the one thing guaranteed to look wrong, so it keeps its
    # proportions and the body shows around it.
    sign = Image.open(SIGN).convert("RGBA")
    sh = int(h * SIGN_HEIGHT_FRAC)
    sw = int(sh * sign.width / sign.height)
    if sw > int(w * 0.62):
        sw = int(w * 0.62)
        sh = int(sw * sign.height / sign.width)
    sign = sign.resize((sw, sh), Image.LANCZOS)
    ox = (w - sw) // 2
    oy = int((h - sh) * 0.42)
    panel.paste(sign, (ox, oy), sign)

    # A hint of the plate standing off the body: a soft drop shadow under it.
    shadow = Image.new("L", (w, h), 0)
    shadow.paste(Image.new("L", (sw, sh), 130), (ox + 4, oy + 6))
    shadow = shadow.filter(ImageFilter.GaussianBlur(5))
    dark = Image.new("RGB", (w, h), (0, 0, 0))
    panel = Image.composite(dark, panel, shadow.point(lambda v: v // 3))
    panel.paste(sign, (ox, oy), sign)

    panel.save(os.path.join(OUT, "T_piano_truck_panel.png"))

    # ROUGHNESS. Enamel coachwork is fairly glossy; the plate is glossier still
    # and the dirt at the bottom is not.
    rough = np.full((h, w), 0.42) + 0.30 * road_dirt[:, :, 0]
    rough[oy:oy + sh, ox:ox + sw] = 0.30
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8), "L").save(
        os.path.join(OUT, "T_piano_truck_panel_rough.png"))

    print("panel -> %s" % os.path.relpath(OUT, ROOT))
    print("  T_piano_truck_panel.png  %dx%d for %.2f x %.2f m"
          % (w, h, PANEL_M[0], PANEL_M[1]))
    print("  sign plate %dx%d at (%d, %d)" % (sw, sh, ox, oy))


if __name__ == "__main__":
    build()
