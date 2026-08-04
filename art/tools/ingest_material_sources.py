"""Turn AI-generated material photos into catalog texture sets.

Drop images from design/MATERIAL_PROMPT_SHEET.md into
art/textures/ai_sources/ under their sheet filenames and run this. For
each known source it:

- center-crops square and makes the image seamlessly tileable
  (half-roll crossfade, both axes);
- derives a height map from band-passed luminance (mortar, grout and
  grain read darker = recessed, which holds for these materials), a
  tangent normal from its gradient, and a roughness map from a
  per-material base modulated by the same detail;
- writes art/textures/ai_materials/<catalog_key>/{albedo,height,normal,
  roughness}.png + material.json with the sheet's real-world scale;
- repoints catalog_mapping.json so the next build_orison.py run picks
  the new set up everywhere that material is used.

Rug sources also emit hue-shifted variants for the cool and green rug
slots. Sources without a SLOTS entry are listed, not guessed at.

    python art/tools/ingest_material_sources.py
"""
import json
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "textures", "ai_sources")
OUT = os.path.join(ROOT, "art", "textures", "ai_materials")
MAPPING = os.path.join(ROOT, "art", "textures", "catalog_mapping.json")

# source file -> (catalog keys, meters_per_tile, rough_base, rough_span,
#                 normal_strength)
SLOTS = {
    "common_brick_interior": (["common_brick", "brick_patched"],
                              0.9, 0.88, 0.10, 7.0),
    "face_brick_street": (["face_brick", "brick"], 1.1, 0.82, 0.10, 7.0),
    "limestone_carved": (["limestone"], 1.6, 0.78, 0.10, 4.0),
    # floor_oak RETIRED from ingest 2026-08-04: the low-res AI tile lost
    # to the procedural set against period reference (warm amber shellac,
    # continuous narrow strips - minimaldomesticity.com et al). Re-enable
    # when a 1024+ generation actually beats generated/floor_oak.
    # "floor_oak_worn": (["floor_oak"], 0.75, 0.55, 0.25, 3.5),
    "terrazzo_lobby": (["terrazzo"], 2.0, 0.38, 0.18, 2.0),
    "stair_marble_worn": (["stair"], 1.2, 0.45, 0.20, 3.0),
    "wainscot_beadboard": (["wainscot"], 0.6, 0.58, 0.15, 5.0),
    "trim_painted_layers": (["trim", "baluster"], 1.1, 0.52, 0.18, 3.5),
    "ceramic_hex_bath": (["ceramic"], 1.0, 0.42, 0.22, 4.5),
    "subway_tile_aged": (["subway_tile"], 0.55, 0.28, 0.20, 4.5),
    "concrete_cellar": (["concrete", "slab"], 2.8, 0.86, 0.08, 3.0),
    "timber_joist": (["timber"], 1.0, 0.80, 0.12, 5.0),
    "brass_aged": (["brass"], 0.25, 0.40, 0.25, 2.0),
    "enamel_appliance": (["appliance"], 0.85, 0.22, 0.15, 1.5),
    "galvanized_aged": (["metal"], 0.8, 0.55, 0.18, 2.0),
    "cast_iron_radiator": (["cast_iron"], 0.4, 0.60, 0.18, 3.0),
    "porcelain_fixture": (["porcelain"], 0.4, 0.18, 0.15, 1.5),
    "bakelite": (["bakelite"], 0.3, 0.25, 0.15, 1.5),
    "linoleum_kitchen": (["linoleum"], 0.8, 0.50, 0.20, 2.0),
    "walnut_furniture": (["wood_dark", "handrail_wood"],
                         0.6, 0.48, 0.20, 2.5),
    "upholstery_rust": (["fabric_warm"], 0.6, 0.92, 0.06, 3.0),
    "rug_persian_worn": (["rug_warm"], 1.5, 0.94, 0.05, 2.5),
    "linen_aged": (["linen"], 0.5, 0.90, 0.06, 2.5),
    "sidewalk_slab": (["sidewalk_haunted", "sidewalk_grout"],
                      2.5, 0.87, 0.08, 4.0),
    "asphalt_street": (["asphalt"], 2.5, 0.90, 0.06, 4.0),
    "tin_ceiling": (["tin_ceiling"], 1.2, 0.45, 0.20, 6.0),
    "marble_lobby_base": (["marble_lobby"], 1.5, 0.30, 0.18, 2.0),
}
# hue-rotated companions: source slot -> [(extra key, hue degrees)]
RECOLOR = {"rug_persian_worn": [("rug_cool", 150.0), ("rug_green", 90.0)]}


