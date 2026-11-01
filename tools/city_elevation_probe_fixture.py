"""Source-bound physical probe targets for the articulated city elevations.

This samples the frozen native export, never the installed collision being tested.
It establishes source/composition correspondence, not architectural acceptance.
Run with --check to reject stale targets; without it to regenerate after review.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
ASSET = 'game/assets/props/city_elevations.glb'
CONSTRUCTION = 'game/tests/fixtures/orison_city_elevations.json'
PLAN = 'art/data/city_elevations/source_plan.json'
OUTPUT = ROOT / 'game/tests/fixtures/orison_city_elevation_probes.json'
DIRECTIONS = np.array([[0, 0, 1], [0, 0, -1], [-1, 0, 0], [1, 0, 0]])


def digest(path):
    raw = path.read_bytes()
    return hashlib.sha256(raw if path.suffix == '.glb' else raw.replace(b'\r\n', b'\n')).hexdigest()


def native_triangles(path, structural_keys):
    raw = path.read_bytes()
    size = struct.unpack_from('<I', raw, 12)[0]
    doc, binary = json.loads(raw[20:20 + size]), raw[28 + size:]
    widths = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}
    kinds = {5126: '<f4', 5125: '<u4', 5123: '<u2', 5121: 'u1'}

    def accessor(index):
        a = doc['accessors'][index]
        view = doc['bufferViews'][a['bufferView']]
        assert 'byteStride' not in view and 'sparse' not in a
        return np.frombuffer(binary, dtype=kinds[a['componentType']],
                             offset=view.get('byteOffset', 0) + a.get('byteOffset', 0),
                             count=a['count'] * widths[a['type']]).reshape(a['count'], widths[a['type']])

    groups, structural = {}, {}
    for node in doc['nodes']:
        # Refuse a newly transformed format instead of silently sampling it wrong.
        assert not any(k in node for k in ['matrix', 'rotation', 'scale', 'children'])
        owner = node['name'].split('__')[0]
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            assert primitive.get('mode', 4) == 4
            xyz = accessor(primitive['attributes']['POSITION']).astype(float) + node.get('translation', [0, 0, 0])
            triangles = xyz[accessor(primitive['indices']).ravel()].reshape(-1, 3, 3)
            groups.setdefault(owner, []).append(triangles)
            structural.setdefault(owner, []).append(np.full(len(triangles), node['name'].split('__')[-1] in structural_keys))
    return ({owner: np.concatenate(parts) for owner, parts in groups.items()},
            {owner: np.concatenate(parts) for owner, parts in structural.items()})


def first_hit(triangles, point, normal):
    """Same 80mm front-face segment as the composed test, using scalar doubles."""
    origin, direction = point + normal * .04, -normal
    e1, e2 = triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0]
    h = np.cross(direction, e2)
    determinant = (e1 * h).sum(axis=1)
    valid = determinant > 1e-10
    inverse = np.zeros_like(determinant)
    inverse[valid] = 1 / determinant[valid]
    s = origin - triangles[:, 0]
    u = inverse * (s * h).sum(axis=1)
    q = np.cross(s, e1)
    v = inverse * (q * direction).sum(axis=1)
    distance = inverse * (q * e2).sum(axis=1)
    valid &= (u >= -1e-8) & (v >= -1e-8) & (u + v <= 1 + 1e-8) & (distance >= 0) & (distance <= .08)
    return float(np.min(distance[valid])) if valid.any() else None


def target_at_height(triangles, height, seed, normal, structural=None):
    normals = np.cross(triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0])
    normals /= np.maximum(np.linalg.norm(normals, axis=1)[:, None], 1e-30)
    eligible = np.ones(len(triangles), dtype=bool) if structural is None else structural
    faces = triangles[eligible & ((normals * normal).sum(axis=1) > .99999)
                      & (triangles[:, :, 1].min(axis=1) < height)
                      & (triangles[:, :, 1].max(axis=1) > height)]
    candidates = []
    for face in faces:
        ends = []
        for a, b in zip(face, np.roll(face, -1, axis=0)):
            if abs(b[1] - a[1]) < 1e-8:
                continue
            fraction = (height - a[1]) / (b[1] - a[1])
            if 0 <= fraction <= 1:
                ends.append(a + (b - a) * fraction)
        if len(ends) >= 2:
            candidates.append((ends[0] + ends[1]) * .5)
    for point in sorted(candidates, key=lambda p: float(np.linalg.norm(p - seed))):
        hit = first_hit(triangles, point, normal)
        if hit is not None and abs(hit - .04) < .0001:
            return point
    raise ValueError(f'No exposed source face at height={height}, normal={normal.tolist()}')


def build():
    fixture = json.loads((ROOT / CONSTRUCTION).read_text())
    plan = {b['id']: b for b in json.loads((ROOT / PLAN).read_text())['buildings']}
    assert digest(ROOT / ASSET) == fixture['asset_sha256']
    structural_keys = {b["wall_key"] for b in plan.values()} | {"limestone", "limewash_plaster", "terracotta"}
    groups, structural = native_triangles(ROOT / ASSET, structural_keys)
    stations = []
    for building in fixture['buildings']:
        identity, rect = building['id'], building['main_rect']
        bottom = building['shaft_bottom']
        if plan[identity].get('architecture', {}).get('style') == 'elks878':
            # The source builder explicitly retains the occupied Harukiya below
            # this native shaft. It is not missing city stock and must stay open.
            bottom = min(r['z0'] for r in fixture['original_records'] if r['id'] == identity + '_s0')
        top = building.get('shaft_top', building['setback_height'])
        for fraction in [.12, .36, .64, .88]:
            height = bottom + (top - bottom) * fraction
            seeds = [[rect[0] + .12, height, -rect[1]], [rect[2] - .12, height, -rect[3]],
                     [rect[0], height, -rect[1] - .12], [rect[2], height, -rect[3] + .12]]
            for side, (seed, normal) in enumerate(zip(seeds, DIRECTIONS)):
                point = target_at_height(groups[identity], height, np.array(seed), normal, structural[identity])
                stations.append(dict(building=identity, side=side, fraction=fraction,
                                     point=point.tolist(), normal=normal.tolist()))
    assert len(stations) == 400
    return dict(evidence_class='INERT', schema=1,
                scope='Native source to composed physical correspondence; not design or artistic acceptance',
                source_bindings={name: digest(ROOT / name) for name in [ASSET, CONSTRUCTION, PLAN]},
                stations=stations)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    result = build()
    if args.check:
        assert json.loads(OUTPUT.read_text()) == result, 'Stale or changed source probe fixture'
    else:
        OUTPUT.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(f'City native elevation probes: {len(result["stations"])}; check={args.check}')
