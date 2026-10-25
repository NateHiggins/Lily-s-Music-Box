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
layout = json.loads((ROOT/'game/data/building_layout.json').read_text(encoding='utf8'))
owners = [m for f in layout['floors'] for m in f.get('markers',[])
          if m.get('kind')=='door' and m.get('zone')=='PASSAGE']
assert len(owners)==11 and all(m['w']==width and m['h']==height and m['subtype']=='storefront' for m in owners)
recipes = json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf8'))['materials']
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

def emit(name, bm, key, horizontal=False, smooth=False):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), name
    assert bm.calc_volume(signed=True) > 0, name
    # Preserve exact meeting datums. Tiny eased edges stay within original stock.
    if not smooth:
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges if e.calc_face_angle(0) > .6],
                        offset=.0003, segments=2, affect='EDGES')
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), name
    volume = bm.calc_volume(signed=True)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.normal_update()
    vertices, faces, charts, normals = [], [], [], []
    for face in bm.faces:
        p = np.array([v.co[:] for v in face.verts])
        if np.linalg.norm(np.cross(p[1]-p[0], p[2]-p[0])) < 1e-14: continue
        order = [2, 1, 0] if horizontal else [0, 1, 2]
        tile = recipes[key]['meters_per_tile']
        _, _, uv, _ = chart_for_triangle(p[:, order], np.zeros(3), tile)
        start = len(vertices); vertices.extend(p.tolist())
        faces.append((start, start+1, start+2)); charts.extend(uv)
        normals.extend([v.normal[:] for v in face.verts])
    bm.free()
    mesh = bpy.data.meshes.new(name); mesh.from_pydata(vertices, [], faces); mesh.update()
    uv = mesh.uv_layers.new(name='MetreStock')
    for loop, value in zip(uv.data, charts): loop.uv = value
    if smooth:
        for polygon in mesh.polygons: polygon.use_smooth = True
        mesh.normals_split_custom_set(normals)
    obj = bpy.data.objects.new(name, mesh); bpy.context.scene.collection.objects.link(obj)
    obj['material_key'] = key
    pieces.append({'name':name, 'key':key, 'volume_m3':volume, 'triangles':len(faces),
                   'low':[min(v[i] for v in vertices) for i in range(3)],
                   'high':[max(v[i] for v in vertices) for i in range(3)]})

for i, x in enumerate([0, width-.13]):
    box('Stile'+str(i), (x, -.022, bottom), (x+.13, .022, height-.01), 'door_oak')
for i, (lo, hi) in enumerate([(bottom,.13),(.715,.845),(height-.13,height-.01)]):
    box('Rail'+str(i), (.13,-.022,lo), (width-.13,.022,hi), 'door_oak', True)
# A retained solid collision must not be dressed as an empty lower aperture.
box('LowerPanel', (.125,-.018,.12), (width-.125,.018,.725), 'door_oak')
# Ten millimetres of glazing sits behind each rail; the old upper glass gap is closed.
box('Glazing', (.115,-.006,.835), (width-.115,.006,height-.12), 'glass_drawn_expressive')
# Cast bow pull with a beaded, lobed escutcheon. The two return ends bear on
# the plate; opposed through-fixings enter solid timber. Original period
# interpretation, informed by Sargent's 1925 Colonial hardware catalogue.
def swept_stock(name, centres, radii, side, ring_segments=16):
    verts, faces = [], []
    for j, centre in enumerate(centres):
        tangent = Vector(centres[min(j+1,len(centres)-1)])-Vector(centres[max(j-1,0)])
        tangent.normalize(); across=Vector((1,0,0)); other=tangent.cross(across).normalized()
        for k in range(ring_segments):
            a=2*math.pi*k/ring_segments
            verts.append(Vector(centre)+radii[j]*(math.cos(a)*across+math.sin(a)*other))
    for j in range(len(centres)-1):
        for k in range(ring_segments):
            a=j*ring_segments+k;b=j*ring_segments+(k+1)%ring_segments
            faces.append((a,b,b+ring_segments,a+ring_segments))
    faces.extend([tuple(reversed(range(ring_segments))),tuple(range(len(verts)-ring_segments,len(verts)))])
    bm=bmesh.new();vs=[bm.verts.new(p) for p in verts]
    for face in faces:bm.faces.new([vs[k] for k in face])
    emit(name,bm,'door_brass',smooth=True)

