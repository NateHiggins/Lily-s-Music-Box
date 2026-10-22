"""INERT deformed native-skin review, not a self-contact solver or publication."""
from pathlib import Path
import bpy,bmesh,hashlib,json,os
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
CASE=Path(os.environ.get('ORISON_HOSE_POSE',str(ROOT/'art/reviews/v2_hose_follower_20261021/right_payout_v4/payout.json'))).resolve()
SOURCE=ROOT/'art/blender/v2_deployable_hose/rig_v3/blender/fire_capacity_candidate.blend'
OUT=Path(os.environ.get('ORISON_HOSE_POSE_REVIEW_OUT',str(ROOT/'tmp/v2-hose-follower-20261021/deformed_right_v1'))).resolve()
assert CASE.is_relative_to(ROOT) and OUT.is_relative_to(ROOT/'tmp')
OUT.mkdir(parents=True,exist_ok=True)
data=json.loads(CASE.read_text());assert len(data['frames'])==len(data['bind_frames'])==610
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));bpy.context.preferences.filepaths.save_version=0
obj=bpy.data.objects['Capacity study hose'];bpy.context.view_layer.update();assert obj.matrix_world==Matrix.Identity(4)
B=Matrix(((1,0,0),(0,0,-1),(0,1,0))).to_4x4()
def frame(rows):
 m=Matrix.Identity(4)
 for column in range(3):
  for row in range(3):m[row][column]=rows[column][row]
 m.translation=Vector(rows[3]);return m
frames=[frame(rows) for rows in data['frames']]
binds=[frame(rows) for rows in data['bind_frames']]
deltas=[B@current@bind.inverted()@B.inverted() for current,bind in zip(frames,binds)]
names={group.index:int(group.name.removeprefix('HoseRing')) for group in obj.vertex_groups}
normal=[entry.vector.copy() for entry in obj.data.corner_normals]
rings=[]
for vertex in obj.data.vertices:
 groups=[group for group in vertex.groups if group.weight>1e-6]
 assert len(groups)==1 and abs(groups[0].weight-1)<1e-6
 ring=names[groups[0].group];rings.append(ring);vertex.co=deltas[ring]@vertex.co
for modifier in list(obj.modifiers):obj.modifiers.remove(modifier)
world=obj.matrix_world.copy();obj.parent=None;obj.matrix_world=world
obj.data.update();obj.data.normals_split_custom_set([(deltas[rings[loop.vertex_index]].to_3x3()@normal[i]).normalized() for i,loop in enumerate(obj.data.loops)])
for other in bpy.data.objects:
 if other.type in ['MESH','ARMATURE'] and other!=obj:other.hide_render=True
obj.hide_render=False;obj.hide_viewport=False
faces=[tuple(polygon.vertices) for polygon in obj.data.polygons];assert all(len(face)==3 for face in faces)
vertices=[vertex.co.copy() for vertex in obj.data.vertices]
tree=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
sets=[set(face) for face in faces]
pairs=[(first,last) for first,last in tree.overlap(tree) if first<last and not sets[first].intersection(sets[last])]
# Independent known crossing verifies that this BVH really reports crossings.
control=BVHTree.FromPolygons([Vector(p) for p in [(0,0,0),(1,0,0),(0,1,0),(.25,.25,-1),(.25,.25,1),(.75,.25,0)]],[(0,1,2),(3,4,5)],all_triangles=True)
assert any(first!=last for first,last in control.overlap(control))
bm=bmesh.new();bm.from_mesh(obj.data);bad=sum(not edge.is_manifold for edge in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
report={'evidence_class':'INERT','scope':'Actual native vertices deformed with the captured imported bind/current frames. Static self-crossing and native appearance review only. No self-contact dynamics, installed world, water, save or human acceptance.','vertices':len(vertices),'triangles':len(faces),'nonmanifold_edges':bad,'signed_volume_m3':volume,'self_crossing_pairs_without_shared_vertices':len(pairs),'first_pairs':pairs[:30],'first_pair_rings':[[[rings[index] for index in faces[first]],[rings[index] for index in faces[last]]] for first,last in pairs[:30]],'known_crossing_control':True,'source_bindings':{path.relative_to(ROOT).as_posix():hashlib.sha256(path.read_bytes()).hexdigest() for path in [CASE,SOURCE,Path(__file__)]}}
(OUT/'deformed_geometry.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral deformed cloth review');scene.world.color=(.18,.18,.18)
for old in list(bpy.data.objects):
 if old.type in ['LIGHT','CAMERA']:bpy.data.objects.remove(old,do_unlink=True)
bpy.ops.object.camera_add();scene.camera=bpy.context.object;scene.camera.data.lens=55
lights=[]
for power in [8,5]:
 bpy.ops.object.light_add(type='AREA');light=bpy.context.object;light.data.energy=power;light.data.size=.25;lights.append(light)
def b(point):return Vector((point.x,-point.z,point.y))
for name,index in [('tip',0),('body',305),('outlet',607)]:
 target=b(frames[index].translation);scene.camera.location=target+b(Vector((.03,.12,.35)))
 scene.camera.rotation_euler=(target-scene.camera.location).to_track_quat('-Z','Y').to_euler()
 for light,offset in zip(lights,[Vector((.10,.24,.28)),Vector((-.25,.08,.18))]):
  light.location=target+b(offset);light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.file.make_paths_absolute();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'deformed_skin.blend'));bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'deformed_skin.blend'))
print('DEFORMED NATIVE REVIEW',json.dumps(report))
# Failure is retained after all captures, so a defect can be inspected.
assert bad==0 and volume>0 and not pairs, 'Deformed cloth is not geometrically qualified'
