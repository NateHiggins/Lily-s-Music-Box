"""Refit the existing native companion with a retracting keyboard hinge carriage.

Run after the formed-shell publisher. Existing editable stock and export charts
are retained; only the hinge's fixed half is transferred onto the new carriage.
"""
from pathlib import Path
import collections, hashlib, json, math, sys
import bpy, bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_native_batch import partition, export

native = ROOT / 'art/blender/service_companion_v2.blend'
bpy.ops.wm.open_mainfile(filepath=str(native))
bpy.context.preferences.filepaths.save_version = 0
assert 'CompanionKeyboardCarriage' not in bpy.data.objects, 'Refit already applied'
exports = bpy.data.collections['ServiceRadiophoneV2']
stocks = bpy.data.collections['EditableIndividualStock']
data_path = ROOT / 'game/data/device/service_companion_v2.json'
data = json.loads(data_path.read_text())
catalog = json.loads((ROOT / 'game/data/runtime_material_sets.json').read_text())['materials']
carriage = bpy.data.objects.new('CompanionKeyboardCarriage', None)
exports.objects.link(carriage)
groups = collections.defaultdict(list)

def coords(p): return Vector((p[0], -p[2], p[1]))

def stock_box(name, center, size, surface):
    low = Vector(center) - Vector(size) / 2
    high = Vector(center) + Vector(size) / 2
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([coords((x,y,z)) for z in [low.z,high.z] for y in [low.y,high.y] for x in [low.x,high.x]], [],
                    [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)])
    mesh.update()
    obj = bpy.data.objects.new('Stock__'+name, mesh)
    stocks.objects.link(obj)
    obj.data.materials.append(bpy.data.materials[surface])
    groups[surface].append(obj)
    return obj

# The rail bearers remain bolted to the chassis. Their pin, stop shoulders and
# alternating fixed knuckles now ride together, rather than separating as the
# keyboard slides. Copy the original stock, including its physical bores.
names = ['Stock__Continuous hinge pin', 'Stock__Open angle stop', 'Stock__Open angle stop.001']
for prefix in ['Interleaved hinge knuckle', 'Hinge leaf']:
    names += ['Stock__'+prefix+('' if i == 0 else '.%03d' % i) for i in range(0,9,2)]
for name in names:
    obj = bpy.data.objects[name]
    groups[obj.data.materials[0].name].append(obj)

# Remove those exact stock vertices from the old material batches. This edits
# the Blender mesh, preserving all untouched UV/tangent corner attributes.
removed = {}
for surface, objects in groups.items():
    draw = bpy.data.objects['CompanionFixed__'+surface]
    wanted = {tuple(round(v,7) for v in point.co) for obj in objects for point in obj.data.vertices}
    bm = bmesh.new(); bm.from_mesh(draw.data)
    vertices = [v for v in bm.verts if tuple(round(x,7) for x in v.co) in wanted]
    assert len(vertices) == sum(len(obj.data.vertices) for obj in objects), (surface,len(vertices))
    removed[surface] = len(vertices)
    bmesh.ops.delete(bm, geom=vertices, context='VERTS')
    bm.to_mesh(draw.data); bm.free(); draw.data.update()

# Move the rail inner faces outside the end knuckles' swept width. The old
# broad bearers were acceptable fixed seats but would intersect a sliding pin.
fixed_steel = bpy.data.objects['CompanionFixed__CompanionSteel'].data
for name in ['Stock__Hinge bearer', 'Stock__Hinge bearer.001']:
    source = bpy.data.objects[name]
    side = -1 if source.data.vertices[0].co.x < 0 else 1
    remap = {}
    for vertex in source.data.vertices:
        old = vertex.co.copy()
        vertex.co.x = side*.098 + (old.x-side*.094)*.6
        remap[tuple(round(x,7) for x in old)] = vertex.co.copy()
    changed = 0
    for vertex in fixed_steel.vertices:
        key = tuple(round(x,7) for x in vertex.co)
        if key in remap: vertex.co = remap[key]; changed += 1
    assert changed == 8
fixed_steel.update()
# Resizing a rail changes its metric UV derivatives. Rechart this native
# material batch with the established metre/tangent recipe before exporting.
fixed_draw = bpy.data.objects['CompanionFixed__CompanionSteel']
refit = partition(exports,'RefittedFixedSteel',[fixed_draw],data['finishes']['CompanionSteel'],
                  bpy.data.materials['CompanionSteel'],Matrix.Identity(4),catalog)
