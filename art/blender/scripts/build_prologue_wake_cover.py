"""Temporary opaque sleeper cover for the installed 4B bed, not a bed replacement.

Blender --background --python-exit-code 1 --python this_file.py
Native/reference review and GLB go outside the game until imported review.
"""
from pathlib import Path
import hashlib, json, math, os, sys
import bpy, bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(os.environ.get('PROLOGUE_COVER_OUT', 'C:/ov/reports/prologue_20261028/wake_cover'))
OUT.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(Path(__file__).parent))
from metric_gltf_export import CatalogueMetricUV
from check_exported_tangents import validate
from fabrication_uvs import chart_for_triangle

source = ROOT / 'art/blender/bedding.blend'
source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source))
scene = bpy.context.scene
bed = bpy.data.objects['Bed_135_260_thrown']
retained = {bed, *bed.children_recursive}
for obj in list(bpy.data.objects):
    if obj not in retained:
        bpy.data.objects.remove(obj, do_unlink=True)
for obj in retained:
    obj.hide_render = False
    obj.hide_set(False)
    # Only the existing thrown counterpane is replaced during this shot.
    if obj.name.startswith(('DrapedBlanket', 'Turnback')):
        obj.hide_render = True

catalog = json.loads((ROOT / 'game/data/runtime_material_sets.json').read_text())['materials']['linen']
material = bpy.data.materials.new('linen')
material.use_nodes = True
nodes, links = material.node_tree.nodes, material.node_tree.links
bsdf = nodes.get('Principled BSDF')
bsdf.inputs['Metallic'].default_value = catalog['metallic']
uv = nodes.new('ShaderNodeTexCoord')
scale = nodes.new('ShaderNodeVectorMath'); scale.operation = 'SCALE'
scale.inputs['Scale'].default_value = 1 / catalog['meters_per_tile']
links.new(uv.outputs['UV'], scale.inputs[0])
for index, filename in enumerate(catalog['files']):
    texture = nodes.new('ShaderNodeTexImage')
    texture.image = bpy.data.images.load(str(ROOT / 'game/assets/building/textures' / filename), check_existing=True)
    if index:
        texture.image.colorspace_settings.name = 'Non-Color'
    links.new(scale.outputs['Vector'], texture.inputs['Vector'])
    if index == 0:
        links.new(texture.outputs['Color'], bsdf.inputs['Base Color'])
    elif index == 1:
        links.new(texture.outputs['Color'], bsdf.inputs['Roughness'])
    else:
        normal = nodes.new('ShaderNodeNormalMap')
        links.new(texture.outputs['Color'], normal.inputs['Color'])
        links.new(normal.outputs['Normal'], bsdf.inputs['Normal'])

# Native Blender axes: head at -Y, mattress top at Z=.680. glTF conversion
# supplies Godot +Y once; no extra .18 bed lift or external presentation scale.
NX, NY = 40, 72
vertices, faces = [], []
def bump(x, y, cx, cy, sx, sy):
    return math.exp(-((x-cx)/sx)**2 - ((y-cy)/sy)**2)

for j in range(NY + 1):
    y = -1.12 + 2.36*j/NY
    for i in range(NX + 1):
        x = -.75 + 1.5*i/NX
        edge = max(0., (abs(x)-.60)/.15)
        # Broad anonymous mass, including a completely covered head; no skin,
        # anatomical inserts or exposed identity under the brightest flash.
        mass = (.145*bump(x,y,-.05,-.83,.20,.21)
                + .245*bump(x,y,.015,-.30,.29,.44)
                + .175*bump(x,y,-.055,.28,.27,.42)
                + .09*bump(x,y,.035,.76,.22,.30))
        fold = .007*(math.sin(17*x+3*y)**2)*math.exp(-((abs(x)-.32)/.28)**2)
        fold *= math.sin(math.pi*j/NY)**2
        z = .692 + mass + fold - .135*edge**1.3
        vertices.append((x, y, z))
for j in range(NY):
    for i in range(NX):
        k = j*(NX+1)+i
        faces.append((k, k+1, k+NX+2, k+NX+1))
mesh = bpy.data.meshes.new('ContinuousOpaqueCounterpane')
mesh.from_pydata(vertices, [], faces); mesh.update()
cover = bpy.data.objects.new('PrologueWakeCover', mesh)
bpy.context.collection.objects.link(cover)
mesh.materials.append(material)
for face in mesh.polygons:
    face.use_smooth = True
uvs = mesh.uv_layers.new(name='UVMap')
for face in mesh.polygons:
    for loop_index in face.loop_indices:
        co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
        uvs.data[loop_index].uv = (co.x+.75, co.y+1.12)
bpy.context.view_layer.objects.active = cover
solid = cover.modifiers.new('Continuous sewn cloth thickness', 'SOLIDIFY')
solid.thickness = .003; solid.offset = -1
bpy.ops.object.modifier_apply(modifier=solid.name)
mesh = cover.data
bm = bmesh.new(); bm.from_mesh(mesh)
bmesh.ops.triangulate(bm, faces=list(bm.faces))
bm.to_mesh(mesh); bm.free(); mesh.update()
# Solidify inherits coincident UVs on the narrow sewn rim. Give those triangles
# actual thickness charts before export; do not waive collapsed UV/tangents.
for face in mesh.polygons:
    loops = list(face.loop_indices)
    a,b,c = [mesh.uv_layers.active.data[k].uv.copy() for k in loops]
    det = (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)
    if abs(det) <= 1e-12:
        points = [tuple(mesh.vertices[mesh.loops[k].vertex_index].co) for k in loops]
        _,_,values,_ = chart_for_triangle(points,(0,0,0),.6)
        for index,k in enumerate(loops):mesh.uv_layers.active.data[k].uv = values[index]
        face.use_smooth = False
