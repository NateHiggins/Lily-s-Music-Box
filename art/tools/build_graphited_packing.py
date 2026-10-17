"""Periodic graphited fibre packing, shared by stem and removable union seals.

Original procedural weave; no lettering, lighting, photographic source or
painted highlights. The 8 mm tile carries sixteen 0.5 mm threads. Graphite
darkens the fibres but does not make the composite a polished metal.
"""
from pathlib import Path
import hashlib
import json
import shutil

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def build():
    out = ROOT / 'art/textures/procedural/graphited_packing'
    out.mkdir(parents=True, exist_ok=True)
    size, tile, threads, relief = 256, .008, 16, .000060
    y, x = np.mgrid[:size, :size] / size
    warp = np.cos(x * threads * 2 * np.pi)
    weft = np.cos(y * threads * 2 * np.pi)
    cross = np.cos(x * threads * np.pi) * np.cos(y * threads * np.pi)
    height = (warp * (.5 + .35 * cross) + weft * (.5 - .35 * cross)) * .25 + .5
    fibres = np.sin(2 * np.pi * (x * 64 + y * 32))
    height = np.clip(height + fibres * .04, 0, 1)
    albedo = np.clip(np.array([43, 44, 43])[None, None, :]
                     + (height - .5)[..., None] * 28
                     + fibres[..., None] * 1.5, 0, 255)
    # Different fibre bundles retain different amounts of graphite. This
    # restrained variation follows the weave, never a fixture-sized dirt mask.
    roughness = np.clip(.83 + (height - .5) * .16 + fibres * .015, .74, .92)
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * relief * size * .5 / tile
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * relief * size * .5 / tile
    normal = np.stack((-dx, dy, np.ones_like(dx)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1)[..., None]
    for name, data in [('albedo', albedo), ('roughness', roughness * 255),
                       ('normal', (normal * .5 + .5) * 255), ('height', height * 255)]:
        Image.fromarray(np.rint(data).astype('uint8')).save(out / (name + '.png'))
    maps = {key: key + '.png' for key in ('albedo', 'roughness', 'normal', 'height')}
    metadata = dict(material='graphited_packing',
                    generator='art/tools/build_graphited_packing.py', source=__doc__,
                    meters_per_tile=tile, relief_mm=relief * 1000,
                    normal_convention='OpenGL', normal_strength=1.0, metallic=0,
                    roughness_range=[float(roughness.min()), float(roughness.max())],
                    maps=maps, map_sha256={key: hashlib.sha256((out / name).read_bytes()).hexdigest()
                                          for key, name in maps.items()})
    (out / 'material.json').write_text(json.dumps(metadata, indent=2) + '\n',
                                      encoding='utf-8', newline='\n')
    for source, suffix in [('albedo', 'albedo'), ('roughness', 'rough'), ('normal', 'normal')]:
        shutil.copyfile(out / (source + '.png'), ROOT / 'game/assets/building/textures'
                        / ('T_ai_materials_graphited_packing_' + suffix + '.png'))
    print('graphited_packing: 256 px, 8 mm tile, 60 micron relief, three runtime maps')


if __name__ == '__main__':
    build()
