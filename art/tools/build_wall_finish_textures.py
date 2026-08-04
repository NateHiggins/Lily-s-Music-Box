"""Composite per-wall finishes from the AI-generated source library.

art/textures/wall_sources/ holds sixteen FLUX-generated layers (see
design/WALL_TEXTURE_PROMPT_SHEET.md): photoreal plaster and wallpaper
albedos, binary damage stencils, grayscale relief maps, and stain
overlays shot on white. This tool composites them into one unique
texture set per room-facing masonry wall:

- albedo.png (RGBA): plaster or papered surface, moisture/soot/leak
  overlays — and the ALPHA CHANNEL is the survival mask. Where the
  century stripped the finish, the exporter's quad goes transparent and
  the true brick wall behind it shows.
- normal.png: relief composed from the survival crust, the generated
  plaster height detail, and paper lift — the finish reads as raised
  material over the masonry.
- roughness.png: paper sheens lower, damp darkens and tightens.

Damage placement stays CAUSE-SHAPED (rising-damp tide, one wandering
leak, settlement at opening corners, a delamination island) but the
SILHOUETTES come from the generated stencils: the causal field decides
where loss is likely, the stencil decides what torn plaster actually
looks like there. Every wall samples the sources at its own offsets,
scales and mirrors, so no two walls repeat.

    python art/tools/build_wall_finish_textures.py [--force]
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
LAYOUT = os.path.join(ROOT, "art", "data", "building_layout.json")
SRC = os.path.join(ROOT, "art", "textures", "wall_sources")
OUT_ROOT = os.path.join(ROOT, "art", "textures", "wall_finishes")
PX_PER_M = 96
MAX_PX = 1024

PLASTERS = ["plaster_calcimine", "plaster_distemper_green",
            "plaster_tide", "plaster_parchment"]
PAPERS = ["paper_damask", "paper_stripe", "paper_floral",
          "paper_anaglypta"]
# metres of wall each source image is assumed to cover
SCALE_M = {"plaster": 2.3, "paper": 1.9, "mask": 3.0, "relief": 2.0,
           "stain": 2.8}

_cache = {}


def load(name: str, gray: bool = False) -> np.ndarray:
    key = (name, gray)
    if key not in _cache:
        img = Image.open(os.path.join(SRC, name + ".png"))
        img = img.convert("L" if gray else "RGB")
        _cache[key] = np.asarray(img, dtype=np.float32) / 255.0
    return _cache[key]


def sample(arr: np.ndarray, length: float, h: float, wpx: int, hpx: int,
           covers_m: float, rng: np.random.Generator) -> np.ndarray:
    """Cut a wall-sized window from a source at real-world scale.

    The source is mirror-tiled as far as the wall needs, sampled from a
    random origin with random flips, then resized to the bake grid —
    every wall sees a different stretch of the same material.
    """
    src_h, src_w = arr.shape[:2]
    px_m = src_w / covers_m
    need_w = max(8, int(length * px_m))
    need_h = max(8, int(h * px_m))
    a = arr
    if rng.random() < 0.5:
        a = a[:, ::-1]
    if rng.random() < 0.5:
        a = a[::-1, :]
    # mirror-tile via reflected index grids
    ox = rng.integers(0, src_w)
    oy = rng.integers(0, src_h)
    ix = (np.arange(need_w) + ox)
    iy = (np.arange(need_h) + oy)

    def mirror(idx, n):
        period = 2 * n
        m = np.mod(idx, period)
        return np.where(m < n, m, period - 1 - m)
    window = a[np.ix_(mirror(iy, src_h), mirror(ix, src_w))]
    img = Image.fromarray((np.clip(window, 0, 1) * 255).astype(np.uint8))
    img = img.resize((wpx, hpx), Image.LANCZOS)
    return np.asarray(img, dtype=np.float32) / 255.0


def blur(a: np.ndarray, radius: float) -> np.ndarray:
    img = Image.fromarray((np.clip(a, 0.0, 1.0) * 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(radius)),
                      dtype=np.float32) / 255.0


def bake(wall: dict) -> None:
    fid = wall["finish_texture"]
    ax, ay = wall["a"]
    bx, by = wall["b"]
    z, h = wall["z"], wall["h"]
    horizontal = abs(by - ay) < 1e-6
    length = abs((bx - ax) if horizontal else (by - ay))
    if length < 0.3 or h < 0.5:
        return
    seed = int(round((ax + 31.0) * 17 + (ay + 37.0) * 29
                     + (bx + 41.0) * 11 + (by + 43.0) * 7
                     + (z + 5.0) * 13))
    decor_seed = abs(hash(fid)) % (2 ** 31)
    rng = np.random.default_rng(decor_seed)

    wpx = min(MAX_PX, max(128, int(length * PX_PER_M)))
    hpx = min(MAX_PX, max(128, int(h * PX_PER_M)))
    u = np.linspace(0.0, 1.0, wpx, dtype=np.float32)[None, :]
    v = np.linspace(1.0, 0.0, hpx, dtype=np.float32)[:, None]  # row 0 = top

    phase = (seed % 97) / 97.0 * math.tau
    leak_u = 0.68 + ((seed // 7) % 17) / 100.0
    island_u = 0.28 + ((seed // 11) % 35) / 100.0

    # --- causal likelihood of finish loss (0..1 field, not a stencil) ----
    tide = (0.075 + 0.052 * (np.sin(u * 8.2 + phase) * 0.5 + 0.5)
            + 0.030 * (np.sin(u * 21.0 + phase * 0.7) * 0.5 + 0.5))
    causal = np.clip((tide + 0.10 - v) * 5.0, 0.0, 1.0)
    leak_center = (leak_u + np.sin(v * 12.0 + phase) * 0.018
                   + np.sin(v * 31.0 + phase * 0.4) * 0.008)
    wet = 0.030 + np.maximum(0.0, 0.62 - v) * 0.10
    causal = np.maximum(causal, np.clip(
        (wet - np.abs(u - leak_center)) * 22.0, 0.0, 0.9) * (v < 0.62))
    for opening in wall.get("openings", []):
        center = opening["at"] / max(length, 0.001)
        half = opening["w"] * 0.5 / max(length, 0.001)
        top = (opening.get("sill", 0.0) + opening["h"]) / max(h, 0.001)
        for corner, direction in ((center - half, -1.0), (center + half, 1.0)):
            run = np.maximum(0.0, v - top)
            line_u = (corner + direction * run * 0.58
                      + np.sin(v * 43.0 + phase * 1.7) * 0.011)
            width = 0.015 + run * 0.05
            causal = np.maximum(causal, np.clip(
                (width - np.abs(u - line_u)) * 30.0, 0.0, 0.8) * (run < 0.30))
    du = (u - island_u) / 0.16
    dv = (v - 0.30) / 0.18
    causal = np.maximum(causal, np.clip(
        1.15 - (du * du + dv * dv), 0.0, 0.85))
    causal = np.maximum(causal, 0.08)   # a century leaves no wall untouched

    # --- survival mask: causal field gates the generated stencils --------
    sten_a = sample(load("mask_delamination", True), length, h, wpx, hpx,
                    SCALE_M["mask"], rng)
    sten_b = sample(load("mask_peel", True), length, h, wpx, hpx,
                    SCALE_M["mask"], rng)
    stencil = np.minimum(sten_a, 0.35 + sten_b * 0.65)
    missing = stencil < (0.04 + causal * 0.72)
    present = 1.0 - missing.astype(np.float32)
    present = (blur(present, 2.0) > 0.5).astype(np.float32)
    alpha = blur(present, 1.0)

    # --- surface build ---------------------------------------------------
    plaster_name = PLASTERS[decor_seed % len(PLASTERS)]
    albedo = sample(load(plaster_name), length, h, wpx, hpx,
                    SCALE_M["plaster"], rng)
    papered = (decor_seed % 10) < 5
    paper = np.zeros((hpx, wpx), dtype=np.float32)
    if papered:
        paper_name = PAPERS[(decor_seed // 7) % len(PAPERS)]
        paper_tex = sample(load(paper_name), length, h, wpx, hpx,
                           SCALE_M["paper"], rng)
        tear = sample(load("mask_paper_tear", True), length, h, wpx, hpx,
                      SCALE_M["mask"], rng)
        metres = u * length
        roll_pos = metres + (seed % 19) * 0.031
        roll = np.floor(roll_pos / 0.61).astype(np.int64)
        in_roll = np.mod(roll_pos, 0.61)
        rolls = (in_roll > 0.008) & (in_roll < 0.602)
        rolls &= ((roll * 7 + seed) % 10) < 6
        paper = (rolls & (tear > 0.45)
                 & (causal < 0.55)).astype(np.float32) * present
        paper = (blur(paper, 1.5) > 0.5).astype(np.float32)
        albedo = (albedo * (1.0 - paper[..., None])
                  + paper_tex * paper[..., None])

    # --- coherent moisture, leak and soot overlays -----------------------
    tide_tex = sample(load("stain_tide"), length, h, wpx, hpx,
                      SCALE_M["stain"], rng)
    leak_tex = sample(load("stain_leak"), length, h, wpx, hpx,
                      SCALE_M["stain"], rng)
    soot_tex = sample(load("stain_soot"), length, h, wpx, hpx,
                      SCALE_M["stain"], rng)
    tide_w = np.clip((tide + 0.16 - v) * 4.0, 0.0, 1.0) * 0.85
    leak_w = np.clip((0.06 - np.abs(u - leak_center)) * 12.0, 0.0, 1.0) \
        * np.clip(0.94 - v, 0.0, 1.0) * 0.8
    soot_w = np.clip((v - 0.78) * 2.5, 0.0, 1.0) * 0.55
    for tex, w in ((tide_tex, tide_w), (leak_tex, leak_w),
                   (soot_tex, soot_w)):
        albedo = albedo * (1.0 - w[..., None]) + albedo * tex * w[..., None]
    edge_band = np.clip(blur(present, 5.0) - blur(present, 1.2), 0.0, 1.0)
    albedo *= (1.0 - edge_band[..., None] * 0.45)

    # --- relief: crust + generated height detail -> normal ---------------
    relief = sample(load("relief_plaster", True), length, h, wpx, hpx,
                    SCALE_M["relief"], rng)
    height = (blur(present, 1.6) * 0.62 + relief * 0.26 * present
              + paper * 0.06)
    gy_, gx_ = np.gradient(height.astype(np.float32))
    scale = 6.0
    nx = -gx_ * scale
    ny = gy_ * scale
    nz = np.ones_like(height)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack(((nx / norm) * 0.5 + 0.5,
                       (ny / norm) * 0.5 + 0.5,
                       (nz / norm) * 0.5 + 0.5), axis=-1)

    lum = albedo.mean(axis=-1)
    rough = np.clip(0.92 - paper * 0.14 - tide_w * 0.18 - leak_w * 0.15
                    + (lum - 0.5) * 0.10, 0.35, 1.0)

    out_dir = os.path.join(OUT_ROOT, fid)
    os.makedirs(out_dir, exist_ok=True)
    rgba = np.concatenate([np.clip(albedo, 0.0, 1.0),
                           np.clip(alpha, 0.0, 1.0)[..., None]], axis=-1)
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(
        os.path.join(out_dir, "albedo.png"), optimize=True)
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8), "L").save(
        os.path.join(out_dir, "roughness.png"), optimize=True)
    Image.fromarray((np.clip(normal, 0, 1) * 255).astype(np.uint8),
                    "RGB").save(os.path.join(out_dir, "normal.png"),
                                optimize=True)


def main() -> None:
    force = "--force" in sys.argv
    with open(LAYOUT, encoding="utf-8") as fh:
        layout = json.load(fh)
    baked = skipped = 0
    for fl in layout["floors"]:
        for wall in fl["walls"]:
            fid = wall.get("finish_texture")
            if not fid:
                continue
            marker = os.path.join(OUT_ROOT, fid, "albedo.png")
            if os.path.exists(marker) and not force:
                skipped += 1
                continue
            bake(wall)
            baked += 1
    print("baked %d wall finishes (%d already present)" % (baked, skipped))


if __name__ == "__main__":
    main()
