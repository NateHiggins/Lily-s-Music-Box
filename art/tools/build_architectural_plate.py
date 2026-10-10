"""Dossier slice 55 (CITY_SHOP_PHOTO_SUPPLIES-001): one print on the photo shop's rail is a building.

Replaces atlas cell 3 (bottom right, the one cell a single print uses) of
art/data/photo_portraits/portrait_atlas.png with a procedural architectural
plate: a six-storey 1928 apartment front in warm grey/sepia gelatin-silver
tones to match the three generated portraits. Deterministic and idempotent:
cells 0-2 are left byte-for-byte, cell 3 is drawn from a fixed seed. No
reference photograph, no lettering, numerals, signs or logos.

    python art/tools/build_architectural_plate.py
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
ATLAS = ROOT / "art/data/photo_portraits/portrait_atlas.png"
W, H = 512, 768
rng = np.random.default_rng(1928)


def smooth_noise(cells_x, cells_y, sigma):
    g = rng.random((cells_y, cells_x)).astype(np.float32)
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
    return np.asarray(img.filter(ImageFilter.GaussianBlur(sigma)), dtype=np.float32) / 255.0


def rect(a, x0, y0, x1, y1, v):
    a[max(0, int(y0)):max(0, int(y1)), max(0, int(x0)):max(0, int(x1))] = v


def plate():
    L = np.zeros((H, W), np.float32)
    y = np.arange(H, dtype=np.float32)[:, None]
    # Sky: a pale overcast band, lighter toward the top.
    sky_bottom = 92
    L[:] = 0.80 - 0.10 * (y / sky_bottom) + 0.06 * (smooth_noise(6, 4, 14) - 0.5)
    # The neighbours: darker party walls at both edges, a little lower and higher.
    rect(L, 0, 130, 34, H, 0.30); rect(L, W - 28, 112, W, H, 0.27)
    x0, x1 = 34, W - 28
    # Brick field with faint coursing and mottle.
    brick = 0.47 + 0.05 * (smooth_noise(40, 60, 1.2) - 0.5) + 0.025 * (smooth_noise(8, 12, 6) - 0.5)
    courses = 0.012 * (np.sin(np.arange(H, dtype=np.float32) * np.pi / 2.0)[:, None] > 0.7)
    body = brick - courses
    L[sky_bottom:, x0:x1] = body[sky_bottom:, x0:x1]
    # Cornice: a projecting stone band with its shadow and a dentil row.
    rect(L, x0 - 8, sky_bottom, x1 + 8, sky_bottom + 14, 0.70)
    rect(L, x0 - 8, sky_bottom + 14, x1 + 8, sky_bottom + 20, 0.22)
    for dx in range(x0 - 4, x1 + 4, 9):
        rect(L, dx, sky_bottom + 20, dx + 5, sky_bottom + 27, 0.64)
    rect(L, x0, sky_bottom + 27, x1, sky_bottom + 31, 0.30)
    # Floors: five upper storeys of five bays, then a stone ground floor.
    ground_top, street = 622, 712
    storey = (ground_top - (sky_bottom + 44)) / 5.0
    bays = 5
    bay_w = (x1 - x0) / bays
    shades = rng.random((5, bays))
    for f in range(5):
        top = sky_bottom + 44 + f * storey
        for b in range(bays):
            cx = x0 + (b + 0.5) * bay_w
            ww, wh = bay_w * 0.46, storey * 0.62
            wx0, wy0 = cx - ww / 2, top + storey * 0.16
            # Stone lintel and sill.
            rect(L, wx0 - 5, wy0 - 9, wx0 + ww + 5, wy0 - 2, 0.68)
            rect(L, wx0 - 4, wy0 + wh + 1, wx0 + ww + 4, wy0 + wh + 6, 0.66)
            rect(L, wx0 - 4, wy0 + wh + 6, wx0 + ww + 4, wy0 + wh + 8, 0.30)
            # Glass, then the drawn blind at its own height, then sash bars.
            rect(L, wx0, wy0, wx0 + ww, wy0 + wh, 0.16)
            blind = shades[f, b]
            # Upper panes catch the overcast sky; the reveal throws a shadow under the lintel.
            g = np.linspace(0.34, 0.18, max(1, int(wh * 0.5)))[:, None]
            if blind <= 0.35: L[int(wy0):int(wy0) + g.shape[0], int(wx0):int(wx0 + ww)] = g
            rect(L, wx0, wy0, wx0 + ww, wy0 + 4, 0.08)
            rect(L, wx0, wy0, wx0 + 3, wy0 + wh, 0.10)
            # Soot washed down from the sill.
            streak = np.clip(1 - (np.arange(int(storey * 0.5), dtype=np.float32) / (storey * 0.5)), 0, 1)[:, None] * 0.07
            sy = int(wy0 + wh + 8); sx0_, sx1_ = int(wx0 + ww * 0.15), int(wx0 + ww * 0.85)
            L[sy:sy + streak.shape[0], sx0_:sx1_] -= streak[:max(0, min(streak.shape[0], H - sy))] * (0.6 + 0.8 * rng.random())
            if blind > 0.35:
                rect(L, wx0 + 2, wy0 + 2, wx0 + ww - 2, wy0 + 2 + (wh - 4) * min(1.0, blind * 0.9), 0.58)
            rect(L, wx0, wy0 + wh * 0.5 - 2, wx0 + ww, wy0 + wh * 0.5 + 2, 0.62)
            for k in (1, 2):
                rect(L, wx0 + ww * k / 3 - 1, wy0, wx0 + ww * k / 3 + 1, wy0 + wh * 0.5, 0.60)
            for side in (wx0 - 2, wx0 + ww):
                rect(L, side, wy0, side + 2, wy0 + wh, 0.58)
        # A string course under each storey.
        rect(L, x0, top + storey - 3, x1, top + storey, 0.55)
    # The fire escape down the second bay: platforms, rails and ladders.
    fx0 = x0 + bay_w * 1.0 + 4; fx1 = x0 + bay_w * 2.0 - 4
    for f in range(5):
        p = sky_bottom + 44 + f * storey + storey * 0.80
        rect(L, fx0, p, fx1, p + 4, 0.10)
        rect(L, fx0, p - 26, fx1, p - 24, 0.12)
        for xx in np.arange(fx0, fx1, 6):
            rect(L, xx, p - 26, xx + 1, p, 0.14)
        lx = fx0 + 8 + (f % 2) * (fx1 - fx0 - 24)
        rect(L, lx, p + 4, lx + 2, p + storey - 4, 0.12); rect(L, lx + 12, p + 4, lx + 14, p + storey - 4, 0.12)
        for r in np.arange(p + 10, p + storey - 6, 9):
            rect(L, lx, r, lx + 14, r + 1.5, 0.14)
    # Ground floor: rusticated stone, the arched entrance and its lamps, two shop windows.
    stone = 0.66 + 0.04 * (smooth_noise(30, 40, 1.5) - 0.5)
    L[ground_top:street, x0:x1] = stone[ground_top:street, x0:x1]
    for yy in range(ground_top + 14, street, 15):
        rect(L, x0, yy, x1, yy + 2, 0.48)
    cx = (x0 + x1) / 2
    door_w, door_top = 74, ground_top + 16
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    arch = ((np.abs(xx - cx) < door_w / 2) & (yy > door_top + door_w / 2) & (yy < street)) | (((xx - cx) ** 2 + (yy - door_top - door_w / 2) ** 2) < (door_w / 2) ** 2)
    ring = ((np.abs(xx - cx) < door_w / 2 + 7) & (yy > door_top + door_w / 2) & (yy < street)) | (((xx - cx) ** 2 + (yy - door_top - door_w / 2) ** 2) < (door_w / 2 + 7) ** 2)
    L[ring & ~arch] = 0.74
    L[arch] = 0.12
    rect(L, cx - 2, door_top + door_w / 2, cx + 2, street, 0.30)
    for side in (-1, 1):
        lx = cx + side * (door_w / 2 + 20)
        rect(L, lx - 1, door_top + 8, lx + 1, door_top + 30, 0.15)
        rect(L, lx - 5, door_top + 2, lx + 5, door_top + 12, 0.82)
        sx0 = x0 + 18 if side < 0 else cx + door_w / 2 + 40
        sx1 = cx - door_w / 2 - 40 if side < 0 else x1 - 18
        rect(L, sx0, ground_top + 22, sx1, street - 14, 0.20)
        rect(L, sx0, ground_top + 22, sx1, ground_top + 34, 0.44)
        rect(L, sx0 - 4, street - 14, sx1 + 4, street - 9, 0.62)
    # Street and kerb, a lamp post on the near pavement.
    rect(L, 0, street, W, H, 0.36)
    rect(L, 0, street + 18, W, street + 22, 0.58)
    L[street + 22:, :] = 0.30 + 0.05 * (smooth_noise(20, 10, 2)[street + 22:, :] - 0.5)
    rect(L, W - 70, 600, W - 66, street + 20, 0.10)
    rect(L, W - 74, 585, W - 62, 590, 0.12)
    rect(L, W - 75, 590, W - 61, 604, 0.80)
    # Raking afternoon light from the left; the facade darkens toward the street.
    L[sky_bottom:, :] *= (1.08 - 0.16 * (xx[sky_bottom:, :] / W)) * (1.04 - 0.10 * ((yy[sky_bottom:, :] - sky_bottom) / (H - sky_bottom)))
    # A soft lens: slight blur, vignette, grain and the paper's fade.
    img = Image.fromarray((np.clip(L, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.9))
    L = np.asarray(img, dtype=np.float32) / 255.0
    r = np.sqrt(((xx - W / 2) / (W * 0.62)) ** 2 + ((yy - H / 2) / (H * 0.62)) ** 2)
    L = L * (1 - 0.28 * np.clip(r, 0, 1) ** 2.2)
    L = L + rng.normal(0, 0.028, L.shape).astype(np.float32)
    L = 0.07 + 0.86 * np.clip(L, 0, 1)
    # Warm grey/sepia toning matched to the three generated prints' channel ratios.
    rgb = np.stack([L * 1.0, L * 0.865, L * 0.735], axis=-1) + np.array([0.035, 0.03, 0.025])
    return (np.clip(rgb, 0, 1) * 255).astype(np.uint8)


def main():
    atlas = np.array(Image.open(ATLAS).convert("RGB"))
    assert atlas.shape == (1536, 1024, 3), atlas.shape
    atlas[768:1536, 512:1024] = plate()
    Image.fromarray(atlas, "RGB").save(ATLAS, optimize=False)
    print("architectural plate written to atlas cell 3:", ATLAS)


if __name__ == "__main__":
    main()
