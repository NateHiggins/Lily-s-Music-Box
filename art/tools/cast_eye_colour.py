#!/usr/bin/env python3
"""The cast's brown eyes. The pack's "brown" iris is maroon, and in the engine a brown-eyed face read as red-eyed
(close review of cast_r13, 2026-11-13). `true_brown` turns the iris, and only the iris, to a dark brown: its
drawing (the fibres, the dark rim, the pupil) is kept, its hue is moved from red to brown and it is a little
less saturated and darker. The white of the eye and its veins are left as they are.

    python art/tools/cast_eye_colour.py <picture in> <picture out>

art/blender/scripts/build_cast_wardrobe.py calls `true_brown` on the picture it loads; this file is also run on
a picture already exported. Numpy only, so Blender's own Python can import it.
"""
from __future__ import annotations

import sys

import numpy as np

BROWN_HUE = 0.072          # 26 degrees: a warm dark brown
RED_BAND = 0.07            # hues this near to red are the iris


def true_brown(rgb: np.ndarray) -> np.ndarray:
    """rgb: float array (..., 3) in 0..1, display values. Returns the same shape."""
    rgb = np.clip(rgb.astype(np.float32), 0.0, 1.0)
    high, low = rgb.max(axis=-1), rgb.min(axis=-1)
    spread = high - low
    saturation = np.where(high > 1e-6, spread / np.maximum(high, 1e-6), 0.0)
    safe = np.maximum(spread, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(high == r, ((g - b) / safe) % 6.0, np.where(high == g, (b - r) / safe + 2.0, (r - g) / safe + 4.0)) / 6.0
    from_red = np.minimum(hue, 1.0 - hue)
    # How much of a point is iris: red in hue and saturated. Eased, so the rim blends and the veins stay.
    iris = np.clip((RED_BAND - from_red) / 0.03, 0.0, 1.0) * np.clip((saturation - 0.3) / 0.2, 0.0, 1.0)
    new_s = np.clip(saturation * 0.82, 0.0, 1.0)
    new_v = high * 0.8
    sector = BROWN_HUE * 6.0
    x = new_v * new_s * (1.0 - abs(sector % 2.0 - 1.0))
    chroma = new_v * new_s
    base = new_v - chroma
    brown = np.stack([base + chroma, base + x, base], axis=-1)      # sector 0: red highest, then green
    return rgb + (brown - rgb) * iris[..., None]


def main(argv: list[str]) -> int:
    from PIL import Image

    source, target = argv[1], argv[2]
    picture = Image.open(source).convert("RGBA")
    data = np.asarray(picture).astype(np.float32) / 255.0
    data[..., :3] = true_brown(data[..., :3])
    Image.fromarray((np.clip(data, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8), "RGBA").save(target)
    print("wrote", target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
