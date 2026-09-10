"""Extract the authored arcade entrance from the admitted street owner cell.

Material records and non-kiosk geometry are copied exactly. The kiosk is moved
onto the sidewalk with its collision and normals. V1 files are never outputs.
"""
from pathlib import Path
import hashlib
import json
import os
import struct

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

def relocate_subway(candidate):
    """Relocate complete kiosk triangles, including imported collision meshes.

    The authored kiosk occupies x=18.55..20.20, below y=3.71. The adjacent
    facade's vertices and downpipe lie outside this envelope. Refuse shared
    boundary vertices rather than stretching any other assembly.
    """
    binary = bytearray()
    moved = {}
    def read(index):
        a = candidate['accessors'][index]
        v = candidate['bufferViews'][a['bufferView']]
        b = candidate['buffers'][v['buffer']]
        source = (OUTPUT.parent / b['uri']).resolve().read_bytes()
        width = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        code = {5123:'H',5125:'I',5126:'f'}[a['componentType']]
        size = struct.calcsize('<'+code*width)
        start = v.get('byteOffset',0)+a.get('byteOffset',0)
        return [struct.unpack_from('<'+code*width,source,start+i*v.get('byteStride',size)) for i in range(a['count'])]
    buffer_id = len(candidate['buffers'])
    for node in candidate['nodes']:
        if '_gateway_' not in node['name']: continue
        for primitive in candidate['meshes'][node['mesh']]['primitives']:
            positions = read(primitive['attributes']['POSITION'])
            indices = [v[0] for v in read(primitive['indices'])]
            inside = lambda p: 18.50 <= p[0] <= 20.21 and -1.35 <= p[1] <= 3.72 and 27.75 <= p[2] <= 33.30
            selected, retained = set(), set()
            triangles = 0
            for i in range(0,len(indices),3):
                tri = indices[i:i+3]
                if all(inside(positions[j]) for j in tri):
                    selected.update(tri)
                    triangles += 1
                else: retained.update(tri)
            assert not selected.intersection(retained), node['name']
            if not selected: continue
            # Turn the long stair parallel to the opposite sidewalk. World
            # center is (2.5,0,16), after Passage's -9.795 m Z registration.
            new = [(2.5+p[2]-30.525,p[1],25.795-(p[0]-19.375)) if i in selected else p for i,p in enumerate(positions)]
            assert all(new[i] == positions[i] for i in retained)
            offset = len(binary)
            for p in new: binary.extend(struct.pack('<3f',*p))
            view_id = len(candidate['bufferViews'])
            candidate['bufferViews'].append({'buffer':buffer_id,'byteOffset':offset,'byteLength':len(new)*12,'target':34962})
            accessor = {'bufferView':view_id,'componentType':5126,'count':len(new),'type':'VEC3',
                        'min':[min(p[i] for p in new) for i in range(3)],
                        'max':[max(p[i] for p in new) for i in range(3)]}
            primitive['attributes']['POSITION'] = len(candidate['accessors'])
            candidate['accessors'].append(accessor)
            normals = read(primitive['attributes']['NORMAL'])
            assert len(normals) == len(positions)
            rotated = [(n[2],n[1],-n[0]) if i in selected else n for i,n in enumerate(normals)]
            offset = len(binary)
            for n in rotated: binary.extend(struct.pack('<3f',*n))
            view_id = len(candidate['bufferViews'])
            candidate['bufferViews'].append({'buffer':buffer_id,'byteOffset':offset,'byteLength':len(rotated)*12,'target':34962})
            primitive['attributes']['NORMAL'] = len(candidate['accessors'])
            candidate['accessors'].append({'bufferView':view_id,'componentType':5126,'count':len(rotated),'type':'VEC3'})
            moved[node['name']] = {'vertices':len(selected),'triangles':triangles}
    assert len(moved) == 6, moved
    path = OUTPUT.with_name('passage_gateway_subway.bin')
    path.write_bytes(binary)
    candidate['buffers'].append({'uri':path.name,'byteLength':len(binary)})
    return {'source_center_m':[19.375,0,30.525], 'target_world_center_m':[2.5,0,16], 'yaw_degrees':90, 'moved':moved,
            'buffer':path.relative_to(ROOT).as_posix(),'buffer_sha256':sha(path)}


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
    subway = relocate_subway(candidate)
    OUTPUT.write_text(json.dumps(candidate, separators=(',', ':'))+'\n', encoding='utf-8')
    manifest = {'schema': 'orison.v2.passage-gateway-source.v1',
        'source': SOURCE.relative_to(ROOT).as_posix(), 'source_sha256': source_hash,
        'output': OUTPUT.relative_to(ROOT).as_posix(), 'output_sha256': sha(OUTPUT),
        'authored_nodes': [PREFIX+n for n in NAMES], 'resources': resources,
        'geometry_changed': True, 'runtime_adopted': True,
        'subway_relocation': subway,
        'scope': 'Existing gateway extraction with subway kiosk turned along the opposite sidewalk outside the arcade; other triangles unchanged.'}
    MANIFEST.write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    assert sha(SOURCE) == source_hash
    print('Extracted', len(selected), 'gateway roots; V2 subway relocated; V1 source unchanged')


if __name__ == '__main__':
    build()
