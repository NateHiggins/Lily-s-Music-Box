"""Bake one unique plaster/wallpaper finish per room-facing masonry wall.

gen_layout's construction audit stamps every retained envelope wall with a
`finish_texture` id; this tool reads art/data/building_layout.json and
bakes art/textures/wall_finishes/<id>/{albedo,roughness,normal}.png for
each. build_orison.py builds a quad 6 mm proud of the brick and wires
these maps in — the ALBEDO ALPHA is the survival mask, so wherever the
century has stripped the finish, the quad goes transparent and the real
brick wall behind it shows through.

The damage is cause-shaped, never sprinkled (ported from the retired
geometric finish pass): rising damp draws an uneven tide line at the
floor; one high leak wanders down; settlement cracks fan from opening
corners; one broad delamination island bridges them. Wallpaper lives in
real 0.61 m roll widths, dies before plaster at damp edges, and many
rolls are already stripped. A relief heightmap — plaster slab over
brick, feathered torn edges, paper lift, trowel noise — is baked to the
normal map so the survivors read as a raised crust, and moisture stains
cross paper and plaster in one coherent overlay.

Per-wall uniqueness: the wall's own coordinates seed the damage (as the
geometric pass did), and the id seeds the decor - papered, painted, or
bare scarred plaster, in a period palette.

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
OUT_ROOT = os.path.join(ROOT, "art", "textures", "wall_finishes")
PX_PER_M = 96
MAX_PX = 1024

# Period decor, faded a century: (name, background, ink) in 0..1 sRGB.
PALETTES = [
    ("dusty_rose", (0.760, 0.640, 0.600), (0.580, 0.420, 0.400)),
    ("sage", (0.660, 0.700, 0.610), (0.470, 0.540, 0.430)),
    ("ochre", (0.780, 0.690, 0.500), (0.620, 0.500, 0.320)),
    ("teal_gaslight", (0.560, 0.660, 0.650), (0.360, 0.480, 0.480)),
    ("burgundy", (0.610, 0.450, 0.430), (0.430, 0.280, 0.280)),
    ("parlor_cream", (0.800, 0.760, 0.660), (0.640, 0.580, 0.460)),
]
PLASTERS = [
    (0.815, 0.790, 0.735),   # aged lime white
    (0.790, 0.775, 0.700),   # nicotine cream
    (0.755, 0.760, 0.700),   # sick pale green
    (0.800, 0.760, 0.690),   # old parchment
]
PAINTS = [
    (0.700, 0.720, 0.680), (0.740, 0.700, 0.600), (0.640, 0.680, 0.700),
]


def blur(a: np.ndarray, radius: float) -> np.ndarray:
    img = Image.fromarray((np.clip(a, 0.0, 1.0) * 255).astype(np.uint8))
    img = img.filter(ImageFilter.GaussianBlur(radius))
    return np.asarray(img, dtype=np.float32) / 255.0


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
    # v runs bottom-up in wall space; image row 0 is the TOP of the wall.
    v = np.linspace(1.0, 0.0, hpx, dtype=np.float32)[:, None]

    phase = (seed % 97) / 97.0 * math.tau
    leak_u = 0.68 + ((seed // 7) % 17) / 100.0
    island_u = 0.28 + ((seed // 11) % 35) / 100.0

    # --- cause-shaped loss ------------------------------------------------
    tide = (0.075 + 0.052 * (np.sin(u * 8.2 + phase) * 0.5 + 0.5)
            + 0.030 * (np.sin(u * 21.0 + phase * 0.7) * 0.5 + 0.5))
    missing = (v < tide)
    leak_center = (leak_u + np.sin(v * 12.0 + phase) * 0.018
                   + np.sin(v * 31.0 + phase * 0.4) * 0.008)
    wet_width = 0.022 + np.maximum(0.0, 0.62 - v) * 0.095
    missing |= (v < 0.60) & (np.abs(u - leak_center) < wet_width)
    for opening in wall.get("openings", []):
        center = opening["at"] / max(length, 0.001)
        half = opening["w"] * 0.5 / max(length, 0.001)
        top = (opening.get("sill", 0.0) + opening["h"]) / max(h, 0.001)
        for corner, direction in ((center - half, -1.0), (center + half, 1.0)):
            run = np.maximum(0.0, v - top)
            # cracks meander at mortar joints instead of drawing rulers
            line_u = (corner + direction * run * 0.58
                      + np.sin(v * 43.0 + phase * 1.7) * 0.011)
            width = 0.008 + run * 0.05
            missing |= (run < 0.30) & (np.abs(u - line_u) < width)
            du = (u - (corner + direction * 0.055)) / 0.115
            dv = (v - (top - 0.075)) / 0.16
            missing |= (du * du + dv * dv) < 1.0
    du = (u - island_u) / 0.17
    dv = (v - 0.27) / 0.19
    wobble = (0.86 + 0.10 * np.sin(u * 29.0 + phase)
              + 0.07 * np.sin(v * 37.0 - phase))
    missing |= (du * du + dv * dv) < wobble

    present = 1.0 - missing.astype(np.float32)
    # Torn plaster breaks along aggregate, not sine curves: erode the edge
    # with fine noise so the boundary crumbles at brick scale.
    edge_noise = (np.sin(u * 231.0 + phase * 3.1)
                  * np.sin(v * 197.0 - phase * 2.3)
                  + rng.standard_normal((hpx, wpx)).astype(np.float32) * 0.55)
    soft = blur(present, 2.5)
    present = ((soft + edge_noise * 0.09) > 0.5).astype(np.float32)
    alpha = blur(present, 1.0)

    # --- decor class ------------------------------------------------------
    style = ["papered", "painted", "bare"][int(decor_seed % 10 > 5)
                                           + int(decor_seed % 10 > 8)]
    plaster_rgb = np.array(PLASTERS[decor_seed % len(PLASTERS)],
                           dtype=np.float32)
    palette = PALETTES[(decor_seed // 7) % len(PALETTES)]
    paper_bg = np.array(palette[1], dtype=np.float32)
    paper_ink = np.array(palette[2], dtype=np.float32)

    trowel = blur(rng.standard_normal((hpx, wpx)).astype(np.float32) * 0.5
                  + 0.5, 6.0) - 0.5
    albedo = plaster_rgb[None, None, :] * (1.0 + trowel[..., None] * 0.14)

    paper = np.zeros((hpx, wpx), dtype=np.float32)
    if style == "papered":
        metres = u * length
        roll_pos = metres + (seed % 19) * 0.031
        roll = np.floor(roll_pos / 0.61).astype(np.int64)
        in_roll = np.mod(roll_pos, 0.61)
        paper_mask = (in_roll > 0.012) & (in_roll < 0.598)
        paper_mask &= ((roll * 7 + seed) % 10) < 4
        paper_mask = paper_mask & np.broadcast_to(
            np.ones_like(v, dtype=bool), (hpx, wpx))
        paper_mask &= ~(v < tide + 0.10)
        paper_mask &= ~(np.abs(u - leak_center)
                        < 0.055 + np.maximum(0.0, 0.72 - v) * 0.04)
        torn_edge = 0.18 + ((roll * 13 + seed) % 9).astype(np.float32) * 0.018
        paper_mask &= (v > torn_edge)
        paper = paper_mask.astype(np.float32) * present
        # the pattern: stripes, lattice, or sprig dots, by wall
        kind = (decor_seed // 13) % 3
        um = u * length
        vm = v * h
        if kind == 0:        # striped paper
            pat = (np.sin(um * math.tau / 0.115) * 0.5 + 0.5 > 0.55)
            pattern = pat.astype(np.float32) * 0.85
        elif kind == 1:      # damask-ish diamond lattice
            pat = (np.sin(um * math.tau / 0.24 + vm * math.tau / 0.30)
                   * np.sin(um * math.tau / 0.24 - vm * math.tau / 0.30))
            pattern = np.clip(pat * 2.2, 0.0, 1.0)
        else:                # sprig dots on a half-drop grid
            gx = np.mod(um, 0.17) - 0.085
            gy = np.mod(vm + np.floor(um / 0.17) * 0.085, 0.17) - 0.085
            pattern = (np.sqrt(gx * gx + gy * gy) < 0.021).astype(np.float32)
        paper_rgb = (paper_bg[None, None, :] * (1.0 - pattern[..., None])
                     + paper_ink[None, None, :] * pattern[..., None])
        albedo = (albedo * (1.0 - paper[..., None])
                  + paper_rgb * paper[..., None])
    elif style == "painted":
        paint_rgb = np.array(PAINTS[decor_seed % len(PAINTS)],
                             dtype=np.float32)
        # paint survives patchily; bare plaster grins through worn zones
        wear = blur(rng.standard_normal((hpx, wpx)).astype(np.float32)
                    * 0.5 + 0.5, 14.0)
        coat = np.clip((wear - 0.36) * 4.0, 0.0, 1.0) * present
        albedo = (albedo * (1.0 - coat[..., None])
                  + paint_rgb[None, None, :]
                  * (1.0 + trowel[..., None] * 0.10) * coat[..., None])

    # --- one coherent moisture overlay ------------------------------------
    stain = np.zeros((hpx, wpx), dtype=np.float32)
    stain += np.clip((tide + 0.11 - v) * 9.0, 0.0, 1.0)
    width = 0.035 + np.maximum(0.0, 0.90 - v) * 0.035
    stain += np.clip((width - np.abs(u - leak_center)) * 30.0, 0.0, 1.0) \
        * (v < 0.94)
    stain = np.clip(blur(stain, 5.0), 0.0, 1.0)
    stain_rgb = np.array((0.42, 0.36, 0.30), dtype=np.float32)
    albedo = albedo * (1.0 - stain[..., None] * 0.45) \
        + stain_rgb[None, None, :] * stain[..., None] * 0.28
    # grime collects at the torn boundary and in a soot veil up top
    edge_band = np.clip(blur(present, 5.0) - blur(present, 1.2), 0.0, 1.0)
    albedo *= (1.0 - edge_band[..., None] * 0.55)
    soot = np.clip((v - 0.80) * 2.2, 0.0, 1.0)
    albedo *= (1.0 - soot[..., None] * 0.16)

    # --- relief bitmap -> normal map --------------------------------------
    height = blur(present, 2.0) * 0.72 + paper * 0.10 + trowel * 0.12 \
        - stain * 0.05
    gy_, gx_ = np.gradient(height.astype(np.float32))
    # v axis is flipped in image rows; flip Y so bumps light correctly
    scale = 5.2
    nx = -gx_ * scale
    ny = gy_ * scale
    nz = np.ones_like(height)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack(((nx / norm) * 0.5 + 0.5,
                       (ny / norm) * 0.5 + 0.5,
                       (nz / norm) * 0.5 + 0.5), axis=-1)

    rough = (0.84 + trowel * 0.08 - paper * 0.12 - stain * 0.24
             + edge_band * 0.08)

    out_dir = os.path.join(OUT_ROOT, fid)
    os.makedirs(out_dir, exist_ok=True)
    rgba = np.concatenate([np.clip(albedo, 0.0, 1.0),
                           np.clip(alpha, 0.0, 1.0)[..., None]], axis=-1)
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(
        os.path.join(out_dir, "albedo.png"), optimize=True)
    Image.fromarray((np.clip(rough, 0.0, 1.0) * 255).astype(np.uint8),
                    "L").save(os.path.join(out_dir, "roughness.png"),
                              optimize=True)
    Image.fromarray((np.clip(normal, 0.0, 1.0) * 255).astype(np.uint8),
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
