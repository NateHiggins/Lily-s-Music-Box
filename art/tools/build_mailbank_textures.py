"""Generate the lobby mail bank's textures: aged brass, typed name cards,
and the engraved header plate.

Cutler-style prewar bank (research: Ephemeral New York / Atlas Obscura /
Traditional Building on 1900s-30s NYC lobby letter boxes): cast brass
doors with beveled frames, round cylinder locks, glass-front name card
holders, a brass surround with header plate, outgoing LETTERS slot. Aged:
dark patina in recesses, polished where fingers go.

    python art/tools/build_mailbank_textures.py
        writes game/assets/building/textures/mailbank/*.png
"""
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "building", "textures", "mailbank")
FONTS = r"C:\Windows\Fonts"

# Grid order, left-right top-bottom, matching MailBankProp's door layout.
CARDS = [
    ("1A", "MARSH"), ("1B", None), ("1C", None), ("1D", "VALE"),
    ("2A", "VALE"), ("2B", "ORTIZ"),
    ("2C", "KELLS"), ("2D", None), ("3A", "REED"), ("3B", "BELL"),
    ("3C", None), ("3D", "SATO"),
    ("4A", "WREN"), ("4B", "MAINTENANCE"), ("4C", "ORTIZ / PRICE"),
    ("4D", "\u2014 GUESTS \u2014"), ("5A", "QUELL"), ("5B", "DWYER"),
    ("5C", "BELL"), ("5D", None), ("6A", "REED"), ("6B", "PRICE"),
    ("6C", "KESSLER"), ("6D", None),
]

rng = random.Random(19260802)


def brass() -> None:
    size = 512
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y_pix in range(size):
        for x_pix in range(size):
            v = rng.uniform(-9, 9)
            px[x_pix, y_pix] = (int(138 + v), int(109 + v), int(51 + v * 0.7))
    # Patina: soft dark blotches, then verdigris hints, both blurred in.
    blotch = Image.new("L", (size, size), 0)
    bdraw = ImageDraw.Draw(blotch)
    for _ in range(46):
        x_pix, y_pix = rng.randrange(size), rng.randrange(size)
        r = rng.randrange(18, 85)
        bdraw.ellipse([x_pix - r, y_pix - r, x_pix + r, y_pix + r],
                      fill=rng.randrange(30, 90))
    blotch = blotch.filter(ImageFilter.GaussianBlur(22))
    dark = Image.new("RGB", (size, size), (74, 58, 30))
    img = Image.composite(dark, img, blotch)
    verd = Image.new("L", (size, size), 0)
    vdraw = ImageDraw.Draw(verd)
    for _ in range(12):
        x_pix, y_pix = rng.randrange(size), rng.randrange(size)
        r = rng.randrange(8, 30)
        vdraw.ellipse([x_pix - r, y_pix - r, x_pix + r, y_pix + r],
                      fill=rng.randrange(20, 55))
    verd = verd.filter(ImageFilter.GaussianBlur(14))
    green = Image.new("RGB", (size, size), (74, 96, 78))
    img = Image.composite(green, img, verd)
    # Fine vertical brushing.
    draw = ImageDraw.Draw(img, "RGBA")
    for _ in range(900):
        x_pix = rng.randrange(size)
        y_pix = rng.randrange(size)
        length = rng.randrange(12, 60)
        tone = rng.choice([(255, 240, 200, 10), (40, 30, 12, 12)])
        draw.line([x_pix, y_pix, x_pix, y_pix + length], fill=tone)
    img.save(os.path.join(OUT, "T_mailbank_brass_albedo.png"))

    rough = Image.new("L", (size, size))
    rpx = rough.load()
    bpx = blotch.load()
    for y_pix in range(size):
        for x_pix in range(size):
            base = 118 + rng.uniform(-10, 10)
            rpx[x_pix, y_pix] = int(min(235, base + bpx[x_pix, y_pix] * 0.45))
    rough.save(os.path.join(OUT, "T_mailbank_brass_rough.png"))


def cards() -> None:
    cw, ch = 128, 64
    img = Image.new("RGB", (cw * 6, ch * 4), (20, 16, 12))
    try:
        font_unit = ImageFont.truetype(os.path.join(FONTS, "courbd.ttf"), 21)
        font_name = ImageFont.truetype(os.path.join(FONTS, "cour.ttf"), 15)
        font_small = ImageFont.truetype(os.path.join(FONTS, "cour.ttf"), 12)
    except OSError:
        font_unit = font_name = font_small = ImageFont.load_default()
    for i, (unit, name) in enumerate(CARDS):
        col, row = i % 6, i // 6
        x0, y0 = col * cw, row * ch
        tone = rng.randrange(-14, 6)
        paper = (233 + tone, 224 + tone, 198 + tone)
        if name is None:
            paper = (214 + tone, 200 + tone, 168 + tone)  # yellowed, older
        card = ImageDraw.Draw(img)
        card.rectangle([x0 + 3, y0 + 3, x0 + cw - 4, y0 + ch - 4], fill=paper)
        # A faint rule line, like the card stock came printed with one.
        card.line([x0 + 10, y0 + 42, x0 + cw - 10, y0 + 42],
                  fill=(168, 152, 120), width=1)
        jx, jy = rng.randrange(-2, 3), rng.randrange(-2, 3)
        ink = (36, 32, 40)
        if name is None:
            if unit == "2D":  # one vacancy is marked, the others just fade
                card.text((x0 + 26 + jx, y0 + 22 + jy), "VACANT",
                          font=font_name, fill=(120, 104, 88))
        elif name == "MAINTENANCE":
            card.text((x0 + 12 + jx, y0 + 10 + jy), unit, font=font_unit,
                      fill=(88, 30, 24))
            card.text((x0 + 12 + jx, y0 + 44 + jy), "MAINTENANCE",
                      font=font_small, fill=(88, 30, 24))
        else:
            card.text((x0 + 12 + jx, y0 + 10 + jy), unit, font=font_unit,
                      fill=ink)
            font_pick = font_small if len(name) > 10 else font_name
            card.text((x0 + 12 + jx, y0 + 44 + jy), name, font=font_pick,
                      fill=ink)
    img.save(os.path.join(OUT, "T_mailbank_cards.png"))


def header() -> None:
    w, h = 512, 96
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y_pix in range(h):
        for x_pix in range(w):
            v = rng.uniform(-7, 7)
            shade = 1.0 - abs(y_pix - h / 2) / h * 0.35
            px[x_pix, y_pix] = (int((150 + v) * shade), int((119 + v) * shade),
                                int((58 + v * 0.7) * shade))
    draw = ImageDraw.Draw(img)
    try:
        font_big = ImageFont.truetype(os.path.join(FONTS, "times.ttf"), 40)
        font_sub = ImageFont.truetype(os.path.join(FONTS, "times.ttf"), 22)
    except OSError:
        font_big = font_sub = ImageFont.load_default()
    # Incised lettering: dark fill with a thin light drop edge below-right.
    for text, font, y_pix in [("THE ORISON", font_big, 8),
                              ("U. S.  M A I L", font_sub, 58)]:
        bbox = draw.textbbox((0, 0), text, font=font)
        x_pix = (w - (bbox[2] - bbox[0])) // 2
        draw.text((x_pix + 1, y_pix + 1), text, font=font,
                  fill=(196, 168, 104))
        draw.text((x_pix, y_pix), text, font=font, fill=(48, 36, 16))
    img.save(os.path.join(OUT, "T_mailbank_header.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    brass()
    cards()
    header()
    print("wrote 4 textures to %s" % OUT)
