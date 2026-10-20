"""Native nozzle coupling candidate. Engineered dimensions, no standard claim.
The hose datum is fixed; a captured swivel nut drives a separate nozzle spigot.
Only writes below repository tmp. No canonical publication or runtime verdict.
"""
from pathlib import Path
import hashlib, json, math, os, sys, shutil
import bpy, bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(os.environ.get('ORISON_FIRE_NOZZLE_JOINT_OUT', str(
    ROOT/'tmp/v2-fire-hand-20261019/nozzle_joint_native1'))).resolve()
assert OUT.is_relative_to(ROOT/'tmp'), OUT
for folder in ['art/blender', 'game/assets/props']:
    (OUT/folder).mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_native_batch import material, partition, export
from check_exported_tangents import validate

if os.environ.get('ORISON_FIRE_NOZZLE_JOINT_PUBLISH')=='1':
    report=json.loads((OUT/'construction.json').read_text())
    for path,digest in report['source_bindings'].items():
        p=ROOT/path;raw=p.read_bytes()
        if p.suffix in ['.py','.json']:raw=raw.replace(b'\r\n',b'\n')
        assert hashlib.sha256(raw).hexdigest()==digest,path
    glb=OUT/'game/assets/props/fire_nozzle_joint.glb';blend=OUT/'art/blender/fire_nozzle_joint.blend'
    assert hashlib.sha256(glb.read_bytes()).hexdigest()==report['glb_sha256']
    assert hashlib.sha256(blend.read_bytes()).hexdigest()==report['blend_sha256'];validate(glb)
    bpy.ops.wm.open_mainfile(filepath=str(blend));bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_nozzle_joint.blend'))
    bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_nozzle_joint.blend'))
    report['candidate_blend_sha256']=report['blend_sha256']
    report['blend_sha256']=hashlib.sha256((ROOT/'art/blender/fire_nozzle_joint.blend').read_bytes()).hexdigest()
    shutil.copyfile(glb,ROOT/'game/assets/props/fire_nozzle_joint.glb')
    shutil.copyfile(OUT/'runtime_projection.json',ROOT/'game/data/orison_v2/fire_nozzle_joint.json')
    (ROOT/'art/blender/fire_nozzle_joint_construction.json').write_text(json.dumps(report,indent=2)+'\n')
    print('FIRE NOZZLE JOINT PUBLISH PASS');raise SystemExit(0)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
PITCH = .0028
ROOT_R, CREST, CLEAR, BORE = .0215, .0225, .00025, .012
SEAT, BASE, STROKE, SIDES = .017, .030, .012, 96
catalog = json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finish = dict(catalog_key='radiator_service_brass', tint=[.90,.82,.63,1.],
              pigment=1., normal=.15, roughness=.8, metallic=.92)
assert finish['catalog_key'] in catalog
mat = material(ROOT, 'brass', finish, catalog)
native = bpy.data.collections.new('Editable nozzle joint profiles')
bpy.context.scene.collection.children.link(native)
exports = bpy.data.collections.new('FireNozzleJoint')
bpy.context.scene.collection.children.link(exports)
objects, metrics = {}, {}

def phase(y, angle):
    value = ((y-SEAT)/PITCH-angle/math.tau) % 1.
    return max(0., min(1., (.42-abs(value-.5))/.30))

def male_r(y, angle):
    y += BASE
    fade = min(1., max(0., (y-SEAT)/(PITCH*.5)), max(0., (.0297-y)/(PITCH*.5)))
    return ROOT_R+(CREST-ROOT_R)*phase(y, angle)*fade

def female_r(y, angle):
    return ROOT_R+CLEAR+(CREST-ROOT_R)*max(phase(y, angle), max(0., (y-.028)/.001))

def stock(name, rings):
    vertices, faces = [], []
    for y, radius in rings:
        for index in range(SIDES):
            angle = math.tau*index/SIDES
            r = radius(y, angle) if callable(radius) else radius
            vertices.append((r*math.cos(angle), -r*math.sin(angle), y))
    for row in range(len(rings)):
        following = (row+1) % len(rings)
        for index in range(SIDES):
            j = (index+1) % SIDES
            faces.append((row*SIDES+index, following*SIDES+index,
                          following*SIDES+j, row*SIDES+j))
    mesh = bpy.data.meshes.new(name+'_EditableMesh')
    mesh.from_pydata(vertices, [], faces); mesh.update()
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bad = sum(not edge.is_manifold for edge in bm.edges)
    volume = bm.calc_volume(signed=True)
    assert bad == 0 and volume > 0, (name, bad, volume)
    bm.to_mesh(mesh); bm.free()
    source = bpy.data.objects.new(name+'_Editable', mesh); native.objects.link(source)
    objects[name] = source
    obj = partition(exports, name, [source], finish, mat, Matrix.Identity(4), catalog)
    metrics[name] = dict(nonmanifold_edges=bad, volume_m3=volume,
                         triangles=len(obj.data.polygons))
    return obj

