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
import re
import zlib

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
                              1.2, 0.88, 0.10, 7.0),
    # Two-generator split (2026-08-04): the sooty iron-spot facade brick
    # holds face_brick; the brighter clinker-speckled photo source takes
    # the generic brick key, so party walls stop twinning the facade.
    "face_brick_street": (["face_brick"], 2.2, 0.82, 0.10, 7.0),
    "face_brick_clinker": (["brick"], 1.5, 0.84, 0.10, 7.0),
    "limestone_carved": (["limestone"], 1.6, 0.78, 0.10, 4.0),
    # floor_oak re-earned its slot 2026-08-04: the 2048 slot-format
    # generation beat the procedural set against period reference (warm
    # amber, staggered joints, flat light, no landmarks). ~48 strips at
    # a true 5.7 cm face = 2.7 m coverage, measured not assumed.
    "floor_oak_worn": (["floor_oak"], 2.7, 0.55, 0.25, 3.5),
    "terrazzo_lobby": (["terrazzo"], 4.0, 0.38, 0.18, 2.0),
    "stair_marble_worn": (["stair"], 1.2, 0.45, 0.20, 3.0),
    "wainscot_beadboard": (["wainscot"], 0.72, 0.58, 0.15, 5.0),
    "trim_painted_layers": (["trim", "baluster"], 1.1, 0.52, 0.18, 3.5),
    "ceramic_hex_bath": (["ceramic"], 0.65, 0.42, 0.22, 4.5),
    "subway_tile_aged": (["subway_tile"], 0.67, 0.28, 0.20, 4.5),
    "concrete_cellar": (["concrete", "slab"], 2.8, 0.86, 0.08, 3.0),
    # Materials that carried real geometry on a flat colour until now.
    # Vertex counts are from the audit across all eight floors, which is
    # what decided the order they were worth generating in.
    # The last of the script-generated sets. plaster is the big one: it
    # is the interior finish on every wall of every apartment, and it was
    # the only surface in a furnished room carrying no detail at all.
    "plaster_aged": (["plaster"], 1.8, 0.88, 0.08, 2.5),
    "plaster_stained": (["plaster_stained"], 1.8, 0.90, 0.08, 2.5),
    "terracotta_pot": (["terracotta"], 0.4, 0.86, 0.08, 3.0),
    "soil_potting": (["soil"], 0.35, 0.95, 0.06, 3.5),
    "neon_porcelain": (["enamel"], 0.6, 0.18, 0.14, 2.0),
    "plywood_sheet": (["plywood"], 1.2, 0.80, 0.14, 3.0),
    "leaf_fall": (["leaf_fall"], 1.5, 0.65, 0.18, 3.5),
    # Wet surfaces are authored as darkened albedo, never as reflections:
    # a baked sky tiles into the pavement as a repeating patch of cloud.
    "puddle_water": (["puddle"], 2.0, 0.05, 0.06, 1.0),
    "wet_asphalt": (["wet_asphalt"], 2.5, 0.22, 0.10, 2.5),
    "timber_joist": (["timber"], 1.0, 0.80, 0.12, 5.0),
    "brass_aged": (["brass"], 0.25, 0.40, 0.25, 2.0),
    "enamel_appliance": (["appliance"], 0.85, 0.22, 0.15, 1.5),
    # One enamel, five lives (design/ORISON_APPLIANCE_BIBLE.md IV).
    "enamel_pristine": (["enamel_pristine"], 0.85, 0.18, 0.12, 1.2),
    "enamel_paintflecked": (["enamel_paintflecked"], 0.85, 0.30, 0.18, 1.6),
    "enamel_dented": (["enamel_dented"], 0.85, 0.34, 0.20, 2.4),
    "enamel_greasy": (["enamel_greasy"], 0.85, 0.26, 0.16, 1.4),
    "enamel_workshop": (["enamel_workshop"], 0.85, 0.32, 0.18, 1.6),
    "galvanized_aged": (["metal"], 0.8, 0.55, 0.18, 2.0),
    "cast_iron_radiator": (["cast_iron"], 0.4, 0.60, 0.18, 3.0),
    "porcelain_fixture": (["porcelain"], 0.4, 0.18, 0.15, 1.5),
    "bakelite": (["bakelite"], 0.3, 0.25, 0.15, 1.5),
    # 11 squares across the sheet; at 1.1 m that is a ~10 cm check,
    # which is what this pattern was actually printed at. At the old
    # 0.8 m they came out 7 cm and read as bathroom mosaic.
    "linoleum_kitchen": (["linoleum"], 1.1, 0.50, 0.20, 2.0),
    "walnut_furniture": (["wood_dark", "handrail_wood"],
                         0.6, 0.48, 0.20, 2.5),
    "upholstery_rust": (["fabric_warm"], 0.6, 0.92, 0.06, 3.0),
    "rug_persian_worn": (["rug_warm"], 1.5, 0.94, 0.05, 2.5),
    "linen_aged": (["linen"], 0.5, 0.90, 0.06, 2.5),
    # The unjointed slab now supplies only the GROUT - the ground you see
    # in the gaps between flags. sidewalk_haunted comes from the jointed
    # source below, per flag. Both used to write sidewalk_haunted and
    # whichever ingested last silently won.
    "sidewalk_slab": (["sidewalk_grout"], 2.5, 0.87, 0.08, 4.0),
    "asphalt_street": (["asphalt"], 2.5, 0.90, 0.06, 4.0),
    "tin_ceiling": (["tin_ceiling"], 1.2, 0.45, 0.20, 6.0),
    "marble_lobby_base": (["marble_lobby"], 1.5, 0.30, 0.18, 2.0),
    # Six stair treads stacked in one sheet, sampled a band at a time.
    # metres_per_tile is meaningless for it - nothing world-projects it -
    # but the field is positional so it gets the tread width anyway.
    "stair_treads": (["stair_treads"], 1.2, 0.42, 0.20, 3.0),
    # The last of the procedural "library" family, folded in here so the
    # whole building draws from one photographic source of truth.
    # Coverage figures are the meters_per_tile these already had in
    # art/textures/library/*/asset.json - changing them would shift the
    # scale under everything already placed.
    "chrome_brushed": (["chrome"], 0.80, 0.22, 0.18, 3.0),
    "leaf_surface": (["plant"], 0.40, 0.62, 0.15, 4.0),
    "aged_paper": (["paper"], 0.50, 0.85, 0.08, 2.0),
    "upholstery_cool": (["fabric_cool"], 0.70, 0.90, 0.06, 3.5),
    "upholstery_moss": (["fabric_green"], 0.70, 0.90, 0.06, 3.5),
    "aged_countertop": (["countertop"], 1.20, 0.35, 0.18, 2.0),
    "art_canvas_sheet": (["art"], 0.80, 0.60, 0.14, 1.5),
    # One coal source serves both keys: "soot" is the deposit on a flue
    # and "char" was a shader-only flat black on the coal heap and the
    # F05 flue boxes. They are the same substance and there is no reason
    # for one of them to be a colour swatch.
    "charred_surface": (["soot", "char"], 1.20, 0.92, 0.06, 3.5),
    # One paving flag, with slivers of its neighbours at the edges - the
    # joints sit at 17% and 83% in both axes. It was retired because
    # tiling it gives alternating wide and narrow flags, which is not a
    # module any city ever poured. Sampled per flag instead (see
    # build_sidewalk_flag) it is exactly right: the geometry supplies the
    # joints and the texture supplies one stone.
    "sidewalk_slab_jointed": (["sidewalk_haunted"], 1.52, 0.86, 0.09, 5.0),
    # The elevator sheet (2026-08-06). Nine surfaces the building had no
    # honest version of: the car is panelled, gated and floored in
    # materials that existed nowhere else in the catalog, and the
    # lighting work wanted a real opal and a real bronze. Coverage is
    # per-cell as prompted, not guessed: these are small parts read from
    # close, so the tiles are small.
    "brass_worn": (["brass_bright"], 0.35, 0.34, 0.22, 2.0),
    "bronze_patina": (["bronze"], 0.60, 0.62, 0.20, 3.5),
    "steel_car_paint": (["car_paint"], 1.00, 0.55, 0.20, 3.0),
    "quartered_oak": (["oak_quartered"], 0.90, 0.45, 0.18, 3.0),
    "milk_glass": (["milk_glass"], 0.50, 0.22, 0.10, 1.2),
    "bakelite_black": (["bakelite_black"], 0.30, 0.28, 0.14, 1.8),
    "terrazzo_car_floor": (["terrazzo_dark"], 1.20, 0.40, 0.18, 2.5),
    "brass_mesh": (["brass_mesh"], 0.35, 0.52, 0.18, 5.0),
    "indicator_enamel": (["indicator_enamel"], 0.50, 0.24, 0.12, 1.5),
}
# Sources that are COMPOSITIONS, not tiling swatches.
#
# These skip both the square centre-crop and the seamless blend. The
# crop would throw away half the picture - the stair sheet is six treads
# stacked two-to-one tall, so squaring it discards three of them - and
# the half-roll blend would smear the top of the sheet into the bottom,
# which for that sheet means blending tread six's grime line into tread
# one's nosing. Anything sampled by an explicit UV window belongs here.
COMPOSITION = {"stair_treads", "art_canvas_sheet",
               "sidewalk_slab_jointed"}

