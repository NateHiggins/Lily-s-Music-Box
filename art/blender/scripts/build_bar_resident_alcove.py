"""Two joined oak lounge chairs on the retired arcade deck, at original scale.

No source-cell geometry, animation, collision or gameplay owner is rewritten.
This builder authors only the missing physical places and a small wall shelf.
"""
from pathlib import Path
import collections, hashlib, json, math, sys
import bpy, bmesh, numpy as np
from mathutils import Vector, Matrix

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0, str(ROOT/'art/blender/scripts'))
from fabrication_chart_batch import triangle_charts
from fabrication_normals import stock_corner_normals
from fabrication_grain import stock_grain_frame
from check_exported_tangents import validate as validate_export

PLAN = ROOT/'art/data/bar_resident_places/source_plan.json'
plan = json.loads(PLAN.read_text(encoding='utf8'))
catalog = json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf8'))['materials']
FINISHES = {'oak': 'wood_dark', 'cloth': 'velour', 'hardware': 'door_brass'}
TINTS = {'oak': [.30,.19,.12,1.], 'cloth': [.34,.075,.10,1.], 'hardware': [1.,1.,1.,1.]}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
stocks = bpy.data.collections.new('EditableClosedStocks'); bpy.context.scene.collection.children.link(stocks)
exports = bpy.data.collections.new('RuntimePartitions'); bpy.context.scene.collection.children.link(exports)
stocks.hide_render = True
pieces = collections.defaultdict(list); checks = []; contacts = []; materials = {}

def material(key):
    if key in materials: return materials[key]
    spec = catalog[FINISHES[key]]
    mat = bpy.data.materials.new(FINISHES[key]); mat.use_nodes = True
    nodes = mat.node_tree.nodes; links = mat.node_tree.links; bsdf = nodes['Principled BSDF']
    bsdf.inputs['Metallic'].default_value = float(spec['metallic'])
    coord = nodes.new('ShaderNodeTexCoord'); scale = nodes.new('ShaderNodeVectorMath'); scale.operation = 'SCALE'
    scale.inputs[3].default_value = 1/float(spec['meters_per_tile']); links.new(coord.outputs['UV'], scale.inputs[0])
    for index, channel in enumerate(['Base Color', 'Roughness', 'Normal']):
        image = bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]))
        if index: image.colorspace_settings.name = 'Non-Color'
        tex = nodes.new('ShaderNodeTexImage'); tex.image = image; links.new(scale.outputs[0], tex.inputs['Vector'])
        if index == 2:
            normal = nodes.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value = .35
            links.new(tex.outputs['Color'], normal.inputs['Color']); links.new(normal.outputs[0], bsdf.inputs[channel])
        elif index == 0:
            tint=nodes.new('ShaderNodeMixRGB'); tint.blend_type='MULTIPLY'; tint.inputs[0].default_value=1.; tint.inputs[2].default_value=TINTS[key]
            links.new(tex.outputs['Color'],tint.inputs[1]); links.new(tint.outputs[0],bsdf.inputs[channel])
        else: links.new(tex.outputs['Color'], bsdf.inputs[channel])
    materials[key] = mat; return mat

def solid(name, vertices, faces, key='oak', bevel=0):
    mesh = bpy.data.meshes.new(name); mesh.from_pydata(vertices, [], faces); mesh.update()
    obj = bpy.data.objects.new(name, mesh); stocks.objects.link(obj); mesh.materials.append(material(key))
    bpy.context.view_layer.objects.active = obj
    if bevel:
        mod = obj.modifiers.new('Worked arris', 'BEVEL'); mod.width = bevel; mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new(); bm.from_mesh(mesh); bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if bm.calc_volume(signed=True) < 0: bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True) > 1e-12, name
    checks.append({'name': name, 'volume_m3': bm.calc_volume(signed=True)})
    bm.to_mesh(mesh); bm.free(); pieces[(assembly, key)].append(obj)
    return obj

def box(name, low, high, key='oak', bevel=.002):
    return solid(name, [(x,y,z) for z in [low[2],high[2]] for y in [low[1],high[1]] for x in [low[0],high[0]]],
                 [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)], key, bevel)

