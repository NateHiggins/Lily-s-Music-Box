#!/usr/bin/env python3
"""Turn a drawing of an embroidered design on a black ground into the two pictures a gown wears.

    python art/tools/cast_embroidery.py <drawing.png> <out stem> [--low 0.1] [--high 0.26] [--fill 0.94]
                                        [--stitch 3.2] [--relief 5.0] [--mirror]

Writes <out stem>.png (the threads, transparent where there is only ground) and <out stem>_normal.png (their
relief: the body of each stitched shape stands up from the cloth, and a fine diagonal satin stitch runs over
it). Both are square, 1024 on a side, with the design upright in the middle and clear margins all round, which
is what art/blender/scripts/build_cast_wardrobe.py `embroidery` wraps round a gown.

The drawing is made for the purpose (art/tools/imagegen.py or by hand). No reference photograph is used, and
nothing with lettering passes: look at the drawing first.
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

SIZE = 1024


def smoothstep(low: float, high: float, value: np.ndarray) -> np.ndarray:
    t = np.clip((value - low) / (high - low), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def blur(layer: np.ndarray, radius: float) -> np.ndarray:
    picture = Image.fromarray(np.clip(layer * 255.0, 0, 255).astype(np.uint8))
    return np.asarray(picture.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32) / 255.0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("drawing")
    parser.add_argument("stem")
    parser.add_argument("--low", type=float, default=0.1, help="darker than this is ground")
    parser.add_argument("--high", type=float, default=0.26, help="lighter than this is thread")
    parser.add_argument("--fill", type=float, default=0.94, help="how much of the picture's height the design takes")
    parser.add_argument("--stitch", type=float, default=3.2, help="the satin stitch's spacing in pixels")
    parser.add_argument("--relief", type=float, default=5.0)
    parser.add_argument("--mirror", action="store_true")
    args = parser.parse_args()
    drawing = Image.open(args.drawing).convert("RGB")
    if args.mirror:
        drawing = drawing.transpose(Image.FLIP_LEFT_RIGHT)
    tall = int(SIZE * args.fill)
    wide = min(SIZE - 32, int(tall * drawing.size[0] / drawing.size[1]))
    drawing = drawing.resize((wide, tall), Image.LANCZOS)
    rgb = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    left, top = (SIZE - wide) // 2, (SIZE - tall) // 2
    rgb[top:top + tall, left:left + wide] = np.asarray(drawing, dtype=np.float32) / 255.0
    brightest = rgb.max(axis=2)
    thread = smoothstep(args.low, args.high, brightest)
    # Specks of light in the ground are not stitches: a shape must survive being worn down a pixel.
    solid = Image.fromarray((thread * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(5))
    thread = np.minimum(thread, np.asarray(solid, dtype=np.float32) / 255.0)
    # Clear margins, so the design can be wrapped without its edge showing.
    # The drawing's own edge is a straight line; stitching does not stop on one. It thins out over a thumb's width.
    margin = np.zeros((SIZE, SIZE), dtype=np.float32)
    across = np.clip(np.minimum(np.arange(wide), np.arange(wide)[::-1]) / 44.0, 0.0, 1.0)
    down = np.clip(np.minimum(np.arange(tall), np.arange(tall)[::-1]) / 44.0, 0.0, 1.0)
    margin[top:top + tall, left:left + wide] = down[:, None] * across[None, :]
    margin = smoothstep(0.0, 1.0, margin)
    thread = blur(thread * margin, 0.7)
    # Silk thread is brighter and richer than a picture of it.
    grey = rgb.mean(axis=2, keepdims=True)
    colour = np.clip((grey + (rgb - grey) * 1.25) * 1.2, 0.0, 1.0)
    mean = (colour * thread[..., None]).sum(axis=(0, 1)) / max(float(thread.sum()), 1e-6)
    colour = np.where(thread[..., None] > 0.02, colour, mean)        # no dark fringe where the edge is sampled
    out = np.concatenate([colour, thread[..., None]], axis=2)
    Image.fromarray(np.clip(out * 255.0, 0, 255).astype(np.uint8), "RGBA").save(args.stem + ".png")
    # Relief: each stitched shape stands up, fuller where the thread is lighter, with the satin stitch across it.
    ys, xs = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    lay = math.radians(35.0)
    satin = np.sin((xs * math.cos(lay) + ys * math.sin(lay)) * math.tau / args.stitch)
    height = blur(thread, 2.2) * (0.6 + 0.4 * blur(brightest, 1.0)) + 0.07 * satin * thread
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * args.relief
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * args.relief
    length = np.sqrt(dx * dx + dy * dy + 1.0)
    # Green up, as the game's normal maps are: the picture's rows run downward, so the sign of dy is kept.
    normal = np.stack([-dx / length * 0.5 + 0.5, dy / length * 0.5 + 0.5, 1.0 / length * 0.5 + 0.5], axis=2)
    Image.fromarray(np.clip(normal * 255.0, 0, 255).astype(np.uint8), "RGB").save(args.stem + "_normal.png")
    print("wrote", args.stem + ".png", "and", args.stem + "_normal.png", "stitched: %.1f%% of the picture" % (float((thread > 0.5).mean()) * 100.0))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