# Sources carrying a generator watermark, and the fraction of the image
# to keep from the top-left.
#
# Gemini stamps a small four-pointed sparkle at roughly 85-88% across
# and down. Left in, it would be bad; run through make_tileable it would
# be WORSE, because the half-roll crossfade moves the corners to the
# CENTRE of the tile - so the watermark would end up in the middle of
# every wall, floor or sofa using that material, repeated forever.
# Cropping it off before anything else is the only safe order.
# Keyed by FILE stem, not slot: one slot's candidates come from
# different generators, and only some carry the sparkle.
PRECROP = {
    "chrome_brushed": 0.82,
    "upholstery_cool": 0.82,
    "leaf_surface_v2": 0.82,
    "charred_surface_v2": 0.82,
}

# hue-rotated companions: source slot -> [(extra key, hue degrees)]
RECOLOR = {"rug_persian_worn": [("rug_cool", 150.0), ("rug_green", 90.0)]}

# Keys whose maps must also be staged into the Godot asset tree.
#
# The Blender build only bakes out the materials its own geometry uses,
# so a finish that exists solely on a GDScript-built prop - the elevator
# car, which is authored entirely in elevator.gd - never reaches
# res://assets/building/textures/ and MatLib silently falls back to flat
# colour. Copying them here keeps that reproducible instead of a manual
# step somebody has to remember after every regeneration.
GODOT_STAGE = ("brass_bright", "bronze", "car_paint", "oak_quartered",
               "milk_glass", "bakelite_black", "terrazzo_dark",
               "brass_mesh", "indicator_enamel")