# Shape keys move the opaque outside and inside together. Border attachment
# weights taper to zero; there is no cloth solver or hidden simulated body.
cover.shape_key_add(name='Basis')
for name in ['Breath', 'Recoil']:
    key = cover.shape_key_add(name=name)
    for point in key.data:
        x, y, z = point.co
        envelope = bump(x,y,0,-.25,.32,.59)
        if name == 'Breath':
            point.co.z += .012*envelope
        else:
            point.co.x -= .035*envelope
            point.co.z += .030*envelope
cover['material_key'] = 'linen'
cover['scope'] = 'temporary prologue presentation; no collision, save or anatomy authority'
cover['bed_owner'] = '4B_wake_bed'
cover['mattress_top_m'] = .680
cover['bedding_source_sha256'] = source_hash

# Check sampled envelope and positive thickness. Keep the existing mattress,
# frame, pillows and all other bed variants untouched in their source file.
samples = []
for breath, recoil in [(0,0), (1,0), (0,1), (1,1), (.5,.5)]:
    cover.data.shape_keys.key_blocks['Breath'].value = breath
    cover.data.shape_keys.key_blocks['Recoil'].value = recoil
    deps = bpy.context.evaluated_depsgraph_get()
    evaluated = cover.evaluated_get(deps).to_mesh()
    lowest = min(v.co.z for v in evaluated.vertices if abs(v.co.x)<.59)
    assert lowest >= .680, (breath,recoil,lowest)
    samples.append({'breath':breath,'recoil':recoil,'interior_min_z':lowest})
    cover.evaluated_get(deps).to_mesh_clear()
for key in cover.data.shape_keys.key_blocks:
    key.value = 0

# Preserve the metre chart through the shared glTF exporter.
attribute = mesh.attributes.new('_metre_uv', 'FLOAT_VECTOR', 'CORNER')
for loop in mesh.loops:
    value = mesh.uv_layers.active.data[loop.index].uv
    attribute.data[loop.index].vector = (value.x, value.y, 0)
# Preserve each incident chart's derivative through exporter deduplication.
# The shared hook removes this guide after constructing finite tangents; it
# does not change the smooth normals, UV phase, topology or triangle count.
guide = mesh.attributes.new('_tangent_guide', 'FLOAT_VECTOR', 'CORNER')
for face in mesh.polygons:
    loops = list(face.loop_indices)
    a,b,c = [mesh.vertices[mesh.loops[k].vertex_index].co for k in loops]
    u,v,w = [mesh.uv_layers.active.data[k].uv for k in loops]
    first,second = v-u,w-u
    tangent = ((b-a)*second.y-(c-a)*first.y)/(first.x*second.y-first.y*second.x)
    for k in loops:guide.data[k].vector = tangent.normalized()
bpy.ops.object.select_all(action='DESELECT'); cover.select_set(True)
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension = CatalogueMetricUV
asset = OUT / 'prologue_wake_cover.glb'
bpy.ops.export_scene.gltf(filepath=str(asset), export_format='GLB', use_selection=True,
    export_yup=True, export_tangents=True, export_attributes=True, export_extras=True,
    export_materials='EXPORT', export_animations=False, export_morph=True, export_morph_normal=True)
export_report = validate(asset)

scene.render.engine = 'CYCLES'; scene.cycles.device = 'CPU'; scene.cycles.samples = 20
scene.render.resolution_x = 1280; scene.render.resolution_y = 900; scene.render.resolution_percentage = 100
scene.world.color = (.05,.05,.05)
camera_data = bpy.data.cameras.new('NativeReviewCamera')
camera = bpy.data.objects.new('NativeReviewCamera',camera_data); bpy.context.collection.objects.link(camera)
camera.location = (2.45,2.45,2.4)
camera.rotation_euler = (Vector((0,0,.65))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.lens = 45; scene.camera = camera
light_data = bpy.data.lights.new('ReviewSoftbox','AREA'); light_data.energy = 220; light_data.size = 3
light = bpy.data.objects.new('ReviewSoftbox',light_data); bpy.context.collection.objects.link(light)
light.location = (1,-1,3.5); light.rotation_euler = (Vector((0,0,.6))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'art/blender/prologue_wake_cover.blend'))
for name, recoil in [('rest',0),('recoil',1)]:
    cover.data.shape_keys.key_blocks['Recoil'].value = recoil
    scene.render.filepath = str(OUT / (name+'.png'))
    bpy.ops.render.render(write_still=True)
assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash
report = {'evidence_class':'INERT','source_bedding_sha256':source_hash,
    'builder_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),
    'native_samples':samples,'export':export_report,'failures':[],
    'limits':'CPU/native construction only; not imported, runtime optical, collision or prologue acceptance.'}
(OUT/'construction.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('WAKE_COVER_NATIVE',json.dumps(report),flush=True)
