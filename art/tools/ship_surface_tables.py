#!/usr/bin/env python3
"""MX-3 -- ship the height maps calibrated, and the wall mask library.

Two things the layered surface (game/shaders/orison_surface.gdshaderinc,
SurfacePass) needed from the ingest side, done at SHIP time so the art
sources stay as the ingest wrote them:

1. HEIGHT MAPS. The ingest's heights are band-passed luminance that never
   span 0..1 (face brick 0.39..0.65, concrete 0.45..0.54). Every catalog
   photographed set's height.png is stretched to its own p1..p99 range;
   independently authored physical maps retain their units. Both are written under
   game/assets/building/textures/height/<key>.png, and the calibration --
   millimetres of relief per base key, metres per tile from the set's
   material.json, the stretch applied -- is written to
   game/scripts/generated/surface_calibration.gd. SurfacePass reads that
   table; its two hand tables and its boot-time percentile measurement go.
   Each set's material.json gains "relief_mm".

2. THE MASK LIBRARY. art/textures/wall_sources holds the generated stencils
   and overlays the finish compiler uses; packed here into one RGBA tile,
   game/assets/building/textures/masks/wall_age.png, in the layered
   surface's mask convention -- R damage (delamination), G grime (soot),
   B moisture (leak + tide), A wear (peel) -- made seamless by the same
   half-roll crossfade the ingest uses. One fetch replaces four fbm fields
   for the standing age on walls.

Run from the repo root:  python art/tools/ship_surface_tables.py
Then:                     Godot --headless --path game --import
"""
from __future__ import annotations

import json
import os
import argparse

import numpy as np
from PIL import Image
from ingest_material_sources import INDEPENDENT_SURFACES

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
MAPPING = os.path.join(ROOT, "art", "textures", "catalog_mapping.json")
TEX_ROOT = os.path.join(ROOT, "art", "textures")
HEIGHT_OUT = os.path.join(ROOT, "game", "assets", "building", "textures", "height")
MASK_OUT = os.path.join(ROOT, "game", "assets", "building", "textures", "masks")
GD_OUT = os.path.join(ROOT, "game", "scripts", "generated", "surface_calibration.gd")
WALL_SOURCES = os.path.join(TEX_ROOT, "wall_sources")

# Millimetres of relief spanned by a set's height map once stretched. Mortar
# is the deepest thing on the building; a board seam is barely anything.
# Per BASE key; family variants (_b/_c/_d) inherit.
RELIEF_MM = {
    "face_brick": 10.0, "common_brick": 9.0, "brick": 9.0, "brick_patched": 9.0,
    "concrete": 3.0, "slab": 3.0, "limestone": 4.0, "subway_tile": 3.0,
    "ceramic": 2.5, "terrazzo": 0.6,
    "stair": INDEPENDENT_SURFACES["stair"]["relief_mm"], "landing": 2.0,
    "floor_oak": 1.5, "wainscot": 6.0, "tin_ceiling": 6.0, "cast_iron": 2.0,
    "sidewalk_haunted": 5.0, "asphalt": 5.0, "wet_asphalt": 4.0,
    "marble_lobby": 1.0, "linoleum": 0.8, "plywood": 1.0, "timber": 2.5,
    "stair_treads": 2.0, "trim": 1.5, "wainscot_beadboard": 6.0,
}
VARIANT_SUFFIXES = ("_b", "_c", "_d")
MASK_SIZE = 1024


def base_key(key: str) -> str:
    for s in VARIANT_SUFFIXES:
        if key.endswith(s):
            return key[:-2]
    return key


