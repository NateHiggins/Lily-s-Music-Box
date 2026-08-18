"""Two materials the windows have been borrowing `trim` for.

Owner, 2026-08-18: *"the textures on all the window parts need updating and the
geometry reads as computer generated."*

`trim` is the paint on every skirting, architrave and picture rail in the
building, and until now it was also the paint on every window sash and every
venetian slat. That is wrong in two different directions and each wants its own
sheet.

SASH — painted joinery that lives OUTSIDE.
    A skirting board is repainted when the room is decorated and never sees
    weather. A sash is on the wet side of the wall: the paint chalks, the brush
    drag along the grain of the stile stays visible under it, and the bottom
    rail holds the dirt that runs off the glass. It also sits in a rebate 20 mm
    behind the masonry face, so it is nearly always in its own shadow — a
    surface that reads by its ROUGHNESS break rather than by its colour.
    Directional on purpose: brush drag runs along the member, and the members
    run both ways, which is exactly what a stile and a rail look like.

BLIND_SLAT — not paint at all.
    A venetian slat is rolled aluminium or basswood, and W-JOINERY's complaint
    is optical before it is visual: these are the surfaces `window_glow` lights
    FROM BEHIND, so a slat wants to be pale, faintly milky and dusty on the
    face that points up, where nobody has wiped it since the flat was let. The
    fine draw lines run ALONG the slat because that is the direction it came
    off the roll, and they are the thing that catches a gradient across the
    crown when the light is behind it.

Neither sheet gets a height map: §HeightmapPass excludes paint on purpose
("parallax on a flat painted wall costs a texture fetch per pixel and shows
nothing"), and both of these are paint-thin.

Run:  python art/tools/build_window_joinery_maps.py
"""
import json
import os
import zlib

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX = os.path.join(ROOT, "art", "textures", "generated")
PX = 1024

# A sash stile is 42 mm wide and a slat 50 mm, so both sheets have to survive
# being sampled across a hand's width of surface. One tile at 0.5 m puts a
# couple of draw lines across a slat rather than a hundred, which is what the
# real thing looks like from inside the room.
TILE_M = 0.50

# Held DELIBERATELY darker than the slats behind it. First pass put both near
# 0.82 and the frame disappeared into the blind: a sash is only legible as
# joinery when there is something for it to be legible against, and what is
# always behind it is the treatment. Period sash paint went on over lead and
# went warm; the slats are cold enamel. That difference is the whole reading.
SASH_PAINT = np.array([0.66, 0.625, 0.555])  # lead white gone warm and dirty
SASH_CHALK = np.array([0.78, 0.765, 0.725])  # where the weather has bloomed it
SASH_DIRT = np.array([0.30, 0.275, 0.235])   # run-off, bottom rail and corners

SLAT_FACE = np.array([0.855, 0.845, 0.805])  # pale enamel over aluminium
SLAT_DUST = np.array([0.60, 0.575, 0.525])   # what settles on the upper face


def _noise(seed, size, octaves=5):
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size), dtype=np.float64)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = max(2, 2 ** (o + 2))
        grid = rng.random((n, n))
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize(
            (size, size), Image.BICUBIC)
        out += np.asarray(img, dtype=np.float64) / 255.0 * amp
        total += amp
        amp *= 0.5
    return out / total


def _streaks(seed, size, count, softness):
    """Bands running down V, the direction a member's grain runs.

    Built by stretching a one-dimensional field across the sheet rather than
    by blurring a two-dimensional one: a blurred noise field still has
    structure across the streak, and that cross-structure is what makes
    procedural brush marks read as static instead of as drag.
    """
    rng = np.random.default_rng(seed)
    line = rng.random(size)
    line = np.asarray(
        Image.fromarray((line[None, :] * 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(softness)), dtype=np.float64)[0] / 255.0
    coarse = rng.random(max(4, count))
    coarse = np.asarray(
        Image.fromarray((coarse[None, :] * 255).astype(np.uint8)).resize(
            (size, 1), Image.BICUBIC), dtype=np.float64)[0] / 255.0
    field = 0.6 * line + 0.4 * coarse
    return np.repeat(field[None, :], size, axis=0)


def _normal_from_height(height, strength):
    """OpenGL +Y, matching every other normal map in the project."""
    gy, gx = np.gradient(height.astype(np.float64))
    nx = -gx * strength
    ny = gy * strength
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.dstack([nx / length, ny / length, nz / length])


def _write(name, albedo, rough, height, strength, note):
    out = os.path.join(TEX, name)
    os.makedirs(out, exist_ok=True)
    Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8),
                    "RGB").save(os.path.join(out, "albedo.png"))
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8),
                    "L").save(os.path.join(out, "roughness.png"))
    n = _normal_from_height(height, strength)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8),
                    "RGB").save(os.path.join(out, "normal.png"))
    with open(os.path.join(out, "material.json"), "w", encoding="utf-8") as fh:
        json.dump({"name": name, "meters_per_tile": TILE_M, "note": note},
                  fh, indent=2)
        fh.write("\n")
    print("%-11s -> %s" % (name, os.path.relpath(out, ROOT)))
    print("   albedo mean %.3f  roughness %.2f..%.2f  %.2f m per tile"
          % (albedo.mean(), rough.min(), rough.max(), TILE_M))


