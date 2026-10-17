"""Prove that tail retirement preserves all other native heating geometry.

Blender --python-exit-code 1 --python this_file -- --before FILE --after FILE --out FILE
Native equality is not runtime, collision, pressure or human acceptance.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

import bpy


def stocks(path):
    bpy.ops.wm.open_mainfile(filepath=str(path.resolve()))
    result = {}
    for obj in bpy.data.objects:
        if obj.type != 'MESH': continue
        digest = hashlib.sha256()
        for row in obj.matrix_world: digest.update(struct.pack('<4d', *row))
        for vertex in obj.data.vertices: digest.update(struct.pack('<3d', *vertex.co))
        for face in obj.data.polygons:
            digest.update(struct.pack('<I', len(face.vertices)))
            digest.update(struct.pack('<' + 'I' * len(face.vertices), *face.vertices))
        for layer in obj.data.uv_layers:
            digest.update(layer.name.encode())
            for value in layer.data: digest.update(struct.pack('<2d', *value.uv))
        for normal in obj.data.corner_normals: digest.update(struct.pack('<3d', *normal.vector))
        result[obj.name] = digest.hexdigest()
    return result


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--before', required=True, type=Path)
parser.add_argument('--after', required=True, type=Path)
parser.add_argument('--out', required=True, type=Path)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
before, after = stocks(args.before), stocks(args.after)
removed = sorted(set(before) - set(after))
added = sorted(set(after) - set(before))
changed = sorted(name for name in set(before) & set(after) if before[name] != after[name])
root = Path(__file__).resolve().parents[3]
expected = json.loads((root / 'art/data/orison_v2/heating_refit_authoring.json').read_text())['retire_legacy_radiator_tails']
passed = removed == sorted(expected) and not added and not changed
result = dict(evidence_class='INERT', scope='Native stock names, object frames, vertices, faces, UVs and corner normals only; no runtime acceptance.',
              status='PASS' if passed else 'FAIL', retained=len(after), removed=removed,
              added=added, changed=changed,
              before_sha256=hashlib.sha256(args.before.read_bytes()).hexdigest(),
              after_sha256=hashlib.sha256(args.after.read_bytes()).hexdigest())
args.out.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
print('NATIVE TAIL RETIREMENT', result['status'], len(after), 'retained;', len(removed), 'removed;', len(changed), 'changed', flush=True)
if not passed: raise RuntimeError('Retained native heating changed; see diagnostic')