def crossfade_tile(img: np.ndarray) -> np.ndarray:
    """Half-roll crossfade (the ingest's seamless rule) for a 2-D or 3-D array."""
    h, w = img.shape[:2]
    rolled = np.roll(np.roll(img, h // 2, axis=0), w // 2, axis=1)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    wx = np.clip(np.abs(xx - w / 2) / (w / 2), 0, 1)
    wy = np.clip(np.abs(yy - h / 2) / (h / 2), 0, 1)
    # weight 1 at the centre (original), 0 at the edges (rolled), smooth
    wgt = (1.0 - np.maximum(wx, wy)) ** 1.5
    wgt = wgt[..., None] if img.ndim == 3 else wgt
    return img * wgt + rolled * (1.0 - wgt)


def ship_heights(keys=None) -> dict:
    with open(MAPPING, encoding="utf-8") as stream:
        mapping = json.load(stream)
    os.makedirs(HEIGHT_OUT, exist_ok=True)
    table = {}
    for key, rel in sorted(mapping.items()):
        base = base_key(key)
        if base not in RELIEF_MM:
            continue
        set_dir = os.path.join(TEX_ROOT, rel)
        hp = os.path.join(set_dir, "height.png")
        mp = os.path.join(set_dir, "material.json")
        if not os.path.exists(hp):
            continue
        meta = {}
        if os.path.exists(mp):
            with open(mp, encoding="utf-8") as stream:
                meta = json.load(stream)
        h = np.asarray(Image.open(hp).convert("L"), dtype=np.float32) / 255.0
        physical = INDEPENDENT_SURFACES.get(base)
        if physical and meta.get("height_model") == physical["model"]:
            # Its authored normal already encodes this physical height span.
            # Percentile stretching here would amplify only the height map.
            lo, hi, stretched = 0.0, 1.0, h
        else:
            lo, hi = np.percentile(h, 1.0), np.percentile(h, 99.0)
            if hi - lo < 0.02:
                hi = lo + 0.02
            stretched = np.clip((h - lo) / (hi - lo), 0, 1)
        selected = keys is None or key in keys
        if selected:
            pixels = np.rint(stretched * 255) if physical and meta.get("height_model") == physical["model"] else stretched * 255
            Image.fromarray(pixels.astype(np.uint8), "L").save(
                os.path.join(HEIGHT_OUT, key + ".png"), optimize=True)
        tile_m = 1.0
        if os.path.exists(mp):
            tile_m = float(meta.get("meters_per_tile", 1.0))
            if selected and meta.get("relief_mm") != RELIEF_MM[base]:
                meta["relief_mm"] = RELIEF_MM[base]
                with open(mp, "w", encoding="utf-8") as stream:
                    json.dump(meta, stream, indent=2)
        table[key] = {"relief_mm": RELIEF_MM[base], "tile_m": tile_m,
                      "source_range": [round(float(lo), 3), round(float(hi), 3)]}
        print("%-22s relief %4.1f mm  tile %.2f m  stretched %.2f..%.2f -> 0..1"
              % (key, RELIEF_MM[base], tile_m, lo, hi))
    return table


def ship_masks() -> None:
    def load(name: str, invert: bool) -> np.ndarray:
        img = Image.open(os.path.join(WALL_SOURCES, name + ".png")).convert("L")
        img = img.resize((MASK_SIZE, MASK_SIZE), Image.LANCZOS)
        a = np.asarray(img, dtype=np.float32) / 255.0
        return 1.0 - a if invert else a
    damage = load("mask_delamination", True)
    grime = load("stain_soot", True)
    moisture = np.clip(load("stain_leak", True) * 1.2 + load("stain_tide", True) * 0.9, 0, 1)
    wear = load("mask_peel", True)
    # Normalise each field so its useful range is 0..1 (the stains are faint).
    def norm(a: np.ndarray) -> np.ndarray:
        lo, hi = np.percentile(a, 2.0), np.percentile(a, 99.5)
        return np.clip((a - lo) / max(1e-3, hi - lo), 0, 1)
    pack = np.stack((norm(damage), norm(grime), norm(moisture), norm(wear)), axis=-1)
    pack = crossfade_tile(pack)
    os.makedirs(MASK_OUT, exist_ok=True)
    Image.fromarray((np.clip(pack, 0, 1) * 255).astype(np.uint8), "RGBA").save(
        os.path.join(MASK_OUT, "wall_age.png"), optimize=True)
    with open(os.path.join(MASK_OUT, "SOURCE.md"), "w", encoding="utf-8") as fh:
        fh.write("# wall_age.png\n\nPacked by art/tools/ship_surface_tables.py from "
                 "art/textures/wall_sources: R damage (mask_delamination), G grime "
                 "(stain_soot), B moisture (stain_leak + stain_tide), A wear (mask_peel); "
                 "half-roll crossfade for seamlessness. The layered surface's mask_tex "
                 "convention; mask_tile_m sets its size in metres.\n")
    print("masks: wall_age.png  coverage damage %.1f%% grime %.1f%% moisture %.1f%% wear %.1f%%"
          % tuple(float((pack[..., i] > 0.5).mean() * 100) for i in range(4)))


def write_gd(table: dict) -> None:
    lines = [
        "extends RefCounted",
        "## GENERATED by art/tools/ship_surface_tables.py -- do not edit.",
        "## Per shipped height map: millimetres of relief spanned by 0..1 (the map",
        "## uses 0..1: photographed maps are percentile-stretched; independent",
        "## physical maps keep their units), plus metres per tile from material.json.",
        "const CALIBRATION := {",
    ]
    for key in sorted(table):
        e = table[key]
        lines.append('\t"%s": {"relief_mm": %.2f, "tile_m": %.3f, "source_range": Vector2(%.3f, %.3f)},'
                     % (key, e["relief_mm"], e["tile_m"], e["source_range"][0], e["source_range"][1]))
    lines.append("}")
    lines.append("")
    os.makedirs(os.path.dirname(GD_OUT), exist_ok=True)
    with open(GD_OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))
    print("wrote", GD_OUT, "(%d keys)" % len(table))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--key", action="append", help="ship only these height maps; keep the complete calibration table")
    args = parser.parse_args()
    keys = set(args.key) if args.key else None
    table = ship_heights(keys)
    if keys and not keys.issubset(table):
        raise SystemExit("Unknown or unavailable height keys: " + ", ".join(sorted(keys - table.keys())))
    write_gd(table)
    if keys is None:
        ship_masks()


if __name__ == "__main__":
    main()