GODOT_TEX = os.path.join(ROOT, "game", "assets", "building", "textures")


def stage_for_godot(key):
    """Copy one material's maps under the T_ai_materials_* convention."""
    src = os.path.join(OUT, key)
    if not os.path.isdir(src):
        return False
    pairs = (("albedo.png", "albedo"), ("roughness.png", "rough"),
             ("normal.png", "normal"))
    for fname, suffix in pairs:
        s_path = os.path.join(src, fname)
        if not os.path.exists(s_path):
            continue
        d_path = os.path.join(GODOT_TEX,
                              "T_ai_materials_%s_%s.png" % (key, suffix))
        with open(s_path, "rb") as fh:
            data = fh.read()
        with open(d_path, "wb") as fh:
            fh.write(data)
    return True



# Absolute color governance: per-key target mean sRGB. Generators drift
# ("aged ivory" means something different every run), so ingest pulls
# each delivered albedo's MEAN toward its anchor at ANCHOR_STRENGTH,
# preserving all local variation. Anchored on period reference and the
# building's grade.
COLOR_ANCHORS = {
    "floor_oak": "#9A6132", "common_brick": "#A5663F",
    "brick_patched": "#A5663F", "face_brick": "#6B3B33",
    "brick": "#8A4A3A", "trim": "#E3DAC3", "baluster": "#E3DAC3",
    "wainscot": "#E5DCC6", "limestone": "#C8C1B1", "terrazzo": "#C7BDA6",
    "stair": "#DCD9D2", "ceramic": "#ECE7DC", "subway_tile": "#EAE4D6",
    "concrete": "#98958E", "slab": "#98958E",
    "enamel": "#E8E3D4", "plywood": "#A38A61", "leaf_fall": "#6B4721",
    "plaster": "#DCD6C8", "plaster_stained": "#CFC4AE",
    "terracotta": "#A85C3C", "soil": "#3A2E22",
    "puddle": "#0A0B0E", "wet_asphalt": "#17171A", "timber": "#8A6A48",
    "brass": "#A67C3E", "appliance": "#F0EBDE", "metal": "#9AA0A0",
    "cast_iron": "#B5B2AA",
    "enamel_pristine": "#F2EEE2", "enamel_paintflecked": "#E9E3D2",
    "enamel_dented": "#E4DDCC", "enamel_greasy": "#DCD2B8",
    "enamel_workshop": "#E6E1D4", "porcelain": "#EFE9D6", "bakelite": "#452C20",
    "linoleum": "#B08A6A", "wood_dark": "#5C3A26",
    "handrail_wood": "#5C3A26", "fabric_warm": "#B0552F",
    "rug_warm": "#9E4A3C", "linen": "#D8CBAA",
    "sidewalk_haunted": "#9A9A92", "sidewalk_grout": "#9A9A92",
    "asphalt": "#4B4B49", "tin_ceiling": "#E2DAC6",
    "marble_lobby": "#E8E6E0",
    # Measured off the delivered cells, then nudged the way the lobby
    # reads them: brass warmer because it is only ever seen by lamplight,
    # opal brighter because unlit opal glass is not grey.
    "brass_bright": "#8A6A33", "bronze": "#46402F",
    "car_paint": "#5E5C42", "oak_quartered": "#855832",
    "milk_glass": "#E4E1D8", "bakelite_black": "#24201D",
    "terrazzo_dark": "#4A443C", "brass_mesh": "#6A5228",
    "indicator_enamel": "#E0D5BE",
    "chrome": "#A8ACB0", "plant": "#46573A", "paper": "#DFD2B4",
    "fabric_cool": "#4A6274", "fabric_green": "#6E7042",
    "countertop": "#DED4BC", "soot": "#2A2724", "char": "#241F1C",
}
ANCHOR_STRENGTH = 0.5


