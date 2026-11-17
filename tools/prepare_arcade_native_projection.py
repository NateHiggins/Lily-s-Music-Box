"""Project declared Diner native fittings without changing any native payload.

python -B tools/prepare_arcade_native_projection.py [--check]
Only the generated test fixture is written. No engine, Blender or private reports.
"""
from __future__ import annotations
import argparse
import hashlib
import itertools
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

RAW_IDS = tuple('site_rear_luncheonette_'+suffix for suffix in (
    'shelf_up0_0','shelf_up0_1','shelf_up0_2','shelf0_0','shelf0_1','shelf0_2','shelf0_3',
    'stock0','stock1','stock2','crate_a','crate_b'))
RAW_TOLERANCE = 2e-5  # Existing original box-boundary guard, not a new clearance allowance.

def raw_bounds(record):
    rect, z, height = record.get('rect'), record.get('z0'), record.get('h')
    require(isinstance(rect,list) and len(rect)==4 and all(type(x) in (int,float) and math.isfinite(x) for x in rect), 'invalid source box rect')
    require(type(z) in (int,float) and math.isfinite(z) and type(height) in (int,float) and math.isfinite(height) and height>0 and rect[2]>rect[0] and rect[3]>rect[1], 'invalid source box dimensions')
    return [rect[0],z,-rect[3]],[rect[2],z+height,-rect[1]]

def vector(value):
    require(isinstance(value,list) and len(value)==3 and all(type(x) in (int,float) and math.isfinite(x) for x in value), 'nonfinite bounds')
    return value

def transformed_bounds(delta, low, high):
    points = [[sum(delta[i][j]*p[j] for j in range(3))+delta[i][3] for i in range(3)]
              for p in itertools.product(*zip(low,high))]
    return [min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]

