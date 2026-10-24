"""Three period drapery fabrics, synthesized deterministically and seamlessly.

1920s American apartment drapery (design/ORISON_DRAPERY_2026-10-24.md):
  monks_cloth  coarse 2x2 basket-weave cotton, oatmeal; the Arts and Crafts
               overdrapery of modest flats
  velour       cotton pile drapery cloth; the parlour's heavy curtain, with a
               soft directional pile and crushed sheen, no pattern
  ninon        sheer silk-rayon voile for "glass curtains" hung against the
               glass; a fine open plain weave, near-white

Each set writes albedo/roughness/height/normal to art/textures/procedural/<name>/
and copies albedo/rough/normal to game/assets/building/textures as
T_ai_materials_<name>_*. No lettering, photographs, baked light or seams: every
field is built on a periodic lattice, so the plate tiles exactly.
"""
from pathlib import Path
import hashlib
import json
import shutil

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
N = 1024


def periodic_noise(rng, cutoff):
    freq = np.fft.fftfreq(N)
    radius = np.hypot(freq[:, None], freq[None, :])
    field = np.fft.ifft2(np.fft.fft2(rng.normal(size=(N, N))) * np.exp(-(radius / cutoff) ** 2)).real
    return field / field.std()


def threads(count, axis, rng, wobble=0.0):
    """A periodic thread profile: `count` threads across the plate, each a soft
    rounded ridge 0..1, with slight per-thread thickness variation."""
    coord = (np.arange(N) / N) * count
    phase = coord % 1.0
    index = np.floor(coord).astype(int) % count
    thickness = 0.82 + 0.18 * rng.random(count)
    ridge = np.clip(1.0 - np.abs(phase - 0.5) * 2.0 / thickness[index], 0, 1) ** 0.6
    profile = ridge
    return profile[None, :] if axis == "x" else profile[:, None]


def normal_from(height, relief, metres):
    scale = relief * N / metres
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5 * scale
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5 * scale
    normal = np.stack((-dx, dy, np.ones_like(dx)), axis=-1)
    return normal / np.linalg.norm(normal, axis=-1)[..., None]


def write(name, albedo, rough, height, normal, metres, relief_mm, source, seed):
    out = ROOT / "art/textures/procedural" / name
    out.mkdir(parents=True, exist_ok=True)
    for key, values in [("albedo", albedo), ("roughness", rough * 255), ("height", height * 255),
                        ("normal", (normal * 0.5 + 0.5) * 255)]:
        Image.fromarray(np.rint(np.clip(values, 0, 255)).astype(np.uint8)).save(out / (key + ".png"))
    meta = {"material": name, "generator": "art/tools/build_drapery_fabrics.py", "source": source,
            "seed": seed, "meters_per_tile": metres, "relief_mm": relief_mm,
            "maps": {"albedo": "albedo.png", "roughness": "roughness.png", "height": "height.png",
                     "normal": "normal.png"}}
    meta["map_sha256"] = {k: hashlib.sha256((out / (k + ".png")).read_bytes()).hexdigest() for k in meta["maps"]}
    (out / "material.json").write_text(json.dumps(meta, indent=2) + "\n", newline="\n")
    for source_key, suffix in [("albedo", "albedo"), ("roughness", "rough"), ("normal", "normal")]:
        shutil.copyfile(out / (source_key + ".png"),
                        ROOT / "game/assets/building/textures" / ("T_ai_materials_%s_%s.png" % (name, suffix)))
    print("%s: %.2f m per tile, seamless periodic plate" % (name, metres))


def monks_cloth():
    seed = 19281110
    rng = np.random.default_rng(seed)
    # 0.30 m tile; heavy 2x2 basket weave at ~3.75 mm per pair of threads.
    pairs = 80
    warp = threads(pairs * 2, "x", rng)
    weft = threads(pairs * 2, "y", rng)
    cell_x = (np.floor(np.arange(N) / N * pairs) % 2).astype(float)[None, :]
    cell_y = (np.floor(np.arange(N) / N * pairs) % 2).astype(float)[:, None]
    over = np.where((cell_x + cell_y) % 2 == 0, 1.0, 0.0)
    weave = over * warp + (1 - over) * weft
    slub = periodic_noise(rng, 0.03)
    fibre = periodic_noise(rng, 0.25)
    height = np.clip(0.18 + 0.64 * weave + 0.05 * slub + 0.03 * fibre, 0, 1)
    base = np.array([196.0, 181.0, 152.0])
    shade = 0.80 + 0.22 * weave + 0.022 * slub + 0.02 * fibre
    albedo = base[None, None, :] * shade[..., None]
    rough = np.clip(0.88 + 0.06 * (1 - weave) + 0.02 * fibre, 0.78, 0.97)
    write("monks_cloth", albedo, rough, height, normal_from(height, 0.0007, 0.30), 0.30, 0.7,
          "Coarse 2x2 basket-weave cotton monk's cloth, oatmeal, no pattern, lettering or baked light.", seed)


def velour():
    seed = 19281111
    rng = np.random.default_rng(seed)
    # 0.40 m tile; a dense cut pile reads as fine noise with soft crushed
    # patches and a faint vertical lay of the pile.
    pile = periodic_noise(rng, 0.35)
    lay = periodic_noise(rng, 0.04)
    crush = periodic_noise(rng, 0.012)
    vertical = np.repeat(periodic_noise(rng, 0.06).mean(axis=0, keepdims=True), N, axis=0)
    height = np.clip(0.55 + 0.10 * pile + 0.06 * lay + 0.05 * vertical, 0, 1)
    # Neutral warm grey so per-resident tints (burgundy, green, taupe) carry it.
    base = np.array([168.0, 160.0, 154.0])
    shade = 0.90 + 0.05 * pile + 0.028 * crush + 0.02 * vertical
    albedo = base[None, None, :] * shade[..., None]
    # Pile: high roughness, a little lower where crushed (the sheen of velour).
    rough = np.clip(0.80 - 0.06 * np.clip(crush, 0, None) + 0.03 * pile, 0.66, 0.92)
    write("velour", albedo, rough, height, normal_from(height, 0.00035, 0.40), 0.40, 0.35,
          "Cotton pile drapery velour, neutral for tinting, crushed sheen, no pattern, lettering or baked light.", seed)


def ninon():
    seed = 19281112
    rng = np.random.default_rng(seed)
    # 0.12 m tile; a fine open plain weave (sheer voile/ninon), ~0.5 mm threads
    # with open interstices the sheer shader reads as lighter, rougher gaps.
    count = 240
    warp = threads(count, "x", rng)
    weft = threads(count, "y", rng)
    cover = np.clip(warp + weft, 0, 1)
    fibre = periodic_noise(rng, 0.3)
    height = np.clip(0.25 + 0.5 * cover + 0.04 * fibre, 0, 1)
    base = np.array([238.0, 236.0, 230.0])
    shade = 0.93 + 0.06 * cover + 0.01 * fibre
    albedo = base[None, None, :] * shade[..., None]
    rough = np.clip(0.62 + 0.12 * (1 - cover) + 0.02 * fibre, 0.55, 0.8)
    write("ninon", albedo, rough, height, normal_from(height, 0.00012, 0.12), 0.12, 0.12,
          "Sheer silk-rayon ninon voile for glass curtains, fine open plain weave, near-white, no lettering or baked light.", seed)


if __name__ == "__main__":
    monks_cloth()
    velour()
    ninon()
