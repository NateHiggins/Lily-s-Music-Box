"""Independently inspect packing pose data in the exported GLB, not Blender."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import json, struct, hashlib
import numpy as np
P = output_directory()
asset = P / 'packed_union_scratch.glb'
raw = asset.read_bytes()
chunks = {}
offset = 12
while offset < len(raw):
    size, kind = struct.unpack_from('<II', raw, offset)
    chunks[kind] = raw[offset + 8:offset + 8 + size]
    offset += 8 + size
doc = json.loads(chunks[1313821514])
binary = chunks[5130562]

def array(index):
    a = doc['accessors'][index]
    v = doc['bufferViews'][a['bufferView']]
    dtype = np.dtype({5121: 'u1', 5123: '<u2', 5125: '<u4', 5126: '<f4'}[a['componentType']])
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    return np.ndarray((a['count'], width), dtype=dtype, buffer=binary, offset=v.get('byteOffset', 0) + a.get('byteOffset', 0), strides=(v.get('byteStride', width * dtype.itemsize), dtype.itemsize)).astype(float)
checks = []
samples = []
targets = 0
for mesh in doc['meshes']:
    for primitive in mesh['primitives']:
        if not primitive.get('targets'):
            continue
        attr = primitive['attributes']
        p, n, uv, t = [array(attr[k]) for k in ['POSITION', 'NORMAL', 'TEXCOORD_0', 'TANGENT']]
        ids = array(primitive['indices']).astype(int).reshape((-1, 3))
        tex = uv[ids]
        a = tex[:, 1] - tex[:, 0]
        b = tex[:, 2] - tex[:, 0]
        det = a[:, 0] * b[:, 1] - a[:, 1] * b[:, 0]
        names = mesh.get('extras', {}).get('targetNames', [])
        assert names == ['Spread_%02d' % i for i in range(1, 21)], names
        anchors = [(np.zeros_like(p), np.zeros_like(n), np.zeros_like(t[:, :3]))]
        for index, target in enumerate(primitive['targets']):
            targets += 1
            anchors.append(tuple((array(target[k]) for k in ['POSITION', 'NORMAL', 'TANGENT'])))
        last = anchors[-1][0]
        checks.append(dict(label='baked anchors preserve the native linear position path', passed=all((np.max(abs(dp - last * index / 20)) < 1e-07 for index, (dp, dn, dt) in enumerate(anchors)))))
        for index, (first, second) in enumerate(zip(anchors, anchors[1:])):
            for weight in np.linspace(0, 1, 9):
                dp, dn, dt = [a * (1 - weight) + b * weight for a, b in zip(first, second)]
                point = (p + dp)[ids]
                normal = n + dn
                normal /= np.linalg.norm(normal, axis=1)[:, None]
                tangent = t[:, :3] + dt
                tangent /= np.linalg.norm(tangent, axis=1)[:, None]
                du = ((point[:, 1] - point[:, 0]) * b[:, 1, None] - (point[:, 2] - point[:, 0]) * a[:, 1, None]) / det[:, None]
                dv = ((point[:, 2] - point[:, 0]) * a[:, 0, None] - (point[:, 1] - point[:, 0]) * b[:, 0, None]) / det[:, None]
                expected = du[:, None, :] - normal[ids] * np.sum(du[:, None, :] * normal[ids], axis=2)[:, :, None]
                expected /= np.linalg.norm(expected, axis=2)[:, :, None]
                agreement = np.sum(expected * tangent[ids], axis=2)
                handed = np.sum(np.cross(normal[ids], tangent[ids]) * dv[:, None, :], axis=2) * t[ids, 3]
                orthogonality = np.max(abs(np.sum(normal * tangent, axis=1)))
                finite = all((np.isfinite(x).all() for x in [point, normal, tangent, agreement, handed]))
                minimum = float(agreement.min())
                wrong = int(np.sum(handed <= 0))
                passed = finite and minimum > 0.999 and (wrong == 0) and (orthogonality < 0.001)
                sample = dict(mesh=mesh['name'], segment=index, weight=float(weight), spread=float((index + weight) / 20), minimum_tangent_agreement=minimum, maximum_normal_tangent_dot=float(orthogonality), wrong_handed_corners=wrong, passed=bool(passed))
                samples.append(sample)
checks.append(dict(label='export contains the intended movable packing anchors', passed=targets == 20, targets=targets))
checks.append(dict(label='all sampled morph frames preserve the strict tangent contract', passed=all((s['passed'] for s in samples))))
report = dict(evidence_class='INERT', scope='Scratch exported packing, nine samples per adjacent shading-anchor interval over the unchanged native linear position path, strict tangent derivative/orthogonality/handedness checks. Runtime must blend the named adjacent Spread_01..20 targets; no production controls or runtime proof.', asset_sha256=hashlib.sha256(raw).hexdigest(), checks=checks, samples=samples, failures=[c for c in checks if not c['passed']])
(P / 'packing_morph_buffer_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('PACKING MORPH', targets, 'targets', len(samples), 'samples', len(report['failures']), 'failed checks', flush=True)
for row in samples:
    if not row['passed']:
        print(row, flush=True)
if report['failures']:
    raise RuntimeError('Exported packing morph needs correction')