for side in [-1,1]:
    prefix='Pull'+str(side)
    x=width-.065
    # Closed extrusion: narrow waist, rounded end lobes, no plate/glass overlap.
    outline=[]
    for k in range(48):
        a=2*math.pi*k/48
        z=.221*math.cos(a)
        half_width=.020+.008*math.exp(-((abs(z)-.177)/.037)**2)
        outline.append((x+half_width*math.sin(a),1.03+z))
    bm=bmesh.new();rings=[]
    for depth in [.022,.027]:rings.append([bm.verts.new((px,side*depth,pz)) for px,pz in outline])
    bm.faces.new(rings[0]);bm.faces.new(list(reversed(rings[1])))
    for k in range(48):bm.faces.new((rings[0][k],rings[1][k],rings[1][(k+1)%48],rings[0][(k+1)%48]))
    emit(prefix+'_Escutcheon',bm,'door_brass')
    # Fine cast bead follows the outline, seated into the plate rather than floating.
    centres=[(x+(px-x)*.90,side*.028,1.03+(pz-1.03)*.97) for px,pz in outline]
    centres.append(centres[0])
    # A closed tube path doesn't need coincident capped rings: use a poly curve
    # converted to native mesh and retain its watertight round section.
    curve=bpy.data.curves.new(prefix+'_Bead','CURVE');curve.dimensions='3D'
    curve.bevel_depth=.001;curve.bevel_resolution=1;curve.resolution_u=1
    spline=curve.splines.new('POLY');spline.points.add(len(centres)-2)
    for point,co in zip(spline.points,centres[:-1]):point.co=(*co,1)
    spline.use_cyclic_u=True
    obj=bpy.data.objects.new(prefix+'_Bead',curve);bpy.context.collection.objects.link(obj)
    deps=bpy.context.evaluated_depsgraph_get();mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(deps))
    bm=bmesh.new();bm.from_mesh(mesh);bpy.data.objects.remove(obj,do_unlink=True);bpy.data.meshes.remove(mesh)
    emit(prefix+'_Bead',bm,'door_brass',smooth=True)
    centres=[];radii=[]
    for j in range(25):
        t=j/24
        centres.append((x,side*(.030+.063*math.sin(math.pi*t)**.65),.872+.316*t))
        radii.append(.009+.004*math.sin(math.pi*t)**2+.003*math.exp(-((t-.15)/.055)**2)+.003*math.exp(-((t-.85)/.055)**2))
    swept_stock(prefix+'_Bow',centres,radii,side)
    # Four slotted screw heads: slot is actual absent head stock over a solid stem.
    for i,z in enumerate([.832,1.228]):
        cylinder(prefix+'_ScrewStem'+str(i),(x,side*.028,z),.0035,.004,'door_brass',True)
        for half in [-1,1]:
            bm=bmesh.new();radius=.0038;lo=.00055
            arc=[(radius*math.cos(a),radius*math.sin(a)) for a in np.linspace(math.asin(lo/radius),math.pi-math.asin(lo/radius),12)]
            rings=[]
            for depth in [.029,.031]:rings.append([bm.verts.new((x+px,side*depth,z+half*pz)) for px,pz in arc])
            bm.faces.new(rings[0]);bm.faces.new(list(reversed(rings[1])))
            for k in range(len(arc)):bm.faces.new((rings[0][k],rings[1][k],rings[1][(k+1)%len(arc)],rings[0][(k+1)%len(arc)]))
            emit(prefix+'_Screw'+str(i)+'_'+str(half),bm,'door_brass')

asset = ROOT/'game/assets/props/passage_shop_leaves.glb'
native = ROOT/'art/blender/passage_shop_leaves.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native), compress=True)
# Keep editable castings/fixings separate in the native file, but submit only
# one brass draw and one targeting/collision bound per side in the game.
for side in [-1,1]:
    bpy.ops.object.select_all(action='DESELECT')
    stocks=[o for o in bpy.context.scene.objects if o.name.startswith('Pull'+str(side)+'_')]
    for obj in stocks:obj.select_set(True)
    bpy.context.view_layer.objects.active=stocks[0];bpy.ops.object.join()
    bpy.context.object.name='Pull'+str(side)
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
data['owners'] = [m['id'] for m in owners]
data['source_bindings'] = {}
for relative in ['art/blender/passage_shop_leaves.blend',
                 'art/blender/scripts/build_passage_shop_leaves.py',
                 'art/blender/scripts/fabrication_uvs.py',
                 'art/blender/scripts/check_exported_tangents.py',
                 'art/blender/scripts/build_media_battery_supply.py',
                 'game/data/building_layout.json', 'game/data/runtime_material_sets.json']:
    raw=(ROOT/relative).read_bytes()
    if not relative.endswith('.blend'):raw=raw.replace(b'\r\n',b'\n')
    data['source_bindings'][relative]=hashlib.sha256(raw).hexdigest()
(ROOT/'game/tests/fixtures/passage_shop_leaves.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n')
print('PASSAGE SHOP LEAVES:', len(pieces), 'closed stocks;', derivatives)
