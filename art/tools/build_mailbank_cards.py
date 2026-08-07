"""Render the name card for every box in the lobby mail bank.

The bank has twenty-four doors and the old atlas had twelve cells, so
half the building wore somebody else's card - and at 128 px a card is a
grey smudge the moment you lean in to read it, which is the one thing a
mail bank exists to let you do.

This renders one card per unit at 256 px: the unit number in a stencilled
box on the left, the tenant typed beside it. A card is not a label. It is
a slip of paper somebody fed into a typewriter, so they yellow at
different rates, sit slightly crooked in their frames, and the vacant
ones are blank card stock with the last name still faintly showing where
it was erased.

    python art/tools/build_mailbank_cards.py
"""
import json
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "building", "textures", "mailbank")
MONO = "C:/Windows/Fonts/consola.ttf"
MONO_B = "C:/Windows/Fonts/consolab.ttf"

# A card is a wide slip, not a square. The quad it lands on is 0.115 x
# 0.052 m - roughly 2.2:1 - so square cells squashed every name flat.
CW, CH = 256, 128
COLS = 6

# The order the prop walks its doors in. Keep in step with UNITS in
# mail_bank_prop.gd or every card lands one box out.
UNITS = ["1A", "1B", "1C", "1D", "2A", "2B",
         "2C", "2D", "3A", "3B", "3C", "3D",
         "4A", "4B", "4C", "4D", "5A", "5B",
         "5C", "5D", "6A", "6B", "6C", "6D"]

# Who the building says lives there. Blank means the box is not let.
TENANTS = {
    "1A": "E. MARSH", "1D": "T. VALE", "2A": "M. VALE", "2B": "L. ORTIZ",
    "2C": "J. KELLS", "3A": "M. REED", "3B": "O. BELL", "3D": "R. SATO",
    "4A": "P. WREN", "4B": "MAINTENANCE", "4C": "ORTIZ / PRICE",
    "4D": "TRANSIENT", "5A": "N. QUELL", "5B": "C. DWYER", "5C": "I. BELL",
    "6A": "S. REED", "6B": "J. PRICE", "6C": "M. KESSLER",
}
# Boxes with a story instead of a tenant.
GHOSTS = {"2D": "SEALED 1927", "5D": "", "3C": "", "6D": "STORE",
          "1B": "", "1C": ""}


def card(unit, rng):
    age = rng.random()
    paper = Image.new("RGB", (CW, CH),
                      (238 - int(age * 34), 233 - int(age * 40),
                       214 - int(age * 46)))
    d = ImageDraw.Draw(paper)
    # laid-paper tooth, so the card is stock rather than a flat fill
    for _ in range(int(CW * CH * 0.05)):
        x, y = rng.randrange(CW), rng.randrange(CH)
        v = rng.randint(-7, 7)
        r, g, b = paper.getpixel((x, y))
        paper.putpixel((x, y), (max(0, min(255, r + v)),
                                max(0, min(255, g + v)),
                                max(0, min(255, b + v))))
    # the number, boxed and stencilled at the left
    num_font = ImageFont.truetype(MONO_B, 62)
    d.rectangle((9, 26, 85, 102), outline=(58, 52, 44), width=3)
    bb = d.textbbox((0, 0), unit, font=num_font)
    d.text((47 - (bb[2] - bb[0]) / 2 - bb[0],
            64 - (bb[3] - bb[1]) / 2 - bb[1]), unit,
           font=num_font, fill=(38, 34, 28))
    # the tenant, typed. Long names step down a size rather than run off.
    name = TENANTS.get(unit, GHOSTS.get(unit, ""))
    if name:
        size = 34
        font = ImageFont.truetype(MONO, size)
        while size > 13:
            bb2 = d.textbbox((0, 0), name, font=font)
            if bb2[2] - bb2[0] <= CW - 104:
                break
            size -= 2
            font = ImageFont.truetype(MONO, size)
        ink = (44, 40, 34) if unit not in GHOSTS else (120, 112, 100)
        bb2 = d.textbbox((0, 0), name, font=font)
        d.text((96, 64 - (bb2[3] - bb2[1]) / 2 - bb2[1]), name,
               font=font, fill=ink)
        # typewriter strike is never perfectly even
        if rng.random() < 0.5:
            d.text((97, 65 - (bb2[3] - bb2[1]) / 2 - bb2[1]), name,
                   font=font, fill=(ink[0], ink[1], ink[2]))
    else:
        # erased: the ghost of whoever it was, mostly rubbed out
        gf = ImageFont.truetype(MONO, 30)
        ghost = Image.new("RGB", (CW, CH), (255, 255, 255))
        gd = ImageDraw.Draw(ghost)
        gd.text((98, 52), "........", font=gf, fill=(150, 145, 136))
        ghost = ghost.filter(ImageFilter.GaussianBlur(1.6))
        paper = Image.blend(paper, ghost, 0.10)
    return paper.rotate(rng.uniform(-1.1, 1.1), resample=Image.BICUBIC,
                        fillcolor=(236, 231, 212))


def main():
    rng = random.Random(1926)
    rows = (len(UNITS) + COLS - 1) // COLS
    atlas = Image.new("RGB", (COLS * CW, rows * CH), (30, 28, 24))
    for i, unit in enumerate(UNITS):
        atlas.paste(card(unit, rng), ((i % COLS) * CW, (i // COLS) * CH))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "T_mailbank_cards.png")
    atlas.save(path, optimize=True)
    with open(os.path.join(ROOT, "game", "data", "mailbank_cards.json"),
              "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"atlas": "T_mailbank_cards.png", "cols": COLS,
                   "rows": rows, "cell_w": CW, "cell_h": CH,
                   "units": UNITS}, fh, indent=1)
    print("wrote %s (%dx%d, %d cards)"
          % (path, atlas.width, atlas.height, len(UNITS)))


if __name__ == "__main__":
    main()
