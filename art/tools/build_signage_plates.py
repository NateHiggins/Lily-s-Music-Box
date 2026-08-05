"""Render engraved brass plates for every sign in the building.

The wayfinding pass drew its unit numbers, floor numbers and directory
lines with Label3D — engine-default text floated in front of a brass
rectangle. It reads as a debug overlay because that is essentially what
it is: no engraving, no depth, no period, and a glyph whose baseline
and tracking answer to Godot rather than to the plate.

This bakes the type INTO the metal instead. Each plate is aged brass
with its legend cut in: a dark incised core, a bright lower-right lip
where the graver threw the metal up, and a soft occlusion inside the
stroke. The result is one atlas the signage pass samples per plate, so
a number is a surface rather than a floating caption.

    python art/tools/build_signage_plates.py
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "building", "textures",
                   "signage")
SERIF = "C:/Windows/Fonts/BOOKOS.TTF"
SERIF_BOLD = "C:/Windows/Fonts/BOOKOSB.TTF"

CELL = 256
# Every legend the building needs, in atlas order. Units first (the
# plaque beside each door), then storey plates, then the mail bank.
UNITS = ["1A", "1D", "2A", "2B", "2C", "2D", "3A", "3B", "3C", "3D",
         "4A", "4B", "4C", "4D", "5A", "5B", "5C", "5D",
         "6A", "6B", "6C", "6D"]
FLOORS = ["B1", "1", "2", "3", "4", "5", "6", "ROOF"]
EXTRA = ["MAIL", "LETTERS", "SUPER", "NO EXIT", "STAIR", "OUT"]
LEGENDS = UNITS + FLOORS + EXTRA
COLS = 6


def brass_ground(size):
    """Rolled brass: warm base, faint vertical grain, corner tarnish."""
    import random
    rng = random.Random(1610)
    img = Image.new("RGB", (size, size), (166, 128, 62))
    px = img.load()
    for x in range(size):
        streak = rng.uniform(-9, 9)
        for y in range(size):
            n = rng.uniform(-4, 4) + streak
            r, g, b = px[x, y]
            px[x, y] = (max(0, min(255, int(r + n))),
                        max(0, min(255, int(g + n * 0.9))),
                        max(0, min(255, int(b + n * 0.6))))
    img = img.filter(ImageFilter.GaussianBlur(0.4))
    # tarnish creeping from the corners, where hands never wipe
    tar = Image.new("L", (size, size), 0)
    td = ImageDraw.Draw(tar)
    m = int(size * 0.30)
    td.ellipse((-m, -m, m, m), fill=110)
    td.ellipse((size - m, size - m, size + m, size + m), fill=90)
    tar = tar.filter(ImageFilter.GaussianBlur(size * 0.10))
    dark = Image.new("RGB", (size, size), (78, 60, 32))
    return Image.composite(dark, img, tar.point(lambda v: int(v * 0.55)))


def engrave(plate, text, size):
    """Cut the legend into the plate: incision, lip, and shadow."""
    font_path = SERIF_BOLD if len(text) <= 3 else SERIF
    fs = int(size * (0.46 if len(text) <= 3 else 0.22))
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    # Shrink to fit rather than trusting the guess: "OUT" in bold at 46%
    # ran off its own plate, and a legend that overflows its cell bleeds
    # into its neighbour in the atlas.
    font = ImageFont.truetype(font_path, fs)
    limit = size * 0.82
    for _ in range(12):
        bb = md.textbbox((0, 0), text, font=font)
        if (bb[2] - bb[0]) <= limit and (bb[3] - bb[1]) <= limit:
            break
        fs = int(fs * 0.92)
        font = ImageFont.truetype(font_path, fs)
    bbox = md.textbbox((0, 0), text, font=font)
    tx = (size - (bbox[2] - bbox[0])) // 2 - bbox[0]
    ty = (size - (bbox[3] - bbox[1])) // 2 - bbox[1]
    md.text((tx, ty), text, font=font, fill=255)

    out = plate.copy()
    # 1. the incision itself, darker than the ground
    cut = Image.new("RGB", (size, size), (54, 40, 20))
    out = Image.composite(cut, out, mask)
    # 2. the burr: metal thrown up on the lower-right of every stroke
    lip = mask.filter(ImageFilter.GaussianBlur(1.2))
    lip = Image.eval(lip, lambda v: v)
    shifted = Image.new("L", (size, size), 0)
    shifted.paste(lip, (2, 2))
    burr = Image.eval(
        Image.merge("L", [shifted]).point(lambda v: v), lambda v: v)
    only_burr = Image.composite(
        Image.new("L", (size, size), 0), burr, mask)
    bright = Image.new("RGB", (size, size), (226, 196, 128))
    out = Image.composite(bright, out,
                          only_burr.point(lambda v: int(v * 0.55)))
    # 3. occlusion hugging the stroke, so it sits in the metal
    halo = mask.filter(ImageFilter.GaussianBlur(2.6))
    halo = Image.composite(Image.new("L", (size, size), 0), halo, mask)
    shade = Image.new("RGB", (size, size), (104, 80, 40))
    out = Image.composite(shade, out, halo.point(lambda v: int(v * 0.45)))
    return out


def main() -> None:
    rows = (len(LEGENDS) + COLS - 1) // COLS
    atlas = Image.new("RGB", (COLS * CELL, rows * CELL), (30, 24, 14))
    ground = brass_ground(CELL)
    for i, legend in enumerate(LEGENDS):
        cell = engrave(ground, legend, CELL)
        atlas.paste(cell, ((i % COLS) * CELL, (i // COLS) * CELL))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "engraved_plates.png")
    atlas.save(path, optimize=True)
    index = {legend: [i % COLS, i // COLS]
             for i, legend in enumerate(LEGENDS)}
    import json
    with open(os.path.join(ROOT, "game", "data", "signage_plates.json"),
              "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"atlas": "engraved_plates.png", "cols": COLS,
                   "rows": rows, "cell": CELL, "index": index}, fh,
                  indent=1)
    print("wrote %s (%dx%d, %d legends)"
          % (path, atlas.width, atlas.height, len(LEGENDS)))


if __name__ == "__main__":
    main()
