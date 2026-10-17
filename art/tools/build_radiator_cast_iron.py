"""Author periodic oxide-covered sand-cast iron, independent of worked iron.

The continuous dark oxide is dielectric. No exposed-metal islands, rust
stains, baked highlights, lettering or photographic pixels are present.
Relief is a physical height field; colour is quiet mineral variation rather
than painted cavity shadows. All fields are periodic before differentiation.
"""
from pathlib import Path
import hashlib
import json
import shutil

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def build():
    out = ROOT / 'art/textures/procedural/radiator_cast_iron'
    out.mkdir(parents=True, exist_ok=True)
    size, tile = 512, .064
    rng = np.random.default_rng(19281017)
    fx, fy = np.meshgrid(np.fft.fftfreq(size), np.fft.fftfreq(size))

    def field(cutoff):
        spectrum = np.fft.fft2(rng.standard_normal((size, size)))
        value = np.fft.ifft2(spectrum * np.exp(-(fx * fx + fy * fy) / cutoff**2)).real
        return (value - value.mean()) / value.std()

    sand, fine, mineral = field(.085), field(.22), field(.018)
    # Approximately 0.3--1 mm casting grain, not fixture-sized lumps.
    height_m = sand * .000030 + fine * .000006
    dx = (np.roll(height_m, -1, 1) - np.roll(height_m, 1, 1)) * size / (2 * tile)
    dy = (np.roll(height_m, -1, 0) - np.roll(height_m, 1, 0)) * size / (2 * tile)
    normal = np.stack((-dx, dy, np.ones_like(dx)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1)[..., None]
    albedo = np.clip(np.array([67, 71, 73])[None, None, :]
                     + mineral[..., None] * 1.5 + sand[..., None] * .6, 0, 255)
    roughness = np.clip(.60 + mineral * .025 + fine * .015, .48, .72)
    # The optional source height map is encoded against a declared physical
    # range. Runtime samples the derived normal, not quantized albedo relief.
    extent = float(np.abs(height_m).max())
    height = height_m / (2 * extent) + .5
    values = dict(albedo=albedo, roughness=roughness * 255,
                  normal=(normal * .5 + .5) * 255, height=height * 255)
    for name, value in values.items():
        Image.fromarray(np.rint(value).astype('uint8')).save(out / (name + '.png'))
    metadata = dict(material='radiator_cast_iron', generator='art/tools/build_radiator_cast_iron.py',
                    source=__doc__, meters_per_tile=tile, normal_convention='OpenGL',
                    metallic=0.0, finish='Continuous dark oxide over sand-cast iron; no bare-metal patches.',
                    normal_strength=1.0, height_encoding_range_mm=[-extent * 1000, extent * 1000],
                    rms_relief_mm=float(height_m.std() * 1000),
                    maximum_normal_slope=float(np.hypot(dx, dy).max()),
                    roughness_range=[float(roughness.min()), float(roughness.max())],
                    maps={name: name + '.png' for name in values})
    metadata['map_sha256'] = {name: hashlib.sha256((out / (name + '.png')).read_bytes()).hexdigest()
                              for name in values}
    (out / 'material.json').write_text(json.dumps(metadata, indent=2) + '\n',
                                      encoding='utf-8', newline='\n')
    for source, suffix in [('albedo', 'albedo'), ('roughness', 'rough'), ('normal', 'normal')]:
        shutil.copyfile(out / (source + '.png'), ROOT / 'game/assets/building/textures'
                        / ('T_ai_materials_radiator_cast_iron_' + suffix + '.png'))
    print('radiator_cast_iron: 512 px / 64 mm, RMS relief %.4f mm, maximum slope %.4f'
          % (metadata['rms_relief_mm'], metadata['maximum_normal_slope']))


if __name__ == '__main__':
    build()
