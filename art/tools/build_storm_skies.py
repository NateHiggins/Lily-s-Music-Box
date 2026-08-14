"""Build the geography-locked four-state Orison storm panorama family.

The generated overcast master supplies cloud structure only.  The accepted
Queens night panorama supplies the complete lower skyline, so no generative
edit can move a roof, bridge, horizon or camera.  Every shipped state is then a
deterministic grade of that one composite, with alpha storing broad cloud
optical thickness for the runtime hidden-source mask.
"""

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SKY = ROOT / "game/assets/building/textures/sky"
MASTER_SOURCE = SKY / "orison_queens_storm_overcast_master_source.png"
QUEENS_SOURCE = SKY / "orison_queens_night_half_dome_4k.png"
WIDTH, HEIGHT = 4096, 2048
WRAP = 192
ZENITH = 72


STATES = {
    "morning": {
        "gain": np.array([0.70, 0.75, 0.82], dtype=np.float32),
        "gamma": 0.90,
        "lift": np.array([0.018, 0.020, 0.024], dtype=np.float32),
        "seam_u": 0.17,
        "seam": np.array([0.105, 0.052, 0.018], dtype=np.float32),
    },
    "day": {
        "gain": np.array([0.90, 0.94, 0.98], dtype=np.float32),
        "gamma": 0.84,
        "lift": np.array([0.025, 0.027, 0.030], dtype=np.float32),
        "seam_u": 0.50,
        "seam": np.array([0.025, 0.027, 0.030], dtype=np.float32),
    },
    "evening": {
        "gain": np.array([0.58, 0.49, 0.64], dtype=np.float32),
        "gamma": 0.94,
        "lift": np.array([0.010, 0.008, 0.016], dtype=np.float32),
        "seam_u": 0.78,
        "seam": np.array([0.125, 0.052, 0.015], dtype=np.float32),
    },
    "night": {
        "gain": np.array([0.18, 0.25, 0.43], dtype=np.float32),
        "gamma": 1.04,
        "lift": np.array([0.003, 0.005, 0.011], dtype=np.float32),
        "seam_u": 0.70,
        "seam": np.array([0.035, 0.020, 0.010], dtype=np.float32),
    },
}


def _rgb(path: Path) -> np.ndarray:
    image = Image.open(path).convert("RGB").resize(
        (WIDTH, HEIGHT), Image.Resampling.LANCZOS
    )
    return np.asarray(image, dtype=np.float32) / 255.0


def _smoothstep(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
    t = np.clip((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _composite_master() -> np.ndarray:
    weather = _rgb(MASTER_SOURCE)
    queens = _rgb(QUEENS_SOURCE)
    # The transition is wholly above the skyline. Below it, the accepted
    # panorama remains pixel-identical before the state grade is applied.
    rows = np.arange(HEIGHT, dtype=np.float32)[:, None, None]
    keep_queens = _smoothstep(1450.0, 1680.0, rows)
    master = weather * (1.0 - keep_queens) + queens * keep_queens

    # A quiet convergence band removes polar pinwheels without inventing a
    # second cloud structure at the zenith.
    zenith_mean = master[:ZENITH].mean(axis=1, keepdims=True)
    for y in range(ZENITH):
        t = y / float(ZENITH - 1)
        master[y] = zenith_mean[y] * (1.0 - t) + master[y] * t

    # Make the cylindrical seam exact, feathering toward untouched cloud over
    # the ruled 192 pixels on both edges.
    for x in range(WRAP):
        t = _smoothstep(0.0, float(WRAP - 1), np.array(x, np.float32))
        right = WIDTH - 1 - x
        average = (master[:, x] + master[:, right]) * 0.5
        master[:, x] = average * (1.0 - t) + master[:, x] * t
        master[:, right] = average * (1.0 - t) + master[:, right] * t
    return np.clip(master, 0.0, 1.0)


def _grade(master: np.ndarray, spec: dict) -> np.ndarray:
    graded = np.power(master, spec["gamma"]) * spec["gain"] + spec["lift"]
    yy, xx = np.mgrid[0:HEIGHT, 0:WIDTH].astype(np.float32)
    u = xx / float(WIDTH - 1)
    v = yy / float(HEIGHT - 1)
    # Circular distance keeps a horizon stain continuous through the wrap.
    du = np.minimum(np.abs(u - spec["seam_u"]), 1.0 - np.abs(u - spec["seam_u"]))
    seam = np.exp(-((du / 0.18) ** 2)) * np.exp(-(((v - 0.78) / 0.10) ** 2))
    graded += seam[..., None] * spec["seam"]
    return np.clip(graded, 0.0, 1.0)


def _cloud_alpha(master: np.ndarray) -> np.ndarray:
    luma = master @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    thickness = np.clip(0.78 + (0.43 - luma) * 0.52, 0.48, 0.94)
    # Skyline is always optically solid; the glow belongs behind cloud, never
    # through a building silhouette.
    rows = np.arange(HEIGHT, dtype=np.float32)[:, None]
    thickness = np.maximum(thickness, _smoothstep(1530.0, 1770.0, rows) * 0.97)
    return thickness


def main() -> None:
    master = _composite_master()
    alpha = _cloud_alpha(master)
    for state, spec in STATES.items():
        rgb = _grade(master, spec)
        rgba = np.concatenate([rgb, alpha[..., None]], axis=2)
        pixels = np.round(rgba * 255.0).astype(np.uint8)
        target = SKY / f"orison_queens_{state}_rain_half_dome_4k.png"
        # Pillow's exhaustive PNG optimiser takes more than the project's
        # one-minute tool bound at 4K. Normal compression is deterministic and
        # Godot imports the same pixels.
        Image.fromarray(pixels, "RGBA").save(target, compress_level=6)
        preview = Image.fromarray(pixels[..., :3], "RGB").resize(
            (1024, 512), Image.Resampling.LANCZOS
        )
        preview.save(
            SKY / f"orison_queens_{state}_rain_half_dome_preview.jpg",
            quality=92,
            optimize=True,
        )
        print(f"{state}: {target.name} ({WIDTH}x{HEIGHT}, RGBA)")


if __name__ == "__main__":
    main()