def anchor_color(albedo, key):
    hexa = COLOR_ANCHORS.get(key)
    if not hexa:
        return albedo
    target = np.array([int(hexa[i:i + 2], 16) / 255.0
                       for i in (1, 3, 5)], dtype=np.float32)
    mean = albedo.reshape(-1, 3).mean(axis=0)
    return np.clip(albedo + (target - mean) * ANCHOR_STRENGTH, 0.0, 1.0)


def make_tileable(a: np.ndarray, band_frac: float = 0.12) -> np.ndarray:
    """Make an image wrap by overlap-blending its edges.

    The previous implementation rolled the image by half and then
    crossfaded the rolled and unrolled copies across the WHOLE frame.
    That puts the source's centre at both the middle AND the four
    edges - a 2x2 restatement of the same content inside one tile,
    which halves the apparent tile size and makes every distinctive
    feature announce itself twice per repeat.

    The correct trick keeps the interior untouched: crop the last band
    off, and crossfade what was the tail into the head. The new last
    column is then the source's own neighbour of the new first column,
    so the image wraps with no seam and nothing is duplicated. Costs
    band_frac of the dimension, which is what a seam is worth.
    """
    for axis in (1, 0):
        n = a.shape[axis]
        band = max(2, int(n * band_frac))
        keep = n - band
        w = np.linspace(1.0, 0.0, band, dtype=np.float32)
        w = w * w * (3.0 - 2.0 * w)          # smoothstep, no linear ramp
        shape = [1] * a.ndim
        shape[axis] = band
        w = w.reshape(shape)
        head = np.take(a, np.arange(band), axis=axis)
        tail = np.take(a, np.arange(n - band, n), axis=axis)
        out = np.take(a, np.arange(keep), axis=axis).copy()
        sl = [slice(None)] * a.ndim
        sl[axis] = slice(0, band)
        out[tuple(sl)] = head * (1.0 - w) + tail * w
        a = out
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


# Ship resolution. Sources arrive at 2048 and that is right for the
# BAKE (crops, warps and seam blending all want the headroom), but 105
# shipped maps at 2048 is ~1.7 GB of uncompressed VRAM, which is what
# killed the free camera. A material tiling every metre or two has
# nothing to say above 1024, and roughness has nothing to say above 512.
SHIP_PX = {"albedo": 1024, "normal": 1024, "roughness": 512,
           "height": 512}


