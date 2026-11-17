"""Project declared Diner native fittings without changing any native payload.

python -B tools/prepare_arcade_native_projection.py [--check]
Only the generated test fixture is written. No engine, Blender or private reports.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
PLAN = Path('art/data/arcade_plaza/diner_native_placements.json')
FIXTURE = Path('game/tests/fixtures/arcade_diner_native_projection.json')
CELL = 'shop_luncheonette'
MODEL_NAMES = {'ShopSeating', 'DinerCounter', 'DinerTill', 'DinerBackbar', 'DinerUrns', 'DinerApparatus', 'DinerOverhead'}

def require(ok, message):
    if not ok:
        raise ValueError(message)

def sha(path, lf=False):
    data = path.read_bytes()
    return hashlib.sha256(data.replace(b'\r\n', b'\n') if lf else data).hexdigest()

def resource(root, path):
    require(isinstance(path, str) and path.startswith('res://'), 'resource path required')
    relative = Path(path[6:])
    require(not relative.is_absolute() and '..' not in relative.parts, 'foreign resource path')
    result = (root / 'game' / relative).resolve()
    require(result.is_relative_to((root / 'game').resolve()), 'resource escapes game')
    return result

def matrix(value, rigid=False):
    require(isinstance(value, list) and len(value) == 4 and all(isinstance(r, list) and len(r) == 4 for r in value), 'matrix must be four rows')
    require(all(type(x) in (int, float) and math.isfinite(x) for row in value for x in row), 'nonfinite matrix')
    require(value[3] == [0, 0, 0, 1], 'nonaffine matrix')
    if rigid:
        for i in range(3):
            for j in range(3):
                require(abs(sum(value[k][i] * value[k][j] for k in range(3)) - (1 if i == j else 0)) <= 1e-10, 'delta scale/shear forbidden')
        a, b, c = value[:3]
        determinant = a[0]*(b[1]*c[2]-b[2]*c[1])-a[1]*(b[0]*c[2]-b[2]*c[0])+a[2]*(b[0]*c[1]-b[1]*c[0])
        require(abs(determinant-1) <= 1e-10, 'delta reflection forbidden')
    return value

def mul(a, b):
    return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]

def label_transform(label):
    at, yaw = label.get('at'), label.get('yaw')
    require(isinstance(at, list) and len(at)==3 and all(type(x) in (int,float) and math.isfinite(x) for x in at), 'invalid source label position')
    require(type(yaw) in (int,float) and math.isfinite(yaw), 'invalid source label yaw')
    c, t = math.cos(yaw), math.sin(yaw)
    return matrix([[c,0,t,at[0]],[0,1,0,at[1]],[-t,0,c,at[2]],[0,0,0,1]])

class NativeGLB:
    def __init__(self, path):
        data = path.read_bytes()
        require(data[:4] == b'glTF' and struct.unpack_from('<I', data, 4)[0] == 2 and struct.unpack_from('<I', data, 8)[0] == len(data), 'invalid GLB')
        size, kind = struct.unpack_from('<II', data, 12)
        require(kind == 0x4e4f534a, 'missing GLB JSON')
        self.doc = json.loads(data[20:20+size])
        size2, kind2 = struct.unpack_from('<II', data, 20+size)
        require(kind2 == 0x004e4942, 'missing GLB binary')
        self.binary = data[28+size:28+size+size2]
        self.names = {}
        self.parents = {}
        for i, node in enumerate(self.doc['nodes']):
            if 'mesh' in node:
                require(node['name'] not in self.names, 'duplicate native node')
                self.names[node['name']] = i
            for child in node.get('children', []):
                require(child not in self.parents, 'multiple native parents')
                self.parents[child] = i
    def local(self, i):
        node = self.doc['nodes'][i]
        if 'matrix' in node:
            require(not any(k in node for k in ('translation', 'rotation', 'scale')), 'mixed node transform')
            flat = node['matrix']
            require(len(flat) == 16, 'node matrix size')
            return matrix([[flat[j*4+i] for j in range(4)] for i in range(4)])
        t, q, s = node.get('translation', [0,0,0]), node.get('rotation', [0,0,0,1]), node.get('scale', [1,1,1])
        require(len(t)==3 and len(q)==4 and len(s)==3 and all(type(x) in (int,float) and math.isfinite(x) for x in t+q+s), 'invalid node TRS')
        x,y,z,w = q
        require(abs(sum(v*v for v in q)-1) <= 1e-6, 'nonunit node quaternion')
        b = [[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)], [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)], [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
        return matrix([[b[i][j]*s[j] for j in range(3)]+[t[i]] for i in range(3)]+[[0,0,0,1]])
    def transform(self, i, seen=None):
        seen = set() if seen is None else seen
        require(i not in seen, 'cyclic node hierarchy')
        seen.add(i)
        local = self.local(i)
        return mul(self.transform(self.parents[i], seen), local) if i in self.parents else local
    def triangles(self, name):
        require(name in self.names, 'missing native part '+name)
        mesh = self.doc['meshes'][self.doc['nodes'][self.names[name]]['mesh']]
        total = 0
        for primitive in mesh['primitives']:
            require(primitive.get('mode', 4)==4, 'nontriangle native primitive')
            positions = self.doc['accessors'][primitive['attributes']['POSITION']]
            if 'indices' not in primitive:
                count = positions['count']
            else:
                accessor = self.doc['accessors'][primitive['indices']]
                require(accessor['type']=='SCALAR' and not accessor.get('sparse'), 'unsupported indices')
                view = self.doc['bufferViews'][accessor['bufferView']]
                fmt = {5121:'B',5123:'H',5125:'I'}.get(accessor['componentType'])
                require(fmt is not None, 'invalid index type')
                width = struct.calcsize('<'+fmt)
                offset = view.get('byteOffset',0)+accessor.get('byteOffset',0)
                stride = view.get('byteStride',width)
                count = accessor['count']
                for k in range(count):
                    require(struct.unpack_from('<'+fmt, self.binary, offset+k*stride)[0] < positions['count'], 'native index out of range')
            require(count > 0 and count % 3 == 0, 'invalid native triangle count')
            total += count // 3
        return total

def build(root=ROOT, plan=None):
    root = Path(root)
    plan = json.loads((root/PLAN).read_text(encoding='utf-8')) if plan is None else plan
    require(plan.get('schema_version')==1 and plan.get('cell')==CELL, 'wrong native placement plan')
    for key in ('fabrication_source', 'cell_source', 'mount_source'):
        require(sha(resource(root, plan[key]), True)==plan[key+'_sha256_lf'], 'source binding changed: '+key)
    mount_text = resource(root, plan['mount_source']).read_text(encoding='utf-8')
    specs = {name:(path,prefix,meta) for path,name,prefix,meta in re.findall(r'return mount_records\(cell,layout,"([^"]+)","([^"]+)","([^"]+)","([^"]+)"', mount_text)}
    models, native_assets, expected, owners, natives = [], {}, set(), {}, {}
    expected_labels = {}
    source_bindings = {plan['mount_source']: dict(kind='lf', sha256=plan['mount_source_sha256_lf'])}
    for model in plan['models']:
        name = model['name']
        require(name not in natives and name in specs, 'duplicate or foreign model')
        sidecar, prefix, meta = specs[name]
        require((sidecar,prefix,meta)==(model['sidecar'],model['prefix'],model['part_meta']), 'mount_records identity changed')
        require(sha(resource(root,sidecar),True)==model['sidecar_sha256_lf'], 'native sidecar changed')
        source_bindings[sidecar] = dict(kind='lf', sha256=model['sidecar_sha256_lf'])
        data = json.loads(resource(root,sidecar).read_text(encoding='utf-8'))
        require(data['asset']==model['asset'], 'sidecar asset changed')
        require(sha(resource(root,model['asset']))==model['asset_sha256'], 'native asset changed')
        cells = [c for c in data['cells'] if c['id']==CELL]
        require(len(cells)==1, 'native cell missing or duplicated')
        for label in cells[0].get('labels', []):
            identity = (name, label['id'])
            require(identity not in expected_labels and isinstance(label.get('text'), str) and bool(label['text']), 'duplicate or invalid native label')
            expected_labels[identity] = label
        native = NativeGLB(resource(root,model['asset']))
        for part in cells[0]['parts']:
            identity = (name,part['name'])
            require(identity not in expected and part['name'] in native.names, 'duplicate or absent native sidecar part')
            expected.add(identity)
        natives[name] = native
        owners[name] = model
        native_assets[model['asset']] = model['asset_sha256']
        models.append(dict(name=name,part_meta=meta))
    require(set(owners)==MODEL_NAMES, 'all seven exact Diner native models required')
    entries, seen, assemblies, targets = [], set(), set(), set()
    groups = {}
    for group in plan['groups']:
        require(group['name'] not in groups, 'duplicate placement group')
        groups[group['name']] = group
        delta = matrix(group['delta_transform'], rigid=True)
        for assembly in group['assemblies']:
            require(assembly['id'] not in assemblies, 'duplicate assembly')
            assemblies.add(assembly['id'])
            name = assembly['model']
            require(name in owners, 'foreign assembly model')
            require(bool(assembly['parts']), 'empty assembly')
            model, native = owners[name], natives[name]
            for part in assembly['parts']:
                ident = (name,part['part_id'])
                require(ident in expected, 'foreign native part')
                require(ident not in seen, 'duplicate native part')
                require(part['part_id'].startswith(assembly['id']+'__'), 'part assigned to wrong assembly')
                seen.add(ident)
                source = native.transform(native.names[part['part_id']])
                target = matrix(part['target_transform'])
                composed = mul(delta,source)
                require(max(abs(target[i][j]-composed[i][j]) for i in range(4) for j in range(4)) <= 1e-10, 'target differs from delta * source (double transform?)')
                target_name = model['prefix']+part['part_id']
                require(target_name not in targets, 'duplicate target name')
                targets.add(target_name)
                entries.append(dict(model=name,part_meta=model['part_meta'],part_id=part['part_id'],source_transform=source,delta_transform=delta,target_transform=target,triangles=native.triangles(part['part_id']),target_name=target_name))
    require(seen==expected, 'missing native parts')
    require(len(assemblies)==17 and len(entries)==41, 'Diner requires all17 complete assemblies/41parts')
    labels, seen_labels = [], set()
    for declared in plan.get('labels', []):
        identity = (declared['model'], declared['label_id'])
        require(identity in expected_labels, 'foreign native label')
        require(identity not in seen_labels, 'duplicate native label')
        seen_labels.add(identity)
        require(declared.get('group')=='diner_menu' and declared['model']=='DinerOverhead', 'menu label assigned to wrong group')
        group = groups.get(declared['group'], {})
        require(any(a['model']=='DinerOverhead' and a['id']=='storm_shop_luncheonette_menu_board' for a in group.get('assemblies', [])), 'menu group does not own native board')
        source_label = expected_labels[identity]
        require(declared.get('text')==source_label['text'], 'native label text changed')
        source = label_transform(source_label)
        delta = matrix(group['delta_transform'], rigid=True)
        target = matrix(declared['target_transform'])
        composed = mul(delta, source)
        require(max(abs(target[i][j]-composed[i][j]) for i in range(4) for j in range(4)) <= 1e-10, 'label target differs from menu delta * source')
        node_name = 'Words_'+declared['label_id']
        require(node_name not in targets, 'duplicate target label name')
        targets.add(node_name)
        labels.append(dict(model=declared['model'],label_id=declared['label_id'],node_name=node_name,text=source_label['text'],source_transform=source,delta_transform=delta,target_transform=target,target_name=node_name))
    require(seen_labels==set(expected_labels), 'missing native labels')
    return dict(schema_version=1,cell=CELL,placement_source=PLAN.as_posix(),placement_sha256_lf=sha(root/PLAN,True),source_bindings=source_bindings,fabrication_source=plan['fabrication_source'],fabrication_sha256_lf=plan['fabrication_source_sha256_lf'],cell_source=plan['cell_source'],cell_source_sha256_lf=plan['cell_source_sha256_lf'],native_assets=native_assets,models=models,entries=entries,labels=labels)

def render(doc):
    return json.dumps(doc,indent=1,allow_nan=False)+'\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    text=render(build(args.root))
    output=args.root/FIXTURE
    if args.check:
        require(output.exists() and output.read_text(encoding='utf-8').replace('\r\n','\n')==text, 'native projection fixture stale; rerun producer')
        print('ARCADE DINER NATIVE PROJECTION OK')
    else:
        output.parent.mkdir(parents=True,exist_ok=True)
        output.write_text(text,encoding='utf-8',newline='\n')
        print('WROTE '+str(FIXTURE))
    return 0

if __name__=='__main__':
    raise SystemExit(main())
