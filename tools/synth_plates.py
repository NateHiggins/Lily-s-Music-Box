#!/usr/bin/env python3
"""Synthesize original procedural source plates for the texture pipeline.

Each recipe composes noise, banding and pattern primitives into a flat
1024x1024 base-color plate saved to art/textures/source/<material>.png,
ready for material_textures.py to normalize into seamless PBR sets. All
plates are generated from math here - nothing is sampled from photos.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "art" / "textures" / "source"
N = 1024


def noise(sigma=60, blur=0.0, seed_shift=0):
    img = Image.effect_noise((N, N), sigma)
    if seed_shift:
        img = ImageChops.offset(img, seed_shift * 37, seed_shift * 91)
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return img


def fbm(octaves=((3, 90), (11, 60), (41, 35)), seed_shift=0):
    """Multi-scale clouds: blurred noise layers averaged coarse-to-fine."""
    acc = Image.new("L", (N, N), 128)
    for i, (blur, sigma) in enumerate(octaves):
        layer = noise(sigma, blur, seed_shift + i)
        acc = ImageChops.add(acc, layer, scale=2.0, offset=-64)
    return acc


def tint(gray, lo, hi):
    """Map grayscale into an RGB ramp lo->hi (0..255 tuples)."""
    bands = []
    for c in range(3):
        lut = [round(lo[c] + (hi[c] - lo[c]) * v / 255) for v in range(256)]
        bands.append(gray.point(lut))
    return Image.merge("RGB", bands)


def stripes(period, angle=0, jitter=None, duty=0.5, soft=2.0):
    img = Image.new("L", (N, N))
    px = img.load()
    jl = jitter.load() if jitter else None
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    for y in range(N):
        for x in range(N):
            t = (x * ca + y * sa)
            if jl:
                t += (jl[x, y] - 128) / 24.0
            phase = (t % period) / period
            v = 255 if phase < duty else 0
            px[x, y] = v
    return img.filter(ImageFilter.GaussianBlur(soft))


def grain(direction="v", coarse=140, streak=26, seed=0):
    """Wood grain: heavy directional motion blur over noise."""
    g = noise(coarse, 0, seed)
    size = (1, streak) if direction == "v" else (streak, 1)
    for _ in range(3):
        g = g.filter(ImageFilter.BoxBlur(2))
        g = g.resize((N // size[0] if size[0] > 1 else N,
                      N // size[1] if size[1] > 1 else N)).resize((N, N))
    return g


def plank_seams(w=128, direction="v", depth=60):
    img = Image.new("L", (N, N), 255)
    d = ImageDraw.Draw(img)
    for k in range(0, N + 1, w):
        if direction == "v":
            d.line((k, 0, k, N), fill=255 - depth, width=3)
        else:
            d.line((0, k, N, k), fill=255 - depth, width=3)
    return img.filter(ImageFilter.GaussianBlur(1.2))


def brick_pattern(course=64, brick=170, mortar_v=210, brick_lo=70,
                  brick_hi=130, seed=5):
    img = Image.new("L", (N, N), mortar_v)
    d = ImageDraw.Draw(img)
    rnd = seed
    for row in range(0, N // course + 1):
        y0 = row * course
        off = (brick // 2) if row % 2 else 0
        x = -off
        while x < N:
            rnd = (rnd * 1103515245 + 12345) % (2 ** 31)
            v = brick_lo + rnd % (brick_hi - brick_lo)
            d.rectangle((x + 3, y0 + 3, x + brick - 3, y0 + course - 3),
                        fill=v)
            x += brick
    return img.filter(ImageFilter.GaussianBlur(1.0))


def weave(period=8, contrast=70):
    a = stripes(period, 0, duty=0.5, soft=1.0)
    b = stripes(period, 90, duty=0.5, soft=1.0)
    x = ImageChops.difference(a, b)
    x = x.point(lambda v: 128 + (v - 128) * contrast // 128)
    return ImageChops.add(x, noise(25, 0.6), scale=2.0, offset=-64)


def save(name, img):
    SRC.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(SRC / f"{name}.png", optimize=True)
    print("plate:", name)


def build_all(only=None):
    R = {}

    # --- woods
    oakish = ImageChops.multiply(
        tint(grain("v", 150, 30, 1), (96, 66, 42), (150, 112, 74)),
        tint(plank_seams(146, "v", 70), (200, 200, 200), (255, 255, 255)))
    R["wood_dark"] = ImageEnhance.Brightness(oakish).enhance(0.62)
    R["timber"] = ImageChops.multiply(
        tint(grain("h", 170, 34, 3), (104, 78, 52), (148, 116, 82)),
        tint(plank_seams(170, "h", 55), (205, 205, 205), (255, 255, 255)))
    R["trim"] = tint(fbm(((9, 26), (33, 18)), 7),
                     (204, 199, 183), (224, 219, 205))
    R["stair"] = tint(fbm(((5, 60), (19, 40), (67, 24)), 9),
                      (128, 123, 112), (163, 158, 147))
    R["slab"] = tint(fbm(((7, 70), (23, 45)), 11), (74, 72, 69),
                     (102, 100, 96))

    # --- masonry & stone
    fb_ = ImageChops.multiply(
        tint(brick_pattern(56, 150, 200, 60, 110, 7),
             (58, 26, 20), (168, 150, 138)),
        tint(noise(40, 1.2, 2), (190, 190, 190), (255, 255, 255)))
    R["face_brick"] = fb_
    R["common_brick"] = ImageChops.multiply(
        tint(brick_pattern(62, 176, 215, 90, 150, 11),
             (118, 78, 56), (186, 168, 150)),
        tint(noise(45, 1.2, 4), (185, 185, 185), (255, 255, 255)))
    R["limestone"] = ImageChops.multiply(
        tint(fbm(((11, 40), (37, 26)), 13), (186, 179, 158), (212, 206, 188)),
        tint(stripes(210, 2, noise(70, 6, 5), 0.94, 3.0),
             (235, 235, 235), (255, 255, 255)))

    # --- ceramics, metals, appliances
    R["porcelain"] = tint(fbm(((15, 14), (51, 9)), 15),
                          (228, 231, 229), (240, 242, 240))
    R["ceramic"] = ImageChops.multiply(
        tint(fbm(((17, 12),), 17), (196, 201, 199), (214, 218, 216)),
        tint(stripes(128, 0, None, 0.965, 1.2), (225, 225, 225),
             (255, 255, 255)))
    R["enamel"] = tint(fbm(((13, 16), (47, 10)), 19),
                       (222, 216, 200), (238, 232, 216))
    R["metal"] = tint(grain("h", 90, 40, 21), (120, 123, 127),
                      (156, 159, 163))
    R["chrome"] = tint(grain("h", 60, 60, 23), (188, 192, 197),
                       (216, 220, 226))
    R["brass"] = tint(grain("h", 80, 45, 25), (128, 104, 56),
                      (170, 145, 88))
    R["appliance"] = tint(fbm(((11, 14), (37, 9)), 27),
                          (216, 216, 212), (230, 230, 226))
    R["bakelite"] = tint(fbm(((9, 40), (29, 25)), 29), (32, 24, 20),
                         (58, 46, 38))

    # --- textiles & soft goods
    R["linen"] = ImageChops.add(
        tint(weave(6, 40), (206, 203, 194), (224, 221, 213)),
        noise(18, 0.4, 31).convert("RGB"), scale=8.0, offset=-16)
    R["paper"] = tint(fbm(((7, 16), (23, 10)), 33), (222, 217, 202),
                      (236, 231, 217))
    for key, lo, hi in (("fabric_warm", (118, 68, 50), (162, 100, 78)),
                        ("fabric_cool", (72, 87, 108), (108, 124, 148)),
                        ("fabric_green", (78, 98, 74), (112, 132, 104))):
        R[key] = ImageChops.multiply(
            tint(weave(7, 55), (200, 200, 200), (255, 255, 255)),
            Image.new("RGB", (N, N), hi))
        R[key] = ImageChops.add(R[key], tint(fbm(((21, 30),), 35),
                                (0, 0, 0), (28, 22, 18)), scale=2.0,
                                offset=-14)
    for key, lo, hi in (("rug_warm", (104, 52, 42), (146, 82, 66)),
                        ("rug_cool", (54, 66, 86), (84, 98, 122)),
                        ("rug_green", (64, 82, 62), (96, 116, 92))):
        base = ImageChops.multiply(
            tint(weave(11, 70), (190, 190, 190), (255, 255, 255)),
            Image.new("RGB", (N, N), hi))
        R[key] = ImageChops.add(base, noise(30, 0.8, 37).convert("RGB"),
                                scale=6.0, offset=-22)

    # --- misc
    R["soot"] = tint(fbm(((5, 80), (17, 55), (61, 30)), 39),
                     (14, 14, 15), (48, 46, 45))
    R["plant"] = ImageChops.multiply(
        tint(fbm(((7, 60), (19, 40)), 41), (46, 84, 40), (96, 132, 74)),
        tint(stripes(36, 30, noise(60, 4, 43), 0.72, 2.0),
             (205, 215, 205), (255, 255, 255)))
    R["art"] = ImageChops.add(
        tint(fbm(((9, 50), (31, 35)), 45), (116, 96, 70), (168, 148, 116)),
        tint(weave(5, 25), (0, 0, 0), (26, 26, 24)), scale=2.0, offset=-12)

    for name, img in R.items():
        if only and name not in only:
            continue
        save(name, img)


if __name__ == "__main__":
    build_all(set(sys.argv[1:]) or None)