def make_tileable(a: np.ndarray) -> np.ndarray:
    for axis in (1, 0):
        n = a.shape[axis]
        rolled = np.roll(a, n // 2, axis=axis)
        t = np.linspace(0.0, 1.0, n, dtype=np.float32)
        w = np.clip(1.0 - np.abs(t - 0.5) * 2.0, 0.0, 1.0)
        w = np.clip((w - 0.38) / 0.24, 0.0, 1.0)
        shape = [1] * a.ndim
        shape[axis] = n
        w = w.reshape(shape)
        a = rolled * (1.0 - w) + a * w
    return a


def blur(a: np.ndarray, radius: float) -> np.ndarray:
    img = Image.fromarray((np.clip(a, 0.0, 1.0) * 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(radius)),
                      dtype=np.float32) / 255.0


def save_gray(a: np.ndarray, path: str) -> None:
    Image.fromarray((np.clip(a, 0.0, 1.0) * 255).astype(np.uint8),
                    "L").save(path, optimize=True)


def hue_rotate(rgb: np.ndarray, degrees: float) -> np.ndarray:
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8),
                          "RGB").convert("HSV")
    h, s, v = [np.asarray(c, dtype=np.float32) for c in img.split()]
    h = np.mod(h + degrees / 360.0 * 255.0, 255.0)
    out = Image.merge("HSV", [Image.fromarray(c.astype(np.uint8), "L")
                              for c in (h, s, v)]).convert("RGB")
    return np.asarray(out, dtype=np.float32) / 255.0


def write_set(key: str, albedo: np.ndarray, metres: float,
              rough_base: float, rough_span: float,
              normal_strength: float, source_name: str) -> None:
    out_dir = os.path.join(OUT, key)
    os.makedirs(out_dir, exist_ok=True)
    lum = albedo.mean(axis=-1)
    # band-passed luminance as height: local detail without the broad
    # lighting-ish gradients an AI photo sometimes smuggles in
    height = np.clip(0.5 + (blur(lum, 2.0) - blur(lum, 24.0)) * 1.6, 0, 1)
    gy, gx = np.gradient(height)
    nx = -gx * normal_strength
    ny = gy * normal_strength
    nz = np.ones_like(height)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack((nx / norm * 0.5 + 0.5, ny / norm * 0.5 + 0.5,
                       nz / norm * 0.5 + 0.5), axis=-1)
    rough = np.clip(rough_base + (0.5 - height) * rough_span * 2.0,
                    0.05, 1.0)
    Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8),
                    "RGB").save(os.path.join(out_dir, "albedo.png"),
                                optimize=True)
    save_gray(height, os.path.join(out_dir, "height.png"))
    save_gray(rough, os.path.join(out_dir, "roughness.png"))
    Image.fromarray((np.clip(normal, 0, 1) * 255).astype(np.uint8),
                    "RGB").save(os.path.join(out_dir, "normal.png"),
                                optimize=True)
    with open(os.path.join(out_dir, "material.json"), "w",
              encoding="utf-8") as fh:
        json.dump({
            "material": key,
            "source": "art/textures/ai_sources/%s.png" % source_name,
            "generator": "ingest_material_sources.py",
            "meters_per_tile": metres,
            "maps": {"albedo": "albedo.png", "roughness": "roughness.png",
                     "height": "height.png", "normal": "normal.png"},
        }, fh, indent=2)


def main() -> None:
    os.makedirs(SRC, exist_ok=True)
    with open(MAPPING, encoding="utf-8") as fh:
        mapping = json.load(fh)
    ingested, unknown = [], []
    for fname in sorted(os.listdir(SRC)):
        stem, ext = os.path.splitext(fname)
        if ext.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
            continue
        if stem not in SLOTS:
            unknown.append(fname)
            continue
        keys, metres, rough_base, rough_span, strength = SLOTS[stem]
        img = Image.open(os.path.join(SRC, fname)).convert("RGB")
        side = min(img.size)
        left = (img.width - side) // 2
        top = (img.height - side) // 2
        img = img.crop((left, top, left + side, top + side))
        albedo = np.asarray(img, dtype=np.float32) / 255.0
        albedo = make_tileable(albedo)
        for key in keys:
            write_set(key, albedo, metres, rough_base, rough_span,
                      strength, stem)
            mapping[key] = "ai_materials/%s" % key
        for extra_key, degrees in RECOLOR.get(stem, []):
            write_set(extra_key, hue_rotate(albedo, degrees), metres,
                      rough_base, rough_span, strength, stem)
            mapping[extra_key] = "ai_materials/%s" % extra_key
        ingested.append((stem, keys))
    with open(MAPPING, "w", encoding="utf-8") as fh:
        json.dump(mapping, fh, indent=1)
        fh.write("\n")
    for stem, keys in ingested:
        print("ingested %-24s -> %s" % (stem, ", ".join(keys)))
    for fname in unknown:
        print("UNKNOWN source (no SLOTS entry):", fname)
    if not ingested and not unknown:
        print("art/textures/ai_sources/ is empty - drop sheet images in "
              "and re-run")
    else:
        print("re-run the Blender build to see them in the floors")


if __name__ == "__main__":
    main()