def rod(name, a, b, radius, key='hardware', n=12):
    a,b = Vector(a),Vector(b); axis=(b-a).normalized()
    u=axis.cross(Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0))).normalized(); v=axis.cross(u)
    vertices=[p+radius*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)) for p in [a,b] for i in range(n)]
    return solid(name, vertices, [tuple(reversed(range(n)))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]+[tuple(range(n,2*n))],key)

frames = {}
for row in plan['alcove']:
    assembly = row['id']; frames[assembly] = (Vector(row['at']), Matrix.Rotation(math.radians(row['yaw']), 3, 'Z'))
    # Four continuous posts; rails terminate against the post faces. Rear
    # uprights carry the back frame rather than intersecting a floating panel.
    for x in [-.26,.22]:
        for y in [-.26,.22]:
            height = 1.02 if y < 0 else .43
            box('Post', (x,y,0), (x+.04,y+.04,height), bevel=.002)
            contacts.append({'assembly':assembly,'foot_local':[x+.02,y+.02,0], 'support':'retail_bar_deck_s'})
        for z in [.18,.375]: box('SideRail',(x,-.22,z),(x+.04,.22,z+.035))
    for y in [-.26,.22]: box('SeatCrossRail',(-.22,y,.375),(.22,y+.04,.43))
    box('SeatBearing',(-.22,-.22,.407),(.22,.22,.43),bevel=.001)
    box('UpholsteredSeat',(-.265,-.265,.43),(.265,.265,.49),'cloth',.012)
    box('BackLowerRail',(-.22,-.26,.53),(.22,-.22,.58))
    box('BackCrestRail',(-.22,-.26,.965),(.22,-.22,1.02),bevel=.005)
    for x in [-.145,0,.145]: box('BackSpindle',(x-.012,-.25,.58),(x+.012,-.23,.965),bevel=.001)
    # Distinct removable back pad with its own solid edge, carried by slats.
    box('BackPad',(-.215,-.229,.59),(.215,-.184,.94),'cloth',.009)
    for x in [-.24,.24]:
        for z in [.395,.99]: rod('PegCap',(x,-.263,z),(x,-.26,z),.006)
    # Diagonal corner blocks are enclosed within the seat frame.
    for x in [-1,1]:
        for y in [-1,1]:
            a=Vector((x*.219,y*.219,.37)); b=Vector((x*.17,y*.17,.37))
            rod('CornerBrace',a,b,.018,'oak',8)

assembly = 'ResidentAlcoveShelf'; frames[assembly] = (Vector((3.88,-36.1,-2.62)), Matrix.Identity(3))
box('WallLedge',(-.08,-.94,.79),(.08,.94,.82),bevel=.003)
for y in [-.65,.65]:
    box('BracketWallPlate',(.105,y-.02,.57),(.12,y+.02,.795),'hardware',.001)
    box('BracketArm',(-.035,y-.018,.767),(.105,y+.018,.789),'hardware',.001)
    rod('BracketDiagonal',(.10,y,.59),(-.035,y,.767),.008)
    for z in [.60,.75]: rod('WallFastener',(.102,y,z),(.106,y,z),.005)

