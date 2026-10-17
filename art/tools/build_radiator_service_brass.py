"""Periodic aged service brass, without door-buffing streaks or painted wear.

Fine oxide colour variation and isotropic tool microrelief are independent.
No baked lighting, fixture-sized dirt, lettering or photographic source.
"""
from pathlib import Path
import hashlib
import json
import shutil

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def build():
    out = ROOT / 'art/textures/procedural/radiator_service_brass'
    out.mkdir(parents=True, exist_ok=True)
    size, tile = 512, .04
    rng = np.random.default_rng(1928101702)
    fx, fy = np.meshgrid(np.fft.fftfreq(size), np.fft.fftfreq(size))

    def field(cutoff):
        values = np.fft.ifft2(np.fft.fft2(rng.standard_normal((size, size)))
                             * np.exp(-(fx * fx + fy * fy) / cutoff**2)).real
        return (values - values.mean()) / values.std()

    fine, tooling, oxide = field(.28), field(.10), field(.025)
    height_m = tooling * .00000065 + fine * .00000018
    dx = (np.roll(height_m, -1, 1) - np.roll(height_m, 1, 1)) * size / (2 * tile)
    dy = (np.roll(height_m, -1, 0) - np.roll(height_m, 1, 0)) * size / (2 * tile)
    normal = np.stack((-dx, dy, np.ones_like(dx)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1)[..., None]
    albedo = np.clip(np.array([166, 137, 80])[None, None, :]
                     + oxide[..., None] * np.array([1.4, 1.2, .7])
                     + tooling[..., None] * .25, 0, 255)
    roughness = np.clip(.40 + oxide * .010 + tooling * .006 + fine * .003, .34, .48)
    extent = float(np.abs(height_m).max())
    values = dict(albedo=albedo, roughness=roughness * 255,
                  normal=(normal * .5 + .5) * 255,
                  height=(height_m / (2 * extent) + .5) * 255)
    for name, value in values.items():
        Image.fromarray(np.rint(value).astype('uint8')).save(out / (name + '.png'))
    metadata = dict(material='radiator_service_brass',
                    generator='art/tools/build_radiator_service_brass.py',
                    source=__doc__, seed=1928101702, meters_per_tile=tile,
                    normal_convention='OpenGL', normal_strength=1.0,
                    metallic=.92, roughness_range=[float(roughness.min()), float(roughness.max())],
                    height_encoding_range_mm=[-extent * 1000, extent * 1000],
                    rms_relief_mm=float(height_m.std() * 1000),
                    maximum_normal_slope=float(np.hypot(dx, dy).max()),
                    maps={name: name + '.png' for name in values})
    metadata['map_sha256'] = {name: hashlib.sha256((out / (name + '.png')).read_bytes()).hexdigest()
                              for name in values}
    (out / 'material.json').write_text(json.dumps(metadata, indent=2) + '\n',
                                      encoding='utf-8', newline='\n')
    for source, suffix in [('albedo', 'albedo'), ('roughness', 'rough'), ('normal', 'normal')]:
        shutil.copyfile(out / (source + '.png'), ROOT / 'game/assets/building/textures'
                        / ('T_ai_materials_radiator_service_brass_' + suffix + '.png'))
    print('radiator_service_brass: 512 px / 40 mm, RMS relief %.5f mm, maximum slope %.4f'
          % (metadata['rms_relief_mm'], metadata['maximum_normal_slope']))


if __name__ == '__main__':
    build()
