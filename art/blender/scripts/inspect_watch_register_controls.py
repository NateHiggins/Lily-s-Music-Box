"""Native detector cover open/closed review; no runtime acceptance."""
from pathlib import Path
import bpy,json,math
from mathutils.bvhtree import BVHTree
from mathutils import Vector,Matrix
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
out=ROOT/'tmp/v2-patrol-20261013/native';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/service_instruments.blend'))
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
for obj in bpy.data.collections['Composed review'].objects:obj.hide_render=obj.get('actor')!='M05' or obj.hide_render
plan=json.loads((ROOT/'art/data/service_instruments/source_plan.json').read_text(encoding='utf-8'))
actor=next(a for a in plan['actors'] if a['actor']=='F01_SIGNAL_REGISTER')
def surface(obj):
 obj.data.calc_loop_triangles()
 return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[tuple(t.vertices) for t in obj.data.loop_triangles],all_triangles=True)
key=bpy.data.objects['M05_TestKey_review'];original=key.matrix_world.copy()
fixed={p['name']:surface(bpy.data.objects[f'M05_P{p["index"]:03d}_review']) for p in actor['meshes'] if p['name'] in ['CounterPlate','CounterWindow','RegisterGong','RegisterBacking']}
collisions=[]
for i in range(121):
 angle=-math.pi*.5*i/120
 key.matrix_world=original@C@Matrix.Rotation(angle,4,'Z')@C.inverted()
 moving=surface(key)
 for name,target in fixed.items():
  if moving.overlap(target):collisions.append({'angle':angle,'stock':name})
key.matrix_world=original
(out/'register_test_key_sweep.json').write_text(json.dumps({'evidence_class':'INERT','sampled_poses':121,'collisions':collisions,'checked_stock':list(fixed)},indent=2),encoding='utf-8')
assert not collisions,collisions[:10]
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=20
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Detector review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.4,.44,.5,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
scene.view_settings.view_transform='AgX'
center=C.to_3x3()@Vector((0,.23,.1))
for at,power in [((.8,1,1.5),100),((-.7,.5,.8),60)]:
 bpy.ops.object.light_add(type='AREA',location=C.to_3x3()@Vector(at));lamp=bpy.context.object
 lamp.data.energy=power;lamp.data.size=1;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=C.to_3x3()@Vector((.45,.32,.85)));camera=bpy.context.object
camera.data.lens=45;camera.data.clip_start=.01
camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
scene.render.filepath=str(out/'register.png');bpy.ops.render.render(write_still=True)
print('REGISTER NATIVE REVIEW rendered')
