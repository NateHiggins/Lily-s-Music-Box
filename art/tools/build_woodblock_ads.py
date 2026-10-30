#!/usr/bin/env python3
"""Woodblock illustrations for the newspapers' advertisements and Sunday cartoon.

One-bit ink at the real resolution (128 x 96), drawn from a small figure and prop
kit with hand-cut hatching. Each scene below is one composed gag. No lettering:
words belong to the advertisement's live text (RUL-008). Deterministic: the same
source writes the same bytes.

    python art/tools/build_woodblock_ads.py [--sheet <contact.png>] [--only id,id]

Writes game/assets/ui/newspaper/ads/<id>.png and cartoons/<date>.png: ink on
transparency, so the newsprint shows through. The panel draws them at an integer scale with nearest
filtering.
"""
from pathlib import Path
import argparse
import hashlib
import math
import random

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/ui/newspaper/ads"
CARTOON_OUT = ROOT / "game/assets/ui/newspaper/cartoons"
W, H = 128, 96
INK = (28, 25, 22, 255)


class Block:
    def __init__(self, name):
        self.im = Image.new("1", (W, H), 0)
        self.d = ImageDraw.Draw(self.im)
        self.r = random.Random(int(hashlib.sha256(name.encode()).hexdigest()[:8], 16))

    # --- cutting -------------------------------------------------------------
    def line(self, pts, w=1, v=1):
        self.d.line(pts, fill=v, width=w)

    def poly(self, pts, v=1, edge=None):
        self.d.polygon(pts, fill=v, outline=edge if edge is not None else v)

    def rect(self, x0, y0, x1, y1, v=1, edge=None):
        box = (min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1))
        self.d.rectangle(box, fill=v, outline=edge if edge is not None else v)

    def disc(self, x, y, r, v=1, edge=None, ry=None):
        ry = r if ry is None else ry
        self.d.ellipse((x - r, y - ry, x + r, y + ry), fill=v, outline=edge if edge is not None else v)

    def dot(self, x, y, v=1):
        self.d.point((x, y), fill=v)

    def hatch(self, shape, angle=35, gap=3, v=1, wobble=1):
        """Parallel knife cuts inside a polygon, each a little uneven."""
        mask = Image.new("1", (W, H), 0)
        ImageDraw.Draw(mask).polygon(shape, fill=1)
        cuts = Image.new("1", (W, H), 0)
        dc = ImageDraw.Draw(cuts)
        dx, dy = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        span = W + H
        offset = -span
        while offset < span:
            ox, oy = W / 2 - dy * offset, H / 2 + dx * offset
            x0 = ox - dx * span + self.r.randint(-wobble, wobble)
            y0 = oy - dy * span + self.r.randint(-wobble, wobble)
            x1 = ox + dx * span + self.r.randint(-wobble, wobble)
            y1 = oy + dy * span + self.r.randint(-wobble, wobble)
            dc.line((x0, y0, x1, y1), fill=1)
            offset += gap
        self.im.paste(v, mask=ImageChops.logical_and(cuts, mask))

    def frame(self):
        self.d.rectangle((0, 0, W - 1, H - 1), outline=1)
        self.d.rectangle((2, 2, W - 3, H - 3), outline=1)

    def night(self):
        """The black block: everything left standing prints."""
        self.rect(3, 3, W - 4, H - 4, 1)

    def rays(self, x, y, n=14, inner=20, v=0):
        for i in range(n):
            a = math.tau * i / n + self.r.uniform(-0.05, 0.05)
            self.line([(x + math.cos(a) * inner, y + math.sin(a) * inner),
                       (x + math.cos(a) * 200, y + math.sin(a) * 200)], 1, v)

    def ground(self, y=84, v=1):
        self.rect(3, y, W - 4, H - 4, v)
        for i in range(3):
            x = self.r.randint(6, 40) + i * 36
            self.line([(x, y + 3 + i * 2), (x + self.r.randint(10, 24), y + 3 + i * 2)], 1, 1 - v)

    def wall(self, y=84):
        """Tone cut with the knife: solid at the top, the lines thinning and
        spreading as they come down, so the middle of the block stays open."""
        self.rect(3, 3, W - 4, 7, 1)
        gap, line_y, width = 2, 9, 2
        while line_y < y - 34:
            points = [(3, line_y)]
            for x in range(10, W, 8):
                points.append((x, line_y + self.r.randint(-1, 1)))
            self.d.line(points, fill=1, width=width)
            line_y += gap + width
            gap += 1
            if gap > 3:
                width = 1

    def bubbles(self, pts, v=1):
        for x, y, r in pts:
            self.d.ellipse((x - r, y - r, x + r, y + r), outline=v)

    def puffs(self, x, y, n=4, dx=7, dy=-5, v=1, grow=1):
        for i in range(n):
            r = 2 + i * grow
            self.d.ellipse((x + dx * i - r, y + dy * i - r, x + dx * i + r, y + dy * i + r), outline=v, fill=1 - v)

    def lines_of_motion(self, x, y, n=3, length=9, gap=4, v=1):
        for i in range(n):
            self.line([(x, y + i * gap), (x - length, y + i * gap)], 1, v)

    # --- people --------------------------------------------------------------
    def head(self, x, y, r=8, face=1, mouth="smile", hat=None, stache=False, specs=False, bald=False,
             eyes="dot", v=1, hair=False, blush=False):
        """Round head in profile: nose to the side it faces."""
        paper = 1 - v
        self.disc(x, y, r + 1, v)
        self.disc(x, y, r, paper, v)
        self.poly([(x + face * (r - 1), y - 2), (x + face * (r + 3), y + 1), (x + face * (r - 1), y + 3)], paper, v)
        self.line([(x + face * (r - 1), y - 1), (x + face * (r - 1), y + 2)], 1, paper)
        ex, ey = x + face * (r // 3), y - 2
        if eyes == "dot":
            self.rect(ex, ey, ex + face, ey + 1, v)
        elif eyes == "wide":
            self.disc(ex, ey, 2, paper, v)
            self.dot(ex + face, ey, v)
        elif eyes == "shut":
            self.line([(ex - 2, ey), (ex + 2, ey)], 1, v)
        elif eyes == "x":
            self.line([(ex - 1, ey - 1), (ex + 1, ey + 1)], 1, v)
            self.line([(ex - 1, ey + 1), (ex + 1, ey - 1)], 1, v)
        mx, my = x + face * (r // 2), y + r // 2 + 1
        if mouth == "smile":
            self.line([(mx - 3 * face, my), (mx, my + 1), (mx + 2 * face, my - 1)], 1, v)
        elif mouth == "flat":
            self.line([(mx - 3 * face, my), (mx + 2 * face, my)], 1, v)
        elif mouth == "frown":
            self.line([(mx - 3 * face, my + 1), (mx, my), (mx + 2 * face, my + 1)], 1, v)
        elif mouth == "o":
            self.disc(mx, my, 2, v)
        elif mouth == "grin":
            self.rect(min(mx - 4 * face, mx + 2 * face), my - 1, max(mx - 4 * face, mx + 2 * face), my + 1, paper, v)
            for gx in range(min(mx - 4 * face, mx + 2 * face) + 2, max(mx - 4 * face, mx + 2 * face), 2):
                self.line([(gx, my - 1), (gx, my + 1)], 1, v)
        if stache:
            self.line([(mx - 4 * face, my - 2), (mx + 3 * face, my - 2)], 2, v)
        if specs:
            self.d.ellipse((ex - 2, ey - 2, ex + 2, ey + 2), outline=v)
            self.line([(ex - 2 * face, ey), (x - face * r, ey - 1)], 1, v)
        if hair:
            self.poly([(x - r, y - 2), (x - r + 2, y - r), (x + r - 2, y - r), (x + r, y - 3), (x, y - r + 3)], v)
        if hat == "bowler":
            self.line([(x - r - 2, y - r + 3), (x + r + 2, y - r + 3)], 2, v)
            self.d.pieslice((x - r + 1, y - r - 6, x + r - 1, y - r + 7), 180, 360, fill=v)
        elif hat == "top":
            self.line([(x - r - 2, y - r + 3), (x + r + 2, y - r + 3)], 2, v)
            self.rect(x - r + 2, y - r - 8, x + r - 2, y - r + 2, v)
            self.line([(x - r + 2, y - r - 1), (x + r - 2, y - r - 1)], 1, paper)
        elif hat == "boater":
            self.line([(x - r - 3, y - r + 3), (x + r + 3, y - r + 3)], 1, v)
            self.rect(x - r + 1, y - r - 1, x + r - 1, y - r + 2, paper, v)
            self.line([(x - r + 1, y - r + 1), (x + r - 1, y - r + 1)], 1, v)
        elif hat == "cloche":
            self.d.pieslice((x - r - 1, y - r - 3, x + r + 1, y + r - 3), 180, 360, fill=v)
            self.line([(x - face * r, y - 3), (x - face * r, y + 3)], 3, v)
        elif hat == "cap":
            self.d.pieslice((x - r, y - r - 3, x + r, y + r - 5), 180, 360, fill=v)
            self.line([(x, y - 4), (x + face * (r + 4), y - 4)], 2, v)
        elif hat == "mortar":
            self.poly([(x - r - 3, y - r), (x, y - r - 4), (x + r + 3, y - r), (x, y - r + 3)], v)
        return x, y

    def man(self, x, foot, h=56, face=1, hat="bowler", mouth="smile", stache=False, specs=False, eyes="dot",
            arms=None, legs="stand", coat=1, belly=0, r=None, tie=True, hair=False):
        """A small printed man. arms: endpoints relative to the shoulder."""
        r = r or max(6, int(h * 0.16))
        hy = foot - h + r + 2
        neck = hy + r
        hip = foot - int(h * 0.3)
        tw = max(4, int(h * 0.11)) + belly
        paper = 1 - coat
        body = [(x - tw, neck + 1), (x + tw, neck + 1), (x + tw + belly // 2, (neck + hip) // 2),
                (x + tw, hip), (x - tw, hip), (x - tw - belly // 2, (neck + hip) // 2)]
        if legs == "stand":
            self.line([(x - 2, hip), (x - 3, foot)], 3)
            self.line([(x + 2, hip), (x + 3, foot)], 3)
            self.line([(x - 3, foot), (x - 3 + face * 3, foot)], 2)
            self.line([(x + 3, foot), (x + 3 + face * 3, foot)], 2)
        elif legs == "run":
            self.line([(x, hip), (x + face * 7, hip + 5), (x + face * 11, foot - 2)], 3)
            self.line([(x, hip), (x - face * 4, hip + 8), (x - face * 13, foot - 7)], 3)
        elif legs == "sit":
            self.line([(x, hip), (x + face * 11, hip)], 3)
            self.line([(x + face * 11, hip), (x + face * 11, foot)], 3)
        elif legs == "wide":
            self.line([(x - 2, hip), (x - 8, foot)], 3)
            self.line([(x + 2, hip), (x + 8, foot)], 3)
        elif legs == "tiptoe":
            self.line([(x, hip), (x + 1, foot)], 3)
            self.line([(x, hip), (x - face * 8, hip + 5), (x - face * 11, hip + 1)], 3)
        self.poly(body, coat, 1)
        if coat and tie:
            self.line([(x + face, neck + 1), (x + face, neck + 6)], 1, 0)
        if coat:
            # A highlight cut down the side the light falls on.
            self.line([(x + face * (tw - 2), neck + 3), (x + face * (tw - 2), hip - 2)], 1, 0)
        else:
            self.hatch(body, 60, 3)
        if arms:
            for ax, ay in arms:
                self.line([(x, neck + 3), (x + ax, neck + 3 + ay)], 3)
                self.disc(x + ax, neck + 3 + ay, 1, 0, 1)
        self.head(x, hy, r, face, mouth, hat, stache, specs, eyes=eyes, hair=hair)
        return x, hy, neck

    def woman(self, x, foot, h=54, face=1, hat="cloche", mouth="smile", arms=None, dress=1, r=None, eyes="dot"):
        r = r or max(6, int(h * 0.16))
        hy = foot - h + r + 2
        neck = hy + r
        hem = foot - int(h * 0.2)
        self.line([(x - 3, hem), (x - 3, foot)], 2)
        self.line([(x + 3, hem), (x + 3, foot)], 2)
        self.line([(x - 3, foot), (x - 3 + face * 3, foot)], 2)
        self.line([(x + 3, foot), (x + 3 + face * 3, foot)], 2)
        self.poly([(x - 4, neck + 1), (x + 4, neck + 1), (x + 8, hem), (x - 8, hem)], dress, 1)
        if arms:
            for ax, ay in arms:
                self.line([(x, neck + 3), (x + ax, neck + 3 + ay)], 2)
                self.disc(x + ax, neck + 3 + ay, 1, 0, 1)
        self.head(x, hy, r, face, mouth, hat, eyes=eyes)
        return x, hy, neck

    # --- things ---------------------------------------------------------------
    def bottle(self, x, y, s=1.0, v=1):
        """Base centre at x,y."""
        w, b, n = int(9 * s), int(24 * s), int(9 * s)
        self.rect(x - w, y - b, x + w, y, v, 1)
        self.poly([(x - w, y - b), (x + w, y - b), (x + w // 3, y - b - n // 2), (x - w // 3, y - b - n // 2)], v, 1)
        self.rect(x - w // 3, y - b - n, x + w // 3, y - b - n // 2, v, 1)
        self.rect(x - w + 2, y - b // 2 - int(6 * s), x + w - 2, y - b // 2 + int(5 * s), 1 - v, v if v else 1)
        self.line([(x - w + 4, y - b // 2), (x + w - 4, y - b // 2)], 1, v)

    def table(self, x0, x1, y, foot=84):
        self.rect(x0, y, x1, y + 2, 1)
        self.line([(x0 + 3, y + 2), (x0 + 3, foot)], 2)
        self.line([(x1 - 3, y + 2), (x1 - 3, foot)], 2)

    def chair(self, x, foot=84, face=1):
        self.line([(x - face * 6, foot - 26), (x - face * 6, foot)], 2)
        self.line([(x - face * 6, foot - 12), (x + face * 6, foot - 12)], 2)
        self.line([(x + face * 6, foot - 12), (x + face * 6, foot)], 2)

    def dog(self, x, foot, face=1, v=1, stripes=False):
        self.rect(x - 9, foot - 11, x + 9, foot - 5, v, 1)
        self.line([(x - 7, foot - 5), (x - 7, foot)], 2, 1)
        self.line([(x + 7, foot - 5), (x + 7, foot)], 2, 1)
        self.disc(x + face * 11, foot - 14, 4, v, 1)
        self.poly([(x + face * 8, foot - 18), (x + face * 7, foot - 12), (x + face * 10, foot - 15)], 1)
        self.line([(x - face * 9, foot - 10), (x - face * 13, foot - 15)], 1)
        self.dot(x + face * 12, foot - 15, 1 - v)
        if stripes:
            for sx in range(-7, 9, 4):
                self.line([(x + sx, foot - 11), (x + sx, foot - 5)], 2, 1)

    def clock(self, x, y, r=10, hour=(0, -1), minute=(1, 0)):
        self.disc(x, y, r, 0, 1)
        self.d.ellipse((x - r + 1, y - r + 1, x + r - 1, y + r - 1), outline=1)
        self.line([(x, y), (x + hour[0] * r // 2, y + hour[1] * r // 2)], 2)
        self.line([(x, y), (x + minute[0] * (r - 3), y + minute[1] * (r - 3))], 1)

    def radio(self, x, y, w=30, h=16):
        self.rect(x, y - h, x + w, y, 1)
        self.disc(x + 7, y - h // 2, 4, 0, 1)
        self.disc(x + w - 7, y - h // 2, 2, 0, 1)
        self.rect(x + 13, y - h + 3, x + w - 13, y - 4, 0, 1)

    def sparks(self, x, y, n=6, r=10, v=1):
        for i in range(n):
            a = math.tau * i / n + 0.3
            self.line([(x + math.cos(a) * r * .6, y + math.sin(a) * r * .6),
                       (x + math.cos(a) * r, y + math.sin(a) * r)], 1, v)


SCENES = {}


def scene(fn):
    SCENES[fn.__name__] = fn
    return fn


# --- the listening age's props ---------------------------------------------------
def valve(b, x, y, s=1.0, v=1, glow=False):
    """A glass valve standing on its base at x,y."""
    w, h = int(5 * s), int(13 * s)
    b.d.ellipse((x - w, y - h - int(5 * s), x + w, y - int(3 * s)), fill=1 - v, outline=v)
    b.rect(x - w + 1, y - int(4 * s), x + w - 1, y, v)
    b.line([(x - w // 2, y - int(5 * s)), (x - w // 2, y - h + 2)], 1, v)
    b.line([(x + w // 2, y - int(5 * s)), (x + w // 2, y - h + 2)], 1, v)
    b.line([(x - w // 2, y - h + 2), (x + w // 2, y - h + 2)], 1, v)
    if glow:
        b.sparks(x, y - h // 2 - 2, 8, w + 7, v)


def horn(b, x, y, face=1, s=1.0, v=1):
    """A recording horn; its small end at x,y."""
    l, r = int(24 * s), int(11 * s)
    b.poly([(x, y - 2), (x + face * l, y - r), (x + face * l, y + r), (x, y + 2)], 1 - v, v)
    b.line([(x + face * (l - 4), y - r + 2), (x + face * (l - 4), y + r - 2)], 1, v)
    b.line([(x + face * l // 2, y - r // 2), (x + face * l // 2, y + r // 2)], 1, v)


def machine(b, x0, y1, w, h, v=1, antennae=True, sparks=True):
    """A Vantry-grade set: forty years early and much too good for the room."""
    b.rect(x0, y1 - h, x0 + w, y1, v)
    for i in range(max(2, w // 12)):
        dx = x0 + 6 + i * 11
        b.disc(dx, y1 - h + 7, 3, 1 - v)
        b.line([(dx, y1 - h + 7), (dx + 2, y1 - h + 5)], 1, v)
    b.rect(x0 + 4, y1 - h + 14, x0 + w - 4, y1 - h + 19, 1 - v)
    for gx in range(x0 + 6, x0 + w - 4, 3):
        b.line([(gx, y1 - h + 15), (gx, y1 - h + 18)], 1, v)
    if h > 28:
        for gy in range(y1 - h + 23, y1 - 3, 3):
            b.line([(x0 + 4, gy), (x0 + w - 4, gy)], 1, 1 - v)
    if antennae:
        b.line([(x0 + 4, y1 - h), (x0 - 2, y1 - h - 12)], 1, v)
        b.line([(x0 + w - 4, y1 - h), (x0 + w + 2, y1 - h - 12)], 1, v)
    if sparks:
        b.sparks(x0 + w // 2, y1 - h - 8, 7, 8, v)


def cabinet(b, x0, y1, w=26, h=32, with_horn=True):
    b.rect(x0, y1 - h, x0 + w, y1, 1)
    b.rect(x0 + 3, y1 - h + 3, x0 + w - 3, y1 - h // 2, 0, 1)
    for gx in range(x0 + 6, x0 + w - 4, 3):
        b.line([(gx, y1 - h + 4), (gx, y1 - h // 2 - 1)], 1)
    b.disc(x0 + w // 2, y1 - 8, 3, 0, 1)
    if with_horn:
        horn(b, x0 + w // 2, y1 - h - 3, 1, .55)


def mast(b, x, top, foot, w=9, v=1):
    b.line([(x - w, foot), (x, top)], 1, v)
    b.line([(x + w, foot), (x, top)], 1, v)
    y, flip = foot, 1
    while y > top + 4:
        t = (y - top) / (foot - top)
        n = top + (y - top) - 9
        tn = max(0, (n - top) / (foot - top))
        b.line([(x - w * t * flip, y), (x + w * tn * flip, n)], 1, v)
        b.line([(x - w * t, y), (x + w * t, y)], 1, v)
        y, flip = n, -flip
    b.sparks(x, top, 6, 5, v)


def drawers(b, x0, y0, x1, y1, cols=7, rows=8):
    b.rect(x0, y0, x1, y1, 1)
    cw, ch = (x1 - x0) / cols, (y1 - y0) / rows
    for c in range(cols):
        for r in range(rows):
            px, py = int(x0 + c * cw + 1), int(y0 + r * ch + 1)
            b.rect(px, py, int(px + cw - 2), int(py + ch - 2), 0)
            b.dot(int(px + cw / 2 - 1), int(py + ch / 2 - 1), 1)


def bed(b, x0, x1, y=68, foot=84):
    b.rect(x0, y, x1, y + 5, 1)
    b.line([(x0 + 2, y - 10), (x0 + 2, foot)], 2)
    b.line([(x1 - 2, y - 4), (x1 - 2, foot)], 2)


def ladder(b, x, top, foot=84, w=9):
    b.line([(x, foot), (x + 6, top)], 2)
    b.line([(x + w, foot), (x + w + 6, top)], 2)
    for y in range(top + 4, foot, 7):
        t = (foot - y) / (foot - top)
        b.line([(x + 6 * t, y), (x + w + 6 * t, y)], 1)


def fire_helmet(b, x, y, r=7):
    b.d.pieslice((x - r, y - r - 4, x + r, y + r - 4), 180, 360, fill=1)
    b.line([(x - r - 3, y - 4), (x + r + 3, y - 4)], 2)
    b.line([(x, y - r - 4), (x, y - 5)], 1, 0)


# --- for sale in the Arcade today -----------------------------------------------------
@scene
def carbon_capsule(b):
    b.wall()
    b.ground()
    drawers(b, 58, 8, 122, 84, 8, 10)
    ladder(b, 30, 24)
    b.man(38, 46, 26, 1, "cap", "smile", r=5, arms=[(12, -9)], tie=False, coat=0)
    b.disc(52, 21, 2, 0, 1)
    b.sparks(52, 21, 6, 6)


@scene
def rubber_protectant(b):
    b.ground()
    b.rect(68, 10, 122, 84, 1)
    b.rect(78, 22, 108, 60, 0, 1)
    for x, y, r in ((86, 58, 6), (96, 52, 9), (106, 58, 5)):
        b.poly([(x - r, 60), (x, y - r - 8), (x + r, 60)], 1)
    b.man(32, 84, 54, 1, None, "smile", stache=True, arms=[(16, 13)], r=8)
    fire_helmet(b, 32, 37, 8)
    b.line([(4, 80), (64, 80)], 3)
    b.rect(44, 76, 52, 83, 0, 1)
    b.line([(48, 62), (48, 76)], 1)


@scene
def hose_gasket(b):
    b.ground()
    b.line([(4, 72), (40, 72)], 4)
    b.line([(46, 72), (66, 72)], 4)
    b.rect(39, 69, 47, 75, 0, 1)
    for i in range(6):
        b.line([(43, 68), (58 + i * 7, 14 + i * 7)], 1)
        b.line([(43, 68), (60 + i * 7, 28 + i * 6)], 1)
    b.man(92, 84, 52, -1, None, "frown", eyes="shut", stache=True, arms=[(-3, 12)], r=8)
    fire_helmet(b, 92, 40, 8)
    for x, y in ((80, 54), (104, 60), (72, 40), (110, 44)):
        b.dot(x, y)
    b.d.ellipse((54, 80, 59, 83), fill=0, outline=0)
    b.d.ellipse((56, 78, 62, 83), outline=0)


@scene
def household_sundries(b):
    b.wall()
    b.ground()
    b.table(84, 120, 62)
    b.rect(94, 52, 108, 62, 0, 1)
    x, y, n = b.man(48, 84, 56, 1, None, "o", eyes="wide", arms=[(16, -2)], r=10)
    b.d.ellipse((x - 2, y - 8, x + 12, y + 1), fill=1)
    b.disc(x + 4, y - 3, 2, 0)
    b.disc(x + 9, y - 3, 2, 0)
    b.line([(62, 50), (72, 46)], 1)
    b.sparks(74, 44, 8, 9)


@scene
def silk_flex(b):
    b.ground()
    b.rect(90, 66, 118, 84, 0, 1)
    b.line([(90, 66), (118, 84)], 1)
    b.line([(118, 66), (90, 84)], 1)
    b.man(40, 84, 54, 1, None, "grin", stache=True, arms=[(16, -10), (20, -4)], coat=0, tie=False)
    pts = [(58 + i * 4, 28 + (i % 2) * 5) for i in range(11)]
    b.line(pts, 3)
    b.line(pts, 1, 0)
    b.man(104, 66, 36, -1, "top", "flat", r=6, tie=False)


@scene
def valve_sleeve_hardware(b):
    b.wall()
    b.ground()
    b.rect(80, 12, 124, 84, 1)
    for ex, ey in ((90, 26), (108, 22), (96, 44), (114, 52), (88, 62)):
        b.disc(ex, ey, 1, 0)
        b.disc(ex + 5, ey, 1, 0)
    b.rect(10, 78, 62, 84, 1)
    x, y, n = b.man(36, 78, 54, 1, "bowler", "flat", eyes="wide", r=8, arms=[(-8, 12), (8, 12)])
    for i in range(6):
        b.d.ellipse((25 + i * 4, 48, 28 + i * 4, 58), fill=0, outline=1)


@scene
def key_spare(b):
    b.wall()
    b.ground()
    b.man(84, 84, 66, -1, "bowler", "flat", stache=True, arms=[(-14, 12), (-14, -6)], r=9, belly=6)
    b.rect(58, 28, 67, 44, 0, 1)
    b.line([(70, 66), (58, 66)], 3)
    b.d.ellipse((46, 60, 58, 72), outline=1)
    b.table(4, 44, 66)
    b.disc(18, 58, 7, 0, 1)
    b.sparks(18, 58, 6, 12)
    b.man(28, 66, 26, 1, "cap", "frown", r=5, tie=False, arms=[(14, -13)])


@scene
def key_board(b):
    b.ground()
    b.rect(30, 6, 124, 62, 1)
    for x in range(34, 122, 6):
        for y in range(10, 60, 10):
            b.d.ellipse((x, y, x + 2, y + 2), outline=0)
            b.line([(x + 1, y + 3), (x + 1, y + 7)], 1, 0)
    b.man(70, 84, 44, 1, "bowler", "o", eyes="wide", legs="tiptoe", arms=[(9, -13)], r=7)
    b.d.ellipse((66, 39, 71, 44), outline=1, fill=0)
    b.line([(70, 42), (75, 37)], 1)
    b.lines_of_motion(70, 34, 1, 0, 0)


@scene
def record_rack(b):
    b.ground()
    b.rect(52, 28, 92, 60, 0, 1)
    for y in range(32, 58, 4):
        b.line([(55, y), (88, y)], 1)
    b.man(32, 84, 56, 1, "top", "flat", stache=True, arms=[(20, 3)], r=8)
    b.rect(96, 36, 118, 56, 1)
    b.poly([(92, 30), (103, 36), (108, 44), (92, 48)], 1)
    b.line([(106, 56), (106, 84)], 3)
    b.line([(116, 56), (116, 84)], 3)
    b.line([(118, 40), (124, 58)], 2)
    b.poly([(96, 26), (102, 18), (106, 30)], 1)
    b.dot(100, 40, 0)


@scene
def speaker_rack(b):
    b.ground()
    b.rect(84, 34, 124, 38, 1)
    b.rect(88, 38, 92, 84, 1)
    for i, (x, y) in enumerate(((98, 28), (108, 24), (118, 28))):
        b.disc(x, y, 4, 1)
        b.line([(x - 4, y), (x + 6 + i, y - 8)], 2)
    b.man(24, 84, 46, 1, None, "o", eyes="shut", arms=[(10, 8)], r=8, coat=0, tie=False)
    b.rect(8, 8, 20, 12, 1)
    b.line([(24, 22), (16, 14)], 1)
    for r in (8, 14, 20, 26):
        b.d.arc((40 - r, 42 - r, 40 + r, 42 + r), -50, 50, fill=1)


@scene
def quell_tonic(b):
    b.wall()
    b.ground()
    x, y, _ = b.man(30, 84, 52, 1, None, "o", eyes="wide", stache=True, arms=[(14, -8)], r=9)
    b.puffs(x + 8, y - 8, 3, 3, -5)
    b.puffs(x - 8, y - 8, 3, -3, -5)
    b.bottle(50, 44, .3)
    b.rect(76, 80, 112, 84, 0, 1)
    b.man(94, 80, 52, -1, None, "smile", eyes="shut", stache=True, arms=[(-3, 11), (3, 11)], r=9, coat=0, tie=False)


@scene
def chocolate_bar(b):
    b.hatch([(3, 3), (W - 4, 3), (W - 4, H - 4), (3, H - 4)], 72, 7)
    b.ground()
    b.man(66, 84, 58, -1, "bowler", "smile", arms=[(-10, 2)], belly=10, r=9)
    b.rect(62, 6, 66, 84, 0, 1)
    b.rect(50, 6, 80, 14, 0, 1)
    b.rect(50, 42, 57, 50, 0, 1)
    b.line([(50, 46), (57, 46)], 1)


@scene
def bodega_eggs(b):
    b.wall()
    b.ground()
    b.rect(30, 62, 98, 66, 1)
    b.line([(64, 62), (64, 26)], 2)
    b.line([(36, 28), (92, 28)], 2)
    b.line([(36, 28), (30, 46)], 1)
    b.line([(36, 28), (44, 46)], 1)
    b.line([(92, 28), (84, 46)], 1)
    b.line([(92, 28), (100, 46)], 1)
    b.rect(28, 46, 46, 48, 1)
    b.rect(82, 46, 102, 48, 1)
    b.d.ellipse((32, 37, 42, 46), fill=0, outline=1)
    valve(b, 92, 46, .55, 1, True)
    b.man(112, 84, 42, -1, None, "flat", stache=True, r=7, coat=0, tie=False, arms=[(-8, 2)])


@scene
def rat_trap_cheddar(b):
    b.wall()
    b.ground()
    b.table(28, 104, 54)
    b.disc(46, 36, 8, 1, ry=9)
    b.disc(46, 22, 7, 1)
    b.poly([(40, 17), (37, 9), (44, 15)], 1)
    b.poly([(50, 15), (55, 9), (52, 18)], 1)
    b.dot(50, 21, 0)
    b.line([(54, 24), (58, 24)], 1)
    b.poly([(44, 29), (48, 29), (46, 40)], 0)
    b.line([(36, 40), (18, 46)], 1)
    b.line([(54, 36), (68, 46)], 2)
    b.rect(66, 49, 98, 53, 1)
    b.line([(70, 50), (96, 38)], 2)
    b.poly([(76, 49), (92, 49), (92, 39)], 0, 1)
    b.dot(86, 45)


@scene
def harukiya_shoyu(b):
    b.night()
    b.rect(74, 14, 118, 84, 0)
    b.rect(78, 18, 114, 84, 1)
    b.disc(108, 50, 2, 0)
    b.disc(96, 8, 5, 0)
    b.line([(4, 84), (W - 5, 84)], 1, 0)
    x, y, n = b.man(38, 84, 54, 1, None, "flat", eyes="shut", coat=0, tie=False, arms=[(14, -3), (12, -14)])
    b.bottle(52, 40, .35, 0)
    b.line([(50, 34), (46, 28)], 2, 0)


@scene
def peerless_lager(b):
    b.wall()
    b.ground()
    b.rect(58, 56, 124, 84, 1)
    b.rect(58, 54, 124, 56, 1)
    b.bottle(106, 54, .4)
    b.man(38, 84, 54, 1, None, "grin", eyes="shut", stache=True, legs="wide", arms=[(22, 2), (6, -18)], r=8)
    b.rect(26, 26, 40, 34, 1)
    b.line([(24, 34), (44, 34)], 2)
    b.bottle(44, 28, .35)


@scene
def fall_river_sausage(b):
    b.ground()
    b.dog(92, 84, 1)
    pts = [(80 - i * 7, 76 + (i % 2) * 2) for i in range(10)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        b.d.ellipse((min(x0, x1), y0 - 2, max(x0, x1), y0 + 3), fill=1)
    b.man(18, 84, 42, 1, "cap", "o", eyes="wide", arms=[(14, 8)], legs="run", coat=0, tie=False, r=7)
    b.lines_of_motion(106, 64, 3, 0, 4)


@scene
def yesterdays_rolls(b):
    b.wall()
    b.rect(3, 60, W - 4, H - 4, 1)
    b.man(30, 60, 42, 1, "bowler", "frown", arms=[(22, 0)], r=7)
    b.disc(55, 54, 6, 0, 1, ry=5)
    b.poly([(46, 60), (64, 60), (55, 66)], 0)
    b.sparks(55, 56, 7, 12)
    b.man(98, 60, 42, -1, None, "smile", eyes="shut", arms=[(-10, 4)], r=7, coat=0, tie=False)
    b.rect(84, 48, 88, 54, 0, 1)


@scene
def luncheonette_cabinets(b):
    b.wall()
    b.rect(3, 64, W - 4, 67, 1)
    b.line([(12, 67), (12, 84)], 2)
    b.line([(70, 67), (70, 84)], 2)
    b.ground()
    b.rect(26, 72, 38, 74, 1)
    b.line([(32, 74), (32, 84)], 2)
    b.man(32, 72, 34, 1, "bowler", "smile", arms=[(12, -1)], r=7, legs="sit")
    b.d.ellipse((46, 60, 58, 64), fill=0, outline=1)
    machine(b, 78, 84, 44, 66)


@scene
def luncheonette_soda(b):
    b.wall()
    b.rect(3, 62, W - 4, H - 4, 1)
    b.rect(14, 44, 22, 62, 0, 1)
    b.line([(14, 46), (28, 40)], 2)
    b.man(72, 38, 30, -1, "boater", "o", eyes="wide", legs="sit", arms=[(-8, -5), (8, -5)], r=6, tie=False, belly=5)
    b.bubbles([(56, 44, 2), (62, 50, 3), (48, 36, 3), (70, 46, 2), (40, 28, 2), (84, 44, 2), (30, 34, 3),
               (66, 56, 2), (92, 28, 3), (100, 16, 2)])
    b.line([(71, 40), (71, 60)], 2)
    b.rect(66, 58, 76, 62, 0, 1)


@scene
def otis_soda(b):
    for y, n in ((10, 13), (34, 13)):
        b.rect(3, y + 18, W - 4, y + 20, 1)
        for i in range(n):
            x = 10 + i * 9
            b.rect(x - 3, y + 4, x + 3, y + 18, 1)
            b.rect(x - 1, y, x + 1, y + 4, 1)
            b.disc(x, y + 11, 2, 0)
            b.dot(x, y + 11, 1)
    b.ground()
    b.man(60, 84, 34, 1, "boater", "smile", legs="sit", r=6, arms=[(12, -2)], tie=False)
    b.rect(76, 52, 82, 66, 0, 1)
    b.line([(78, 52), (70, 44)], 1)
    b.rect(50, 74, 64, 76, 1)
    b.line([(57, 76), (57, 84)], 2)


@scene
def otis_spices(b):
    b.wall()
    b.ground()
    bed(b, 8, 84, 62)
    b.head(22, 54, 8, 1, "frown", None, eyes="shut")
    b.poly([(28, 60), (82, 60), (82, 64), (28, 64)], 0, 1)
    b.poly([(14, 46), (32, 44), (22, 49)], 1)
    b.line([(15, 46), (31, 44)], 1, 0)
    b.man(44, 58, 30, 1, None, "flat", specs=True, r=5, coat=0, tie=False, arms=[(-9, -3)])
    b.table(92, 122, 60)
    b.rect(100, 46, 114, 60, 1)
    b.line([(98, 46), (116, 46)], 2)
    b.puffs(107, 42, 3, 2, -8)


@scene
def otis_cuts(b):
    b.wall()
    b.ground()
    bed(b, 6, 78, 64)
    b.poly([(28, 60), (76, 60), (76, 64), (28, 64)], 0, 1)
    x, y, n = b.man(24, 66, 32, 1, None, "o", specs=True, r=7, arms=[(12, -3)], tie=False, coat=0)
    horn(b, 38, 46, 1, .75)
    b.rect(32, 41, 38, 44, 0, 1)
    b.disc(34, 47, 2, 0, 1)
    b.man(102, 84, 52, -1, "top", "flat", stache=True, arms=[(-10, -7), (10, -7)], r=8)


@scene
def photograph_occasion(b):
    b.wall()
    b.ground()
    b.rect(102, 40, 120, 52, 1)
    b.rect(96, 42, 102, 50, 1)
    b.line([(106, 52), (100, 84)], 1)
    b.line([(116, 52), (122, 84)], 1)
    b.man(14, 84, 50, 1, None, "flat", stache=True, arms=[(3, 11)], r=7)
    b.woman(34, 84, 46, 1, None, "flat", r=7)
    b.man(50, 84, 30, 1, None, "flat", r=5, tie=False)
    b.rect(62, 44, 86, 58, 1)
    b.line([(66, 58), (66, 84)], 3)
    b.line([(82, 58), (82, 84)], 3)
    b.poly([(84, 46), (92, 32), (96, 34), (90, 50)], 1)
    b.dot(91, 37, 0)


@scene
def radio_bench(b):
    b.night()
    b.line([(4, 84), (W - 5, 84)], 1, 0)
    b.rect(8, 72, 72, 74, 0)
    b.rect(62, 62, 66, 72, 0)
    b.disc(64, 58, 2, 0)
    b.sparks(64, 58, 6, 6, 0)
    b.man(38, 84, 46, 1, None, "flat", specs=True, coat=0, tie=False, r=7, arms=[(18, -4)])
    machine(b, 76, 84, 44, 56, 0)


@scene
def unredeemed_shelf(b):
    b.rect(3, 3, W - 4, 84, 1)
    for y in (22, 42, 62):
        b.rect(3, y, W - 4, y + 1, 0)
    b.r.seed(7)
    for y in (22, 42, 62):
        for x in range(10, 120, 16):
            k = b.r.randint(0, 3)
            if k == 0:
                b.rect(x - 4, y - 12, x + 4, y - 1, 0)
            elif k == 1:
                b.disc(x, y - 7, 6, 0)
            elif k == 2:
                b.poly([(x - 5, y - 1), (x + 5, y - 1), (x, y - 14)], 0)
            else:
                b.rect(x - 2, y - 14, x + 2, y - 1, 0)
            b.line([(x + 5, y - 13), (x + 8, y - 5)], 1, 0)
    b.line([(3, 84), (W - 4, 84)], 2)
    b.rect(52, 62, 76, 84, 1)
    b.man(64, 84, 22, -1, None, "flat", r=4, coat=0, tie=False, arms=[(3, -8)])
    b.rect(65, 62, 70, 66, 0, 1)


@scene
def pawn_used_valves(b):
    b.ground()
    for _ in range(28):
        x, y = b.r.randint(5, W - 6), b.r.randint(5, 80)
        b.dot(x, y)
        b.dot(x + 1, y)
    b.man(52, 84, 54, 1, None, "smile", coat=0, tie=False, arms=[(12, 7), (8, 8)], r=8)
    valve(b, 68, 62, .8, 1, True)
    for x in (36, 38, 40):
        b.line([(x, 44), (x - 3, 50)], 1)


@scene
def gas_mantle_shortage(b):
    b.wall()
    b.ground()
    drawers(b, 74, 8, 124, 84, 6, 9)
    b.man(52, 84, 54, -1, None, "frown", stache=True, coat=0, tie=False, arms=[(-14, 11), (14, 11)], r=8)
    b.rect(36, 60, 42, 70, 0, 1)
    b.man(14, 84, 44, 1, "bowler", "o", arms=[(12, -6)], r=7)
    b.line([(26, 48), (26, 32)], 2)
    b.d.ellipse((22, 24, 30, 33), outline=1)
    for x, y in ((24, 32), (26, 31), (28, 32), (27, 30)):
        b.dot(x, y)


@scene
def contact_mic(b):
    b.night()
    b.line([(4, 84), (W - 5, 84)], 1, 0)
    b.rect(60, 6, 66, 70, 0)
    b.rect(60, 62, 124, 68, 0)
    x, y = 26, 74
    b.poly([(10, 68), (54, 68), (58, 82), (10, 82)], 0)
    b.head(26, 62, 8, 1, "smile", None, eyes="shut")
    b.d.arc((17, 52, 35, 70), 180, 360, fill=1)
    b.line([(36, 58), (62, 44)], 1, 0)
    b.rect(58, 40, 68, 46, 0, 1)
    b.disc(84, 76, 11, 0, ry=7)
    b.disc(72, 74, 5, 0)
    b.poly([(70, 68), (72, 62), (75, 69)], 0)
    b.dot(70, 73, 1)
    b.line([(95, 78), (114, 72)], 1, 0)


@scene
def model_laundry_tickets(b):
    b.ground()
    b.rect(50, 4, 124, 84, 1)
    for y in range(8, 82, 12):
        for x in range(54 + (y // 12 % 2) * 6, 120, 12):
            b.rect(x, y, x + 9, y + 9, 0)
            b.line([(x + 4, y), (x + 4, y + 9)], 1)
            b.line([(x, y + 4), (x + 9, y + 4)], 1)
    ladder(b, 50, 16)
    b.man(32, 84, 40, 1, None, "frown", eyes="shut", coat=0, tie=False, r=6, arms=[(9, -6)])
    b.poly([(25, 50), (39, 50), (34, 76), (29, 76)], 1)
    b.line([(25, 52), (39, 52)], 1, 0)
    b.rect(40, 36, 46, 44, 0, 1)
    b.man(68, 40, 24, -1, "cap", "smile", r=5, tie=False, arms=[(-8, 8)])


@scene
def shoe_machine(b):
    b.ground()
    b.rect(4, 30, 42, 84, 1)
    b.rect(8, 40, 36, 66, 0, 1)
    b.disc(16, 52, 8, 1)
    b.disc(16, 52, 3, 0)
    b.line([(16, 44), (32, 42)], 1)
    b.line([(16, 60), (32, 62)], 1)
    b.rect(26, 48, 36, 56, 1)
    for x, y, r in ((50, 50, 7), (62, 40, 9), (76, 44, 11), (94, 36, 13), (112, 42, 11)):
        b.disc(x, y, r, 0, 1)
    for x, f in ((62, 1), (98, -1)):
        xx, yy, _ = b.man(x, 84, 44, f, "bowler", "frown", eyes="shut", arms=[(f * 9, -8)], r=7)
    b.bubbles([(44, 58, 2), (56, 60, 1), (84, 56, 2), (112, 60, 2)])


@scene
def funeral_chairs(b):
    b.wall()
    b.ground()
    for row, y in enumerate((60, 68, 76, 84)):
        for x in range(14 + row * 3, 96, 14):
            b.line([(x, y - 14), (x, y)], 1)
            b.line([(x, y - 7), (x + 7, y - 7)], 1)
            b.line([(x + 7, y - 7), (x + 7, y)], 1)
    b.rect(100, 54, 124, 58, 1)
    b.line([(104, 58), (104, 72)], 2)
    b.line([(120, 58), (120, 72)], 2)
    b.man(44, 60, 30, 1, "top", "flat", r=5, legs="sit", arms=[(9, -3)])
    b.disc(55, 37, 2, 0, 1)


# --- the world that got very good at listening ----------------------------------------
@scene
def dictation_machine(b):
    b.line([(3, 66), (W - 4, 66)], 1)
    b.ground()
    for x, y in ((12, 40), (24, 22), (108, 34), (64, 14), (40, 48)):
        b.dot(x, y)
        b.dot(x + 1, y + 1)
    bed(b, 6, 56, 62)
    x, y, n = b.man(20, 62, 32, 1, "cap", "o", r=7, tie=False, arms=[(12, -2)])
    b.line([(29, 30), (30, 38)], 1)
    b.line([(12, 34), (28, 34)], 2)
    machine(b, 66, 66, 34, 30, 1, False, True)
    pts = [(100, 44), (108, 40), (116, 50), (106, 62), (118, 74), (92, 80), (70, 76)]
    b.line(pts, 3)
    b.line(pts, 1, 0)
    horn(b, 44, 52, 1, .45)


@scene
def answering_cabinet(b):
    b.hatch([(3, 3), (40, 3), (40, H - 4), (3, H - 4)], 72, 6)
    b.rect(40, 3, 43, 84, 1)
    b.ground()
    b.man(20, 84, 50, 1, "bowler", "frown", arms=[(6, 12)], r=7)
    b.rect(24, 72, 36, 82, 0, 1)
    cabinet(b, 56, 84, 24, 34)
    b.chair(100, 84, -1)
    b.woman(100, 72, 40, -1, None, "smile", arms=[(-10, -2)], r=7, eyes="shut")
    b.line([(92, 62), (84, 58)], 3)


@scene
def iceman_vs_cabinet(b):
    b.ground()
    mast(b, 92, 4, 84, 16)
    b.man(38, 84, 50, 1, "cap", "frown", eyes="shut", arms=[(14, 2)], r=7, tie=False)
    b.rect(48, 58, 64, 72, 0, 1)
    b.line([(50, 58), (60, 72)], 1)
    b.line([(46, 62), (52, 58)], 2)
    b.rect(6, 54, 22, 68, 1)
    b.line([(8, 68), (8, 84)], 2)
    b.line([(20, 68), (20, 84)], 2)
    b.poly([(4, 56), (2, 38), (14, 40), (14, 56)], 1)
    b.dot(7, 44, 0)


@scene
def newark_long_life(b):
    b.ground()
    b.rect(90, 8, 124, 84, 1)
    b.rect(98, 44, 118, 84, 0)
    for x in (94, 104, 114):
        b.rect(x, 2, x + 4, 8, 1)
    b.d.ellipse((12, 34, 80, 56), fill=0, outline=1)
    b.rect(78, 40, 90, 50, 1)
    b.line([(22, 39), (22, 52)], 1)
    b.line([(66, 39), (66, 52)], 1)
    b.line([(22, 45), (66, 45)], 1)
    b.sparks(46, 45, 8, 8)
    for x in (16, 30, 44, 58, 72):
        b.man(x, 84, 28, 1, "cap", "frown", r=4, tie=False, eyes="shut", arms=[(0, -9)])


@scene
def newark_answering_doll(b):
    b.night()
    b.rect(4, 62, 60, 68, 0)
    b.line([(8, 68), (8, 84)], 2, 0)
    b.line([(56, 68), (56, 84)], 2, 0)
    b.line([(8, 62), (8, 50)], 2, 0)
    b.disc(38, 52, 6, 0)
    b.rect(34, 57, 42, 62, 0)
    b.dot(40, 51, 1)
    b.rect(38, 53, 41, 54, 1)
    b.line([(4, 84), (W - 5, 84)], 1, 0)
    x, y, n = b.man(92, 84, 58, -1, None, "o", eyes="wide", coat=0, tie=False, legs="tiptoe", arms=[(14, -15)], r=8)
    b.poly([(83, 34), (101, 34), (94, 16), (106, 20), (101, 34)], 0)
    b.rect(104, 28, 108, 36, 0)
    b.disc(106, 25, 1, 0)
    b.sparks(106, 24, 6, 6, 0)


@scene
def licence_plate(b):
    b.ground()
    b.poly([(46, 36), (84, 12), (122, 36)], 1)
    b.rect(50, 36, 118, 84, 0, 1)
    b.rect(68, 40, 104, 84, 1)
    b.rect(71, 43, 101, 81, 0, 1)
    for x, y in ((73, 45), (98, 45), (73, 78), (98, 78)):
        b.disc(x, y, 1, 1)
    b.head(86, 60, 5, -1, "o", None, eyes="wide")
    b.man(34, 84, 50, 1, "cap", "grin", arms=[(30, -10)], r=7, tie=False, coat=0)
    b.sparks(66, 42, 5, 7)


@scene
def consent_book(b):
    b.wall()
    b.ground()
    bed(b, 34, 112, 62)
    b.poly([(48, 56), (108, 56), (110, 62), (46, 62)], 0, 1)
    b.woman(50, 62, 26, 1, None, "smile", r=6)
    b.rect(58, 42, 68, 54, 0, 1)
    b.man(16, 84, 50, 1, None, "frown", stache=True, coat=0, tie=False, arms=[(14, 8)], r=7)
    b.rect(28, 52, 38, 66, 0, 1)
    for y in (56, 60):
        b.line([(30, y), (36, y)], 1)
    b.disc(92, 46, 7, 1, ry=8)
    b.disc(92, 34, 5, 1)
    b.poly([(88, 30), (87, 24), (92, 29)], 1)
    b.poly([(96, 30), (98, 24), (93, 29)], 1)
    b.dot(90, 33, 0)
    b.dot(94, 33, 0)
    b.line([(84, 48), (40, 58)], 1)


@scene
def wire_insurance(b):
    b.hatch([(3, 62), (W - 4, 62), (W - 4, H - 4), (3, H - 4)], 0, 2, 1, 1)
    b.rect(70, 3, 78, 62, 1)
    for i in range(5):
        b.line([(74, 26), (92 + i * 6, 10 + i * 12)], 1)
    b.man(40, 84, 54, 1, "bowler", "flat", specs=True, arms=[(24, -14), (12, 2)], r=8)
    b.rect(3, 65, W - 4, H - 4, 0)
    b.hatch([(3, 62), (W - 4, 62), (W - 4, H - 4), (3, H - 4)], 0, 2, 1, 1)
    b.rect(50, 44, 58, 54, 0, 1)
    b.line([(58, 32), (70, 32)], 1)


@scene
def parlour_system(b):
    b.wall()
    b.ground()
    b.rect(90, 44, 122, 84, 1)
    b.disc(106, 62, 6, 0)
    horn(b, 96, 34, -1, 1.0)
    pts = [(70, 24), (58, 32), (64, 36), (50, 40), (58, 46), (42, 48)]
    b.line(pts, 3)
    b.man(30, 84, 52, 1, None, "grin", stache=True, arms=[(26, -12)], r=8)
    b.rect(14, 12, 28, 20, 1)
    b.line([(10, 20), (32, 20)], 2)
    b.lines_of_motion(24, 26, 2, 0, 3)


@scene
def listening_chair(b):
    b.wall()
    b.ground()
    b.rect(34, 18, 94, 78, 1)
    b.d.pieslice((22, 12, 58, 58), 90, 270, fill=1)
    b.d.pieslice((70, 12, 106, 58), 270, 90, fill=1)
    b.rect(48, 26, 80, 62, 0)
    b.head(64, 40, 9, 1, "smile", None, eyes="shut")
    b.d.ellipse((46, 33, 52, 46), fill=0, outline=1)
    b.d.ellipse((76, 33, 82, 46), fill=0, outline=1)
    b.rect(54, 50, 74, 62, 1)
    b.line([(38, 78), (38, 84)], 3)
    b.line([(90, 78), (90, 84)], 3)
    pts = [(66, 78), (72, 72), (60, 68), (72, 64), (58, 60)]
    b.line(pts, 1, 0)
    b.disc(58, 60, 2, 0, 1)


@scene
def etiquette_manual(b):
    b.wall()
    b.ground()
    b.line([(4, 36), (W - 5, 36)], 3)
    for i, x in enumerate(range(14, 116, 20)):
        b.rect(x - 6, 72, x + 6, 74, 1)
        b.line([(x, 74), (x, 84)], 2)
        b.man(x, 72, 36, 1, "bowler", "flat", legs="sit", r=6, tie=False, eyes="shut" if i != 3 else "wide",
              arms=[(0, -6)] if i != 3 else [(9, -13)])
        b.disc(x + 3, 37, 3, 0, 1)


@scene
def portable_battery(b):
    b.line([(3, 84), (60, 84), (118, 40)], 2)
    b.hatch([(3, 85), (60, 85), (W - 4, 42), (W - 4, H - 4), (3, H - 4)], 12, 3)
    b.rect(28, 40, 64, 76, 1)
    b.line([(28, 58), (64, 58)], 1, 0)
    b.line([(46, 40), (46, 76)], 1, 0)
    b.line([(62, 76), (24, 84)], 2)
    b.disc(62, 80, 3, 0, 1)
    b.rect(38, 30, 54, 40, 0, 1)
    b.disc(43, 35, 2, 1)
    b.line([(50, 30), (56, 22)], 1)
    b.man(14, 84, 36, 1, "cap", "frown", eyes="shut", r=6, tie=False, arms=[(14, 4)], legs="run")
    b.man(114, 40, 24, -1, "boater", "smile", legs="sit", r=4, tie=False)
    b.rect(96, 42, 102, 46, 0, 1)


@scene
def vantry_parts(b):
    b.night()
    b.rect(60, 8, 124, 84, 0)
    machine(b, 64, 82, 56, 70, 1, False, False)
    for x0, y0, x1, y1 in ((60, 8, 88, 22), (124, 8, 100, 24), (72, 8, 66, 30)):
        b.line([(x0, y0), (x1, y1)], 1, 0)
    b.line([(4, 84), (W - 5, 84)], 1, 0)
    b.man(30, 84, 52, 1, None, "o", specs=True, coat=0, tie=False, arms=[(20, -14)], r=8)
    b.d.ellipse((46, 26, 58, 38), outline=0)
    b.dot(52, 32, 0)
    b.line([(46, 38), (40, 44)], 1, 0)


@scene
def second_hand_set(b):
    b.wall()
    b.ground()
    machine(b, 44, 84, 46, 50)
    pts = [(82, 30), (92, 22), (88, 30), (106, 18), (102, 26), (118, 14)]
    b.line(pts, 2)
    b.man(26, 84, 52, 1, None, "grin", stache=True, arms=[(16, -2)], r=8)
    for x, y in ((6, 12), (16, 12), (11, 21)):
        b.disc(x, y, 4, 1)
    b.man(110, 84, 40, -1, "bowler", "o", eyes="wide", arms=[(-8, -11), (8, -11)], r=7, tie=False, coat=0)


@scene
def society_membership(b):
    b.wall()
    b.ground()
    b.table(26, 106, 62)
    b.d.ellipse((54, 52, 76, 62), fill=1)
    b.line([(64, 52), (66, 46)], 2)
    b.woman(14, 84, 44, 1, None, "flat", r=6)
    b.man(116, 84, 42, -1, None, "flat", eyes="shut", stache=True, r=6, tie=False)
    b.man(68, 62, 42, 1, "top", "smile", stache=True, r=6, arms=[(-14, -3)], tie=False)
    horn(b, 52, 34, -1, .7)
    b.dog(44, 84, -1)
    b.line([(32, 66), (28, 58)], 1)
    b.line([(36, 66), (30, 62)], 1)


@scene
def phonautograph_blanks(b):
    b.wall()
    b.ground()
    b.rect(64, 8, 118, 84, 1)
    b.rect(68, 12, 114, 80, 0)
    b.rect(90, 42, 100, 62, 0, 1)
    b.line([(92, 46), (98, 46)], 1)
    b.line([(92, 52), (98, 52)], 1)
    b.line([(92, 58), (98, 58)], 1)
    b.poly([(64, 8), (82, 14), (82, 90), (64, 84)], 1)
    b.disc(78, 50, 2, 0)
    for x in (14, 32, 50):
        b.man(x, 84, 50, 1, "top" if x == 32 else "bowler", "frown", eyes="shut", stache=True, arms=[(14, 0), (16, 8)], r=7)


@scene
def copper_capsule(b):
    b.rect(3, 62, 42, 84, 1)
    b.rect(86, 62, W - 4, 84, 1)
    b.ground(84)
    b.rect(42, 40, 86, 92, 0, 1)
    b.rect(44, 42, 84, 92, 1)
    b.rect(50, 42, 78, 92, 0, 1)
    b.man(64, 80, 44, 1, None, "o", stache=True, r=7, arms=[(-9, -9), (10, -9)])
    for y in (62, 72):
        b.line([(50, y), (78, y)], 1)
    b.woman(108, 62, 40, -1, "cloche", "smile", arms=[(-14, 2)], r=6)
    b.rect(76, 40, 94, 44, 0, 1)
    b.line([(14, 50), (28, 50)], 2)
    b.line([(21, 44), (21, 62)], 1)


@scene
def circle_tone_removed(b):
    b.wall()
    b.ground()
    b.table(4, 60, 62)
    b.disc(30, 56, 16, 1, ry=5)
    b.disc(30, 56, 4, 0, ry=2)
    b.man(92, 84, 54, -1, None, "flat", specs=True, coat=0, tie=False, r=8, arms=[(-22, -8)])
    b.line([(70, 54), (58, 40)], 2)
    b.line([(72, 52), (60, 38)], 1)
    pts = [(58, 40), (54, 34), (60, 30), (52, 26), (58, 20), (50, 16)]
    b.line(pts, 3)


@scene
def hum_felt(b):
    b.line([(3, 84), (W - 4, 84)], 2)
    b.hatch([(3, 85), (W - 4, 85), (W - 4, H - 4), (3, H - 4)], 8, 2)
    b.rect(48, 56, 118, 62, 1)
    b.line([(54, 62), (48, 78)], 3)
    b.line([(66, 62), (72, 78)], 3)
    b.line([(102, 62), (96, 78)], 3)
    b.line([(114, 62), (120, 78)], 3)
    b.line([(48, 40), (48, 62)], 2)
    b.head(62, 48, 7, 1, "o", None, eyes="wide")
    b.poly([(68, 50), (112, 50), (112, 56), (68, 56)], 0, 1)
    b.line([(70, 50), (78, 44)], 3)
    b.rect(14, 80, 26, 84, 0, 1)
    b.lines_of_motion(44, 64, 3, 12, 6)
    b.d.arc((36, 64, 48, 80), 120, 240, fill=1)


@scene
def hum_tuner(b):
    b.wall()
    b.ground()
    b.rect(38, 72, 62, 75, 1)
    b.line([(42, 75), (42, 84)], 2)
    b.line([(58, 75), (58, 84)], 2)
    b.man(50, 72, 44, 1, None, "o", eyes="wide", coat=0, tie=False, r=7, arms=[(14, -12), (-10, -8)])
    b.line([(66, 14), (66, 36)], 2)
    b.line([(62, 6), (62, 16), (70, 16), (70, 6)], 2)
    for x, y in ((12, 22), (88, 24), (108, 40), (92, 56)):
        p = [(x - 8, y - 4), (x + 8, y - 8), (x + 10, y + 4), (x - 6, y + 8)]
        b.poly(p, 0, 1)
        b.d.ellipse((x - 2, y - 3, x + 4, y + 3), outline=1)
    b.sparks(66, 8, 7, 11)


@scene
def earplugs_for_all(b):
    b.wall(60)
    b.ground()
    x, y, n = b.man(64, 84, 54, 1, None, "smile", eyes="shut", coat=0, tie=False, r=12)
    b.disc(52, y + 1, 4, 1)
    b.disc(76, y + 1, 4, 1)
    for mx, f in ((16, 1), (34, 1), (94, 1), (112, 1)):
        b.man(mx, 84, 34, f, "cap", "o", r=5, tie=False, arms=[(8, -7)], legs="run")
    horn(b, 44, 60, 1, .4)
    horn(b, 104, 60, 1, .45)
    b.d.ellipse((6, 44, 22, 62), outline=1)
    b.line([(14, 44), (14, 62)], 1)
    for i in range(3):
        b.line([(86 + i * 7, 26 - i * 4), (92 + i * 7, 22 - i * 4)], 2)
        b.disc(86 + i * 7, 27 - i * 4, 2, 1)


@scene
def home_cycle_meter(b):
    b.night()
    for x, y in ((14, 14), (40, 8), (96, 12), (116, 28), (60, 18)):
        b.dot(x, y, 0)
    b.poly([(3, 84), (3, 70), (70, 62), (W - 4, 72), (W - 4, 84)], 0)
    b.man(48, 72, 48, 1, "top", "o", stache=True, coat=1, arms=[(22, -6)], r=8)
    b.d.line([(0, 0), (0, 0)], fill=1)
    b.disc(82, 30, 15, 0)
    b.d.ellipse((69, 17, 95, 43), outline=1)
    b.d.arc((72, 20, 92, 40), 180, 360, fill=1)
    b.line([(82, 30), (66, 22)], 2)
    b.line([(66, 22), (56, 26)], 1, 0)


@scene
def queens_light(b):
    b.ground()
    b.d.ellipse((40, 26, 92, 74), fill=0, outline=1)
    b.d.ellipse((42, 28, 90, 72), outline=1)
    b.rect(58, 72, 74, 84, 1)
    b.line([(56, 76), (76, 76)], 1, 0)
    b.line([(54, 50), (62, 40), (66, 50), (70, 40), (78, 50)], 1)
    b.sparks(66, 48, 10, 28)
    b.man(66, 26, 22, 1, "top", "flat", r=4, arms=[(-6, 2), (6, 2)], tie=False)
    for x in (12, 26, 104, 118):
        b.man(x, 84, 30, 1 if x < 66 else -1, "bowler", "o", r=5, tie=False, arms=[(4 if x < 66 else -4, -11)])
        b.rect(x + (4 if x < 66 else -7), 50, x + (7 if x < 66 else -4), 56, 0, 1)


@scene
def queens_exchange(b):
    b.wall()
    b.ground()
    b.rect(10, 34, 92, 84, 1)
    for y in range(40, 62, 6):
        for x in range(14, 90, 6):
            b.disc(x, y, 1, 0)
    b.rect(10, 62, 92, 66, 0)
    b.disc(50, 54, 15, 0, 1, ry=8)
    b.disc(66, 50, 6, 0, 1)
    b.poly([(62, 46), (61, 40), (66, 44)], 0, 1)
    b.poly([(70, 46), (72, 40), (68, 44)], 0, 1)
    b.line([(62, 50), (65, 50)], 1)
    b.line([(36, 56), (24, 44)], 1)
    b.line([(70, 58), (76, 66)], 2)
    b.man(110, 84, 54, -1, None, "frown", stache=True, arms=[(-4, 12), (4, 12)], r=8)
    b.rect(100, 58, 120, 64, 0, 1)


@scene
def sardine_tin(b):
    b.wall()
    b.rect(58, 3, W - 4, 56, 1)
    b.rect(70, 18, 112, 54, 0)
    for x in range(72, 112, 8):
        b.line([(x, 18), (x, 40)], 1)
    b.rect(58, 56, W - 4, H - 4, 1)
    b.man(92, 56, 28, -1, "cap", "flat", r=5, tie=False, coat=0)
    b.line([(82, 28), (76, 24)], 1, 1)
    b.ground()
    b.disc(38, 62, 11, 1, ry=13)
    b.disc(38, 42, 9, 1)
    b.poly([(31, 36), (29, 26), (36, 33)], 1)
    b.poly([(45, 36), (47, 26), (40, 33)], 1)
    b.dot(36, 41, 0)
    b.dot(41, 41, 0)
    b.line([(28, 46), (48, 46)], 3)
    b.line([(26, 44), (30, 46)], 1, 1)
    b.line([(46, 56), (56, 52)], 3)
    b.rect(54, 46, 62, 52, 0, 1)
    b.line([(26, 72), (14, 62)], 2)
    b.line([(32, 74), (32, 84)], 3)
    b.line([(44, 74), (44, 84)], 3)


@scene
def wors_map(b):
    b.hatch([(3, 40), (W - 4, 40), (W - 4, H - 4), (3, H - 4)], 4, 4, 1, 1)
    b.poly([(22, 66), (106, 66), (96, 82), (32, 82)], 1)
    b.man(70, 66, 44, 1, "cap", "frown", legs="sit", arms=[(14, -3), (14, -18)], r=7)
    b.rect(34, 46, 62, 60, 0, 1)
    for x, y in ((38, 50), (44, 54), (50, 48), (56, 53), (41, 56), (53, 57), (47, 52)):
        b.dot(x, y)
        b.line([(x, y), (x, y - 2)], 1)
    b.line([(84, 26), (70, 42)], 2)
    b.disc(85, 25, 3, 1)


@scene
def wors_set_disclaimer(b):
    b.wall()
    b.ground()
    x, y, n = b.man(38, 84, 56, -1, None, "grin", eyes="shut", stache=True, arms=[(30, 0), (28, 8)], r=9)
    b.line([(68, 50), (84, 46)], 2)
    b.rect(84, 34, 114, 56, 1)
    b.disc(93, 45, 5, 0)
    b.disc(106, 40, 2, 0)
    b.line([(110, 34), (116, 22)], 1)
    b.sparks(116, 18, 7, 8)


@scene
def licence_queue_stool(b):
    b.ground()
    b.rect(4, 14, 36, 84, 1)
    b.rect(14, 44, 36, 84, 0)
    b.poly([(38, 34), (48, 30), (48, 46), (38, 46)], 0, 1)
    b.man(52, 84, 44, -1, None, "smile", eyes="shut", r=7, tie=False, coat=0, arms=[(-12, 1)])
    b.poly([(46, 62), (58, 62), (55, 82), (49, 82)], 1)
    b.line([(46, 64), (58, 64)], 1, 0)
    for i, x in enumerate(range(72, 126, 12)):
        b.man(x, 84, 40 - i, -1, "bowler", "frown", eyes="shut", r=5, tie=False)


@scene
def signal_ground_rents(b):
    b.line([(3, 84), (W - 4, 84)], 1)
    b.hatch([(3, 85), (W - 4, 85), (W - 4, H - 4), (3, H - 4)], 8, 3)
    b.line([(64, 84), (64, 18)], 2)
    b.rect(56, 6, 72, 18, 1)
    b.rect(59, 10, 69, 12, 0)
    for x, h in ((26, 44), (40, 48), (52, 46), (76, 46), (88, 48), (102, 44)):
        b.man(x, 84, h, 1 if x < 64 else -1, "bowler", "o", r=6, tie=False, legs="tiptoe",
              arms=[((64 - x) // 4, -14)])
        b.rect(x + (64 - x) // 4 - 2, 84 - h - 2, x + (64 - x) // 4 + 2, 84 - h + 2, 0, 1)


@scene
def pun_derby_cards(b):
    b.wall()
    b.ground()
    b.man(26, 84, 52, 1, "cap", "frown", eyes="shut", legs="wide", r=7, tie=False, arms=[(12, -4)])
    b.disc(26, 58, 15, 1, ry=19)
    b.line([(16, 48), (36, 56)], 1, 0)
    b.table(58, 92, 62)
    b.man(76, 62, 30, 1, None, "grin", legs="sit", r=6, tie=False, arms=[(-14, -12)])
    b.rect(58, 34, 66, 40, 0, 1)
    b.rect(102, 54, 120, 66, 1)
    b.line([(106, 66), (106, 84)], 2)
    b.line([(116, 66), (116, 84)], 2)
    b.poly([(104, 56), (98, 44), (92, 48), (96, 62)], 1)
    b.dot(96, 50, 0)


@scene
def self_repair_course(b):
    b.line([(3, 68), (W - 4, 68)], 1)
    b.ground()
    bed(b, 8, 92, 62)
    x, y, n = b.man(30, 62, 30, 1, None, "o", r=7, tie=False, coat=0, arms=[(14, 2), (20, -6)])
    b.line([(37, 38), (44, 34)], 1)
    b.rect(44, 50, 68, 60, 1)
    b.poly([(44, 50), (68, 50), (72, 38), (48, 38)], 0, 1)
    b.sparks(58, 44, 6, 7)
    horn(b, 96, 36, 1, .7)
    b.line([(96, 36), (40, 46)], 1)
    b.bubbles([(44, 22, 2), (52, 16, 2)])


@scene
def last_word_service(b):
    b.wall()
    b.ground()
    bed(b, 4, 56, 60)
    x, y, n = b.man(18, 60, 32, 1, None, "o", stache=True, r=7, tie=False, coat=0, arms=[(14, -3)])
    horn(b, 30, 38, 1, .55)
    for x, h, kind in ((66, 40, 0), (80, 36, 1), (94, 44, 0)):
        if kind:
            b.woman(x, 84, h, -1, "cloche", "frown", eyes="shut", r=5, arms=[(-3, -4)])
        else:
            b.man(x, 84, h, -1, "bowler", "frown", eyes="shut", r=5, tie=False, arms=[(-3, -6)])
    b.man(114, 84, 52, -1, "top", "flat", r=7, arms=[(-8, 3)])
    b.disc(106, 54, 2, 0, 1)


@scene
def window_scraper(b):
    b.rect(3, 3, W - 4, H - 4, 1)
    b.rect(50, 8, 118, 76, 0)
    mast(b, 92, 10, 74, 14)
    for _ in range(90):
        x, y = b.r.randint(51, 117), b.r.randint(9, 75)
        if math.hypot(x - 90, y - 36) > 21:
            b.rect(x, y, x + 2, y + 1, 1)
    b.line([(84, 8), (84, 76)], 1)
    b.line([(50, 42), (118, 42)], 1)
    b.rect(44, 76, 124, 79, 0)
    b.rect(3, 80, W - 4, H - 4, 1)
    x, y, n = b.man(30, 84, 56, 1, "cap", "frown", coat=0, tie=False, arms=[(36, -6)], r=8)
    b.line([(64, 40), (70, 34)], 1, 0)


# --- the Speaker's Sunday cartoon ---------------------------------------------------
CARTOONS = {}


def cartoon(date):
    def register(fn):
        CARTOONS[date] = fn
        return fn
    return register


def mic(b, x, foot, h=30, v=1):
    b.line([(x, foot), (x, foot - h)], 2, v)
    b.line([(x - 6, foot), (x + 6, foot)], 2, v)
    b.d.ellipse((x - 4, foot - h - 8, x + 4, foot - h), fill=v)
    b.line([(x - 3, foot - h - 4), (x + 3, foot - h - 4)], 1, 1 - v)


def tripod_horn(b, x, foot, face=1, s=.7):
    b.line([(x, foot - 20), (x - 7, foot)], 1)
    b.line([(x, foot - 20), (x + 7, foot)], 1)
    horn(b, x, foot - 24, face, s)


def sash(b, x, top, bottom, w=5):
    b.poly([(x - w, top), (x - w + 3, top), (x + w, bottom), (x + w - 3, bottom)], 0, 1)


def couple(b, x, foot=84):
    b.man(x - 5, foot, 44, 1, None, "frown", eyes="shut", r=6, tie=False, arms=[(8, 2)])
    b.woman(x + 7, foot, 40, -1, None, "frown", eyes="shut", r=6, arms=[(-7, 3)])


def terrier(b, x, foot, face=1):
    b.rect(x - 6, foot - 8, x + 6, foot - 3, 1)
    b.line([(x - 5, foot - 3), (x - 5, foot)], 1)
    b.line([(x + 5, foot - 3), (x + 5, foot)], 1)
    b.disc(x + face * 7, foot - 10, 3, 1)
    b.line([(x + face * 5, foot - 13), (x + face * 5, foot - 16)], 1)
    b.line([(x - face * 6, foot - 8), (x - face * 9, foot - 12)], 1)
    b.dot(x + face * 8, foot - 11, 0)


def mare(b, x, foot=84, face=1, h=20):
    b.rect(x - 14, foot - h - 8, x + 12, foot - h + 4, 1)
    for dx in (-12, -6, 6, 11):
        b.line([(x + dx, foot - h + 4), (x + dx, foot)], 2)
    b.poly([(x + face * 11, foot - h - 6), (x + face * 18, foot - h - 22), (x + face * 25, foot - h - 19),
            (x + face * 24, foot - h - 14), (x + face * 17, foot - h - 10), (x + face * 13, foot - h + 2)], 1)
    b.poly([(x + face * 16, foot - h - 22), (x + face * 15, foot - h - 28), (x + face * 19, foot - h - 22)], 1)
    b.line([(x - face * 14, foot - h - 6), (x - face * 19, foot - h + 6)], 2)
    b.dot(x + face * 20, foot - h - 18, 0)


@cartoon("1928-11-11")
def c_silence(b):
    b.wall()
    b.ground()
    mic(b, 66, 84, 30)
    b.man(36, 84, 54, 1, None, "frown", stache=True, coat=0, tie=False, arms=[(14, -8)], r=8)
    b.disc(52, 34, 3, 0, 1)
    b.dot(52, 33)
    for x in (92, 106, 120):
        b.man(x, 84, 40, -1, "cap", "flat", eyes="shut", r=6, tie=False)


@cartoon("1928-11-18")
def c_referee(b):
    b.ground()
    b.d.ellipse((30, 76, 90, 86), fill=1)
    for x, hat in ((26, "top"), (92, "bowler")):
        f = 1 if x < 60 else -1
        b.man(x, 84, 36, f, hat, "flat", legs="sit", r=6, belly=4, tie=False, arms=[(f * 12, 6)])
        horn(b, x + f * 16, 68, f, .4)
    b.man(60, 84, 34, 1, "cap", "frown", r=6, tie=False, legs="sit", coat=0)
    for x in (112, 122, 12):
        b.man(x, 84, 26, 1, None, "frown", r=4, tie=False, coat=0)


@cartoon("1928-11-25")
def c_elevated(b):
    b.rect(3, 62, W - 4, 66, 1)
    b.line([(14, 66), (14, H - 4)], 3)
    b.line([(110, 66), (110, H - 4)], 3)
    for _ in range(24):
        b.dot(b.r.randint(5, W - 6), b.r.randint(5, 58))
    b.rect(40, 26, 122, 60, 1)
    for x in range(46, 118, 14):
        b.rect(x, 32, x + 10, 44, 0)
        b.head(x + 5, 40, 3, 1, "frown", None, eyes="shut")
    b.man(14, 62, 40, 1, "bowler", "smile", r=6, tie=False, arms=[(9, 2)])
    b.man(30, 62, 36, -1, "bowler", "smile", r=6, tie=False, arms=[(-7, 2)])


@cartoon("1928-12-02")
def c_tow(b):
    b.hatch([(3, 62), (W - 4, 62), (W - 4, H - 4), (3, H - 4)], 3, 4)
    b.poly([(70, 52), (112, 52), (106, 64), (74, 64)], 1)
    b.line([(82, 10), (82, 52)], 2)
    b.line([(100, 14), (100, 52)], 2)
    for x, y0 in ((82, 12), (100, 16)):
        for y in range(y0, y0 + 30, 11):
            b.rect(x - 8, y, x + 8, y + 7, 0, 1)
    b.man(110, 52, 20, -1, "top", "flat", r=3, tie=False, arms=[(-4, -5)])
    b.poly([(8, 56), (32, 56), (28, 64), (10, 64)], 1)
    b.rect(16, 44, 22, 56, 1)
    b.line([(32, 58), (72, 56)], 1)
    b.puffs(20, 40, 3, -3, -6)
    b.poly([(46, 66), (64, 66), (60, 74), (50, 74)], 0, 1)
    b.disc(55, 60, 3, 1)
    b.disc(55, 55, 2, 1)


@cartoon("1928-12-09")
def c_coldest(b):
    for _ in range(26):
        x, y = b.r.randint(5, W - 6), b.r.randint(5, 74)
        b.dot(x, y)
    b.ground()
    b.rect(3, 72, 58, 84, 1)
    b.man(30, 72, 48, 1, "top", "grin", arms=[(16, -14)], belly=8, r=7)
    b.rect(20, 38, 40, 42, 0, 1)
    x, y, n = b.man(88, 84, 46, -1, None, "frown", eyes="shut", r=7, tie=False)
    b.disc(88, 66, 14, 1, ry=18)
    b.line([(78, 56), (98, 62)], 1, 0)
    b.line([(78, 68), (98, 72)], 1, 0)
    b.rect(66, 44, 76, 52, 1)
    b.line([(64, 52), (64, 60)], 1)


@cartoon("1928-12-16")
def c_carols(b):
    b.wall()
    b.ground()
    b.rect(44, 62, 84, 84, 0, 1)
    b.rect(50, 50, 78, 62, 1)
    b.line([(64, 30), (64, 50)], 1)
    b.man(34, 84, 50, 1, "top", "frown", stache=True, r=7, arms=[(26, -16)])
    b.man(94, 84, 50, -1, "top", "frown", stache=True, r=7, arms=[(-26, -16)])
    for x in (108, 118):
        b.man(x, 84, 30, -1, "cap", "o", r=5, tie=False, coat=0)
    for x in (8, 18):
        b.man(x, 84, 30, 1, "cap", "o", r=5, tie=False, coat=0)


@cartoon("1928-12-23")
def c_last_valve(b):
    b.wall()
    b.ground()
    for y in (22, 40):
        b.rect(4, y, 48, y + 2, 1)
    b.man(26, 84, 52, 1, None, "flat", coat=0, tie=False, r=7, arms=[(14, -14)])
    valve(b, 44, 36, .55, 1, True)
    for i, x in enumerate(range(64, 124, 14)):
        b.man(x, 84, 42, -1, "bowler", "frown", r=6, tie=False, arms=[(-7, 8)])
        b.rect(x - 11, 62, x - 3, 70, 0, 1)


@cartoon("1928-12-30")
def c_sergeant(b):
    b.wall()
    b.ground()
    b.man(20, 84, 54, 1, "cap", "o", stache=True, r=8, belly=6, arms=[(14, -10)])
    for x in (50, 66, 82, 98):
        b.man(x, 84, 48, -1, "cap", "flat", r=6, tie=False, arms=[(0, 10)])
    b.man(114, 84, 48, -1, "cap", "smile", r=6, tie=False, arms=[(10, 8)])
    b.poly([(122, 56), (126, 44), (124, 58)], 0, 1)


@cartoon("1929-01-06")
def c_kissena(b):
    b.hatch([(3, 3), (W - 4, 3), (W - 4, 46), (3, 46)], 72, 7)
    b.ground()
    b.d.ellipse((50, 62, 124, 84), fill=0, outline=1)
    for y in (68, 74, 79):
        b.line([(62, y), (112, y)], 1)
    b.rect(86, 62, 88, 72, 1)
    b.line([(82, 72), (92, 72)], 2)
    b.man(16, 84, 46, 1, "bowler", "grin", r=6, arms=[(12, -8)], tie=False)
    b.man(36, 84, 46, 1, "bowler", "flat", r=6, arms=[(8, 4)], tie=False)
    b.poly([(44, 58), (54, 58), (52, 66), (46, 66)], 0, 1)


@cartoon("1929-01-13")
def c_horse_ice(b):
    b.hatch([(3, 60), (W - 4, 60), (W - 4, H - 4), (3, H - 4)], 4, 6)
    b.rect(3, 70, 26, H - 4, 1)
    b.man(14, 70, 46, 1, "bowler", "flat", r=6, arms=[(10, 2)])
    b.disc(26, 45, 3, 0, 1)
    b.line([(20, 42), (26, 42)], 1)
    mare(b, 92, 76, -1, 18)
    b.rect(104, 66, 122, 70, 1)
    b.line([(122, 70), (118, 76)], 2)


@cartoon("1929-01-20")
def c_collection(b):
    b.wall()
    b.ground()
    b.rect(6, 62, 26, 84, 1)
    b.man(16, 62, 34, 1, None, "frown", r=6, tie=False, arms=[(10, 4)])
    b.rect(34, 58, 50, 72, 1)
    b.disc(42, 64, 3, 0)
    for y, off in ((72, 0), (84, 8)):
        for x in range(62, 122, 18):
            b.head(x + off, y - 12, 4, -1, "frown", None, eyes="shut")
            b.rect(x + off - 6, y - 6, x + off + 7, y, 1)
            b.puffs(x + off - 5, y - 18, 2, -2, -4)
    b.man(102, 66, 28, -1, None, "smile", r=5, tie=False, arms=[(-10, 2)])
    b.d.ellipse((86, 48, 94, 52), fill=1)


@cartoon("1929-01-27")
def c_banquet(b):
    b.rect(3, 3, W - 4, 44, 1)
    for x in range(8, 116, 22):
        b.rect(x, 8, x + 18, 40, 0)
        b.head(x + 9, 26, 5, -1, "frown", None, eyes="wide")
    b.ground()
    b.table(38, 122, 58)
    b.d.ellipse((60, 48, 80, 58), fill=1)
    b.d.ellipse((90, 50, 104, 58), fill=0, outline=1)
    b.man(22, 84, 56, 1, None, "grin", stache=True, belly=14, r=9, arms=[(16, 2), (20, -6)], coat=1)
    b.poly([(14, 50), (30, 50), (28, 68), (16, 68)], 0, 1)


@cartoon("1929-02-03")
def c_shut_ins(b):
    b.rect(3, 3, W - 4, H - 4, 1)
    b.rect(10, 20, 54, 70, 0)
    b.rect(74, 20, 118, 70, 0)
    b.head(30, 42, 6, 1, "frown", None, eyes="wide")
    b.rect(20, 50, 40, 70, 1)
    for x, y in ((14, 62), (44, 58), (46, 66), (12, 52)):
        b.rect(x, y, x + 7, y + 6, 0, 1)
    b.disc(42, 34, 3, 1)
    b.sparks(42, 34, 6, 7)
    b.head(96, 42, 6, -1, "smile", None)
    b.rect(86, 50, 106, 70, 1)
    b.disc(80, 62, 3, 1)


@cartoon("1929-02-10")
def c_hymns(b):
    b.wall()
    b.line([(3, 84), (W - 4, 84)], 2)
    for x in (54, 80, 106):
        couple(b, x)
    b.man(20, 84, 50, 1, "cap", "flat", r=7, arms=[(10, 6), (-4, -12)])
    b.rect(30, 56, 40, 66, 0, 1)
    b.disc(28, 36, 2, 0, 1)
    b.line([(36, 80), (42, 84)], 1)


@cartoon("1929-02-17")
def c_lent(b):
    b.wall()
    b.ground()
    b.table(28, 84, 62)
    b.rect(50, 28, 74, 56, 0, 1)
    for y in range(32, 54, 4):
        b.line([(53, y), (71, y)], 1)
    b.head(62, 22, 8, 1, "flat", None, eyes="shut")
    b.dot(58, 22)
    b.disc(62, 23, 2, 0, 1)
    b.rect(50, 56, 74, 62, 1)
    b.woman(16, 84, 46, 1, None, "flat", r=6)
    b.man(110, 84, 50, -1, None, "flat", r=7, tie=False)
    b.rect(102, 44, 118, 46, 0)


@cartoon("1929-02-24")
def c_boxer(b):
    b.wall()
    b.ground()
    b.man(44, 84, 54, 1, "bowler", "grin", r=7, coat=0, arms=[(16, -6)])
    b.hatch([(38, 44), (50, 44), (50, 66), (38, 66)], 45, 3)
    b.line([(58, 38), (66, 34)], 2)
    b.puffs(68, 30, 2, 3, -5)
    b.rect(92, 44, 120, 50, 1)
    b.man(106, 84, 32, -1, "top", "flat", r=5, tie=False)
    horn(b, 88, 42, -1, .5)
    b.rect(10, 70, 24, 84, 1)
    b.man(16, 70, 32, 1, None, "frown", eyes="x", r=7, tie=False, coat=0, arms=[(7, -5)])
    b.d.ellipse((17, 40, 26, 48), fill=1)


@cartoon("1929-03-03")
def c_clerk(b):
    b.wall()
    b.ground()
    for x in (10, 26, 42):
        b.man(x, 84, 30, 1, "bowler", "flat", eyes="shut", legs="sit", r=5, tie=False)
    b.man(66, 84, 54, 1, None, "o", stache=True, r=8, arms=[(14, -14)])
    b.rect(92, 62, 124, 84, 1)
    b.rect(100, 52, 112, 62, 1)
    b.line([(106, 52), (108, 42)], 2)
    horn(b, 108, 40, 1, .55)
    b.lines_of_motion(118, 70, 2, 0, 3)


@cartoon("1929-03-10")
def c_robin(b):
    b.ground()
    b.line([(64, 84), (64, 34)], 4)
    b.line([(64, 50), (48, 34)], 2)
    b.line([(64, 46), (84, 28)], 2)
    b.line([(64, 34), (56, 18)], 1)
    b.line([(84, 28), (92, 22)], 1)
    b.disc(94, 8, 3, 1)
    b.line([(96, 6), (102, 3)], 1)
    b.line([(90, 8), (86, 12)], 1)
    b.man(20, 84, 46, 1, "bowler", "flat", r=6, tie=False, arms=[(8, 4)])
    tripod_horn(b, 40, 84, 1, .6)
    b.man(104, 84, 46, -1, "bowler", "flat", r=6, tie=False, arms=[(-8, -6)])
    b.man(120, 84, 42, -1, "cap", "flat", r=6, tie=False)
    b.man(8, 84, 40, 1, "cap", "flat", r=5, tie=False)


@cartoon("1929-03-17")
def c_parade(b):
    for i in range(4):
        b.rect(3, 72 + i * 4, W - 4, 73 + i * 4, 1)
    for x in range(60, 124, 12):
        b.man(x, 58, 24, -1, "cap", "o", r=4, tie=False)
    b.ground(84)
    b.man(26, 84, 46, 1, None, "flat", r=6, tie=False, coat=0, arms=[(12, -2)])
    b.disc(40, 58, 2, 0, 1)
    x, y, n = b.man(54, 84, 54, -1, "top", "frown", r=7, stache=True)
    sash(b, 54, n + 2, 70, 5)


@cartoon("1929-03-24")
def c_trunks(b):
    b.rect(3, 72, W - 4, H - 4, 1)
    b.rect(44, 40, 76, 72, 0, 1)
    b.rect(84, 34, 122, 72, 0, 1)
    for x0, x1, y0 in ((44, 76, 40), (84, 122, 34)):
        b.line([(x0, y0 + 10), (x1, y0 + 10)], 1)
        b.line([(x0 + 8, y0), (x0 + 8, 72)], 1)
        b.line([(x1 - 8, y0), (x1 - 8, 72)], 1)
    b.man(92, 34, 16, 1, "cap", "flat", legs="sit", eyes="shut", r=3, tie=False)
    b.line([(98, 28), (116, 26)], 1)
    b.man(32, 72, 28, 1, "bowler", "o", r=5, tie=False, arms=[(8, 4)])
    b.man(14, 72, 44, 1, "cap", "frown", r=6, tie=False, eyes="shut", arms=[(16, 6)])
    b.line([(44, 56), (30, 62)], 1)


@cartoon("1929-03-31")
def c_hat(b):
    b.line([(3, 74), (W - 4, 74)], 1)
    b.line([(3, 80), (W - 4, 80)], 1)
    b.ground()
    b.woman(84, 84, 52, -1, None, "flat", r=7)
    b.d.ellipse((46, 16, 124, 46), fill=1)
    b.d.pieslice((62, 2, 108, 50), 180, 360, fill=1)
    for x, y in ((70, 14), (90, 10), (100, 20)):
        b.disc(x, y, 3, 0)
    b.man(28, 84, 50, 1, None, "o", eyes="wide", r=7, arms=[(10, -10)])
    mic(b, 46, 84, 26)
    for x, y in ((14, 32), (40, 28)):
        b.dot(x, y)
        b.dot(x, y + 3)


@cartoon("1929-04-07")
def c_promoter(b):
    b.wall()
    b.line([(3, 84), (W - 4, 84)], 2)
    for x in (80, 106):
        couple(b, x)
    b.rect(34, 72, 52, 84, 1)
    b.disc(43, 78, 2, 0)
    b.man(16, 76, 34, 1, None, "smile", eyes="shut", legs="sit", r=6, stache=True)
    b.line([(30, 74), (42, 72)], 3)
    b.rect(10, 42, 24, 46, 0, 1)
    b.line([(26, 72), (26, 84)], 1)
    b.line([(8, 76), (8, 84)], 1)


@cartoon("1929-04-14")
def c_dog_voter(b):
    b.ground()
    b.rect(40, 66, 66, 84, 0, 1)
    b.line([(40, 66), (66, 84)], 1)
    x, y, n = b.man(52, 66, 48, 1, "top", "o", r=7, stache=True, arms=[(14, -10)])
    sash(b, 52, n + 2, 50, 4)
    b.rect(46, 48, 58, 54, 0)
    b.dog(92, 84, -1)
    b.rect(74, 66, 80, 71, 0, 1)
    for x in (112, 124):
        b.man(x, 84, 34, -1, "bowler", "flat", r=5, tie=False)


@cartoon("1929-04-21")
def c_ash(b):
    b.poly([(3, 84), (40, 44), (82, 52), (W - 4, 84)], 1)
    b.hatch([(3, 3), (W - 4, 3), (W - 4, 18), (3, 18)], 0, 3)
    for x in (20, 46, 92, 110):
        b.puffs(x, 42, 3, 2, -8)
    b.man(52, 54, 40, 1, "top", "smile", r=6, coat=0, tie=False, arms=[(12, -8), (-5, -13)])
    b.rect(100, 56, 124, 84, 0, 1)
    b.rect(106, 62, 118, 74, 1)
    b.ground()


@cartoon("1929-04-28")
def c_collie(b):
    b.wall()
    b.ground()
    b.rect(14, 26, 28, 50, 1)
    b.disc(21, 32, 3, 0)
    b.line([(26, 50), (34, 80)], 1)
    b.d.ellipse((30, 78, 42, 84), fill=1)
    b.rect(50, 58, 72, 80, 1)
    b.line([(54, 80), (54, 84)], 2)
    b.line([(68, 80), (68, 84)], 2)
    b.poly([(68, 60), (76, 44), (84, 46), (82, 52), (76, 56), (72, 66)], 1)
    b.poly([(74, 46), (72, 38), (78, 44)], 1)
    b.dot(79, 49, 0)
    b.line([(50, 62), (42, 72)], 2)
    b.man(106, 84, 36, -1, None, "smile", legs="sit", r=6, arms=[(-12, -2)], tie=False)
    b.rect(88, 56, 94, 64, 0, 1)


@cartoon("1929-05-05")
def c_major(b):
    b.ground()
    mare(b, 40, 84, 1, 22)
    b.rect(76, 42, 124, 78, 1)
    b.rect(76, 52, 94, 66, 0)
    b.disc(88, 78, 6, 0, 1)
    b.disc(114, 78, 6, 0, 1)
    b.head(85, 58, 4, -1, "frown", "cap")
    b.line([(79, 66), (70, 72)], 2)
    b.lines_of_motion(70, 62, 2, 0, 3)


@cartoon("1929-05-12")
def c_mothers_day(b):
    b.ground()
    b.rect(4, 18, 28, 84, 1)
    b.rect(8, 26, 24, 50, 0)
    b.line([(16, 26), (16, 44)], 1)
    for i, x in enumerate(range(38, 124, 15)):
        b.man(x, 84, 44, -1, "bowler", "frown", eyes="shut", r=6, tie=False, arms=[(-3, 11)])
        b.line([(x - 3, 66), (x - 8, 78)], 1)
        b.disc(x - 8, 79, 2, 0, 1)


@cartoon("1929-05-19")
def c_mud(b):
    b.rect(3, 60, W - 4, H - 4, 1)
    for y in (66, 74, 82):
        b.line([(8 + y % 11, y), (40 + y % 17, y)], 1, 0)
        b.line([(70, y + 1), (116, y + 1)], 1, 0)
    b.rect(3, 42, W - 4, 44, 1)
    x, y, n = b.man(30, 66, 46, 1, "bowler", "smile", r=7, coat=0, arms=[(20, 2)])
    b.rect(52, 42, 60, 52, 0, 1)
    mare(b, 96, 66, -1, 14)
    b.rect(82, 44, 110, 56, 1)


@cartoon("1929-05-26")
def c_old_soldiers(b):
    b.ground()
    b.rect(90, 4, 124, 40, 1)
    b.rect(90, 40, 124, 42, 0, 1)
    b.man(108, 40, 26, -1, None, "frown", r=5, coat=0, tie=False, arms=[(-8, -8)])
    b.line([(70, 4), (70, 22)], 1)
    b.poly([(70, 4), (84, 8), (70, 14)], 1)
    b.rect(8, 60, 64, 76, 1)
    b.disc(20, 78, 6, 0, 1)
    b.disc(54, 78, 6, 0, 1)
    for x in (14, 24, 34, 44, 54):
        b.head(x, 54, 4, 1, "smile", "cap", eyes="shut")
    b.man(80, 84, 22, 1, "cap", "o", r=4, tie=False)
    horn(b, 86, 66, 1, .3)
    b.man(98, 84, 22, 1, "cap", "o", r=4, tie=False)


@cartoon("1929-06-02")
def c_coney(b):
    b.line([(3, 84), (W - 4, 84)], 2)
    for i in range(4):
        b.rect(30 + i * 4, 84 - i * 6, 110, 84 - i * 6, 1)
    b.rect(50, 10, 124, 60, 1)
    b.rect(64, 18, 100, 58, 0)
    b.man(50, 60, 34, 1, None, "grin", r=6, coat=0, tie=False, arms=[(-9, -8)])
    for x, y in ((14, 84), (28, 84), (42, 84)):
        b.man(x, y, 26, 1, None, "frown", r=5, tie=False, coat=0, eyes="shut")
    for r in (8, 14, 20):
        b.d.arc((30 - r, 30 - r, 30 + r, 30 + r), 150, 210, fill=1)


@cartoon("1929-06-09")
def c_pun_owner(b):
    b.wall()
    b.ground()
    b.table(58, 124, 62)
    for x in (72, 90, 110):
        b.head(x, 50, 6, -1, "grin" if x == 90 else "flat", None, eyes="shut" if x == 90 else "dot", )
        b.rect(x - 6, 56, x + 6, 62, 1)
    b.man(42, 84, 52, 1, "cap", "o", r=7, coat=0, arms=[(16, 2)])
    pts = [(58, 60), (64, 60), (64, 84), (72, 84), (72, 62)]
    b.rect(54, 56, 68, 84, 0, 1)
    for y in range(60, 82, 4):
        b.line([(57, y), (65, y)], 1)
    mare(b, 14, 84, 1, 18)


@cartoon("1929-06-16")
def c_dawn(b):
    b.rect(3, 3, W - 4, 58, 1)
    b.d.pieslice((86, 34, 118, 78), 180, 360, fill=0)
    b.rays(102, 56, 13, 22)
    b.rect(3, 56, W - 4, 58, 1)
    b.hatch([(3, 60), (W - 4, 60), (W - 4, H - 4), (3, H - 4)], 88, 5)
    b.ground(84)
    b.man(70, 84, 42, 1, "bowler", "o", r=6, arms=[(16, -14)], coat=0, tie=False)
    tripod_horn(b, 36, 84, 1, .5)
    b.man(18, 84, 40, 1, "bowler", "frown", r=6, coat=0, tie=False)
    b.man(52, 84, 34, 1, "cap", "frown", r=5, coat=0, tie=False)


@cartoon("1929-06-23")
def c_beach(b):
    b.line([(3, 22), (W - 4, 22)], 1)
    for y in range(34, 86, 12):
        for x in range(8 + (y % 24), 124, 16):
            b.head(x, y, 5, 1 if x % 32 else -1, "smile", "boater" if x % 3 else None)
    b.man(52, 66, 42, 1, "boater", "o", legs="tiptoe", r=6, arms=[(16, -12)], tie=False)
    b.d.pieslice((92, 42, 124, 68), 180, 360, fill=1)
    b.line([(108, 55), (108, 78)], 1)
    b.head(108, 70, 5, -1, "smile", "cloche")


@cartoon("1929-06-30")
def c_wall_licence(b):
    b.wall(60)
    b.ground()
    b.rect(70, 26, 94, 46, 0, 1)
    b.rect(73, 29, 91, 43, 0, 1)
    b.man(34, 84, 54, 1, "bowler", "flat", stache=True, r=7, arms=[(14, 2)])
    b.rect(46, 50, 58, 62, 0, 1)
    b.man(108, 84, 50, -1, None, "frown", r=8, coat=0, tie=False, arms=[(-6, 12)], belly=5)


@cartoon("1929-07-07")
def c_committee(b):
    b.wall()
    b.ground()
    b.table(10, 118, 60)
    b.woman(64, 60, 28, 1, "cloche", "smile", r=6)
    b.rect(74, 52, 84, 60, 0, 1)
    for x, a in ((22, (6, -8)), (42, (6, 2)), (98, (-6, -8))):
        b.man(x, 84, 54, 1 if x < 64 else -1, None, "o", eyes="wide", r=7, arms=[a])
    for x, y in ((30, 34), (52, 42), (84, 30), (110, 40), (14, 44)):
        b.rect(x, y, x + 5, y + 7, 0, 1)
    b.lines_of_motion(46, 28, 2, 8, 4)


@cartoon("1929-07-14")
def c_lifeguard(b):
    b.line([(3, 84), (W - 4, 84)], 1)
    b.hatch([(3, 85), (W - 4, 85), (W - 4, H - 4), (3, H - 4)], 4, 5)
    b.line([(54, 84), (62, 44)], 2)
    b.line([(82, 84), (74, 44)], 2)
    b.rect(58, 44, 80, 47, 1)
    b.rect(62, 62, 74, 64, 1)
    b.man(69, 44, 30, 1, "cap", "flat", legs="sit", r=5, tie=False, coat=0)
    b.man(30, 84, 30, 1, None, "smile", r=5, tie=False, coat=0, arms=[(9, -4)])
    b.poly([(38, 62), (44, 62), (41, 72)], 1)
    b.disc(41, 60, 3, 0, 1)
    x, y, n = b.man(102, 84, 52, -1, None, "frown", r=7, tie=False, coat=0, belly=8)
    for ly in range(n + 4, 66, 4):
        b.line([(90, ly), (114, ly)], 1)


@cartoon("1929-07-21")
def c_pool(b):
    b.line([(3, 66), (W - 4, 66)], 2)
    b.hatch([(3, 67), (W - 4, 67), (W - 4, H - 4), (3, H - 4)], 3, 4)
    for x, y in ((72, 74), (90, 80), (108, 72), (120, 82), (60, 84)):
        b.head(x, y, 4, 1, "o", None, eyes="shut")
    x, y, n = b.man(28, 66, 50, 1, "top", "frown", r=7, stache=True, arms=[(14, 2)])
    b.line([(42, 44), (50, 40)], 1)
    b.line([(42, 44), (50, 48)], 1)
    for i in range(8):
        b.line([(70 - i * 2, 64), (44 - i * 3 + i, 8 + i * 4)], 1)
    for sx, sy in ((10, 18), (20, 12), (34, 16), (6, 34), (52, 22)):
        b.dot(sx, sy)
        b.dot(sx + 1, sy + 1)


@cartoon("1929-07-28")
def c_supper(b):
    b.wall()
    b.ground()
    b.table(36, 124, 60)
    for x in (48, 66, 84, 102, 118):
        b.head(x, 46, 6, -1 if x % 4 else 1, "grin", None, eyes="shut")
        b.rect(x - 5, 52, x + 5, 60, 1)
    b.rect(6, 10, 20, 84, 1)
    b.rect(24, 74, 34, 76, 1)
    b.line([(26, 76), (26, 84)], 1)
    b.line([(32, 76), (32, 84)], 1)
    b.man(29, 74, 28, 1, "bowler", "frown", r=5, tie=False, arms=[(6, -4)])
    b.rect(35, 54, 37, 62, 0, 1)


@cartoon("1929-08-04")
def c_dune(b):
    b.night()
    for x, y in ((14, 12), (44, 20), (74, 10), (104, 18), (118, 34), (30, 34), (60, 28)):
        b.dot(x, y, 0)
    b.poly([(3, 84), (24, 62), (80, 58), (92, 84)], 0)
    for x, f in ((42, 1), (60, 1)):
        b.head(x, 48, 6, f, "flat", "cap")
        b.rect(x - 5, 54, x + 5, 62, 1)
        b.line([(x - 5, 56), (x - 8, 46)], 2, 1)
    b.rect(92, 54, 122, 84, 0)
    b.rect(98, 60, 112, 72, 1)
    b.poly([(88, 54), (108, 40), (124, 54)], 0)
    b.man(106, 84, 28, -1, None, "o", legs="sit", eyes="shut", r=6, tie=False, coat=1)


@cartoon("1929-08-11")
def c_three_owners(b):
    b.wall()
    b.ground()
    b.rect(94, 40, 124, 84, 1)
    b.man(110, 40, 24, -1, None, "flat", r=6, tie=False, coat=0)
    b.poly([(99, 26), (92, 16), (92, 34)], 0, 1)
    terrier(b, 76, 84, 1)
    for x, a in ((14, (0, 0)), (30, (0, 0)), (46, (0, 0))):
        b.man(x, 84, 52, 1, "bowler", "frown", r=6, arms=[(8, 11)], stache=True, tie=False)
        b.line([(x + 8, 62), (70, 74)], 1)


@cartoon("1929-08-18")
def c_wedding(b):
    b.line([(64, 3), (64, 40)], 0)
    b.wall()
    b.ground()
    b.man(38, 84, 46, 1, None, "flat", r=7, specs=True, coat=0, tie=False, arms=[(6, 2)])
    b.man(14, 84, 40, 1, "bowler", "flat", r=5, tie=False)
    b.woman(84, 84, 44, -1, None, "grin", dress=0, r=6, eyes="shut")
    b.man(104, 84, 46, -1, None, "flat", r=6, tie=False)
    terrier(b, 62, 84, 1)
    b.line([(68, 74), (72, 66)], 1)


@cartoon("1929-08-25")
def c_nell(b):
    b.ground()
    mare(b, 90, 84, -1, 24)
    b.man(30, 84, 48, 1, "bowler", "flat", specs=True, r=6, arms=[(18, -2)], tie=False)
    b.rect(36, 48, 46, 58, 0, 1)
    b.man(58, 84, 26, 1, "cap", "smile", r=5, coat=0, tie=False, arms=[(8, -3)])
    b.poly([(64, 62), (72, 60), (72, 63)], 1)


@cartoon("1929-09-01")
def c_lost_booth(b):
    b.line([(3, 84), (W - 4, 84)], 1)
    for x in range(3, 124, 7):
        b.line([(x, 84), (x, H - 4)], 1)
    b.rect(6, 6, 122, 16, 1)
    b.line([(10, 16), (10, 84)], 2)
    b.line([(118, 16), (118, 84)], 2)
    b.rect(14, 62, 114, 65, 1)
    for x in range(20, 100, 11):
        b.head(x, 50, 4, 1, "smile", None, eyes="shut" if x % 3 else "dot")
        b.rect(x - 3, 54, x + 3, 62, 1)
        b.line([(x, 65), (x + 2, 74)], 1)
    b.man(104, 64, 34, -1, None, "frown", r=6, legs="sit", coat=0, tie=False)
    for y in (48, 54):
        b.line([(98, y), (110, y)], 1)


@cartoon("1929-09-08")
def c_roll_machine(b):
    b.wall()
    b.ground()
    b.table(30, 80, 56)
    b.rect(44, 40, 66, 56, 1)
    horn(b, 56, 32, 1, .55)
    b.line([(56, 32), (56, 40)], 2)
    b.man(22, 84, 52, 1, "top", "grin", r=7, arms=[(18, -8)], stache=True)
    b.woman(112, 84, 44, -1, None, "smile", r=6, arms=[(-8, -5)], eyes="shut")
    b.d.ellipse((100, 44, 105, 49), fill=1)
    for x, y in ((90, 84), (40, 84), (62, 84)):
        b.head(x, y - 8, 4, -1 if x > 50 else 1, "grin", None, eyes="wide")
        b.rect(x - 3, y - 4, x + 3, y, 1)


@cartoon("1929-09-15")
def c_tilden(b):
    b.line([(3, 84), (W - 4, 84)], 1)
    b.hatch([(3, 85), (W - 4, 85), (W - 4, H - 4), (3, H - 4)], 8, 4)
    b.man(38, 84, 72, 1, None, "flat", r=8, coat=0, tie=False, arms=[(4, 14)], eyes="shut")
    b.d.ellipse((46, 56, 58, 72), outline=1)
    b.man(76, 84, 24, -1, "cap", "o", r=4, tie=False, arms=[(-5, -5)])
    b.rect(92, 74, 106, 84, 1)
    horn(b, 98, 70, 1, .3)
    b.disc(116, 80, 4, 0, 1)
    b.dot(114, 79)
    b.dot(118, 79)
    b.line([(114, 83), (118, 83)], 1)


@cartoon("1929-09-22")
def c_coal_man(b):
    b.hatch([(3, 3), (W - 4, 3), (W - 4, 40), (3, 40)], 8, 5)
    b.rect(3, 72, 76, 84, 1)
    b.ground()
    b.rect(10, 18, 44, 72, 0, 1)
    b.man(32, 72, 48, 1, None, "grin", r=7, eyes="wide", arms=[(22, 4)])
    b.disc(32, 34, 7, 1)
    b.rect(27, 38, 37, 40, 0)
    b.dot(35, 32, 0)
    b.rect(52, 50, 62, 60, 0, 1)
    b.man(92, 84, 52, -1, "boater", "o", r=7, coat=0, tie=False, arms=[(-3, 11)], eyes="wide")
    b.lines_of_motion(124, 40, 3, 12, 6)


@cartoon("1929-09-29")
def c_ice_wagon(b):
    b.ground()
    b.rect(6, 18, 40, 84, 1)
    b.rect(10, 24, 36, 84, 0)
    b.man(24, 84, 50, 1, None, "frown", r=7, tie=False, coat=0, arms=[(14, 2)], stache=True)
    b.rect(36, 52, 48, 56, 0, 1)
    b.rect(92, 48, 118, 68, 1)
    b.disc(98, 72, 4, 0, 1)
    b.disc(114, 72, 4, 0, 1)
    b.rect(82, 52, 88, 58, 1)
    b.line([(88, 56), (92, 56)], 2)
    b.line([(82, 58), (82, 72)], 2)
    for x in range(44, 92, 5):
        b.dot(x, 83 - (x % 2))
        b.line([(x, 82), (x + 2, 82)], 1, 0)


@cartoon("1929-10-06")
def c_mack(b):
    b.line([(3, 84), (W - 4, 84)], 2)
    b.rect(3, 72, W - 4, H - 4, 1)
    b.man(64, 72, 62, 1, "bowler", "flat", r=7, eyes="shut", coat=1, arms=[(0, 12)])
    for x, top, f in ((22, 36, 1), (106, 36, -1)):
        b.line([(x - 6, 72), (x, top)], 1)
        b.line([(x + 6, 72), (x, top)], 1)
        for y in range(top + 6, 72, 7):
            b.line([(x - 4, y), (x + 4, y)], 1)
        b.man(x, top + 2, 30, f, "cap", "o", r=5, tie=False, arms=[(f * 14, 2)], legs="stand")


@cartoon("1929-10-13")
def c_hoover(b):
    b.hatch([(3, 3), (W - 4, 3), (W - 4, 40), (3, 40)], 90, 3)
    b.rect(3, 62, W - 4, H - 4, 1)
    b.rect(3, 58, W - 4, 62, 0, 1)
    b.man(62, 58, 36, 1, None, "flat", r=7, coat=1, tie=False)
    b.rect(54, 26, 70, 28, 0, 1)
    for x in (18, 34, 92, 110):
        b.man(x, 58, 34, 1 if x < 60 else -1, "bowler", "flat", r=6, tie=False, eyes="shut" if x in (18, 110) else "dot",
              arms=[(14, -8)] if x == 34 else None)


@cartoon("1929-10-20")
def c_sell(b):
    b.wall()
    b.ground()
    for x0 in (8,):
        b.rect(x0, 56, 92, 62, 1)
        b.rect(x0, 70, 92, 74, 1)
        b.line([(x0 + 2, 62), (x0 + 2, 84)], 2)
        b.line([(90, 62), (90, 84)], 2)
    b.man(68, 72, 40, 1, None, "flat", eyes="shut", stache=True, r=7, legs="sit", arms=[(8, -2)])
    for x in (20, 40):
        b.head(x, 46, 5, 1, "flat", "cloche" if x == 20 else "bowler", eyes="shut")
    b.man(106, 84, 28, -1, "cap", "o", r=5, tie=False, legs="sit", eyes="wide")
    b.line([(78, 46), (96, 56)], 1)


@cartoon("1929-10-27")
def c_tape(b):
    b.wall()
    b.rect(58, 48, W - 4, 84, 1)
    b.man(96, 48, 26, -1, "cap", "o", eyes="wide", r=5, tie=False, coat=0, arms=[(9, -6)])
    b.man(40, 84, 66, 1, "bowler", "flat", belly=12, r=9)
    b.man(14, 84, 54, 1, None, "flat", r=7, coat=0, tie=False, arms=[(14, -3)], stache=True)
    b.line([(3, 84), (W - 4, 84)], 1)
    b.r.seed(29)
    for _ in range(16):
        x, y = b.r.randint(5, 56), b.r.randint(76, 90)
        b.d.arc((x, y, x + 8, y + 5), 0, 270, fill=1)


@cartoon("1929-11-03")
def c_tea_tin(b):
    b.wall()
    b.ground()
    b.table(36, 92, 60)
    b.rect(52, 42, 68, 60, 1)
    b.disc(60, 42, 8, 0, 1, ry=2)
    b.line([(52, 50), (68, 50)], 1, 0)
    b.woman(20, 84, 44, 1, None, "smile", r=7, arms=[(24, -3)], eyes="shut")
    b.man(108, 84, 44, -1, None, "flat", legs="sit", r=7, stache=True, arms=[(-10, 2)])
    b.rect(90, 66, 98, 72, 0, 1)
    b.rect(88, 46, 94, 58, 0, 1)


def printed(block):
    """What the press does: the knife's chatter along every edge, and flecks of
    ink left standing in the cleared wood near the black."""
    px = block.im.load()
    before = block.im.copy()
    src = before.load()
    r = block.r
    for y in range(3, H - 3):
        for x in range(3, W - 3):
            near = sum(bool(src[a, c]) for a, c in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
            ink = bool(src[x, y])
            if ink and near <= 2 and r.random() < 0.12:
                px[x, y] = 0
            elif not ink and near >= 1 and r.random() < 0.04:
                px[x, y] = 255
    for _ in range(16):
        x, y = r.randint(4, W - 5), r.randint(4, H - 5)
        if not src[x, y]:
            px[x, y] = 255


def build(only=None):
    made = {}
    for folder, table in ((OUT, SCENES), (CARTOON_OUT, CARTOONS)):
        folder.mkdir(parents=True, exist_ok=True)
        for name, fn in table.items():
            if only and name not in only:
                continue
            block = Block(name)
            fn(block)
            printed(block)
            block.frame()
            made[name] = block.im
            ink = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            ink.paste(INK, mask=block.im)
            ink.save(folder / f"{name}.png", optimize=True)
    return made


def sheet(made, path, scale=2, columns=6, labels=False):
    rows = math.ceil(len(made) / columns)
    gap = 8
    out = Image.new("RGB", ((W * scale + gap) * columns + gap, (H * scale + gap) * rows + gap), (219, 212, 189))
    for i, (name, im) in enumerate(made.items()):
        big = im.convert("L").point(lambda p: 255 if p else 0).resize((W * scale, H * scale), Image.NEAREST)
        x, y = gap + (i % columns) * (W * scale + gap), gap + (i // columns) * (H * scale + gap)
        out.paste((28, 25, 22), (x, y), big)
    out.save(path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet")
    parser.add_argument("--only")
    args = parser.parse_args()
    built = build(set(args.only.split(",")) if args.only else None)
    print(f"{len(built)} woodblocks -> {OUT}")
    if args.sheet:
        sheet(built, args.sheet)
