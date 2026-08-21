#!/usr/bin/env python3
"""CT-1 -- family skin atlases for the dream fauna, built from the plates.

Owner direction 2026-08-21: "a variety of hyperdimensional critters we have
sketched need detailed textures, build them from the ones we made". No new
generation; every family's skin is a COMPOSITION of the six cases' substance
plates already ingested under game/assets/dream/incarnations/<case>/.

The fauna meshes have no UVs. They carry CUSTOM0 = (body_t, angle/TAU + 0.5)
-- position along the body and angle around it -- which is a cylindrical
atlas coordinate: u runs along the creature, v around it. Each atlas is
composed in that space:

    base     plate A, tiled along the body and around it, with a hashed
             per-tile rotation so the plate's own repeat does not show
    bands    plate B in soft bands along the body (segments, rings, pleats)
    wires    the cloisonne wire lattice the shader already draws, rasterised
             here in atlas space and filled with plate C (the gold), so the
             shader's gold_mask and the atlas agree
    jewels   cells of plate D where its luminance peaks (eyes, buttons,
             beads) -- mask G
    wear     the crests of the composed height -- mask B

Outputs per family (1024 x 1024 PNG):
    game/assets/dream/fauna_skins/<family>/albedo.png   RGB
    game/assets/dream/fauna_skins/<family>/normal.png   OpenGL tangent normal
    game/assets/dream/fauna_skins/<family>/mask.png     R gold  G jewel  B wear

Run from the repo root:  python art/tools/build_fauna_skins.py [--preview]
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
PLATES = os.path.join(ROOT, "game", "assets", "dream", "incarnations")
OUT = os.path.join(ROOT, "game", "assets", "dream", "fauna_skins")
SIZE = 1024

# Family -> recipe. Plates are "<case>/<plate>"; the shader's family_motif
# index orders them (DreamFaunaDirector.FAMILY_LABELS).
FAMILIES = [
    {"key": "gilders_button", "motif": 0,
     "base": "mina/lens_membrane", "band": "mae/lacquer_craquelure",
     "gold": "mina/gilt_edge", "jewel": "cal/dial_glass",
     "tiles": (2, 3), "band_period": 3.0, "band_width": 0.22,
     "wire_scale": 24.0, "wire_width": 0.075, "jewel_threshold": 0.72,
     "tint": (1.00, 0.92, 0.98)},
    {"key": "tessellate", "motif": 1,
     "base": "mae/marquetry_grain", "band": "peter/ledger_stock",
     "gold": "omar/solder_alloy", "jewel": "juno/bakelite",
     "tiles": (3, 4), "band_period": 6.0, "band_width": 0.30,
     "wire_scale": 34.0, "wire_width": 0.06, "jewel_threshold": 0.80,
     "tint": (0.96, 0.90, 0.86)},
    {"key": "wine_anemone", "motif": 2,
     "base": "mina/ink_fiber", "band": "juno/speaker_cloth",
     "gold": "juno/oxidized_brass", "jewel": "mae/aged_glass",
     "tiles": (1, 4), "band_period": 2.0, "band_width": 0.18,
     "wire_scale": 20.0, "wire_width": 0.09, "jewel_threshold": 0.78,
     "tint": (0.92, 0.80, 0.96)},
    {"key": "ribbonette", "motif": 3,
     "base": "juno/diaphragm", "band": "mae/foxed_label_stock",
     "gold": "mina/gilt_edge", "jewel": "cal/valve_mica",
     "tiles": (4, 2), "band_period": 9.0, "band_width": 0.35,
     "wire_scale": 30.0, "wire_width": 0.05, "jewel_threshold": 0.82,
     "tint": (1.00, 0.94, 0.90)},
    {"key": "the_loupe", "motif": 4,
     "base": "omar/tool_steel", "band": "cal/wax_groove",
     "gold": "peter/brass_fastener", "jewel": "cal/dial_glass",
     "tiles": (2, 2), "band_period": 4.0, "band_width": 0.16,
     "wire_scale": 28.0, "wire_width": 0.07, "jewel_threshold": 0.70,
     "tint": (0.90, 0.86, 0.96)},
]


def load_plate(ref: str) -> dict:
    case, plate = ref.split("/")
    base = os.path.join(PLATES, case, "T_ai_dream_%s_%s" % (case, plate))
    out = {}
    for kind in ("albedo", "normal", "height", "roughness"):
        path = os.path.join(base, kind + ".png")
        if not os.path.exists(path):
            raise SystemExit("missing plate map: " + path)
        img = Image.open(path)
        img = img.convert("RGB") if kind in ("albedo", "normal") else img.convert("L")
        img = img.resize((SIZE, SIZE), Image.LANCZOS)
        out[kind] = np.asarray(img, dtype=np.float32) / 255.0
    return out


def hash2(ix: np.ndarray, iy: np.ndarray, seed: float) -> np.ndarray:
    return np.mod(np.sin(ix * 127.1 + iy * 311.7 + seed) * 43758.5453, 1.0)


def tiled(img: np.ndarray, tiles_u: int, tiles_v: int, seed: float) -> np.ndarray:
    """Tile a plate across the atlas with a hashed quarter-turn and offset
    per tile so the plate's own period does not read along the body."""
    h, w = img.shape[:2]
    vv, uu = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32) / SIZE
    cu = np.floor(uu * tiles_u)
    cv = np.floor(vv * tiles_v)
    fu = uu * tiles_u - cu
    fv = vv * tiles_v - cv
    rot = np.floor(hash2(cu, cv, seed) * 4.0)
    ou = hash2(cu, cv, seed + 9.0)
    ov = hash2(cu, cv, seed + 17.0)
    su = np.where(rot % 2 == 0, fu, fv)
    sv = np.where(rot % 2 == 0, fv, fu)
    su = np.where(rot >= 2, 1.0 - su, su)
    x = ((su + ou) % 1.0 * (w - 1)).astype(np.int32)
    y = ((sv + ov) % 1.0 * (h - 1)).astype(np.int32)
    return img[y, x]


