"""Inspect exported canopy shells/metric UVs and calibrated stock maps.

Native candidate checks only. Does not install stock or write runtime proof.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'art/blender/scripts'))
from check_exported_tangents import validate as check_tangents


def primitives(path):
    raw = Path(path).read_bytes()
    chunks = {}
    offset = 12
    while offset < len(raw):
        length, kind = struct.unpack_from('<II', raw, offset)
        chunks[kind] = raw[offset + 8:offset + 8 + length]
        offset += 8 + length
    doc = json.loads(chunks[0x4E4F534A])
    data = chunks[0x004E4942]

    def array(index):
        accessor = doc['accessors'][index]
        view = doc['bufferViews'][accessor['bufferView']]
        dtype = np.dtype({5121: 'u1', 5123: '<u2', 5125: '<u4', 5126: '<f4'}[accessor['componentType']])
        width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[accessor['type']]
        return np.ndarray((accessor['count'], width), dtype=dtype, buffer=data,
                          offset=view.get('byteOffset', 0) + accessor.get('byteOffset', 0),
                          strides=(view.get('byteStride', width * dtype.itemsize), dtype.itemsize)).astype(float)

    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            indices = array(primitive['indices']).astype(int).reshape((-1, 3))
            yield mesh['name'], {key: array(value)[indices] for key, value in primitive['attributes'].items()}


def check_pane_shells(plan, points, normals):
    count = 0
    max_error = 0.
    for row in plan['parts']:
        if row['material'] != 'glassish' or row.get('kind') == 'gable_prism':
            continue
        axes = np.array(row['axes'])
        half = np.array(row['size_m']) / 2
        local = (points - row['center_m']) @ axes.T
        inside = np.all(np.abs(local) <= half + .00001, axis=(1, 2))
        triangles = local[inside]
        ns = normals[inside] @ axes.T
        area = np.linalg.norm(np.cross(triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0]), axis=1) / 2
        for axis in range(3):
            expected = float(np.prod(np.delete(half * 2, axis)))
            for direction in [-1, 1]:
                face = np.all(np.abs(triangles[:, :, axis] - direction * half[axis]) < .00001, axis=1)
                error = abs(float(area[face].sum()) / expected - 1)
                if error > .003 or not np.any(face) or np.min(ns[face, :, axis] * direction) < .999:
                    raise ValueError(f'Open, mis-sized or inverted glass face: {row["id"]} axis={axis} side={direction}, area error={error}')
                max_error = max(max_error, error)
        count += 1
    return {'closed_rectangular_glass_panes': count, 'maximum_shell_face_area_error': max_error}


def inspect(directory):
    directory = Path(directory)
    asset = directory / 'canopy/arcade_canopy.glb'
    plan = json.loads((directory / 'canopy/canopy_plan.json').read_text())
    native = json.loads((directory / 'canopy/native_review.json').read_text())
    if hashlib.sha256(asset.read_bytes()).hexdigest() != native['asset_sha256']:
        raise ValueError('Native export has changed')
    if hashlib.sha256((directory / 'canopy/arcade_canopy.blend').read_bytes()).hexdigest() != native['native_sha256']:
        raise ValueError('Editable native source has changed')
    for relative, expected in native['source_bindings'].items():
        if hashlib.sha256((ROOT / relative).read_bytes().replace(b'\r\n', b'\n')).hexdigest() != expected:
            raise ValueError('Candidate source drift: ' + relative)
    from plan_v2_arcade_canopy import build
    # JSON normalizes tuple profiles to lists; compare normalized values.
    if plan != json.loads(json.dumps(build())):
        raise ValueError('Native candidate differs from current owning plan')
    report = check_tangents(asset)
    metrics = []
    for name, data in primitives(asset):
        p, uv = data['POSITION'], data['TEXCOORD_0']
        edges = np.stack((p[:, 1] - p[:, 0], p[:, 2] - p[:, 0]), axis=-1)
        charts = np.stack((uv[:, 1] - uv[:, 0], uv[:, 2] - uv[:, 0]), axis=-1)
        singular = np.linalg.svd(edges @ np.linalg.inv(charts), compute_uv=False)
        if not np.isfinite(singular).all() or singular.min() < .98 or singular.max() > 1.02:
            raise ValueError('Non-metric exported UVs: ' + name)
        metrics.extend([float(singular.min()), float(singular.max())])
        if name == 'canopy__glassish':
            report.update(check_pane_shells(plan, p, data['NORMAL']))
    if report.get('closed_rectangular_glass_panes') != 198:
        raise ValueError('Expected all 192 barrel panes and six lantern side panes')
    report['uv_stretch_min_max'] = [min(metrics), max(metrics)]
    report['materials'] = []
    for key in ['arcade_terrazzo', 'arcade_terrazzo_dark']:
        folder = directory / 'materials' / key
        meta = json.loads((folder / 'material.json').read_text())
        if hashlib.sha256((ROOT / meta['generator']).read_bytes().replace(b'\r\n', b'\n')).hexdigest() != meta['generator_sha256_lf']:
            raise ValueError('Material generator changed: ' + key)
        for name, file in meta['maps'].items():
            if hashlib.sha256((folder / file).read_bytes()).hexdigest() != meta['map_sha256'][name]:
                raise ValueError('Material map drift: ' + key + '/' + name)
        if (ROOT / meta['albedo_source']).read_bytes() != (folder / 'albedo.png').read_bytes():
            raise ValueError('Generated diffuse stock was altered')
        height = np.asarray(Image.open(folder / 'height.png')).astype(float) / 65535 * meta['relief_mm'] / 1000
        if not 0 < meta['relief_mm'] < .1 or meta['meters_per_tile'] != .4:
            raise ValueError('Incorrect terrazzo height/scale')
        dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * len(height) / (2 * meta['meters_per_tile'])
        dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * len(height) / (2 * meta['meters_per_tile'])
        expected = np.stack((-dx, dy, np.ones_like(dx)), axis=-1)
        expected /= np.linalg.norm(expected, axis=2)[..., None]
        normal = np.asarray(Image.open(folder / 'normal.png')).astype(float) / 255 * 2 - 1
        error = float(np.max(np.abs(normal - expected)))
        if error > .004:
            raise ValueError('Stored height and normal disagree: ' + key)
        report['materials'].append(dict(key=key, relief_mm=meta['relief_mm'], maximum_normal_error=error))
    report.update(evidence_class='INERT', scope='Native exported candidate and offline map calibration only. No game, loaded mipmap, collision, route or acceptance proof.')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    report = inspect(args.directory)
    if args.out:
        args.out.write_text(json.dumps(report, indent=2) + '\n', encoding='utf8', newline='\n')
    print(json.dumps(report, indent=2))
