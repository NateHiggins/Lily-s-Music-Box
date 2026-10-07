"""Bounded finish-only dependency refresh; no new native acceptance is granted."""
from pathlib import Path
import hashlib, json, struct, subprocess

ROOT = Path.cwd()
BASE = 'd1de58c1'
CHANGED = ['diner_counter', 'diner_till', 'hardware_tools', 'photo_cameras',
           'photo_counter', 'photo_stock', 'photo_enlargers', 'photo_portraits', 'radio_wire']
DEPENDENTS = ['diner_backbar', 'diner_urns', 'diner_apparatus', 'diner_overhead',
              'photo_receiving', 'radio_display', 'radio_receiving']
pending = {}


def original(path):
    return subprocess.check_output(['git', 'show', BASE + ':' + path])


def digest(data, path):
    if Path(path).suffix not in ['.blend', '.glb', '.png', '.bin']:
        data = data.replace(b'\r\n', b'\n')
    return hashlib.sha256(data).hexdigest()


def current(path):
    return pending.get(path, (ROOT / path).read_bytes())


def geometry(data):
    magic, version, length = struct.unpack_from('<III', data)
    assert magic == 0x46546C67 and version == 2 and length == len(data)
    offset = 12; chunks = {}
    while offset < len(data):
        size, kind = struct.unpack_from('<II', data, offset); offset += 8
        chunks[kind] = data[offset:offset + size]; offset += size
    doc = json.loads(chunks[0x4E4F534A]); buf = chunks[0x004E4942]
    def rows(index):
        a = doc['accessors'][index]; v = doc['bufferViews'][a['bufferView']]
        count = {'SCALAR': 1, 'VEC3': 3}[a['type']]
        fmt = {5121: 'B', 5123: 'H', 5125: 'I', 5126: 'f'}[a['componentType']]
        size = struct.calcsize('<' + fmt) * count
        start = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        return [buf[start + k * v.get('byteStride', size):start + k * v.get('byteStride', size) + size] for k in range(a['count'])]
    result = {}
    for mesh in doc['meshes']:
        hashes = []
        for p in mesh['primitives']:
            assert p.get('mode', 4) == 4 and 'targets' not in p
            positions = rows(p['attributes']['POSITION']); indices = rows(p['indices'])
            fmt = {5121: 'B', 5123: 'H', 5125: 'I'}[doc['accessors'][p['indices']]['componentType']]
            h = hashlib.sha256()
            for i in indices: h.update(positions[struct.unpack('<' + fmt, i)[0]])
            hashes.append({'triangles': len(indices) // 3, 'positions_sha256': h.hexdigest(), 'material': p.get('material')})
        result[mesh['name']] = hashes
    return {'parts': result, 'graph': {key: doc.get(key) for key in ['nodes', 'scenes', 'scene', 'skins', 'animations', 'materials', 'cameras']}}


allowed = set(); evidence = []
for family in CHANGED:
    asset = f'game/assets/props/{family}.glb'
    before = original(asset); after = current(asset)
    a = geometry(before); b = geometry(after)
    assert a == b, ('physical geometry/scene change', family)
    fixture = f'game/tests/fixtures/orison_{family}.json'
    old = json.loads(original(fixture)); new = json.loads(current(fixture))
    for key in set(old) | set(new):
        if key not in ['asset_sha256', 'source_bindings']:
            assert old.get(key) == new.get(key), ('semantic fixture change', family, key)
    runtime = f'game/data/orison_v2/{family}.json'
    assert json.loads(original(runtime)) == json.loads(current(runtime))
    for path in [asset, f'art/blender/{family}.blend', fixture]: allowed.add(path)
    evidence.append({'family': family, 'before_asset_sha256': digest(before, asset),
                     'after_asset_sha256': digest(after, asset), 'geometry': b,
                     'fixture_semantics_unchanged': True, 'runtime_data_unchanged': True})

refresh = []
for family in DEPENDENTS:
    fixture = f'game/tests/fixtures/orison_{family}.json'
    construction = f'art/blender/{family}_construction.json'
    old = json.loads(original(fixture)); new = json.loads(current(fixture))
    assert old == new, ('dependent already changed', family)
    assert json.loads(current(construction)) == old
    updates = []
    for path, bound in old['source_bindings'].items():
        actual = digest(current(path), path)
        if actual == bound: continue
        assert path in allowed, ('unapproved input drift', family, path)
        assert bound == digest(original(path), path), ('pre-existing drift', family, path)
        new['source_bindings'][path] = actual
        updates.append({'path': path, 'before': bound, 'after': actual})
    if not updates: continue
    # All non-binding fields and native/export bytes remain unchanged.
    for path in [f'art/blender/{family}.blend', f'game/assets/props/{family}.glb', f'game/data/orison_v2/{family}.json']:
        assert digest(current(path), path) == digest(original(path), path)
    for report in [fixture, construction]:
        text = current(report).decode('utf-8')
        for change in updates:
            # Replace only this exact binding, preserving formatting and unrelated hashes.
            needle = json.dumps(change['path']) + ': ' + json.dumps(change['before'])
            assert text.count(needle) == 1, (report, change['path'])
            text = text.replace(needle, json.dumps(change['path']) + ': ' + json.dumps(change['after']))
        assert json.loads(text) == new
        pending[report] = text.replace('\r\n', '\n').encode('utf-8')
    allowed.add(fixture)
    refresh.append({'family': family, 'updates': updates, 'native_and_export_unchanged': True})

for path, data in pending.items(): (ROOT / path).write_bytes(data)
out = ROOT / 'tmp/v2-finish-review/grain-repair-dependency-reuse.json'
out.write_text(json.dumps({'evidence_class': 'INERT', 'baseline': BASE,
    'method': 'Exact expanded physical triangle bytes, glTF scene graph, fixture semantics and runtime data unchanged; only declared finish dependency bindings refreshed. Existing geometry proofs retain their original scope and date.',
    'changed_exports': evidence, 'reused_dependents': refresh}, indent=2) + '\n', encoding='utf-8')
print('Compared', len(evidence), 'exports;', sum(len(row['geometry']['parts']) for row in evidence), 'unchanged mesh partitions; refreshed', len(refresh), 'dependent reports without rebuilding their assets')
