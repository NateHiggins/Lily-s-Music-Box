"""Three periodic, metric city finishes; no photographs or baked illumination."""
from pathlib import Path
import hashlib, json, shutil
import numpy as np
from PIL import Image
import generate_runtime_materials

ROOT = Path(__file__).resolve().parents[2]
SIZE = 1024
METRES = 1.2
SPECS = {
    'city_grey_brick': ([.48, .47, .44], .80),
    'city_slate': ([.25, .28, .31], .67),
    'city_roof_clay': ([.59, .30, .16], .72),
}


def build():
    y, x = np.mgrid[:SIZE, :SIZE].astype(float) / SIZE
    for index, (key, (colour, roughness)) in enumerate(SPECS.items()):
        rng = np.random.default_rng(19281028 + index)
        f = np.fft.fftfreq(SIZE)
        fx, fy = np.meshgrid(f, f)

        def noise(cutoff):
            a = np.fft.ifft2(np.fft.fft2(rng.normal(size=(SIZE, SIZE))) *
                            np.exp(-((fx / cutoff) ** 2 + (fy / cutoff) ** 2))).real
            return a / a.std()

        fine, grain = noise(.15), noise(.035)
        if key == 'city_grey_brick':
            rows, columns = 16, 5
            row = np.floor(y * rows).astype(int)
            shifted = x * columns + (row % 2) * .5
            col = np.floor(shifted).astype(int) % columns
            dx = np.minimum(shifted % 1, 1 - shifted % 1) * METRES / columns
            dy = np.minimum(y * rows % 1, 1 - y * rows % 1) * METRES / rows
            edge = np.minimum(dx, dy)
            body = np.clip((edge - .003) / .004, 0, 1)
            body = body * body * (3 - 2 * body)
            variation = rng.uniform(-.035, .035, (rows, columns))[row, col]
            rgb = np.array(colour) + variation[..., None] + grain[..., None] * .009
            rgb = rgb * body[..., None] + np.array([.60, .58, .53]) * (1 - body[..., None])
            height = body * .004 + (fine * .00008 + grain * .00012) * body
            rough = roughness + (1 - body) * .09 + fine * .008
        elif key == 'city_slate':
            rows, columns = 6, 4
            row = np.floor(y * rows).astype(int)
            shifted = x * columns + (row % 2) * .5
            col = np.floor(shifted).astype(int) % columns
            edge = np.minimum(shifted % 1, 1 - shifted % 1)
            body = np.clip((edge - .008) / .014, 0, 1)
            overlap = np.clip((y * rows % 1) / .05, 0, 1)
            variation = rng.uniform(-.03, .03, (rows, columns))[row, col]
            rgb = np.array(colour) + variation[..., None] + grain[..., None] * .008
            height = body * overlap * .003 + grain * .00008 + fine * .00003
            rough = roughness + grain * .014 + fine * .008
        else:
            rows, columns = 4, 6
            row = np.floor(y * rows).astype(int)
            col = np.floor(x * columns).astype(int)
            variation = rng.uniform(-.04, .04, (rows, columns))[row, col]
            rgb = np.array(colour) + variation[..., None] + grain[..., None] * .007
            overlap = np.clip((y * rows % 1) / .06, 0, 1)
            height = (1 - np.cos(x * columns * np.pi * 2)) * .008 + overlap * .002
            height += grain * .00006 + fine * .00004
            rough = roughness + grain * .009 + fine * .007
        # Image rows run downward; this is the project's OpenGL tangent normal.
        hx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * SIZE / (2 * METRES)
        hy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * SIZE / (2 * METRES)
        normal = np.stack((-hx, hy, np.ones_like(height)), -1)
        normal /= np.linalg.norm(normal, axis=-1)[..., None]
        folder = ROOT / 'art/textures/procedural' / key
        folder.mkdir(parents=True, exist_ok=True)
        maps = {'albedo': rgb, 'roughness': rough, 'normal': normal * .5 + .5}
        for channel, values in maps.items():
            Image.fromarray(np.rint(np.clip(values, 0, 1) * 255).astype('uint8')).save(folder / (channel + '.png'), optimize=True)
        # Retain physical relief as a linear 16-bit source, not another runtime map.
        lo, hi = float(height.min()), float(height.max())
        Image.fromarray(np.rint((height - lo) / (hi - lo) * 65535).astype('uint16')).save(folder / 'height.png')
        meta = {'material': key, 'generator': 'art/tools/build_city_masonry.py',
                'seed': 19281028 + index, 'meters_per_tile': METRES,
                'height_min_m': lo, 'height_max_m': hi,
                'maps': {c: c + '.png' for c in [*maps, 'height']}}
        meta['map_sha256'] = {c: hashlib.sha256((folder / n).read_bytes()).hexdigest() for c, n in meta['maps'].items()}
        (folder / 'material.json').write_text(json.dumps(meta, indent=2) + '\n', encoding='utf-8', newline='\n')
        for channel, suffix in [('albedo', 'albedo'), ('roughness', 'rough'), ('normal', 'normal')]:
            shutil.copyfile(folder / (channel + '.png'), ROOT / 'game/assets/building/textures' / ('T_ai_materials_' + key + '_' + suffix + '.png'))
    catalog_path = ROOT / 'art/data/material_catalog.json'
    mapping_path = ROOT / 'art/textures/catalog_mapping.json'
    catalog = json.loads(catalog_path.read_text())
    mapping = json.loads(mapping_path.read_text())
    for key in SPECS:
        catalog[key] = {'base_color': [1., 1., 1., 1.], 'roughness': 1., 'metallic': 0.}
        mapping[key] = 'procedural/' + key
    catalog_path.write_text(json.dumps(catalog, indent=1) + '\n', encoding='utf-8', newline='\n')
    mapping_path.write_text(json.dumps(mapping, indent=1) + '\n', encoding='utf-8', newline='\n')
    print('City PBR contract:', generate_runtime_materials.generate())


if __name__ == '__main__':
    build()
