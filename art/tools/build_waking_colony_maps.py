#!/usr/bin/env python3
"""Deterministic PBR recipes for the waking colony's organelles and cilia.

RUL-012, by Lily's ruling waking_cell_surface_rule_20261109: the colony's
organelles and cilia are physical surfaces and owe registered maps. Only the
lensing membrane is an optical effect.

Six recipes, each an analytic construction that tiles in both directions. No
reference pixel is read, baked or stored, and nothing here draws a letter,
a numeral or a mark.

    chromatin   nucleus and nucleolus: dense islands between paler channels,
                with pore dimples in the envelope
    vesicle     vacuoles: a wet, nearly clear wall with faint thickness drift
    cristae     mitochondria: a folded inner membrane read through the wall
    granule     storage granules: grains with concentric growth lamellae
    fibre       filaments: two crossed families of fibrils
    cuticle     cilia: lengthwise striae and sparse sockets on a jointed limb

Albedo is a pale neutral carrying only the structure; the shader multiplies
it by the organelle's own colour. The cell is half a metre across, so a
recipe's tile is sized to its organelle, not to biology; the renderer's
uv_tile is the mesh's measured metres per UV unit over meters_per_tile. The smart-projected meshes have islands at
arbitrary angles, so every recipe except the cuticle is free of a preferred
direction. The cilium's UVs are authored (u around, v along), so the cuticle
may run along the limb.

Outputs, for each recipe, in game/assets/dream/waking_colony/:
    <name>_albedo.png  <name>_roughness.png  <name>_normal.png (OpenGL)
    <name>_recipe.json

Run from the repo root:  python art/tools/build_waking_colony_maps.py [--check]
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/dream/waking_colony"
SOURCE = "art/tools/build_waking_colony_maps.py"
TAU = 2.0 * np.pi


def grid(n: int):
    y, x = np.mgrid[:n, :n].astype(np.float64) / n
    return x, y


def lattice(n: int, cells: int, seed: int) -> np.ndarray:
    """Smooth value noise in [0, 1] that wraps at the tile edge."""
    rng = np.random.default_rng(seed)
    values = rng.random((cells, cells))
    x, y = grid(n)
    fx, fy = x * cells, y * cells
    ix, iy = np.floor(fx).astype(int), np.floor(fy).astype(int)
    tx, ty = fx - ix, fy - iy
    tx = tx * tx * (3.0 - 2.0 * tx)
    ty = ty * ty * (3.0 - 2.0 * ty)
    a = values[iy % cells, ix % cells]
    b = values[iy % cells, (ix + 1) % cells]
    c = values[(iy + 1) % cells, ix % cells]
    d = values[(iy + 1) % cells, (ix + 1) % cells]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def fbm(n: int, cells: int, octaves: int, seed: int) -> np.ndarray:
    total = np.zeros((n, n))
    weight = 0.0
    for o in range(octaves):
        gain = 0.5 ** o
        total += lattice(n, cells * 2 ** o, seed + 101 * o) * gain
        weight += gain
    return total / weight


def worley(n: int, cells: int, seed: int, jitter: float = 0.9):
    """Nearest and second-nearest feature distance, in cell units, wrapping.
    Also returns a stable random value for the nearest cell."""
    rng = np.random.default_rng(seed)
    px = (rng.random((cells, cells)) - 0.5) * jitter + 0.5
    py = (rng.random((cells, cells)) - 0.5) * jitter + 0.5
    tag = rng.random((cells, cells))
    x, y = grid(n)
    fx, fy = x * cells, y * cells
    ix, iy = np.floor(fx).astype(int), np.floor(fy).astype(int)
    f1 = np.full((n, n), 9.0)
    f2 = np.full((n, n), 9.0)
    near = np.zeros((n, n))
    cx = np.zeros((n, n))
    cy = np.zeros((n, n))
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            jx, jy = (ix + ox) % cells, (iy + oy) % cells
            dx = (ix + ox + px[jy, jx]) - fx
            dy = (iy + oy + py[jy, jx]) - fy
            dist = np.sqrt(dx * dx + dy * dy)
            closer = dist < f1
            f2 = np.where(closer, f1, np.minimum(f2, dist))
            near = np.where(closer, tag[jy, jx], near)
            cx = np.where(closer, dx, cx)
            cy = np.where(closer, dy, cy)
            f1 = np.where(closer, dist, f1)
    return f1, f2, near, cx, cy


def smooth(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
    t = np.clip((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def soften(field: np.ndarray, passes: int) -> np.ndarray:
    """A wrapping box blur: keeps the tile seamless, unlike an image filter."""
    for _ in range(passes):
        field = (field + np.roll(field, 1, 0) + np.roll(field, -1, 0)
                 + np.roll(field, 1, 1) + np.roll(field, -1, 1)) / 5.0
    return field


def normal_from_height(height: np.ndarray, strength: float) -> np.ndarray:
    """OpenGL tangent normal (green up) from a wrapping height field."""
    n = height.shape[0]
    gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5 * n
    gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5 * n
    normal = np.stack((-gx * strength, gy * strength, np.ones_like(gx)), axis=-1)
    return normal / np.linalg.norm(normal, axis=-1, keepdims=True)


def chromatin(n: int):
    f1, f2, tag, _, _ = worley(n, 7, 4101)
    drift = fbm(n, 4, 4, 4102)
    islands = smooth(0.62, 0.18, f1 + (drift - 0.5) * 0.35)
    channels = smooth(0.02, 0.16, f2 - f1)
    p1, _, _, _, _ = worley(n, 22, 4103, jitter=0.6)
    pores = smooth(0.20, 0.07, p1) * (1.0 - islands * 0.6)
    height = soften(0.25 + 0.55 * islands * channels + 0.10 * drift - 0.22 * pores, 2)
    shade = 0.74 + 0.20 * (1.0 - islands) + 0.05 * (tag - 0.5) - 0.16 * pores
    warm = islands * 0.035
    albedo = np.stack((shade + warm, shade - warm * 0.4, shade + warm * 0.6), axis=-1)
    roughness = 0.40 + 0.16 * islands - 0.10 * pores + 0.05 * (drift - 0.5)
    return albedo, roughness, height, 0.110, 0.00090


def vesicle(n: int):
    drift = fbm(n, 3, 4, 4201)
    film = 0.5 + 0.5 * np.sin(TAU * (drift * 2.2 + lattice(n, 5, 4202)))
    d1, _, _, _, _ = worley(n, 9, 4203, jitter=0.8)
    droplets = smooth(0.16, 0.05, d1)
    height = soften(0.5 + 0.20 * (drift - 0.5) + 0.10 * droplets, 3)
    shade = 0.86 + 0.07 * (film - 0.5) + 0.05 * droplets
    albedo = np.stack((shade - 0.012 * film, shade, shade + 0.018 * film), axis=-1)
    roughness = 0.085 + 0.05 * (drift - 0.5) + 0.07 * droplets
    return albedo, roughness, height, 0.110, 0.00022


def cristae(n: int):
    # Level bands of a smooth wrapping field fold like a labyrinth, with no
    # preferred direction. A second field breaks the bands into shelves.
    field = fbm(n, 3, 3, 4301)
    folds = 0.5 + 0.5 * np.sin(TAU * field * 9.0)
    ridges = smooth(0.35, 0.80, folds)
    breaks = smooth(0.42, 0.55, lattice(n, 9, 4302))
    ridges = ridges * (0.55 + 0.45 * breaks)
    height = soften(0.22 + 0.62 * ridges, 1)
    shade = 0.70 + 0.22 * ridges
    albedo = np.stack((shade + 0.03 * ridges, shade, shade - 0.035 * ridges), axis=-1)
    roughness = 0.52 - 0.18 * ridges + 0.04 * (lattice(n, 24, 4303) - 0.5)
    return albedo, roughness, height, 0.040, 0.00035


def granule(n: int):
    f1, f2, tag, _, _ = worley(n, 6, 4401, jitter=0.75)
    edge = smooth(0.0, 0.14, f2 - f1)
    lamellae = 0.5 + 0.5 * np.cos(TAU * f1 * (5.0 + 3.0 * tag))
    dome = np.clip(1.0 - f1 * 1.25, 0.0, 1.0) ** 0.6
    height = soften(edge * (0.30 + 0.50 * dome + 0.07 * lamellae), 1)
    shade = 0.72 + 0.16 * dome * edge + 0.06 * (lamellae - 0.5) + 0.05 * (tag - 0.5)
    albedo = np.stack((shade + 0.02, shade + 0.01, shade - 0.04 * dome), axis=-1)
    roughness = 0.46 - 0.14 * dome * edge + 0.08 * (1.0 - edge) + 0.04 * (lamellae - 0.5)
    return albedo, roughness, height, 0.043, 0.00050


def fibre(n: int):
    x, y = grid(n)
    wander = (fbm(n, 3, 3, 4501) - 0.5) * 0.9
    one = 0.5 + 0.5 * np.sin(TAU * (11.0 * (x + y) + wander))
    two = 0.5 + 0.5 * np.sin(TAU * (9.0 * (x - y) - wander * 1.3 + 0.25))
    over = smooth(0.35, 0.65, lattice(n, 8, 4502))
    strands = np.maximum(one ** 2.2 * (0.6 + 0.4 * over), two ** 2.2 * (1.0 - 0.4 * over))
    height = soften(0.18 + 0.70 * strands, 1)
    shade = 0.68 + 0.24 * strands
    albedo = np.stack((shade, shade - 0.015 * strands, shade + 0.03 * strands), axis=-1)
    roughness = 0.50 - 0.20 * strands + 0.05 * (lattice(n, 30, 4503) - 0.5)
    return albedo, roughness, height, 0.035, 0.00021


def cuticle(n: int):
    x, y = grid(n)
    wander = (fbm(n, 2, 3, 4601) - 0.5) * 0.35
    striae = 0.5 + 0.5 * np.sin(TAU * (14.0 * x + wander + 0.6 * np.sin(TAU * y)))
    striae = striae ** 1.6
    rings = smooth(0.80, 0.97, 0.5 + 0.5 * np.cos(TAU * (2.0 * y + 0.12 * np.sin(TAU * 2.0 * x))))
    s1, _, tag, _, _ = worley(n, 8, 4602, jitter=0.7)
    sockets = smooth(0.17, 0.08, s1) * (tag > 0.55)
    rims = smooth(0.26, 0.19, s1) * (tag > 0.55) - sockets
    height = soften(0.30 + 0.34 * striae + 0.20 * rings + 0.22 * rims - 0.24 * sockets, 1)
    shade = 0.76 + 0.14 * striae - 0.10 * rings - 0.14 * sockets
    albedo = np.stack((shade + 0.015, shade, shade + 0.03 * striae), axis=-1)
    roughness = 0.26 - 0.08 * striae + 0.16 * rings + 0.20 * sockets
    return albedo, roughness, height, 0.025, 0.00015


RECIPES = {
    # name: (builder, pixels, what it is)
    "chromatin": (chromatin, 512,
                  "wrapping cellular islands with channels between them and pore dimples"),
    "vesicle": (vesicle, 256,
                "low wrapping thickness drift and sparse adhering droplets on a wet wall"),
    "cristae": (cristae, 256,
                "level bands of a wrapping smooth field, broken into shelves"),
    "granule": (granule, 256,
                "wrapping cellular grains, domed, with concentric lamellae"),
    "fibre": (fibre, 256,
              "two crossed families of wandering fibrils with an over-and-under mask"),
    "cuticle": (cuticle, 256,
                "lengthwise striae, segment rings and sparse rimmed sockets"),
}


def to_png(values: np.ndarray) -> Image.Image:
    data = (np.clip(values, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    return Image.fromarray(data, "RGB" if data.ndim == 3 else "L")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(name: str) -> dict:
    builder, pixels, construction = RECIPES[name]
    albedo, roughness, height, tile_m, relief_m = builder(pixels)
    # The relief in metres over the tile in metres gives the true slope.
    span = float(height.max() - height.min())
    strength = relief_m / max(span, 1e-6) / tile_m
    normal = normal_from_height((height - height.min()) / max(span, 1e-6) * span, strength)
    maps = {"albedo": albedo, "roughness": roughness, "normal": normal * 0.5 + 0.5}
    hashes = {}
    for channel, values in maps.items():
        path = OUT / f"{name}_{channel}.png"
        to_png(values).save(path, optimize=True)
        hashes[channel] = sha256(path)
    recipe = {
        "material_key": "waking_colony_" + name,
        "source": SOURCE,
        "provenance": "analytic, seeded and periodic: " + construction,
        "pixels": pixels,
        "meters_per_tile": tile_m,
        "relief_m": relief_m,
        "normal_convention": "OpenGL",
        "albedo_role": "pale neutral structure; the shader multiplies the organelle colour",
        "reference_policy": "No reference image was read, baked, projected or stored.",
        "maps": {channel: f"{name}_{channel}.png" for channel in maps},
        "map_sha256": hashes,
    }
    (OUT / f"{name}_recipe.json").write_text(json.dumps(recipe, indent=1) + "\n", newline="\n")
    return recipe


def check() -> int:
    failures = []
    for name in RECIPES:
        path = OUT / f"{name}_recipe.json"
        if not path.is_file():
            failures.append(f"{name}: recipe missing")
            continue
        recipe = json.loads(path.read_text())
        for channel, wanted in recipe["map_sha256"].items():
            found = OUT / recipe["maps"][channel]
            if not found.is_file() or sha256(found) != wanted:
                failures.append(f"{name}: {channel} does not match its recipe")
    for line in failures:
        print("FAIL", line)
    print("waking colony maps: %d recipes, %d failures" % (len(RECIPES), len(failures)))
    return 1 if failures else 0


def main() -> int:
    if "--check" in sys.argv:
        return check()
    OUT.mkdir(parents=True, exist_ok=True)
    for name in RECIPES:
        recipe = build(name)
        print("%-10s %4d px  tile %.3f m  relief %.2f mm" % (
            name, recipe["pixels"], recipe["meters_per_tile"], recipe["relief_m"] * 1000.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