class SourceCell:
    """Exact original cell glTF arrays, not generated replacement geometry."""
    def __init__(self, root, source, buffers):
        path = resource(root,source)
        self.doc = json.loads(path.read_text(encoding='utf-8'))
        self.buffers, self.buffer_bindings = [], {}
        for item in self.doc['buffers']:
            uri = item['uri']
            require(not uri.startswith('data:') and Path(uri).name==uri and '/' not in uri and '\\' not in uri, 'cell buffer must be adjacent')
            name = source.rsplit('/',1)[0]+'/'+uri
            require(name in buffers, 'missing cell binary binding')
            require(sha(resource(root,name))==buffers[name], 'cell binary binding changed')
            data = resource(root,name).read_bytes()
            require(len(data)==item['byteLength'], 'cell binary size changed')
            self.buffers.append(data)
            self.buffer_bindings[name] = dict(kind='raw',sha256=buffers[name])
        require(set(buffers)==set(self.buffer_bindings), 'foreign cell binary binding')
        self.faces = []
        for node_index,node in enumerate(self.doc['nodes']):
            require(not any(k in node for k in ('matrix','translation','rotation','scale','children')), 'original cell nodes must remain flat without TRS')
            if 'mesh' not in node:
                continue
            for primitive_index,primitive in enumerate(self.doc['meshes'][node['mesh']]['primitives']):
                require(primitive.get('mode',4)==4 and not primitive.get('targets'), 'original cell requires static triangles')
                positions, _ = self.accessor(primitive['attributes']['POSITION'])
                require(self.doc['accessors'][primitive['attributes']['POSITION']]['componentType']==5126, 'original position format changed')
                ids, index_bytes = self.accessor(primitive['indices'])
                indices = [row[0] for row in ids]
                require(len(indices)%3==0 and all(0<=i<len(positions) for i in indices), 'original cell indices invalid')
                material = self.doc['materials'][primitive['material']]['name']
                attributes = {}
                for name,accessor_id in primitive['attributes'].items():
                    _, raw = self.accessor(accessor_id)
                    a = self.doc['accessors'][accessor_id]
                    attributes[name] = dict(accessor=accessor_id,component_type=a['componentType'],type=a['type'],count=a['count'],normalized=a.get('normalized',False),sha256=hashlib.sha256(raw).hexdigest())
                witness = dict(node=node['name'],node_index=node_index,mesh_index=node['mesh'],primitive_index=primitive_index,material_name=material,attributes=attributes,index_accessor=primitive['indices'],original_index_count=len(indices),original_index_sha256=hashlib.sha256(index_bytes).hexdigest())
                for triangle in range(len(indices)//3):
                    self.faces.append(dict(points=[positions[indices[triangle*3+j]] for j in range(3)],triangle=triangle,indices=indices[triangle*3:triangle*3+3],binding=witness))
    def accessor(self, index):
        a = self.doc['accessors'][index]
        require(not a.get('sparse'), 'sparse original cell accessor unsupported')
        view = self.doc['bufferViews'][a['bufferView']]
        fmt = {5126:'f',5125:'I',5123:'H',5122:'h',5121:'B',5120:'b'}[a['componentType']]
        width = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        size = struct.calcsize('<'+fmt*width)
        offset, stride = view.get('byteOffset',0)+a.get('byteOffset',0), view.get('byteStride',size)
        source = self.buffers[view.get('buffer',0)]
        require(a['count']==0 or offset+(a['count']-1)*stride+size<=len(source), 'original accessor exceeds buffer')
        raw = b''.join(source[offset+i*stride:offset+i*stride+size] for i in range(a['count']))
        return [list(struct.unpack_from('<'+fmt*width,raw,i*size)) for i in range(a['count'])], raw

def boundary_match(points, low, high, tolerance=RAW_TOLERANCE):
    if not all(low[i]-tolerance<=p[i]<=high[i]+tolerance for p in points for i in range(3)):
        return False
    a = [points[1][i]-points[0][i] for i in range(3)]
    b = [points[2][i]-points[0][i] for i in range(3)]
    n = [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
    length = math.sqrt(sum(x*x for x in n))
    if length<1e-14:
        return False
    axis = max(range(3),key=lambda i:abs(n[i]))
    if abs(n[axis]/length)<.999:
        return False
    plane = high[axis] if n[axis]>0 else low[axis]
    return all(abs(p[axis]-plane)<=tolerance for p in points)

def select_raw_faces(cell, stocks):
    """Outward oriented boundary tests distinguish coincident stacked box faces."""
    selected = {stock['id']:[] for stock in stocks}
    for face in cell.faces:
        matches = [stock for stock in stocks
                   if face['binding']['material_name']=='M_'+stock['source_record']['mat']+'_b'
                   and boundary_match(face['points'],stock['source_low'],stock['source_high'])]
        require(len(matches)<=1, 'ambiguous original stock facets')
        if matches:
            selected[matches[0]['id']].append(face)
    return selected

def validate_box_faces(faces, stock):
    """Six oriented rectangle faces, each tiled by its two original triangles."""
    low, high = stock['source_low'], stock['source_high']
    sides = {(axis, sign):[] for axis in range(3) for sign in (-1,1)}
    for face in faces:
        p = face['points']
        a, b = [[p[k][i]-p[0][i] for i in range(3)] for k in (1,2)]
        n = [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
        axis = max(range(3),key=lambda i:abs(n[i]))
        sign = 1 if n[axis]>0 else -1
        corners = []
        for point in p:
            require(all(min(abs(point[i]-low[i]),abs(point[i]-high[i]))<=RAW_TOLERANCE for i in range(3)), 'raw box facet has noncorner vertices')
            corners.append(tuple(0 if abs(point[i]-low[i])<abs(point[i]-high[i]) else 1 for i in range(3)))
        require(len(set(corners))==3, 'degenerate raw box facet')
        sides[(axis,sign)].append(set(corners))
    for (axis,sign), triangles in sides.items():
        require(len(triangles)==2, 'raw box missing oriented face')
        common = triangles[0] & triangles[1]
        require(len(common)==2 and len(triangles[0] | triangles[1])==4, 'raw box face duplicated or incomplete')
        a,b = sorted(common)
        require(all(a[i]!=b[i] for i in range(3) if i!=axis), 'raw box triangles do not share face diagonal')

def raw_projection(root, plan):
    fabrication = json.loads(resource(root,plan['fabrication_source']).read_text(encoding='utf-8'))
    floors = [f for f in fabrication['floors'] if f['id']=='F01']
    require(len(floors)==1, 'F01 source missing or duplicate')
    actual = {}
    for record in floors[0]['furniture']:
        if record['id'] in RAW_IDS:
            require(record['id'] not in actual, 'duplicate fabrication stock')
            actual[record['id']] = record
    require(set(actual)==set(RAW_IDS), 'mandatory original Diner stocks absent')
    inventory = plan.get('raw_stock_ids')
    require(isinstance(inventory,list) and all(isinstance(x,str) for x in inventory) and len(inventory)==len(RAW_IDS) and len(set(inventory))==len(inventory) and set(inventory)==set(RAW_IDS), 'raw stock inventory missing/empty/duplicated/foreign')
    stocks = plan.get('raw_stocks',[])
    seen, groups = set(), {}
    for stock in stocks:
        identity = stock['id']
        require(identity in actual, 'foreign raw stock')
        require(identity not in seen, 'duplicate raw stock')
        seen.add(identity)
        require(stock['source_record']==actual[identity], 'literal raw source record changed')
        low, high = raw_bounds(actual[identity])
        require(stock['source_low']==low and stock['source_high']==high, 'false raw source box')
        vector(stock['source_low']); vector(stock['source_high'])
        delta = matrix(stock['delta_transform'],rigid=True)
        expected_group = 'original_raw_stacked_crates' if '_crate_' in identity else 'original_raw_rack_and_all_contents'
        require(stock['group']==expected_group, 'wrong raw stock group')
        require(expected_group not in groups or groups[expected_group]==delta, 'raw group relative geometry changed')
        groups[expected_group] = delta
        target_low, target_high = transformed_bounds(delta,low,high)
        vector(stock['target_low']); vector(stock['target_high'])
        require(max(abs(a-b) for a,b in zip(target_low+target_high,stock['target_low']+stock['target_high']))<=1e-10, 'wrong raw target bounds')
    require(seen==set(RAW_IDS), 'missing mandatory raw stocks')
    # Raw stock selectors use canonical box boundaries. Packed position
    # compression moves those vertices beyond the existing 20-micron guard.
    # Preserve source coordinates at import rather than weakening selection.
    import_source = plan['cell_source'] + '.import'
    import_path = resource(root, import_source)
    import_text = import_path.read_text(encoding='utf-8')
    require(re.search(r'^meshes/force_disable_compression=true$', import_text, re.M), 'raw stock requires exact uncompressed imported positions')
    cell = SourceCell(root,plan['cell_source'],plan.get('cell_buffers',{}))
    cell.buffer_bindings[import_source] = dict(kind='lf', sha256=sha(import_path, True))
    selected = select_raw_faces(cell,stocks)
    result = []
    for stock in stocks:
        faces = selected[stock['id']]
        require(len(faces)==12, 'original stock must select exactly12 actual box facets: '+stock['id'])
        validate_box_faces(faces,stock)
        primitives = {}
        for face in faces:
            key = (face['binding']['node_index'],face['binding']['primitive_index'])
            if key not in primitives:
                primitives[key] = dict(face['binding'],selected_triangle_indices=[],selected_indices=[])
            primitives[key]['selected_triangle_indices'].append(face['triangle'])
            primitives[key]['selected_indices'].extend(face['indices'])
        result.append(dict(id=stock['id'],source_record=stock['source_record'],source_low=stock['source_low'],source_high=stock['source_high'],delta_transform=stock['delta_transform'],target_low=stock['target_low'],target_high=stock['target_high'],expected_triangles=len(faces),source_selections=list(primitives.values())))
    return result, cell.buffer_bindings

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
    raw_stocks, cell_bindings = raw_projection(root,plan)
    source_bindings.update(cell_bindings)
    return dict(schema_version=1,cell=CELL,placement_source=PLAN.as_posix(),placement_sha256_lf=sha(root/PLAN,True),source_bindings=source_bindings,fabrication_source=plan['fabrication_source'],fabrication_sha256_lf=plan['fabrication_source_sha256_lf'],cell_source=plan['cell_source'],cell_source_sha256_lf=plan['cell_source_sha256_lf'],native_assets=native_assets,models=models,entries=entries,labels=labels,raw_stock_ids=list(RAW_IDS),raw_stocks=raw_stocks)

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
