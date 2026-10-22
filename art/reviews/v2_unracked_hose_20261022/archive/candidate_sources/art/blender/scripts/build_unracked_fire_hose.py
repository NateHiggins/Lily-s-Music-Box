"""Author a separate, low-density round hose for use AFTER rack extraction.

The installed folded stock remains static. This native source never derives
simulation nodes from the stored folds. Outputs are uninstalled candidates.
"""
from pathlib import Path
import os, sys, math, json, hashlib
import bpy, bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(os.environ.get('ORISON_UNRACKED_HOSE_OUT', str(ROOT/'tmp/v2-unracked-hose-20261022/native_v1'))).resolve()
assert OUT.is_relative_to(ROOT/'tmp')
for directory in ['art/blender', 'game/assets/props']:
    (OUT/directory).mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material, partition, export

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
N = 32
RADIUS = .021
WALL = .00195
LENGTH = 15.24
BODY_EDGES = 128
BODY_SPAN = (LENGTH-.030)/BODY_EDGES
lengths = [.005]*3 + [BODY_SPAN]*BODY_EDGES + [.005]*3
points = [Vector((0., 0., 0.))]
offset = 0.
for distance in lengths:
    offset += distance
    points.append(Vector((offset, 0., 0.)))
assert abs(offset-LENGTH)<1e-10
count = len(points)
half = count*N
def blender(p): return Vector((p.x, -p.z, p.y))
vertices, faces = [], []
for inside in [False, True]:
    radius = RADIUS-WALL*inside
    for p in points:
        for j in range(N):
            angle = math.tau*j/N
            vertices.append(blender(p+Vector((0., -radius*math.cos(angle), radius*math.sin(angle)))))
for inside in [False, True]:
    offset = half*inside
    for i in range(count-1):
        for j in range(N):
            q=(offset+i*N+j, offset+(i+1)*N+j, offset+(i+1)*N+(j+1)%N, offset+i*N+(j+1)%N)
            faces.append(tuple(reversed(q)) if inside else q)
for i in [0, count-1]:
    for j in range(N):
        faces.append((i*N+j, i*N+(j+1)%N, half+i*N+(j+1)%N, half+i*N+j))
mesh=bpy.data.meshes.new('Unracked round linen source')
mesh.from_pydata(vertices, [], faces);mesh.update()
bm=bmesh.new();bm.from_mesh(mesh)
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
assert all(e.is_manifold for e in bm.edges)
volume=bm.calc_volume(signed=True);assert volume>0
bm.to_mesh(mesh);bm.free()
source=bpy.data.objects.new('Unracked cloth source', mesh)
bpy.context.collection.objects.link(source)
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finish=dict(catalog_key='linen', tint=[.75,.71,.59,1], pigment=1., normal=.08, roughness=.9, metallic=0.)
collection=bpy.data.collections.new('Unracked hose export');bpy.context.scene.collection.children.link(collection)
cloth=partition(collection, 'UnrackedHose', [source], finish, material(ROOT,'linen',finish,catalog),
                source.matrix_world.copy(), catalog)
bpy.data.objects.remove(source, do_unlink=True)
assert len(cloth.data.vertices)==count*N*2
for polygon in cloth.data.polygons: polygon.use_smooth=True

armature=bpy.data.armatures.new('Unracked independent sections')
rig=bpy.data.objects.new('UnrackedHoseSkeleton',armature);collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
names=[]
for i,p in enumerate(points):
    bone=armature.edit_bones.new('HoseRing%04d'%i)
    bone.head=blender(p);bone.tail=blender(p+Vector((.01,0,0)))
    bone.align_roll(blender(Vector((0,0,1))));names.append(bone.name)
bpy.ops.object.mode_set(mode='OBJECT')
for i,name in enumerate(names):
    group=cloth.vertex_groups.new(name=name)
    group.add(list(range(i*N,(i+1)*N))+list(range(half+i*N,half+(i+1)*N)),1.,'REPLACE')
