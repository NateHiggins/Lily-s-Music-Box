"""Extract the authored arcade entrance from the admitted street owner cell.

Geometry, collision suffixes, transforms and material records are copied exactly.
Only scene membership and relative resource URIs change. V1 files are never outputs.
"""
from pathlib import Path
import hashlib
import json
import os

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'game/assets/building/floor_01_cells/site_street_common.gltf'
OUTPUT = ROOT / 'game/assets/building/orison_v2/exterior/passage_gateway.gltf'
MANIFEST = ROOT / 'game/data/orison_v2/exterior/passage_gateway_source.json'
NAMES = [
    'common_brick-col', 'gateway_cast_iron', 'gateway_cast_iron-col',
    'gateway_common_brick-col', 'gateway_face_brick-col',
    'gateway_glassish-col', 'gateway_limestone-col', 'gateway_soot-col',
    'gateway_subway_tile-col', 'glassish-col', 'limestone-col', 'metal-col',
]
PREFIX = 'F01_OWN_STREET_retail_passage_proxy_'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def build():
    source_hash = sha(SOURCE)
    admitted = json.loads((ROOT / 'design/astra/evidence/f01_provider_execution_07/integration.json').read_text())
    assert source_hash == admitted['files'][SOURCE.relative_to(ROOT).as_posix()]
    original = json.loads(SOURCE.read_text())
    scene_roots = original['scenes'][original.get('scene', 0)]['nodes']
    selected = []
    for suffix in NAMES:
        matches = [i for i in scene_roots if original['nodes'][i]['name'] == PREFIX + suffix]
        assert len(matches) == 1, suffix
        selected.append(matches[0])
    assert all('children' not in original['nodes'][i] for i in selected)
    candidate = json.loads(json.dumps(original))
    candidate['nodes'] = [original['nodes'][i].copy() for i in selected]
    mesh_ids = sorted({n['mesh'] for n in candidate['nodes']})
    candidate['meshes'] = [original['meshes'][i] for i in mesh_ids]
    for node in candidate['nodes']:
        node['mesh'] = mesh_ids.index(node['mesh'])
    candidate['scenes'] = [{'name': 'V2_PassageGateway', 'nodes': list(range(len(selected)))}]
    candidate['scene'] = 0
    resources = {}
    for section in ['buffers', 'images']:
        for row in candidate.get(section, []):
            uri = row.get('uri', '')
            assert uri and not uri.startswith('data:'), (section, uri)
            path = (SOURCE.parent / uri).resolve()
            assert path.is_relative_to(ROOT / 'game') and path.is_file(), path
            resources[path.relative_to(ROOT).as_posix()] = sha(path)
            row['uri'] = os.path.relpath(path, OUTPUT.parent).replace('\\', '/')
    for source_id, node in zip(selected, candidate['nodes']):
        restored = dict(node, mesh=mesh_ids[node['mesh']])
        assert restored == original['nodes'][source_id]
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(candidate, separators=(',', ':'))+'\n', encoding='utf-8')
    manifest = {'schema': 'orison.v2.passage-gateway-source.v1',
        'source': SOURCE.relative_to(ROOT).as_posix(), 'source_sha256': source_hash,
        'output': OUTPUT.relative_to(ROOT).as_posix(), 'output_sha256': sha(OUTPUT),
        'authored_nodes': [PREFIX+n for n in NAMES], 'resources': resources,
        'geometry_changed': False, 'runtime_adopted': False,
        'scope': 'Entrance extraction only; shared-frame placement and connected traversal remain unproved.'}
    MANIFEST.write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    assert sha(SOURCE) == source_hash
    print('Extracted', len(selected), 'exact authored gateway roots; source unchanged')


if __name__ == '__main__':
    build()