def band_mask(period: float, width: float, seed: float) -> np.ndarray:
    vv, uu = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32) / SIZE
    jitter = 0.15 * np.sin(vv * 6.2831853 * 2.0 + seed) / period
    phase = (uu + jitter) * period
    d = np.abs(phase - np.round(phase))
    return np.clip(1.0 - d / max(1e-4, width * 0.5), 0.0, 1.0) ** 1.5


def wire_mask(scale: float, width: float, motif: float) -> np.ndarray:
    """The shader's fauna_cloisonne_wire, in atlas space: local.x -> u,
    local.z -> v, local.y -> a slow drift, so the baked gold and the
    procedural wire agree where both are drawn."""
    vv, uu = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32) / SIZE
    # Domain warp: cloisonne wire meanders; a straight lattice reads as a
    # drafting grid. Two octaves of smooth noise bend the line families.
    warp_u = value_noise(uu * 3.0, vv * 3.0, motif + 2.0) * 0.16         + value_noise(uu * 9.0, vv * 9.0, motif + 5.0) * 0.05
    warp_v = value_noise(uu * 3.0 + 7.0, vv * 3.0, motif + 3.0) * 0.16         + value_noise(uu * 9.0 + 3.0, vv * 9.0, motif + 6.0) * 0.05
    x = uu * 1.2 - 0.6 + warp_u
    z = vv * 0.8 - 0.4 + warp_v
    y = 0.25 * np.sin(uu * 6.2831853 + warp_v * 4.0)
    line_a = np.abs(np.sin((x + z * 0.35) * scale + motif * 1.71))
    line_b = np.abs(np.sin((z - y * 0.50) * scale * 0.83 - motif * 0.91))
    m = np.minimum(line_a, line_b)
    lo, hi = width * 0.6, width * 1.75
    return 1.0 - np.clip((m - lo) / max(1e-4, hi - lo), 0.0, 1.0)


