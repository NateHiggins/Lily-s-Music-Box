"""Positional wear decal textures (dossier slices 52 and 60): soft procedural masks plus desaturated crops of the
existing atmospheric institutional-wear atlas. No lettering, no numerals, no photographs. Deterministic: the
slice 52 set comes first from its own seed and is byte-identical on every run; slice 60's basement set follows
from a second seed.

    python art/tools/build_wear_decals.py
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/building/textures/wear_decals"
OUT.mkdir(parents=True, exist_ok=True)
N = 512
rng = np.random.default_rng(1928)


def noise(scale, octaves=4):
    acc = np.zeros((N, N)); amp = 1.0; tot = 0
    for o in range(octaves):
        s = max(2, int(scale * 2 ** o))
        g = rng.random((s + 1, s + 1))
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)
        acc += amp * np.asarray(img) / 255.0; tot += amp; amp *= .5
    return acc / tot


def save(name, rgb, alpha):
    a = np.clip(alpha, 0, 1)
    arr = np.dstack([np.clip(rgb, 0, 1)] + [a])
    Image.fromarray((arr * 255).astype(np.uint8), "RGBA").save(OUT / (name + ".png"))

y, x = np.mgrid[0:N, 0:N] / (N - 1.0)
grime = np.array([.18, .15, .11])
# Receptor: a dark grout band round the tray's footprint (the tray covers the middle), wet-darker in spots.
d = np.maximum(np.abs(x - .5), np.abs(y - .5)) * 2  # 0 centre, 1 edge
band = np.exp(-((d - .8) / .09) ** 2) * (.6 + .5 * noise(6))
save("wear_receptor", np.ones((N, N, 3)) * grime, band * .85)
# Corner: the mop-shadow, grime packed into one corner (x=0,y=1) fading out diagonally.
r = np.sqrt(x ** 2 + (1 - y) ** 2)
corner = np.clip(1 - r / .9, 0, 1) ** 1.6 * (.55 + .6 * noise(5))
save("wear_corner", np.ones((N, N, 3)) * grime * .9, corner * .9)
# Path: the dulled walking line down a hall, lighter and matte, soft across its width.
path = np.exp(-((x - .5) / .22) ** 2) * (.5 + .5 * noise(3)) * np.clip(np.minimum(y, 1 - y) / .12, 0, 1)
save("wear_path", np.ones((N, N, 3)) * grime * 1.2, path * .32)
# Crops of the institutional atlas, desaturated to grime and softened: threshold foot scuffs, the
# shoulder/trolley rub and the heat plume (used inverted as the stain under a vent register).
atlas = np.asarray(Image.open(ROOT / "game/assets/building/textures/atmospheric_decals/institutional_wear_atlas.png").convert("RGBA")) / 255.0
h = atlas.shape[0] // 2
for name, (col, row), flip, strength in [("wear_threshold", (0, 1), False, .55), ("wear_rub", (0, 0), False, .42)]:
    tile = atlas[row * h + 8:(row + 1) * h - 8, col * h + 8:(col + 1) * h - 8]
    tile = np.asarray(Image.fromarray((tile * 255).astype(np.uint8), "RGBA").resize((N, N), Image.LANCZOS)) / 255.0
    if flip: tile = tile[::-1]
    lum = tile[..., :3] @ np.array([.3, .59, .11])
    rgb = grime[None, None, :] * (.9 + 1.1 * lum[..., None])
    save(name, rgb, tile[..., 3] * strength)

# Dossier slice 60: the basement's coal and service wear, from a second seed.
rng = np.random.default_rng(1610)
coal = np.array([.055, .05, .045])
# Coal dust trodden from the boiler room: darker toward +u (the fire door), soft at both sides.
side = np.clip(np.minimum(y, 1 - y) / .22, 0, 1) ** .8
dust = np.clip(x ** 1.6 * (.5 + .75 * noise(7)) + .18 * x * np.exp(-((y - .5) / .18) ** 2), 0, 1) * side
save("wear_coal", np.ones((N, N, 3)) * coal, dust * .85)
# A door leaf's sweep: a scuffed quarter ring about the hinge corner (u=0, v=1), the leaf's width out.
r = np.sqrt(x ** 2 + (1 - y) ** 2)
ring = np.exp(-((r - .955) / .018) ** 2) * (.55 + .7 * noise(24)) + .12 * np.clip(1 - np.abs(r - .9) / .1, 0, 1) * noise(9)
save("wear_arc", np.ones((N, N, 3)) * grime * .8, np.clip(ring, 0, 1) * (r < 1.0) * .8)
# Coal dust fanned out from the chute mouth at (u=.5, v=0).
rf = np.sqrt(((x - .5) / .9) ** 2 + y ** 2)
fan = np.clip(np.exp(-rf / .38) * (.45 + .8 * noise(6)) * (1 - np.clip(np.abs(x - .5) / (.15 + .55 * y), 0, 1) ** 3), 0, 1)
save("wear_fan", np.ones((N, N, 3)) * coal, fan * .9)
# The chalked log: a column of short horizontal strokes, tally groups and ticks in a working hand. No numerals.
chalk = np.zeros((N, N))
from PIL import ImageDraw
img = Image.new("L", (N, N), 0); dr = ImageDraw.Draw(img)
row_y = 26
while row_y < N - 26:
    x0 = 70 + int(rng.integers(-6, 7))
    for k in range(int(rng.integers(2, 6))):
        xs = x0 + k * 16
        dr.line([(xs, row_y - 9 + int(rng.integers(-2, 3))), (xs + int(rng.integers(-2, 3)), row_y + 9)], fill=235, width=4)
    if rng.random() < .5:
        dr.line([(x0 - 6, row_y + 7), (x0 + 70, row_y - 7)], fill=225, width=4)
    lx = 230 + int(rng.integers(-10, 10)); dr.line([(lx, row_y), (lx + int(rng.integers(90, 200)), row_y + int(rng.integers(-3, 4)))], fill=215, width=5)
    row_y += int(rng.integers(30, 40))
chalk = np.asarray(img.filter(ImageFilter.GaussianBlur(1.2)), dtype=float) / 255.0 * (.6 + .5 * noise(40))
save("wear_chalk", np.ones((N, N, 3)) * np.array([.86, .85, .8]), np.clip(chalk, 0, 1) * .9)
print(sorted(p.name for p in OUT.glob("*.png")))