parts=[]
for (assembly,key), objects in pieces.items():
    vertices=[]; faces=[]; grain_frames=[]
    for obj in objects:
        points=[v.co[:] for v in obj.data.vertices]; offset=len(vertices); vertices.extend(points)
        grain=stock_grain_frame(points,catalog[FINISHES[key]]['files'][0]) if key=='oak' else None
        grain_frames.extend([grain]*len(points))
        faces.extend(tuple(offset+i for i in f.vertices) for f in obj.data.polygons)
    mesh=bpy.data.meshes.new(assembly+'__'+key); mesh.from_pydata(vertices,[],faces); mesh.update(); mesh.materials.append(materials[key])
    bm=bmesh.new(); bm.from_mesh(mesh); bmesh.ops.triangulate(bm,faces=list(bm.faces)); bm.to_mesh(mesh); bm.free()
    coords=np.array([v.co[:] for v in mesh.vertices]); idx=np.array([l.vertex_index for l in mesh.loops]).reshape((-1,3))
    frames_for_faces=[grain_frames[i] for i in idx[:,0]]
    rotations=np.stack([f[0] if f is not None else np.eye(3) for f in frames_for_faces]); grain=np.array([f is not None and f[1]==0 for f in frames_for_faces])
    ns,us,charts,_=triangle_charts(coords[idx],np.zeros(3),1.,rotations,grain)
    uv=mesh.uv_layers.new(name='Metres'); uv.data.foreach_set('uv',charts.astype(np.float32).ravel())
    guide=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER')
    g=np.repeat(us[:,[0,2,1]],3,axis=0); g[:,2]*=-1; guide.data.foreach_set('vector',g.astype(np.float32).ravel())
    mesh.normals_split_custom_set(stock_corner_normals(mesh))
    obj=bpy.data.objects.new(mesh.name,mesh); exports.objects.link(obj); obj.location=frames[assembly][0]; obj.rotation_euler=frames[assembly][1].to_euler()
    parts.append({'name':obj.name,'assembly':assembly,'catalog_key':FINISHES[key],'tint':TINTS[key],'tile':catalog[FINISHES[key]]['meters_per_tile'],'triangles':len(mesh.polygons)})

class ExportUVHandedness:
    def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for primitive in mesh.primitives:
            def values(key):return np.frombuffer(primitive.attributes[key].buffer_view.data,dtype='<f4').reshape((-1,3)).astype(float)
            n=values('NORMAL'); n/=np.linalg.norm(n,axis=1)[:,None]; g=values('_TANGENT_GUIDE'); t=g-n*np.sum(g*n,axis=1)[:,None]; t/=np.linalg.norm(t,axis=1)[:,None]
            primitive.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((t,-np.ones(len(t)))).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
            del primitive.attributes['_TANGENT_GUIDE']
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
for image in bpy.data.images:
    if image.source=='FILE': image.filepath=bpy.path.relpath(image.filepath,start=str(ROOT/'art/blender'))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/bar_resident_alcove.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in exports.objects: obj.select_set(True)
asset=ROOT/'game/assets/props/bar_resident_alcove.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='PLACEHOLDER')
exported=validate_export(asset)
runtime={'schema_version':1,'asset':'res://assets/props/bar_resident_alcove.glb','parts':parts,'places':plan['places'],'alcove':plan['alcove']}
(ROOT/'game/data/orison_v2/bar_resident_places.json').write_bytes((json.dumps(runtime,indent=2)+'\n').encode('utf8'))
report={'evidence_class':'INERT','scope':'Native construction and exported attributes; contact/render/runtime checks remain separate.','stocks':checks,'floor_contacts':contacts,'exported':exported,'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest()}
dependencies=[PLAN,Path(__file__),ROOT/'game/data/runtime_material_sets.json']
dependencies.extend(ROOT/'art/blender/scripts'/name for name in ['fabrication_chart_batch.py','fabrication_uvs.py','fabrication_normals.py','fabrication_grain.py','check_exported_tangents.py'])
dependencies.extend(ROOT/'game/assets/building/textures'/name for key in FINISHES.values() for name in catalog[key]['files'])
def source_digest(path):
    raw=path.read_bytes()
    return hashlib.sha256(raw.replace(b'\r\n',b'\n') if path.suffix in ['.py','.json'] else raw).hexdigest()
report['source_bindings']={path.relative_to(ROOT).as_posix():source_digest(path) for path in dependencies}
report['frames']={key:{'at':list(value[0]),'yaw':math.degrees(value[1].to_euler().z)} for key,value in frames.items()}
report['shelf_wall_contacts']=[{'assembly':'ResidentAlcoveShelf','point':[.12,y,z],'support_normal':[-1,0,0]} for y in [-.65,.65] for z in [.63,.72]]
(ROOT/'game/tests/fixtures/v2_bar_resident_alcove.json').write_bytes((json.dumps(report,indent=2)+'\n').encode('utf8'))
(ROOT/'art/blender/bar_resident_alcove_construction.json').write_bytes((json.dumps(report,indent=2)+'\n').encode('utf8'))
print('BAR RESIDENT ALCOVE:',len(checks),'closed stocks;',len(parts),'material partitions;',exported)