seat = stock('HoseSeat', [(-.016,.023),(.005,.023),(.005,.020),
    (.014,.020),(.014,.021),(.017,.021),(.017,BORE),(0.,BORE),
    (0.,.02125),(-.016,.02125)])
steps = math.ceil((.029-.017)/PITCH*32)
def grip(radius):return lambda y,a: radius+.004*abs(math.cos(a))**12
nut = stock('NozzleNut', [(.005,grip(.0275)),(.0055,grip(.028)),(.0285,grip(.028)),(.029,grip(.0275))] +
    [(.029-(.029-.017)*i/steps, female_r) for i in range(steps+1)] +
    [(.014,ROOT_R+CLEAR),(.014,.02025),(.005,.02025)])
start, end = SEAT-BASE, .0297-BASE
steps = math.ceil((end-start)/PITCH*32)
spigot = stock('NozzleSpigot', [(start+(end-start)*i/steps,male_r)
    for i in range(steps+1)] + [(0.,.021),(0.,BORE),(start,BORE)])

def tree(name, frame=Matrix.Identity(4)):
    obj = objects[name] if isinstance(name, str) else name
    return BVHTree.FromPolygons([frame@v.co for v in obj.data.vertices],
                               [list(p.vertices) for p in obj.data.polygons])

def vertices(name, index, frame=Matrix.Identity(4)):
    obj = objects[name]
    return [frame@obj.data.vertices[i].co for i in obj.data.polygons[index].vertices]

def contact_only(left, right, frame_left, frame_right, planes):
    contacts = 0
    for i, j in tree(left, frame_left).overlap(tree(right, frame_right)):
        a, b = vertices(left, i, frame_left), vertices(right, j, frame_right)
        # Only measured planar face/edge bearing at the actual native planes.
        accepted = False
        for level, left_below in planes:
            az, bz = [p.z-level for p in a], [p.z-level for p in b]
            if left_below:
                accepted |= max(az)<1e-7 and min(bz)>-1e-7
            else:
                accepted |= min(az)>-1e-7 and max(bz)<1e-7
        assert accepted, (left, right, 'native stock crossing', i, j, a, b)
        contacts += 1
    return contacts

poses = []
for index in range(15):
    travel = STROKE*index/14
    angle = math.tau*travel/PITCH
    nut_frame = Matrix.Rotation(angle,4,'Z')
    male_frame = Matrix.Translation((0,0,BASE+travel))
    assert not tree('NozzleNut',nut_frame).overlap(tree('NozzleSpigot',male_frame)), ('thread crossing',index)
    nut_contacts = contact_only('HoseSeat','NozzleNut',Matrix.Identity(4),nut_frame,
                                [(.005,True),(.014,False)])
    seal_contacts = contact_only('HoseSeat','NozzleSpigot',Matrix.Identity(4),male_frame,
                                 [(SEAT,True)])
    assert nut_contacts > 0
    if index == 0: assert seal_contacts > 0
    else: assert seal_contacts == 0
    poses.append(dict(withdrawal_m=travel,nut_angle_rad=angle,
                       spigot_origin_y_m=BASE+travel,
                       nut_bearing_contacts=nut_contacts,seal_contacts=seal_contacts))

bores, positive, bearings = 0, 0, 0
for name, radius in [('HoseSeat',BORE),('NozzleNut',.02025),('NozzleSpigot',BORE)]:
    obj = objects[name]; test = tree(name)
    low = min(v.co.z for v in obj.data.vertices); high = max(v.co.z for v in obj.data.vertices)
    for index in range(17):
        angle = math.tau*index/16; r = 0 if index == 0 else radius*.90
        assert test.ray_cast(Vector((r*math.cos(angle),r*math.sin(angle),high+.005)),Vector((0,0,-1)),high-low+.010)[0] is None
        bores += 1
    r = .025 if name == 'NozzleNut' else .017
    assert test.ray_cast(Vector((r,0,high+.005)),Vector((0,0,-1)),high-low+.010)[0] is not None
    positive += 1

