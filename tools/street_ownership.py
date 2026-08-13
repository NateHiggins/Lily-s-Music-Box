"""Read the false-colour ownership pass written by StreetIdShot.tscn.

    python tools/street_ownership.py owners <log> <dir>
    python tools/street_ownership.py masses <log> <dir> [min_area]

`owners` ranks the buffers that own the frame and writes overlay.png.
`masses` segments the individual black masses and writes probe_pixels.txt,
which street_provenance.py casts through.

Two decoding rules, both measured rather than assumed:

* Channels are snapped to the nearest 16-step palette level. Godot's
  dark-end sRGB round trip is not exact — nominal 8 lands at 1, 24 at 21,
  40 at 38, 56 at 55 — but never moves a channel by more than half a step.
* Passes are merged. Id 0 in a pass means "named in a different pass"; a
  pixel that is 0 in every pass is a failure, not a result, and is counted
  and reported as one.
"""
import glob
import os
import sys

import numpy as np
from PIL import Image

CHUNK = 4095


def _decode(path):
    raw = np.asarray(Image.open(path).convert("RGB")).astype(np.int32)
    lvl = np.clip(np.rint((raw - 8) / 16.0), 0, 15).astype(np.int32)
    dev = int(np.abs(raw - (lvl * 16 + 8)).max())
    slot = lvl[:, :, 0] + lvl[:, :, 1] * 16 + lvl[:, :, 2] * 256
    return slot, np.all(raw == 0, axis=2), dev


def load(log, d):
    """-> (beauty rgb, per-pixel global id, id -> (class, aabb, path))."""
    legend = {}
    for line in open(log, encoding="utf-8", errors="replace"):
        if not line.startswith("[IDLEG] "):
            continue
        p = line[8:].rstrip("\n").split("\t")
        if len(p) != 5:
            continue
        r, g, b = (int(v) for v in p[1].split(","))
        slot = (r - 8) // 16 + ((g - 8) // 16) * 16 + ((b - 8) // 16) * 256
        legend[int(p[0]) * CHUNK + slot] = (p[2], p[3], p[4])

    idx = bg = None
    worst = 0
    files = sorted(glob.glob(os.path.join(d, "id_*.png")))
    for k, f in enumerate(files):
        slot, b, dev = _decode(f)
        worst = max(worst, dev)
        if idx is None:
            idx, bg = np.zeros_like(slot), b
        hit = slot > 0
        idx[hit] = k * CHUNK + slot[hit]
    idx[bg] = -1

    beauty = np.asarray(Image.open(os.path.join(d, "beauty.png"))
                        .convert("RGB")).astype(np.int32)
    print(f"{len(files)} pass(es), legend {len(legend)} instances, "
          f"worst off-grid deviation {worst} (safe below 8)")
    print(f"background {int(bg.sum())} px; unresolved in every pass "
          f"{int(((idx == 0) & ~bg).sum())} px; ids with no legend entry "
          f"{int(np.isin(idx, [-1] + list(legend), invert=True).sum())} px")
    return beauty, idx, legend


def name(legend, i):
    if i == -1:
        return "(background / sky)"
    if i == 0:
        return "!! UNRESOLVED IN EVERY PASS"
    e = legend.get(int(i))
    return f"{e[2]}   [{e[1]}]" if e else f"UNKNOWN id {i}"


def dark_mask(beauty):
    luma = (beauty[:, :, 0] * 299 + beauty[:, :, 1] * 587
            + beauty[:, :, 2] * 114) // 1000
    return luma < 16, luma


def owners(log, d):
    beauty, idx, legend = load(log, d)
    h, w = idx.shape

    def table(mask, header, top=18):
        n = int(mask.sum())
        print(f"\n== {header}: {n} px ({100.0 * n / (w * h):.2f}% of frame) ==")
        u, c = np.unique(idx[mask], return_counts=True)
        for i in np.argsort(-c)[:top]:
            print(f"{100.0 * c[i] / max(1, n):7.3f}%  {c[i]:8d}  "
                  f"{name(legend, u[i])}")

    table(np.ones((h, w), bool), "whole frame")
    dark, _ = dark_mask(beauty)
    table(dark, "beauty luma < 16 (the black masses)")

    u, c = np.unique(idx[dark], return_counts=True)
    top = [int(u[i]) for i in np.argsort(-c) if int(u[i]) > 0][:8]
    pal = [(255, 60, 60), (60, 255, 60), (80, 140, 255), (255, 220, 40),
           (255, 60, 255), (60, 255, 255), (255, 150, 40), (170, 120, 255)]
    ov = (np.asarray(Image.open(os.path.join(d, "beauty.png")).convert("RGB"))
          // 3 + 40).astype(np.uint8)
    print()
    for n_, i in enumerate(top):
        ov[(idx == i) & dark] = pal[n_ % len(pal)]
        print(f"overlay {pal[n_ % len(pal)]} -> {name(legend, i)}")
    Image.fromarray(ov).save(os.path.join(d, "overlay.png"))
    print(f"wrote {os.path.join(d, 'overlay.png')}")


def masses(log, d, min_area=1500):
    beauty, idx, legend = load(log, d)
    h, w = idx.shape
    dark, _ = dark_mask(beauty)
    seen = np.zeros((h, w), bool)
    found = []
    for y0, x0 in zip(*np.nonzero(dark)):
        if seen[y0, x0]:
            continue
        me = idx[y0, x0]
        stack, pix = [(y0, x0)], []
        seen[y0, x0] = True
        while stack:
            y, x = stack.pop()
            pix.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx] \
                        and dark[ny, nx] and idx[ny, nx] == me:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        if len(pix) < min_area:
            continue
        a = np.array(pix)
        # Probe pixel: the component pixel nearest its centroid, so the ray
        # is guaranteed to leave through this mass and not a neighbour.
        c = a.mean(axis=0)
        py, px = a[np.argmin(((a - c) ** 2).sum(axis=1))]
        v = beauty[a[:, 0], a[:, 1]].mean(axis=1)
        found.append({"id": int(me), "area": len(pix), "px": (int(px), int(py)),
                      "bbox": (int(a[:, 1].min()), int(a[:, 0].min()),
                               int(a[:, 1].max()), int(a[:, 0].max())),
                      "sd": float(v.std()), "mean": float(v.mean())})

    found.sort(key=lambda m: -m["area"])
    print(f"\n{len(found)} dark masses >= {min_area} px "
          f"(sd = luma spread inside the mass; a featureless slab is near 0)\n")
    print(f"{'area':>7} {'probe':>10} {'bbox':>22} {'mean':>5} {'sd':>5}  owner")
    for m in found[:24]:
        b = m["bbox"]
        px = f"{m['px'][0]},{m['px'][1]}"
        bb = f"{b[0]},{b[1]}..{b[2]},{b[3]}"
        print(f"{m['area']:7d} {px:>10} {bb:>22} {m['mean']:5.1f} "
              f"{m['sd']:5.2f}  {name(legend, m['id'])}")
    out = os.path.join(d, "probe_pixels.txt")
    with open(out, "w") as fh:
        for m in found[:24]:
            fh.write(f"{m['px'][0]},{m['px'][1]}\n")
    print(f"\nwrote {out}")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "owners":
        owners(sys.argv[2], sys.argv[3])
    elif cmd == "masses":
        masses(sys.argv[2], sys.argv[3],
               int(sys.argv[4]) if len(sys.argv) > 4 else 1500)
    else:
        sys.exit(__doc__)