modifier=cloth.modifiers.new('Independent round sections','ARMATURE');modifier.object=rig
cloth.parent=rig
projection=dict(schema_version=1,bone_names=names,points=[list(p) for p in points],
                sides=[[0,0,1]]*count,length_m=LENGTH)
(OUT/'rig_projection.json').write_text(json.dumps(projection,indent=2)+'\n',newline='\n')
result=export(OUT,'unracked_fire_hose',collection,material_names_only=True)

# A loose broad U is a placement candidate, not a world-clearance assertion.
# Six short neck intervals are retained. Every other chord has the same length.
laid=[Vector((.170,.445,.098))]
direction=Vector((0,-1,0))
def edge(length, heading): laid.append(laid[-1]+heading*length)
for _ in range(3): edge(.005,direction)
for _ in range(2): edge(BODY_SPAN,direction)
for angle in [math.pi/8,3*math.pi/8]:
    edge(BODY_SPAN,Vector((0,-math.cos(angle),math.sin(angle))))
for _ in range(60): edge(BODY_SPAN,Vector((1,0,0)))
for angle in [math.pi/8,3*math.pi/8,5*math.pi/8,7*math.pi/8]:
    edge(BODY_SPAN,Vector((math.cos(angle),0,math.sin(angle))))
for _ in range(60): edge(BODY_SPAN,Vector((-1,0,0)))
for _ in range(3): edge(.005,Vector((-1,0,0)))
laid.reverse()
assert len(laid)==count
assert max(abs((b-a).length-length) for a,b,length in zip(laid,laid[1:],lengths))<1e-6
(OUT/'placement_candidate.json').write_text(json.dumps(dict(evidence_class='INERT',
    scope='Broad U proposal only; requires live world occupancy before use.',
    points=[list(p) for p in laid]),indent=2)+'\n',newline='\n')

# Review a fully unracked shape using the exact native mesh and bone weights.
for i,p in enumerate(laid):
    tangent=(laid[min(i+1,count-1)]-laid[max(0,i-1)]).normalized()
    # Round sections do not need the folded ribbon's anisotropic roll solve.
    turn=Vector((1,0,0)).rotation_difference(tangent)
    rotation=blender(turn@Vector((1,0,0))).to_track_quat('Y','Z')
    bone=rig.pose.bones[names[i]]
    original=armature.bones[names[i]].matrix_local
    from mathutils import Matrix
    # Conjugate the Godot-space tangent rotation into Blender coordinates.
    basis=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
    pose=(basis@turn.to_matrix()@basis.inverted()).to_4x4()@original
    pose.translation=blender(p);bone.matrix=pose
bpy.context.view_layer.update()
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1400;scene.render.resolution_y=650;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral cloth review');scene.world.color=(.2,.2,.2)
for at,energy,size in [((3,2,2),700,6),((5,1,-1),300,4)]:
    bpy.ops.object.light_add(type='AREA',location=blender(Vector(at)))
    light=bpy.context.object;light.data.energy=energy;light.data.size=size
    light.rotation_euler=(blender(Vector((3.5,.04,.4)))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=blender(Vector((3.7,6,4))))
camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=8.6
camera.rotation_euler=(blender(Vector((3.7,.08,.45)))-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
scene.render.filepath=str(OUT/'unracked_u.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'unracked_review.blend'))
def digest(path):
    data=path.read_bytes()
    if path.suffix in ['.py','.json']:data=data.replace(b'\r\n',b'\n')
    return hashlib.sha256(data).hexdigest()
report=dict(evidence_class='INERT',scope='Uninstalled simple unracked native candidate. No stored-form simulation, installed interaction, world contact or water qualification.',
            rings=count,vertices=len(cloth.data.vertices),triangles=len(cloth.data.polygons),length_m=LENGTH,
            outer_radius_m=RADIUS,wall_m=WALL,volume_m3=volume,export=result,
            source_bindings={p.relative_to(ROOT).as_posix():digest(p) for p in [Path(__file__).resolve(),ROOT/'art/blender/scripts/fabrication_native_batch.py',ROOT/'game/data/runtime_material_sets.json']})
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('UNRACKED HOSE NATIVE',json.dumps(report))
