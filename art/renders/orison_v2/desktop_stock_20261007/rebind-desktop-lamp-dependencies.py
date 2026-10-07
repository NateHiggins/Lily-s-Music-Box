"""Bounded finish-only dependency refresh; no new native acceptance is granted."""
from pathlib import Path
import hashlib, json, struct, subprocess

ROOT = Path.cwd()
BASE = 'd39e5333'
CHANGED = ['task_lamps']
DEPENDENTS = ['reading_nook','work_tables']
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



def without_finish(data):
    import copy
    data=copy.deepcopy(data)
    for variant in data['variants']:
        for part in variant['parts']:part.pop('finish',None)
    return data
asset='game/assets/props/task_lamps.glb'
before=original(asset);after=current(asset)
assert geometry(before)==geometry(after),'physical lamp geometry changed'
fixture='game/tests/fixtures/orison_task_lamps.json'
old=json.loads(original(fixture));new=json.loads(current(fixture))
for key in set(old)|set(new):
    if key in ['asset_sha256','source_bindings']:continue
    if key=='runtime':assert without_finish(old[key])==without_finish(new[key])
    else:assert old.get(key)==new.get(key),(key,'lamp semantics changed')
runtime='game/data/orison_v2/task_lamps.json'
assert without_finish(json.loads(original(runtime)))==without_finish(json.loads(current(runtime)))
refresh=[]
for family in DEPENDENTS:
    names=[f'game/tests/fixtures/orison_{family}.json',f'art/blender/{family}_construction.json']
    reports=[json.loads(current(n)) for n in names];assert reports[0]==reports[1]
    report=reports[0];assert report==json.loads(original(names[0]))
    changes=[]
    for path,bound in report['source_bindings'].items():
        actual=digest(current(path),path)
        if actual==bound:continue
        assert path=='art/blender/task_lamps.blend',path
        assert digest(original(path),path)==bound
        changes.append({'path':path,'before':bound,'after':actual});report['source_bindings'][path]=actual
    for name in names:
        text=current(name).decode('utf-8')
        for change in changes:
            needle=json.dumps(change['path'])+': '+json.dumps(change['before']);assert text.count(needle)==1
            text=text.replace(needle,json.dumps(change['path'])+': '+json.dumps(change['after']))
        assert json.loads(text)==report;pending[name]=text.replace('\r\n','\n').encode()
    for path in [f'art/blender/{family}.blend',f'game/assets/props/{family}.glb',f'game/data/orison_v2/{family}.json']:
        assert digest(current(path),path)==digest(original(path),path)
    refresh.append({'family':family,'changes':changes,'native_export_and_runtime_unchanged':True})
for path,data in pending.items():(ROOT/path).write_bytes(data)
out={'evidence_class':'INERT','baseline':BASE,'lamp_expanded_geometry_unchanged':geometry(after),'method':'Exact expanded physical triangle bytes and scene graph unchanged. Lamp runtime changes consist only of declared finish parameters; original records, contacts, emission/switch datums and construction stock unchanged. Dependent native/export/runtime bytes unchanged. No renewed acceptance claim.','dependents':refresh}
(ROOT/'tmp/v2-finish-review/desktop-lamp-dependency-reuse.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print('Lamp geometry unchanged; refreshed',len(refresh),'dependent native bindings')