def _fit(img: Image.Image, kind: str) -> Image.Image:
    cap = SHIP_PX.get(kind, 1024)
    if max(img.size) <= cap:
        return img
    return img.resize((cap, cap), Image.LANCZOS)


def write_set(key: str, albedo: np.ndarray, metres: float,
              rough_base: float, rough_span: float,
              normal_strength: float, source_name: str) -> None:
    out_dir = os.path.join(OUT, key)
    os.makedirs(out_dir, exist_ok=True)
    albedo = anchor_color(albedo, key)
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
    _fit(Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8),
                         "RGB"), "albedo").save(
        os.path.join(out_dir, "albedo.png"), optimize=True)
    _fit(Image.fromarray((np.clip(height, 0, 1) * 255).astype(np.uint8),
                         "L"), "height").save(
        os.path.join(out_dir, "height.png"), optimize=True)
    _fit(Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8),
                         "L"), "roughness").save(
        os.path.join(out_dir, "roughness.png"), optimize=True)
    _fit(Image.fromarray((np.clip(normal, 0, 1) * 255).astype(np.uint8),
                         "RGB"), "normal").save(
        os.path.join(out_dir, "normal.png"), optimize=True)
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




# ---------------------------------------------------------------- variants
# Multiple generations of one surface are INGREDIENTS, not contestants.
# The old flow kept a winner and discarded the rest; this synthesizes a
# family: <key> is the winner untouched, <key>_b/_c/_d are deterministic
# recombinations, and the Blender build cycles the family per storey.
#
# Recipes by material class, because combination is only honest where
# structure allows it:
#   organic - regional soft-mask blends between candidates, low/high
#             frequency swaps (one gen's layout wearing another's grain),
#             quarter turns where the material has no direction, and a
#             low-frequency value jitter.
#   grid    - anything with a module or a grain direction (boards, tile
#             courses, brushed metal). Cross-candidate ops would misalign
#             the module, so these only self-vary: value jitter and a
#             half turn.
# Compositions (COMPOSITION set) are excluded outright - you do not
# blend two different stair sheets into a third lie.
GRID_SLOTS = {
    "linoleum_kitchen", "subway_tile_aged", "ceramic_hex_bath",
    "tin_ceiling", "wainscot_beadboard", "marble_lobby_base",
    "floor_oak_worn", "timber_joist", "walnut_furniture",
    "galvanized_aged", "chrome_brushed",
}
# mirror of build_orison's ROTATABLE: no direction, quarter turns legal
ROT_OK = {"concrete_cellar", "plaster_aged", "plaster_stained",
          "terrazzo_lobby", "asphalt_street", "wet_asphalt",
          "soil_potting", "charred_surface"}
# keys that stay single: the elevator set (referenced by GDScript props
# at one fixed look) and hue-rotated rug companions (derived, not shot)
NO_VARIANTS = set(GODOT_STAGE) | {"rug_cool", "rug_green"}
MAX_FAMILY = 4


def _vrng(key, i):
    return np.random.default_rng(zlib.crc32(("%s#%d" % (key, i)).encode()))


