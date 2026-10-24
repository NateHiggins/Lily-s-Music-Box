"""Repair the eleven retained arcade leaves as one source-sized native family."""
from pathlib import Path
import ast, hashlib, json, math, sys
import bpy, bmesh, numpy as np
from mathutils import Matrix, Vector
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_uvs import chart_for_triangle
from check_exported_tangents import validate

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
width, height, bottom = .95, 2.10, .016
pieces = []

def box(name, lo, hi, key, horizontal=False):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        v.co = Vector(tuple((lo[i]+hi[i])*.5+v.co[i]*(hi[i]-lo[i]) for i in range(3)))
    emit(name, bm, key, horizontal)

def cylinder(name, at, radius, length, key, depth=False):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24,
                         radius1=radius, radius2=radius, depth=length)
    for v in bm.verts:
        if depth: v.co = Matrix.Rotation(math.pi*.5, 4, 'X') @ v.co
        v.co += Vector(at)
    emit(name, bm, key)

def emit(name, bm, key, horizontal=False):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), name
    assert bm.calc_volume(signed=True) > 0, name
    # Preserve exact meeting datums. Tiny eased edges stay within original stock.
    bmesh.ops.bevel(bm, geom=[e for e in bm.edges if e.calc_face_angle(0) > .6],
                    offset=.0003, segments=2, affect='EDGES')
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), name
    volume = bm.calc_volume(signed=True)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    vertices, faces, charts = [], [], []
    for face in bm.faces:
        p = np.array([v.co[:] for v in face.verts])
        if np.linalg.norm(np.cross(p[1]-p[0], p[2]-p[0])) < 1e-14: continue
        order = [2, 1, 0] if horizontal else [0, 1, 2]
        _, _, uv, _ = chart_for_triangle(p[:, order], np.zeros(3), .30)
        start = len(vertices); vertices.extend(p.tolist())
        faces.append((start, start+1, start+2)); charts.extend(uv)
    bm.free()
    mesh = bpy.data.meshes.new(name); mesh.from_pydata(vertices, [], faces); mesh.update()
    uv = mesh.uv_layers.new(name='MetreStock')
    for loop, value in zip(uv.data, charts): loop.uv = value
    obj = bpy.data.objects.new(name, mesh); bpy.context.scene.collection.objects.link(obj)
    obj['material_key'] = key
    pieces.append({'name':name, 'key':key, 'volume_m3':volume, 'triangles':len(faces),
                   'low':[min(v[i] for v in vertices) for i in range(3)],
                   'high':[max(v[i] for v in vertices) for i in range(3)]})

for i, x in enumerate([0, width-.13]):
    box('Stile'+str(i), (x, -.0275, bottom), (x+.13, .0275, height-.01), 'oak_quartered')
for i, (lo, hi) in enumerate([(bottom,.13),(.715,.845),(height-.13,height-.01)]):
    box('Rail'+str(i), (.13,-.0275,lo), (width-.13,.0275,hi), 'oak_quartered', True)
# A retained solid collision must not be dressed as an empty lower aperture.
box('LowerPanel', (.125,-.018,.12), (width-.125,.018,.725), 'oak_quartered')
# Ten millimetres of glazing sits behind each rail; the old upper glass gap is closed.
box('Glazing', (.115,-.006,.835), (width-.115,.006,height-.12), 'glass_drawn_expressive')
# Both pull sets seat on the actual latch stile, not in the glass field.
for side in [-1, 1]:
    cylinder('Pull'+str(side), (width-.065,side*.07,1.03), .014,.34,'door_brass')
    for i, z in enumerate([.86,1.20]):
        cylinder('Stand'+str(side)+'_'+str(i), (width-.065,side*.045,z), .012,.065,'door_brass', True)

asset = ROOT/'game/assets/props/passage_shop_leaves.glb'
native = ROOT/'art/blender/passage_shop_leaves.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native), compress=True)
source = Path(__file__).with_name('build_media_battery_supply.py')
tree = ast.parse(source.read_text(encoding='utf8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='ExportDerivatives'],type_ignores=[]),str(source),'exec'))
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension = ExportDerivatives
bpy.ops.export_scene.gltf(filepath=str(asset), export_format='GLB', export_tangents=True,
                          export_materials='NONE', export_lights=False, export_cameras=False)
derivatives = validate(asset)
data = {'schema_version':1, 'width':width, 'height':height, 'bottom':bottom,
        'stop_degrees':90, 'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),
        'parts':pieces, 'derivatives':derivatives}
(ROOT/'game/tests/fixtures/passage_shop_leaves.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n')
print('PASSAGE SHOP LEAVES:', len(pieces), 'closed stocks;', derivatives)