def build_sash():
    seed = zlib.crc32(b"sash") % 9973
    # Brush drag along the member, plus the blotch of a coat laid over an
    # older one that was never fully rubbed down.
    drag = _streaks(seed, PX, 34, 1.6)
    blotch = _noise(seed + 13, PX, octaves=4)
    fine = _noise(seed + 51, PX, octaves=6)

    # Chalking is a weather effect and it is patchy, not uniform: the sheet
    # has to carry both a sound painted area and a bloomed one, because a
    # uniformly chalked sash reads as unpainted timber.
    chalk = np.clip((blotch - 0.42) * 2.3, 0.0, 1.0)
    grime = np.clip((1.0 - blotch) * 0.55 + fine * 0.25 - 0.22, 0.0, 1.0)

    base = SASH_PAINT[None, None, :] * (0.94 + 0.12 * drag[:, :, None])
    albedo = base + (SASH_CHALK - SASH_PAINT)[None, None, :] \
        * chalk[:, :, None]
    albedo = albedo + (SASH_DIRT[None, None, :] - albedo) \
        * (grime[:, :, None] * 0.55)

    # Sound paint is satin; chalked paint is dead flat; the greasy run-off in
    # the corners is the only thing on a sash that is smoother than the paint.
    rough = 0.42 + 0.34 * chalk - 0.16 * grime + 0.05 * fine

    # The relief is the brush itself and the ridge where one coat overlapped
    # the last. Small — this is paint, not render.
    height = 0.55 + 0.30 * drag + 0.15 * blotch
    _write("sash", albedo, rough, height, 3.0,
           "Generated by art/tools/build_window_joinery_maps.py. Painted "
           "window joinery on the wet side of the wall: brush drag along the "
           "member, chalked bloom where the weather has had it, run-off in "
           "the corners. Kept separate from `trim` because a skirting board "
           "has never been rained on.")


def build_blind_slat():
    seed = zlib.crc32(b"blind_slat") % 9973
    # Draw lines from the roll, running along the slat. Finer and far more
    # regular than a brush: this is a machine mark, not a hand one.
    draw = _streaks(seed, PX, 96, 0.7)
    settle = _noise(seed + 29, PX, octaves=5)
    speckle = _noise(seed + 67, PX, octaves=7)

    # Dust is a DEPOSIT, so it lands in a field with soft edges and it never
    # covers: a slat that is uniformly dusty is a grey slat, and what makes
    # this read as dust is that the enamel still shows through it.
    dust = np.clip(settle * 0.85 + speckle * 0.35 - 0.30, 0.0, 1.0) * 0.62

    base = SLAT_FACE[None, None, :] * (0.965 + 0.07 * draw[:, :, None])
    albedo = base + (SLAT_DUST[None, None, :] - base) * dust[:, :, None]

    # Enamel is smooth and dust is not, and the contrast between them across
    # one slat is most of what says "nobody has cleaned these". Backlighting
    # only sharpens that: the dusty half scatters and the clean half does not.
    rough = 0.30 + 0.52 * dust + 0.06 * draw

    height = 0.50 + 0.34 * draw + 0.16 * dust
    _write("blind_slat", albedo, rough, height, 2.2,
           "Generated by art/tools/build_window_joinery_maps.py. Rolled slat "
           "with draw lines along its length and dust on the face that points "
           "up. These are the surfaces window_glow lights from behind, so the "
           "roughness break between clean enamel and settled dust is doing "
           "more work here than the colour is.")


def build() -> None:
    build_sash()
    build_blind_slat()


if __name__ == "__main__":
    build()
