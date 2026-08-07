"""Cut the grocery label sheet into the atlas the refrigerators read.

The nine brands in fridge_prop.gd's LARDER table were colours and names
in a comment: a bottle of MERIDIAN MILK was an off-white cylinder that
said nothing. This turns the delivered label sheet into a 3x3 atlas so
the bottle actually carries its label, sampled the way the mail cards
and the clock dials are - uv1_scale/uv1_offset, never AtlasTexture,
which does not crop on a 3D material.

The sheet is labels floating on white with a caption under each. Rows
of label are overwhelmingly non-white; caption rows are a few thin
strokes. That gap is wide enough to split on, so the captions never
reach the atlas.

Each label is fitted into its cell rather than stretched - a milk label
is twice as tall as it is wide and squaring it looks like a mistake -
and the margin is filled from the label's own border colour so a box
wrapped in it does not show white seams at the edges.

    python art/tools/build_larder_labels.py

Writes art/textures/generated/larder_labels.png (and .import stays
Godot's business). Cell order is row-major and must match LARDER_CELL
in game/scripts/props/fridge_prop.gd.
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "textures", "ai_sources")
OUT = os.path.join(ROOT, "game", "assets", "building", "textures",
                   "larder", "larder_labels.png")

SHEET = "ChatGPT Image Aug 6, 2026, 08_55_49 AM.png"
CELL = 384                      # 3 x 384 = 1152 square atlas
NAMES = ["meridian_milk", "holloways_preserve", "crown_vale_butter",
         "peerless_lager", "kesslers_pickles", "astoria_cream",
         "quell_tonic", "wrens_butter", "bell_bros"]


def bands(mask: np.ndarray, axis: int, keep: float) -> list:
    """Runs along `axis` where enough of the perpendicular line is ink."""
    proj = mask.mean(axis=axis)
    out, cur = [], None
    for i, v in enumerate(proj):
        if v > keep:
            cur = [i, i] if cur is None else [cur[0], i]
        elif cur is not None:
            out.append(tuple(cur))
            cur = None
    if cur is not None:
        out.append(tuple(cur))
    return [b for b in out if b[1] - b[0] > 8]


def border_fill(cell: Image.Image) -> tuple:
    """Median colour of the label's outer ring, for the padding."""
    a = np.asarray(cell.convert("RGB"))
    ring = np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3),
                           a[:, :4].reshape(-1, 3),
                           a[:, -4:].reshape(-1, 3)])
    return tuple(int(v) for v in np.median(ring, axis=0))


def main() -> None:
    img = Image.open(os.path.join(SRC, SHEET)).convert("RGB")
    a = np.asarray(img)
    ink = (a.min(axis=2) < 235)

    rows = bands(ink, 1, 0.40)
    if len(rows) != 3:
        raise SystemExit("expected 3 label rows, found %d: %s"
                         % (len(rows), rows))

    atlas = Image.new("RGB", (CELL * 3, CELL * 3), (255, 255, 255))
    n = 0
    for r, (y0, y1) in enumerate(rows):
        strip = ink[y0:y1 + 1]
        cols = bands(strip, 0, 0.20)
        if len(cols) != 3:
            raise SystemExit("row %d: expected 3 labels, found %d: %s"
                             % (r, len(cols), cols))
        for x0, x1 in cols:
            crop = img.crop((x0, y0, x1 + 1, y1 + 1))
            fit = min(CELL / float(crop.width), CELL / float(crop.height))
            w = max(1, int(round(crop.width * fit)))
            h = max(1, int(round(crop.height * fit)))
            cellimg = Image.new("RGB", (CELL, CELL), border_fill(crop))
            cellimg.paste(crop.resize((w, h), Image.LANCZOS),
                          ((CELL - w) // 2, (CELL - h) // 2))
            atlas.paste(cellimg, ((n % 3) * CELL, (n // 3) * CELL))
            print("  cell %d %-20s %dx%d -> %dx%d"
                  % (n, NAMES[n], crop.width, crop.height, w, h))
            n += 1

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    atlas.save(OUT)
    print("wrote %s (%dx%d, %d cells)"
          % (os.path.relpath(OUT, ROOT), atlas.width, atlas.height, n))


if __name__ == "__main__":
    main()
