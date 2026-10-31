#!/usr/bin/env python3
"""Ink the Speaker's weekly cartoons from the generator's chosen drawings.

    python art/tools/imagegen.py --batch <jobs.json> --out <dir>
    python art/tools/build_cartoon_book.py --cuts <dir of generated PNGs>

art/data/newspaper_cartoon_book.json holds each Sunday's prompt and the seed chosen
after looking at the output. Generators sign and caption their drawings with invented
letters (RUL-008), so loose marks at the top and foot of the sheet are cleared, and a
date's wipe list blanks any sign the drawing itself grew. Captions are set live by
NewspaperPanel.
"""
from __future__ import annotations

import argparse
import json
import pathlib

import numpy as np
from PIL import Image, ImageFilter, ImageOps

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/ui/newspaper/cartoons"
BOOK = ROOT / "art/data/newspaper_cartoon_book.json"
INK = (28, 25, 22)
WIDTH = 768
# Grey below this is ink; the band above it is the soft edge of the line.
INK_LEVEL, EDGE = 118, 40
MARK_LEVEL = 170
TOP_BAND, FOOT_BAND = 0.09, 0.16
MARK_HEIGHT, MARK_WIDTH = 0.045, 0.10


def clear_loose_marks(grey: np.ndarray) -> np.ndarray:
    """White out small unconnected marks in the top and foot bands of the sheet."""
    height, width = grey.shape
    dark = (grey < MARK_LEVEL).ravel().tolist()
    seen = bytearray(height * width)
    out = grey.copy()
    for start, is_dark in enumerate(dark):
        if not is_dark or seen[start]:
            continue
        seen[start] = 1
        stack = [start]
        top, bottom, left, right = height, 0, width, 0
        while stack:
            at = stack.pop()
            y, x = divmod(at, width)
            top, bottom, left, right = min(top, y), max(bottom, y), min(left, x), max(right, x)
            for near, inside in ((at - width, y > 0), (at + width, y < height - 1),
                                 (at - 1, x > 0), (at + 1, x < width - 1)):
                if inside and dark[near] and not seen[near]:
                    seen[near] = 1
                    stack.append(near)
        in_band = bottom < height * TOP_BAND or top > height * (1 - FOOT_BAND)
        small = bottom - top < height * MARK_HEIGHT and right - left < width * MARK_WIDTH
        if in_band and small:
            out[max(top - 2, 0):bottom + 3, max(left - 2, 0):right + 3] = 255
    return out


def ink(source: pathlib.Path, wipes: list, target: pathlib.Path) -> None:
    grey = np.array(ImageOps.grayscale(Image.open(source)))
    height, width = grey.shape
    for left, top, right, bottom in wipes:
        grey[int(top * height):int(bottom * height), int(left * width):int(right * width)] = 255
    grey = Image.fromarray(clear_loose_marks(grey))
    grey = ImageOps.autocontrast(grey, cutoff=1)
    scaled = (WIDTH, round(height * WIDTH / width))
    grey = grey.resize(scaled, Image.LANCZOS).filter(ImageFilter.UnsharpMask(2, 120, 2))
    alpha = grey.point(lambda v: 255 if v <= INK_LEVEL else 0 if v >= INK_LEVEL + EDGE
                       else round(255 * (INK_LEVEL + EDGE - v) / EDGE))
    print_ = Image.new("RGBA", scaled, INK + (0,))
    print_.putalpha(alpha)
    bounds = alpha.point(lambda v: 255 if v > 40 else 0).getbbox()
    print_.crop(bounds).save(target, optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cuts", type=pathlib.Path, required=True)
    args = parser.parse_args()
    book = json.loads(BOOK.read_text(encoding="utf8"))
    for date, entry in book["cartoons"].items():
        ink(args.cuts / f"{date}_s{entry['seed']}.png", entry.get("wipe", []), OUT / f"{date}.png")
    print(f"inked {len(book['cartoons'])} cartoons")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
