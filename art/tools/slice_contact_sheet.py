"""Cut a labelled contact sheet into one source image per cell.

Every material sheet comes back from the generator as a single grid with
a caption under each cell. ingest_material_sources.py wants one file per
material, so until now each sheet was cut by hand, which is how you end
up with a caption baked into the top of a tiling texture.

This finds the caption bands itself. A caption sits on a near-white
strip, so rows that are overwhelmingly white are separators and the
bands between them are the cells. Columns are an even split, which has
held for every sheet so far; pass --cols to say how many.

Each cell is inset a few pixels (generators soften cell edges, and a
soft edge tiles as a visible grid) and centre-cropped square before it
is written. Everything after that - tiling, height, normal, roughness -
is ingest_material_sources.py's job.

    python art/tools/slice_contact_sheet.py SHEET.png --cols 3 \\
        --names brass_worn,bronze_patina,steel_car_paint,...

Names are row-major and must match SLOTS keys in the ingest script for
the cell to become a catalog material.
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "textures", "ai_sources")


def caption_bands(a: np.ndarray, white: int, frac: float,
                  run: int) -> list:
    """Row spans that are almost entirely near-white: gaps and captions."""
    hits = (a.min(axis=2) > white).mean(axis=1)
    bands, cur = [], None
    for i, f in enumerate(hits):
        if f > frac:
            cur = [i, i] if cur is None else [cur[0], i]
        else:
            if cur and cur[1] - cur[0] >= run:
                bands.append(tuple(cur))
            cur = None
    if cur and cur[1] - cur[0] >= run:
        bands.append(tuple(cur))
    return bands


def row_spans(a: np.ndarray, rows: int, white: int, frac: float,
              run: int) -> list:
    """The picture bands: what is left once the captions are removed."""
    bands = caption_bands(a, white, frac, run)
    spans, y = [], 0
    for b0, b1 in bands:
        if b0 - y > a.shape[0] * 0.04:      # ignore hairline separators
            spans.append((y, b0))
        y = b1 + 1
    if a.shape[0] - y > a.shape[0] * 0.04:
        spans.append((y, a.shape[0]))
    if rows and len(spans) != rows:
        # Detection disagreed with what the caller expects; an even split
        # is wrong more subtly than a wrong band, so say so rather than
        # silently slicing captions into textures.
        raise SystemExit(
            "found %d picture rows, expected %d: %s\n"
            "pass --white/--frac to retune, or --rows 0 to accept."
            % (len(spans), rows, spans))
    return spans


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("--cols", type=int, required=True)
    ap.add_argument("--rows", type=int, default=0,
                    help="expected picture rows; 0 accepts what is found")
    ap.add_argument("--names", required=True,
                    help="comma-separated, row-major")
    ap.add_argument("--out", default=SRC)
    ap.add_argument("--inset", type=int, default=6)
    ap.add_argument("--white", type=int, default=225)
    ap.add_argument("--frac", type=float, default=0.80)
    ap.add_argument("--run", type=int, default=5)
    args = ap.parse_args()

    path = args.sheet
    if not os.path.isabs(path) and not os.path.exists(path):
        path = os.path.join(SRC, args.sheet)
    img = Image.open(path).convert("RGB")
    a = np.asarray(img)
    names = [n.strip() for n in args.names.split(",") if n.strip()]
    spans = row_spans(a, args.rows, args.white, args.frac, args.run)
    if len(names) != len(spans) * args.cols:
        raise SystemExit("%d names for %d cells (%d rows x %d cols)"
                         % (len(names), len(spans) * args.cols,
                            len(spans), args.cols))

    cw = img.width / float(args.cols)
    os.makedirs(args.out, exist_ok=True)
    n = 0
    for y0, y1 in spans:
        for c in range(args.cols):
            x0 = int(round(c * cw)) + args.inset
            x1 = int(round((c + 1) * cw)) - args.inset
            cell = img.crop((x0, y0 + args.inset, x1, y1 - args.inset))
            side = min(cell.width, cell.height)
            ox = (cell.width - side) // 2
            oy = (cell.height - side) // 2
            cell = cell.crop((ox, oy, ox + side, oy + side))
            dst = os.path.join(args.out, names[n] + ".png")
            cell.save(dst)
            print("  %-22s %dx%d  ->  %s"
                  % (names[n], side, side, os.path.basename(dst)))
            n += 1
    print("sliced %d cells from %s" % (n, os.path.basename(path)))


if __name__ == "__main__":
    main()
