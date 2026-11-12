"""CPU-only static hair audit; no runtime or artistic acceptance.

python art/tools/audit_character_hair_export.py hair.glb --report audit.json
Use --reference frozen.glb to compare all expanded triangle attributes. Exports
from export_character_hair.py also compare the adjacent native snapshot, bound
by the export receipt's hash. Requires NumPy; uses the existing tangent checker.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct

import numpy as np


class GLB:
    """Small read-only reader for embedded, nonsparse hair GLBs."""
    def __init__(self, path):
        raw = Path(path).read_bytes()
        if len(raw) < 12 or struct.unpack_from('<III', raw) != (0x46546C67, 2, len(raw)):
            raise ValueError('Invalid GLB header')
        chunks = {}; offset = 12
        while offset < len(raw):
            length, kind = struct.unpack_from('<II', raw, offset)
            if offset + 8 + length > len(raw):
                raise ValueError('Truncated GLB chunk')
            chunks[kind] = raw[offset + 8:offset + 8 + length]
            offset += 8 + length
        self.doc = json.loads(chunks[0x4E4F534A]); self.binary = chunks[0x004E4942]

    def array(self, index):
        a = self.doc['accessors'][index]
        if 'sparse' in a or a.get('normalized'):
            raise ValueError('Sparse/normalized hair accessors unsupported')
        view = self.doc['bufferViews'][a['bufferView']]
        if view.get('buffer', 0) != 0:
            raise ValueError('Only embedded GLB buffer supported')
        dtype = np.dtype({5121: 'u1', 5123: '<u2', 5125: '<u4', 5126: '<f4'}[a['componentType']])
        width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
        return np.ndarray((a['count'], width), dtype=dtype, buffer=self.binary,
                          offset=view.get('byteOffset', 0) + a.get('byteOffset', 0),
                          strides=(view.get('byteStride', width * dtype.itemsize), dtype.itemsize)).astype(float)

    def parts(self):
        parts = {}
        for mesh in self.doc['meshes']:
            for p in mesh['primitives']:
                if p.get('mode', 4) != 4:
                    raise ValueError('Triangle primitives required')
                role = self.doc['materials'][p['material']].get('alphaMode', 'OPAQUE')
                if role in parts:
                    raise ValueError('Exactly one primitive per hair material required')
                index = self.array(p['indices']).astype(int).reshape((-1, 3))
                parts[role] = {k: self.array(v)[index] for k, v in p['attributes'].items()
                               if k in ('POSITION', 'NORMAL') or k.startswith('TEXCOORD_')}
        return parts


def compare(left, right):
    """Match oriented triangle multisets independent of vertex deduplication."""
    def rows(fields):
        result = {}
        for i, points in enumerate(fields['POSITION']):
            start = min(range(3), key=lambda j: tuple(points[j]))
            values = {k: np.roll(v[i], -start, axis=0) for k, v in fields.items()}
            key = tuple(np.round(values['POSITION'].ravel(), 6))
            result.setdefault(key, []).append(values)
        return result
    a, b = rows(left), rows(right)
    if set(a) != set(b) or any(len(a[k]) != len(b[k]) for k in a):
        raise ValueError('Expanded triangle positions/count/winding differ')
    if set(left) != set(right):
        raise ValueError('Position/normal/UV attribute inventory differs')
    maximum = {k: 0.0 for k in left}
    def order(row):
        return tuple(np.concatenate([row[k].ravel() for k in sorted(row) if k.startswith('TEXCOORD_')]))
    for key in a:
        for x, y in zip(sorted(a[key], key=order), sorted(b[key], key=order)):
            for field in x:
                maximum[field] = max(maximum[field], float(np.max(abs(x[field] - y[field]))))
    for field, delta in maximum.items():
        if delta > (0.001 if field == 'NORMAL' else 0.000001):
            raise ValueError(f'{field} changed by {delta}')
    return {'triangles': len(left['POSITION']), 'max_errors': maximum}


def audit(path, reference=None):
    g = GLB(path); j = g.doc; parts = g.parts()
    if j.get('animations'):
        raise ValueError('Static hair must not contain animations')
    if j.get('skins') or any('skin' in n for n in j.get('nodes', [])):
        raise ValueError('Static hair must not contain skins')
    if any('joints' in x for x in j.get('skins', [])) or any('JOINTS_0' in p['attributes'] for m in j['meshes'] for p in m['primitives']):
        raise ValueError('Static hair must not contain armature weights')
    if len(j['meshes']) != 2 or len(j['materials']) != 2 or set(parts) != {'MASK', 'OPAQUE'}:
        raise ValueError('Exactly two meshes/materials/primitives, MASK cards and OPAQUE cap required')
    for node in j.get('nodes', []):
        if ('matrix' in node and not np.allclose(node['matrix'], np.eye(4).ravel())) or any(
            key in node and not np.allclose(node[key], default)
            for key, default in [('translation', [0, 0, 0]), ('rotation', [0, 0, 0, 1]), ('scale', [1, 1, 1])]):
            raise ValueError('Audit requires baked identity GLB node transforms')
    for fields in parts.values():
        if not all(np.isfinite(v).all() for v in fields.values()):
            raise ValueError('Nonfinite geometry/UV values')
    if 'TEXCOORD_1' not in parts['MASK']:
        raise ValueError('Missing cards UV1 along-strand controls')
    along = parts['MASK']['TEXCOORD_1'][:, :, 1]
    if abs(float(along.min())) > 1e-5 or abs(float(along.max()) - 1) > 1e-5:
        raise ValueError('Cards UV1 along-strand range must span 0..1')
    images = []
    if len(j.get('images', [])) != 3:
        raise ValueError('Expected three shared/derived hair images')
    for image in j['images']:
        view = j['bufferViews'][image['bufferView']]; start = view.get('byteOffset', 0)
        data = g.binary[start:start + view['byteLength']]
        if data[:8] != b'\x89PNG\r\n\x1a\n':
            raise ValueError('Expected embedded PNG hair maps')
        size = struct.unpack_from('>II', data, 16)
        if min(size) < 1 or max(size) > 1024:
            raise ValueError('Hair map exceeds 1024 limit')
        images.append({'name': image.get('name'), 'size': size, 'sha256': hashlib.sha256(data).hexdigest()})
    checker_path = Path(__file__).resolve().parents[1] / 'blender/scripts/check_exported_tangents.py'
    spec = importlib.util.spec_from_file_location('hair_derivative_checker', checker_path)
    checker = importlib.util.module_from_spec(spec); spec.loader.exec_module(checker)
    result = {'derivative': checker.validate(path), 'images': images}
    receipt_path = path.with_suffix('.export.json')
    if receipt_path.exists():
        receipt = json.loads(receipt_path.read_text())
        if receipt['export_sha256'] != hashlib.sha256(path.read_bytes()).hexdigest():
            raise ValueError('Export receipt hash mismatch')
        snapshot_path = path.parent / receipt['native_snapshot']
        if receipt.get('native_snapshot_sha256') != hashlib.sha256(snapshot_path.read_bytes()).hexdigest():
            raise ValueError('Native snapshot hash mismatch')
        with np.load(snapshot_path) as snapshot:
            result['native_comparison'] = {}
            for slot, role in enumerate(('MASK', 'OPAQUE')):
                native = {k[len(str(slot)) + 1:]: snapshot[k].reshape((-1, 3, snapshot[k].shape[-1]))
                          for k in snapshot.files if k.startswith(str(slot) + '_')}
                result['native_comparison'][role] = compare(native, parts[role])
    if reference:
        other = GLB(reference).parts()
        result['reference_comparison'] = {role: compare(other[role], parts[role]) for role in parts}
    if not receipt_path.exists() and not reference:
        raise ValueError('Native snapshot receipt or --reference required to detect truncated exports')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('asset', type=Path); parser.add_argument('--reference', type=Path)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    result = {'asset': str(args.asset), 'scope': 'CPU static export only; no runtime or artistic acceptance', 'failures': []}
    try:
        result.update(audit(args.asset, args.reference))
    except Exception as error:
        result['failures'].append(f'{type(error).__name__}: {error}')
    result['passed'] = not result['failures']
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    return int(not result['passed'])


if __name__ == '__main__':
    raise SystemExit(main())