fixed_draw.data = refit.data
bpy.data.objects.remove(refit,do_unlink=True)

for x in [-.098,.098]:
    # Two cheeks embrace the original 10-mm bearer. The top/bottom flanges
    # overlap it vertically but leave a 0.3-mm running clearance on its faces.
    for side in [-1,1]:
        stock_box('Carriage guide cheek', (x+side*.0047,-.1065,.098), (.0028,.014,.030), 'CompanionBrass')
    stock_box('Carriage bridge', (x,-.1113,.098), (.012,.002,.030), 'CompanionSteel')
    stock_box('Carriage hinge saddle', (x,-.10135,.109), (.012,.0027,.010), 'CompanionSteel')

for surface, objects in groups.items():
    finish = data['finishes'][surface]
    draw = partition(exports,'KeyboardCarriage__'+surface,objects,finish,bpy.data.materials[surface],Matrix.Identity(4),catalog)
    draw.parent = carriage

# Export a closed, latched source. Runtime opens first, then draws the carriage
# 45 mm aft; the established paired folding stays solve their actual endpoints.
proof = export(ROOT,'service_companion_v2',exports,material_names_only=True,staged_output=True)
proof['asset'] = 'res://assets/props/service_companion_v2.glb'
data['asset_sha256'] = hashlib.sha256((ROOT/'game/assets/props/service_companion_v2.glb').read_bytes()).hexdigest()
data['keyboard_retraction_m'] = .045
data_path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
construction_path = ROOT/'art/blender/service_companion_v2_construction.json'
construction = json.loads(construction_path.read_text())
construction['keyboard_carriage'] = dict(travel_m=.045, fixed_stock_vertices_transferred=removed, export=proof,
    sequence='Unlatch, rotate clear, retract along paired chassis bearers; reverse before closing')
construction_path.write_text(json.dumps(construction,indent=2)+'\n',encoding='utf-8',newline='\n')

# A separate native geometry review; never export review camera or lights.
keyboard = bpy.data.objects['CompanionKeyboard']
keyboard.rotation_euler.x = math.pi/2
keyboard.location.y += .045
carriage.location.y = .045
for x,label in [(-.094,'Port'),(.094,'Starboard')]:
    start = coords((x,-.084,.042))
    end = keyboard.matrix_world @ coords((x,.016,-.006))
    difference=end-start
    elbow=(start+end)*.5 + Vector((0,-difference.z,difference.y)).normalized()*math.sqrt(.05**2-difference.length_squared*.25)
    for suffix,a,b in [('Upper',start,elbow),('Lower',elbow,end)]:
        link=bpy.data.objects[label+'KeyboardStay'+suffix]
        link.location=a;link.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
scene = bpy.context.scene
scene.render.engine = 'CYCLES'; scene.cycles.samples = 24
scene.render.resolution_x = 1100; scene.render.resolution_y = 1000; scene.render.resolution_percentage = 100
for obj in bpy.data.objects:
    obj.hide_render = obj.name not in exports.objects
camera_data = bpy.data.cameras.new('CarriageReviewCamera')
camera = bpy.data.objects.new('CarriageReviewCamera',camera_data); scene.collection.objects.link(camera)
camera.location = (.38,-.65,.30)
camera.rotation_euler = (Vector((0,-.025,-.02))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type = 'ORTHO'; camera_data.ortho_scale = .58; scene.camera = camera
for position,energy,size in [((.3,-.6,.6),65,.55),((-.3,-.2,.3),35,.4)]:
    light_data=bpy.data.lights.new('CarriageReviewSoftbox','AREA'); light_data.energy=energy; light_data.shape='DISK'; light_data.size=size
    light=bpy.data.objects.new('CarriageReviewSoftbox',light_data);scene.collection.objects.link(light);light.location=position
    light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
out=ROOT/'tmp/companion_carriage';out.mkdir(parents=True,exist_ok=True)
scene.render.filepath=str(out/'native_open.png');bpy.ops.render.render(write_still=True)
print('KEYBOARD CARRIAGE',json.dumps(construction['keyboard_carriage']))
