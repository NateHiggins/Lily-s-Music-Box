"""Source-sized clay face, lime mortar and matched running-bond PBR stock.

The new generated clay is a pigment ingredient, not a height field. Analytic
joint geometry and independent mineral pores own relief. The close wall's
native bricks use the same chosen 200 x 75 mm course with 9 mm mortar joints.
No legacy whitewash, black joint shadows or image-luminance relief survives.
"""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/textures/ai_sources/arcade_brick_face_20261018.png'
COURSE_X, COURSE_Y, JOINT = .2, .075, .009


def build(out_root, size=1536):
    source = np.asarray(Image.open(SOURCE).convert('RGB'), dtype=float) / 255
    reports = []
    for index, key in enumerate(['arcade_brick_face', 'arcade_lime_mortar', 'arcade_brick_bond']):
        bond = key.endswith('_bond')
        mortar = key.endswith('_mortar')
        tile = 1.2 if bond else .25
        rng = np.random.default_rng(19281019 + index)
        y, x = np.mgrid[:size, :size]
        u, v = x / size, y / size
        relief_noise = np.zeros((size, size))
        # Periodic independent mineral relief, all spatial units are metres.
        for _ in range(24):
            k, l = rng.integers(15, 190, 2)
            phase = rng.uniform(0, np.pi * 2)
            relief_noise += np.cos(np.pi * 2 * (u * k + v * l) + phase) * rng.normal()
        relief_noise /= relief_noise.std()
        pores = np.clip(relief_noise - 1.6, 0, 2) / 2
        micro = relief_noise * .000018 - pores * .00009
        if bond:
            px, py = u * tile, v * tile
            row = np.floor(py / COURSE_Y).astype(int) % 16
            shifted = px + (row % 2) * COURSE_X / 2
            col = np.floor(shifted / COURSE_X).astype(int) % 6
            bx, by = shifted % COURSE_X, py % COURSE_Y
            distance = np.minimum.reduce([bx, COURSE_X - bx, by, COURSE_Y - by])
            face = np.clip((distance - JOINT / 2) / .0018, 0, 1)
            face = face * face * (3 - 2 * face)
            offset_x = rng.uniform(0, .25 - (COURSE_X - JOINT), (16, 6))
            offset_y = rng.uniform(0, .25 - (COURSE_Y - JOINT), (16, 6))
            sx = np.clip((bx - JOINT / 2 + offset_x[row, col]) / .25, 0, 1)
            sy = np.clip((by - JOINT / 2 + offset_y[row, col]) / .25, 0, 1)
            clay = source[np.rint(sy * (len(source) - 1)).astype(int), np.rint(sx * (source.shape[1] - 1)).astype(int)]
            kiln = rng.uniform(.955, 1.035, (16, 6))[row, col]
            clay = clay * kiln[..., None]
            lime = np.array([.59, .565, .515]) + relief_noise[..., None] * .004
            albedo = lime + (clay - lime) * face[..., None]
            height = face * .0045 + micro
            rough = .89 * (1 - face) + .81 * face + relief_noise * .012 + pores * .025
        else:
            height = micro * (1.3 if mortar else 1)
            rough = (.89 if mortar else .81) + relief_noise * .012 + pores * .025
            if mortar:
                albedo = np.array([.59, .565, .515]) + relief_noise[..., None] * .004
            else:
                # Exact generated pigment at output resolution. All geometric
                # information remains in independently authored channels.
                albedo = np.asarray(Image.open(SOURCE).convert('RGB').resize((size, size), Image.Resampling.LANCZOS), dtype=float) / 255
        dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * size / (2 * tile)
        dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * size / (2 * tile)
        normal = np.stack((-dx, dy, np.ones_like(dx)), axis=-1)
        normal /= np.linalg.norm(normal, axis=-1)[..., None]
        rough = np.clip(rough, .7, .96)
        folder = Path(out_root) / 'materials' / key
        folder.mkdir(parents=True, exist_ok=True)
        for name, value in [('albedo', albedo), ('roughness', rough), ('normal', normal * .5 + .5)]:
            Image.fromarray(np.rint(np.clip(value, 0, 1) * 255).astype(np.uint8)).save(folder / (name + '.png'))
        span = float(np.ptp(height))
        Image.fromarray(np.rint((height - height.min()) / span * 65535).astype(np.uint16)).save(folder / 'height.png')
        maps = {name: name + '.png' for name in ['albedo', 'roughness', 'normal', 'height']}
        meta = dict(material=key, status='QUALIFICATION_PENDING', meters_per_tile=tile,
                    generator='art/tools/build_arcade_masonry.py',
                    generator_sha256_lf=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n', b'\n')).hexdigest(),
                    albedo_source=SOURCE.relative_to(ROOT).as_posix(),
                    albedo_source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                    height_model='independent_physical_bond_v1' if bond else 'independent_mineral_pores_v1',
                    course_m=[COURSE_X, COURSE_Y], mortar_joint_m=JOINT,
                    relief_mm=span * 1000, height_storage_bits=16, normal_strength=1.,
                    maps=maps, map_sha256={name: hashlib.sha256((folder / file).read_bytes()).hexdigest() for name, file in maps.items()},
                    measurements=dict(roughness_min=float(rough.min()), roughness_max=float(rough.max()),
                                      normal_slope_rms=float(np.sqrt(np.mean(dx * dx + dy * dy)))))
        (folder / 'material.json').write_text(json.dumps(meta, indent=2) + '\n', encoding='utf8', newline='\n')
        reports.append(meta)
    return reports


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out-root', type=Path, required=True)
    args = parser.parse_args()
    for row in build(args.out_root):
        print(row['material'], row['meters_per_tile'], 'metres;', row['relief_mm'], 'mm relief')
