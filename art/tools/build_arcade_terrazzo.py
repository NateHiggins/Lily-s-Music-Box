"""Prepare fine honed terrazzo stock without publishing it into the game.

Generated diffuse plates remain byte-exact. Independent, physically calibrated
polish/pore relief supplies normals; light marble is never treated as raised
stone. Periodic metre charts are required at installation. --out-root is a review
directory, not the canonical checkout. Publication waits for composed review.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
TILE = .4
SOURCES = {
    'arcade_terrazzo': 'arcade_fine_terrazzo_20261018.png',
    'arcade_terrazzo_dark': 'arcade_dark_terrazzo_20261018.png',
}


def build(out_root):
    reports = []
    for index, (key, filename) in enumerate(SOURCES.items()):
        source = ROOT / 'art/textures/ai_sources' / filename
        with Image.open(source) as image:
            if image.width != image.height:
                raise ValueError('Square stock required: ' + filename)
            size = image.width
        rng = np.random.default_rng(19281018 + index)
        u = (np.arange(size) / size)[None, :]
        v = (np.arange(size) / size)[:, None]

        def field(low, high, count=64):
            # Integer Fourier modes join periodically. Repeating the stock
            # avoids the conspicuous mirrored aggregate motifs rejected on
            # the first bench. Optical fields remain pigment-independent.
            k = rng.integers(low, high + 1, count)
            l = rng.integers(low, high + 1, count)
            phase_u, phase_v = rng.uniform(0, 2 * np.pi, (2, count))
            value = (np.cos(2 * np.pi * v * l[None, :] + phase_v) * rng.normal(size=count)) @ np.cos(2 * np.pi * k[:, None] * u + phase_u[:, None])
            return value / value.std()

        polish = field(70, 220)
        pores = np.clip(field(35, 160) - 1.8, 0, 2.4) / 2.4
        # Ground flush: 4 microns RMS polish, at most 25 micron pore depth.
        height = polish * .000004 - pores * .000025
        rough = np.clip(.36 + polish * .008 + pores * .09, .32, .48)
        dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * size / (2 * TILE)
        dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * size / (2 * TILE)
        normal = np.stack((-dx, dy, np.ones_like(dx)), axis=-1)
        normal /= np.linalg.norm(normal, axis=-1)[..., None]
        folder = Path(out_root) / 'materials' / key
        folder.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, folder / 'albedo.png')
        for name, data in [('roughness', rough), ('normal', normal * .5 + .5)]:
            Image.fromarray(np.rint(np.clip(data, 0, 1) * 255).astype(np.uint8)).save(folder / (name + '.png'))
        span = float(np.ptp(height))
        Image.fromarray(np.rint((height - height.min()) / span * 65535).astype(np.uint16)).save(folder / 'height.png')
        maps = {name: name + '.png' for name in ['albedo', 'roughness', 'normal', 'height']}
        meta = {
            'material': key, 'status': 'DRAFT_NOT_INSTALLED',
            'generator': 'art/tools/build_arcade_terrazzo.py',
            'generator_sha256_lf': hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n', b'\n')).hexdigest(),
            'albedo_source': source.relative_to(ROOT).as_posix(),
            'albedo_source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'meters_per_tile': TILE, 'relief_mm': span * 1000,
            'normal_strength': 1.0, 'height_storage_bits': 16,
            'uv_contract': 'Periodic metre charts at 0.4 m per repeat; repeat sampling. No mirrored aggregate. Independent periodic relief with wrapped central derivatives.',
            'surface': 'Honed flush aggregate. Independent polish and sparse micropores; no chip displacement, cracks, grout or baked wear.',
            'maps': maps,
            'map_sha256': {name: hashlib.sha256((folder / file).read_bytes()).hexdigest() for name, file in maps.items()},
            'measurements': {'roughness_min': float(rough.min()), 'roughness_max': float(rough.max()),
                             'normal_slope_rms': float(np.sqrt(np.mean(dx * dx + dy * dy))),
                             'nonfinite_values': int(np.sum(~np.isfinite(normal)))},
        }
        (folder / 'material.json').write_text(json.dumps(meta, indent=2) + '\n', encoding='utf8', newline='\n')
        reports.append(meta)
    return reports


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out-root', type=Path, required=True)
    args = parser.parse_args()
    for row in build(args.out_root):
        print(row['material'], row['relief_mm'], 'mm; ', row['measurements'])