def value_noise(x: np.ndarray, y: np.ndarray, seed: float) -> np.ndarray:
    """Smooth value noise in [-0.5, 0.5] on a unit lattice."""
    ix = np.floor(x); iy = np.floor(y)
    fx = x - ix; fy = y - iy
    fx = fx * fx * (3.0 - 2.0 * fx); fy = fy * fy * (3.0 - 2.0 * fy)
    a = hash2(ix, iy, seed); b = hash2(ix + 1, iy, seed)
    c = hash2(ix, iy + 1, seed); d = hash2(ix + 1, iy + 1, seed)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy - 0.5


def jewel_mask(lum: np.ndarray, threshold: float) -> np.ndarray:
    """Cells where the plate's luminance peaks. `threshold` is a quantile
    (0.72 = the brightest 28 %), so the mask does not depend on how bright
    a given plate happens to be."""
    lo = float(np.quantile(lum, threshold))
    hi = float(np.quantile(lum, min(0.995, threshold + (1.0 - threshold) * 0.6)))
    m = np.clip((lum - lo) / max(1e-3, hi - lo), 0.0, 1.0)
    # Beads, not a web: the peaks are gated by a jittered dot lattice so the
    # jewels are discrete set stones along the body.
    vv, uu = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32) / SIZE
    k = 14.0
    cu = np.floor(uu * k); cv = np.floor(vv * k * 0.75)
    ju = hash2(cu, cv, 31.0) * 0.5 + 0.25
    jv = hash2(cu, cv, 47.0) * 0.5 + 0.25
    du = (uu * k - cu) - ju
    dv = (vv * k * 0.75 - cv) - jv
    r = np.sqrt(du * du + dv * dv * 1.3)
    bead = np.clip(1.0 - (r - 0.10) / 0.12, 0.0, 1.0)
    keep = (hash2(cu, cv, 59.0) > 0.55).astype(np.float32)
    return (m ** 0.7) * bead * keep


def blur(img: np.ndarray, radius: int) -> np.ndarray:
    from PIL import ImageFilter
    mode = "L" if img.ndim == 2 else "RGB"
    pil = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), mode)
    pil = pil.filter(ImageFilter.GaussianBlur(radius))
    return np.asarray(pil, dtype=np.float32) / 255.0


def normal_from_height(height: np.ndarray, strength: float) -> np.ndarray:
    gy, gx = np.gradient(height)
    nx = -gx * strength
    ny = gy * strength
    nz = np.ones_like(height)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack((nx / n, ny / n, nz / n), axis=-1)