# The original cone is retained; prove its actual back cap meets the new part.
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_service.blend'),link=False) as (available,loaded):
    loaded.objects = ['F059']
body = loaded.objects[0]; assert body is not None
bpy.context.collection.objects.link(body)
body_frame = Matrix.Translation((0,0,BASE+.085))
body_tree = tree(body,body_frame)
male_tree = tree('NozzleSpigot',Matrix.Translation((0,0,BASE)))
assert not body_tree.overlap(tree('HoseSeat'))
for index in range(16):
    angle = math.tau*index/16
    at = Vector((.017*math.cos(angle),.017*math.sin(angle),BASE+.001))
    a = body_tree.ray_cast(at,Vector((0,0,-1)),.005)[0]
    b = male_tree.ray_cast(at,Vector((0,0,-1)),.005)[0]
    # Start inside the cone wall so both measured back planes are visible.
    assert a is not None and b is not None and abs(a.z-BASE)<.0001 and abs(b.z-a.z)<.0001, (index,a,b)
    bearings += 1
body.data.materials.clear(); body.data.materials.append(mat)

native.hide_render=True; native.hide_viewport=True
for obj in exports.objects: obj.hide_render=True
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1200;scene.render.resolution_y=850;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral nozzle fitting review');scene.world.color=(.18,.18,.18)
for position,power in [((.12,-.18,.27),4),((-.15,.10,.16),3)]:
    bpy.ops.object.light_add(type='AREA',location=position)
    light=bpy.context.object;light.data.energy=power;light.data.size=.15
    light.rotation_euler=(Vector((0,0,.065))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(.28,-.45,.24));scene.camera=bpy.context.object;scene.camera.data.lens=55
scene.camera.rotation_euler=(Vector((0,0,.085))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
copies=[]
for source,at in [(seat,(0,0,0)),(nut,(0,0,0)),(spigot,(0,0,BASE))]:
    copy=source.copy();copy.hide_render=False;copy.location=at
    bpy.context.collection.objects.link(copy);copies.append(copy)
body.matrix_world=body_frame;body.hide_render=False
scene.render.filepath=str(OUT/'assembled_nozzle_joint.png');bpy.ops.render.render(write_still=True)
copies[0].location.x=-.070;copies[1].location.x=0;copies[2].location.x=.070
body.hide_render=True
scene.camera.location=(.20,-.30,.16)
scene.camera.rotation_euler=(Vector((0,0,.018))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'exploded_nozzle_joint.png');bpy.ops.render.render(write_still=True)
for obj in copies+[body]:bpy.data.objects.remove(obj,do_unlink=True)
for obj in exports.objects:obj.hide_render=False
result=export(OUT,'fire_nozzle_joint',exports,material_names_only=True)
glb=OUT/'game/assets/props/fire_nozzle_joint.glb';validate(glb)
paths=[Path(__file__).resolve(),ROOT/'art/blender/scripts/fabrication_native_batch.py',
       ROOT/'art/blender/scripts/fabrication_chart_batch.py',ROOT/'art/blender/scripts/fabrication_normals.py',
       ROOT/'art/blender/fire_service.blend',ROOT/'game/data/runtime_material_sets.json']
bindings={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')
          if p.suffix in ['.py','.json'] else p.read_bytes()).hexdigest() for p in paths}
dimensions=dict(pitch_m=PITCH,radial_clearance_m=CLEAR,bore_radius_m=BORE,
                sealing_plane_y_m=SEAT,nozzle_base_y_m=BASE,withdrawal_m=STROKE)
report=dict(evidence_class='INERT',scope='Uninstalled original native candidate; no runtime/human acceptance.',
            source_bindings=bindings,dimensions=dimensions,stocks=metrics,thread_motion=poses,
            clear_bore_rays=bores,positive_stock_rays=positive,original_nozzle_cap_bearings=bearings,
            export=result,glb_sha256=hashlib.sha256(glb.read_bytes()).hexdigest(),
            blend_sha256=hashlib.sha256((OUT/'art/blender/fire_nozzle_joint.blend').read_bytes()).hexdigest())
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n')
(OUT/'runtime_projection.json').write_text(json.dumps(dict(schema_version=1,
    asset='res://assets/props/fire_nozzle_joint.glb',dimensions=dimensions,materials={'brass':finish},
    parts={name:'brass' for name in objects}),indent=2)+'\n')
print('FIRE NOZZLE JOINT NATIVE PASS',json.dumps(metrics))
