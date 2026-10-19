"""Author periodic limewashed finish plaster, without baked cracks or lighting.

Pigment, trowel relief, mineral tooth and roughness have independent fields.
The normal is derived from physical height in metres, not albedo luminance.
"""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
KEY = 'limewash_plaster'
TILE_M = 1.8
SIZE = 1024
SEED = 19281019


def build(out_root):
    target = Path(out_root) / 'art/textures/procedural' / KEY
    target.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)
    frequency = np.fft.fftfreq(SIZE)
    radius = np.hypot(frequency[:, None], frequency[None, :])

    def field(cutoff):
        values = np.fft.ifft2(np.fft.fft2(rng.normal(size=(SIZE, SIZE))) *
                             np.exp(-(radius / cutoff) ** 2)).real
        return (values - values.mean()) / values.std()

    pigment = field(.0025)
    lime_bloom = field(.014)
    trowel = field(.0045)
    mineral = field(.16)
    tooth = field(.32)
    # Quiet warm mineral colour, not a grey AO map or an all-over crack stencil.
    shade = np.clip(pigment * 1.8 + lime_bloom * .65 + mineral * .25, -6, 6)
    albedo = np.array([221., 217., 206.]) + shade[..., None]
    roughness = np.clip(.855 + lime_bloom * .009 + mineral * .012, .80, .91)
    relief_m = .00024
    height = np.clip(.5 + trowel * .13 + mineral * .075 + tooth * .025, 0, 1)
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * relief_m * SIZE / (2 * TILE_M)
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * relief_m * SIZE / (2 * TILE_M)
    normal = np.stack((-dx, dy, np.ones_like(dx)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1)[..., None]
    for name, values in [('albedo', albedo), ('roughness', roughness * 255),
                         ('height', height * 65535), ('normal', (normal * .5 + .5) * 255)]:
        dtype = np.uint16 if name == 'height' else np.uint8
        Image.fromarray(np.rint(np.clip(values, 0, 65535 if name == 'height' else 255)).astype(dtype)).save(target / (name + '.png'))
    meta = {'material': KEY, 'generator': 'art/tools/build_limewash_plaster.py',
            'generator_sha256_lf': hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n', b'\n')).hexdigest(),
            'source': __doc__, 'seed': SEED, 'meters_per_tile': TILE_M,
            'relief_mm': relief_m * 1000, 'height_encoding': 'uint16, physical 0..1 span; no percentile stretch',
            'normal_convention': 'OpenGL +Y, wrapped physical-height derivatives',
            'normal_rms_degrees': float(np.sqrt(np.mean(np.arccos(np.clip(normal[..., 2], -1, 1)) ** 2)) * 180 / np.pi),
            'maps': {key: key + '.png' for key in ['albedo', 'roughness', 'height', 'normal']}}
    meta['map_sha256'] = {key: hashlib.sha256((target / name).read_bytes()).hexdigest() for key, name in meta['maps'].items()}
    (target / 'material.json').write_text(json.dumps(meta, indent=2) + '\n', encoding='utf-8', newline='\n')
    shipping = Path(out_root) / 'game/assets/building/textures'
    shipping.mkdir(parents=True, exist_ok=True)
    for key, suffix in [('albedo', 'albedo'), ('roughness', 'rough'), ('normal', 'normal')]:
        (shipping / ('T_ai_materials_' + KEY + '_' + suffix + '.png')).write_bytes((target / (key + '.png')).read_bytes())
    print(json.dumps({'material': KEY, 'tile_m': TILE_M, 'relief_mm': meta['relief_mm'],
                      'normal_rms_degrees': meta['normal_rms_degrees']}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out-root', type=Path, default=ROOT)
    build(parser.parse_args().out_root)