def _low_noise(rng, size, cells=5):
    g = rng.random((cells, cells))
    img = Image.fromarray((g * 255).astype(np.uint8)).resize(
        (size, size), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0


def _blur(a, radius):
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    img = img.filter(ImageFilter.GaussianBlur(radius))
    return np.asarray(img, dtype=np.float32) / 255.0


def synthesize_family(slot, key, candidates):
    """candidates: list of float albedo arrays (square, tileable, same
    slot). Returns list of (suffix, albedo) for _b onward."""
    n = len(candidates)
    base = candidates[0]
    size = base.shape[0]
    grid = slot in GRID_SLOTS
    out = []
    want = min(MAX_FAMILY - 1, 3 if n > 1 else 2)
    for i in range(want):
        rng = _vrng(key, i + 1)
        if grid or n == 1:
            v = base.copy()
            if i % 2 == 1 or n == 1:
                # half turn: legal for any module, breaks repetition
                v = v[::-1, ::-1].copy()
            jit = 0.90 + 0.14 * _low_noise(rng, size)[..., None]
            v = np.clip(v * jit, 0, 1)
            if not grid and slot in ROT_OK and i == 2:
                v = np.rot90(v).copy()
        else:
            other = candidates[1 + (i % (n - 1))]
            if other.shape != base.shape:
                oi = Image.fromarray((other * 255).astype(np.uint8))
                other = np.asarray(oi.resize((size, size), Image.LANCZOS),
                                   dtype=np.float32) / 255.0
            if i % 2 == 0:
                # regional blend: a low-frequency mask, blurred so the
                # frontier never reads as a seam
                m = _blur((_low_noise(rng, size, 4) > 0.5)
                          .astype(np.float32), size * 0.04)[..., None]
                v = base * (1.0 - m) + other * m
            else:
                # frequency swap: base's layout, other's grain
                lo = np.dstack([_blur(base[..., c], size * 0.02)
                                for c in range(3)])
                o_lo = np.dstack([_blur(other[..., c], size * 0.02)
                                  for c in range(3)])
                v = np.clip(lo + (other - o_lo), 0, 1)
            if slot in ROT_OK and rng.random() < 0.5:
                v = np.rot90(v, 1 + int(rng.random() * 3)).copy()
        out.append(("_" + "bcd"[i], np.clip(v, 0, 1)))
    return out

def main() -> None:
    os.makedirs(SRC, exist_ok=True)
    with open(MAPPING, encoding="utf-8") as fh:
        mapping = json.load(fh)
    # ---- collect: group every candidate file under its slot.
    # <slot>.png is the winner; <slot>_alt.png and <slot>_vN.png are
    # further generations of the same surface.
    groups, unknown = {}, []
    for fname in sorted(os.listdir(SRC)):
        stem, ext = os.path.splitext(fname)
        if ext.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
            continue
        slot = re.sub(r"(_alt|_v\d+)$", "", stem)
        if slot not in SLOTS:
            unknown.append(fname)
            continue
        rank = 0 if stem == slot else (1 if stem.endswith("_alt")
                                       else 1 + int(stem.rsplit("_v", 1)[1]))
        groups.setdefault(slot, []).append((rank, stem, fname))

    def prep(stem, fname, slot):
        img = Image.open(os.path.join(SRC, fname)).convert("RGB")
        if stem in PRECROP:
            keep = PRECROP[stem]
            img = img.crop((0, 0, int(img.width * keep),
                            int(img.height * keep)))
        if slot not in COMPOSITION:
            side = min(img.size)
            left = (img.width - side) // 2
            top = (img.height - side) // 2
            img = img.crop((left, top, left + side, top + side))
        a = np.asarray(img, dtype=np.float32) / 255.0
        if slot not in COMPOSITION:
            a = make_tileable(a)
        return a

    ingested = []
    for slot, cands in sorted(groups.items()):
        cands.sort()
        keys, metres, rough_base, rough_span, strength = SLOTS[slot]
        albedos = [prep(stem, fname, slot) for _, stem, fname in cands]
        base = albedos[0]
        for key in keys:
            write_set(key, base, metres, rough_base, rough_span,
                      strength, cands[0][1])
            mapping[key] = "ai_materials/%s" % key
            if slot in COMPOSITION or key in NO_VARIANTS:
                continue
            fam = synthesize_family(slot, key, albedos)
            for sfx, alb in fam:
                write_set(key + sfx, alb, metres, rough_base, rough_span,
                          strength, cands[0][1] + sfx)
                mapping[key + sfx] = "ai_materials/%s" % (key + sfx)
        for extra_key, degrees in RECOLOR.get(slot, []):
            write_set(extra_key, hue_rotate(base, degrees), metres,
                      rough_base, rough_span, strength, cands[0][1])
            mapping[extra_key] = "ai_materials/%s" % extra_key
        ingested.append((slot, len(albedos), keys))
    with open(MAPPING, "w", encoding="utf-8") as fh:
        json.dump(mapping, fh, indent=1)
        fh.write("\n")
    staged = [k for k in GODOT_STAGE if stage_for_godot(k)]
    if staged:
        print("staged for Godot props: %s" % ", ".join(staged))
    for slot, n, keys in ingested:
        print("ingested %-24s %d gen(s) -> %s"
              % (slot, n, ", ".join(keys)))
    for fname in unknown:
        print("UNKNOWN source (no SLOTS entry):", fname)
    if not ingested and not unknown:
        print("art/textures/ai_sources/ is empty - drop sheet images in "
              "and re-run")
    else:
        print("re-run the Blender build to see them in the floors")


if __name__ == "__main__":
    main()