def blend_normals(a: np.ndarray, b: np.ndarray, w: np.ndarray) -> np.ndarray:
    """Whiteout blend of two [-1,1] normals by weight w."""
    w3 = w[..., None]
    n = a * (1.0 - w3) + b * w3
    n[..., 2] = np.maximum(0.05, n[..., 2])
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def build(family: dict, preview: bool) -> None:
    base = load_plate(family["base"])
    band = load_plate(family["band"])
    gold = load_plate(family["gold"])
    jewel = load_plate(family["jewel"])
    tu, tv = family["tiles"]
    seed = family["motif"] * 7.0 + 1.0

    alb = tiled(base["albedo"], tu, tv, seed)
    hgt = tiled(base["height"], tu, tv, seed)
    rgh = tiled(base["roughness"], tu, tv, seed)

    bm = band_mask(family["band_period"], family["band_width"], seed)
    band_alb = tiled(band["albedo"], tu * 2, tv, seed + 3.0)
    band_h = tiled(band["height"], tu * 2, tv, seed + 3.0)
    alb = alb * (1.0 - bm[..., None]) + band_alb * bm[..., None]
    hgt = hgt * (1.0 - bm) + (band_h * 0.6 + 0.25) * bm
    rgh = rgh * (1.0 - bm) + tiled(band["roughness"], tu * 2, tv, seed + 3.0) * bm

    wm = wire_mask(family["wire_scale"], family["wire_width"], family["motif"])
    gold_alb = tiled(gold["albedo"], 4, 4, seed + 5.0)
    gold_tint = np.array([1.15, 0.95, 0.55], dtype=np.float32)
    gold_fill = np.clip(gold_alb * gold_tint * 1.25, 0, 1)
    alb = alb * (1.0 - wm[..., None]) + gold_fill * wm[..., None]
    # A wire sits proud of the skin: raise the height under it.
    hgt = np.clip(hgt + wm * 0.35, 0, 1)
    rgh = rgh * (1.0 - wm) + 0.28 * wm

    jlum = tiled(jewel["albedo"], 3, 3, seed + 11.0).mean(axis=-1)
    jm = jewel_mask(blur(jlum, 3), family["jewel_threshold"]) * (1.0 - wm)
    jewel_alb = tiled(jewel["albedo"], 3, 3, seed + 11.0)
    alb = alb * (1.0 - jm[..., None]) + jewel_alb * np.array([0.9, 1.0, 1.05]) * jm[..., None]
    rgh = rgh * (1.0 - jm) + 0.12 * jm

    tint = np.array(family["tint"], dtype=np.float32)
    # The plates are photographed dark; the fauna shader lights the atlas as
    # albedo under the wine irradiance, so lift it toward a mid albedo.
    alb = np.clip(alb * tint, 0, 1) ** 0.72
    alb = np.clip(alb * 1.18, 0, 1)

    # Normal: the composed height at two frequencies, plus the plates' own
    # tangent normals blended in by their masks.
    n = normal_from_height(blur(hgt, 1) * 2.2, 6.0)
    base_n = tiled(base["normal"], tu, tv, seed) * 2.0 - 1.0
    n = blend_normals(n, base_n, np.full_like(hgt, 0.45) * (1.0 - wm))
    band_n = tiled(band["normal"], tu * 2, tv, seed + 3.0) * 2.0 - 1.0
    n = blend_normals(n, band_n, bm * 0.5)
    wear = np.clip((hgt - 0.55) / 0.45, 0, 1) ** 1.2
    wear = blur(wear, 2)

    out_dir = os.path.join(OUT, family["key"])
    os.makedirs(out_dir, exist_ok=True)
    Image.fromarray((alb * 255).astype(np.uint8), "RGB").save(
        os.path.join(out_dir, "albedo.png"), optimize=True)
    Image.fromarray((np.clip(n * 0.5 + 0.5, 0, 1) * 255).astype(np.uint8), "RGB").save(
        os.path.join(out_dir, "normal.png"), optimize=True)
    mask = np.stack((wm, jm, wear), axis=-1)
    Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8), "RGB").save(
        os.path.join(out_dir, "mask.png"), optimize=True)
    with open(os.path.join(out_dir, "SOURCE.md"), "w", encoding="utf-8") as fh:
        fh.write("# %s skin atlas\n\nComposed by art/tools/build_fauna_skins.py from the "
                 "ingested plates: base %s, bands %s, wires %s, jewels %s. Atlas space is "
                 "the fauna CUSTOM0 (body_t, angle) coordinate.\n"
                 % (family["key"], family["base"], family["band"], family["gold"], family["jewel"]))
    print("%-16s gold %.1f%%  jewel %.1f%%  wear %.1f%%" % (
        family["key"], wm.mean() * 100, jm.mean() * 100, wear.mean() * 100))
    if preview:
        sheet = Image.new("RGB", (SIZE * 3 // 2, SIZE // 2))
        for i, arr in enumerate((alb, n * 0.5 + 0.5, mask)):
            sheet.paste(Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGB")
                        .resize((SIZE // 2, SIZE // 2), Image.LANCZOS), (i * SIZE // 2, 0))
        sheet.save(os.path.join(out_dir, "_preview.png"))


def main() -> None:
    preview = "--preview" in sys.argv
    for family in FAMILIES:
        build(family, preview)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
