"""Render the notices on the Orison's lobby bulletin board.

The board had five blank cream slabs on it. From the floor they read as
boxes floating in space, because a notice with nothing written on it is
not a notice - it is a rectangle.

These are the things a building like this actually posts, in the voice a
managing agent actually uses: rent, heat, the exterminator, what you may
not do in the halls. They are typed, mimeographed, and pinned up at
different times by different people, so they yellow at different rates
and none of them is straight.

One or two are older than the others and have been left up long past
their date, which is the detail that says nobody is really minding this
building.

    python art/tools/build_lobby_notices.py
"""
import json
import os
import random
import textwrap

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "building", "textures", "notices")
MONO = "C:/Windows/Fonts/consola.ttf"
MONO_B = "C:/Windows/Fonts/consolab.ttf"
SERIF_B = "C:/Windows/Fonts/timesbd.ttf"

CW, CH = 512, 640
COLS = 4

NOTICES = [
    ("rent", "NOTICE TO TENANTS",
     "RENT IS DUE ON THE FIRST. Payment after the fifth incurs a late "
     "charge of two dollars. Cheques to ORISON REALTY CO. only. Do not "
     "leave payment under the office door.", "ORISON REALTY CO.", 0.15),
    ("heat", "HEAT & HOT WATER",
     "The boiler is shut down between 1 and 4 AM for servicing. Bleed "
     "your own radiator before reporting a cold line. Complaints in "
     "writing to the superintendent.", "R. MAINTENANCE", 0.42),
    ("super", "SUPERINTENDENT HOURS",
     "Weekdays 8 AM to 6 PM. Emergencies only after hours: use the "
     "lobby telephone. Do not knock at 4B after 9 PM.", "R. MAINTENANCE",
     0.30),
    ("halls", "HOUSE RULES",
     "No loitering in the halls or on the stoop. No perambulators, "
     "bicycles or refuse to be left in the public ways. Radios and "
     "instruments silent after 10 PM.", "ORISON REALTY CO.", 0.55),
    ("exterm", "EXTERMINATOR",
     "The exterminator calls the second Tuesday of each month. Leave "
     "cupboards clear and pets secured. Tenants absent on the day will "
     "not be revisited.", "ORISON REALTY CO.", 0.68),
    ("roof", "ROOF ACCESS",
     "The roof door is to remain closed at all times. Lines may be hung "
     "on the north side only. Access is not permitted after dark under "
     "any circumstance.", "ORISON REALTY CO.", 0.80),
    ("elev", "ELEVATOR",
     "The car is out of service pending inspection. Use the stair. "
     "This notice was posted in March and has not been taken down.",
     "ORISON REALTY CO.", 0.92),
    ("lost", "FOUND",
     "One key, brass, no tag, found on the third landing. Claim from "
     "the superintendent. Describe it first.", "R. MAINTENANCE", 0.22),
]


def notice(spec, rng):
    key, head, body, sign, age = spec
    base = (240 - int(age * 42), 235 - int(age * 50), 216 - int(age * 58))
    paper = Image.new("RGB", (CW, CH), base)
    d = ImageDraw.Draw(paper)
    for _ in range(int(CW * CH * 0.035)):
        x, y = rng.randrange(CW), rng.randrange(CH)
        v = rng.randint(-8, 8)
        r, g, b = paper.getpixel((x, y))
        paper.putpixel((x, y), (max(0, min(255, r + v)),
                                max(0, min(255, g + v)),
                                max(0, min(255, b + v))))
    ink = (40, 36, 30)
    hf = ImageFont.truetype(SERIF_B, 46)
    bb = d.textbbox((0, 0), head, font=hf)
    d.text(((CW - (bb[2] - bb[0])) / 2 - bb[0], 54), head, font=hf, fill=ink)
    d.line((60, 124, CW - 60, 124), fill=ink, width=3)
    bf = ImageFont.truetype(MONO, 27)
    y = 168
    for line in textwrap.wrap(body, width=34):
        d.text((58, y), line, font=bf, fill=ink)
        y += 38
    sf = ImageFont.truetype(MONO_B, 25)
    d.text((58, CH - 96), sign, font=sf, fill=ink)
    # the pin hole, and the shadow of a hundred hands at the lower corner
    d.ellipse((CW / 2 - 7, 22, CW / 2 + 7, 36), fill=(150, 138, 116))
    smudge = Image.new("RGB", (CW, CH), (255, 255, 255))
    ImageDraw.Draw(smudge).ellipse(
        (CW - 210, CH - 170, CW + 60, CH + 70), fill=(196, 186, 166))
    smudge = smudge.filter(ImageFilter.GaussianBlur(46))
    paper = Image.blend(paper, smudge, 0.16 + age * 0.14)
    return paper


def main():
    rng = random.Random(1926)
    rows = (len(NOTICES) + COLS - 1) // COLS
    atlas = Image.new("RGB", (COLS * CW, rows * CH), (28, 26, 22))
    index = {}
    for i, spec in enumerate(NOTICES):
        atlas.paste(notice(spec, rng), ((i % COLS) * CW, (i // COLS) * CH))
        index[spec[0]] = [i % COLS, i // COLS]
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "lobby_notices.png")
    atlas.save(path, optimize=True)
    with open(os.path.join(ROOT, "game", "data", "lobby_notices.json"),
              "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"atlas": "lobby_notices.png", "cols": COLS, "rows": rows,
                   "index": index}, fh, indent=1)
    print("wrote %s (%dx%d, %d notices)"
          % (path, atlas.width, atlas.height, len(NOTICES)))


if __name__ == "__main__":
    main()
