"""Review native dumbwaiter controls and full pawl sweep against fixed stock."""
from pathlib import Path
import bpy,json,math
from mathutils.bvhtree import BVHTree
from mathutils import Vector,Matrix
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
out=ROOT/'tmp/v2-dumbwaiter-hand-20261013';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/service_instruments.blend'))
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
for obj in bpy.data.collections['Composed review'].objects:obj.hide_render=obj.get('actor')!='M09' or obj.hide_render
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1200;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral dumbwaiter service review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.42,.46,.50,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
scene.view_settings.view_transform='AgX'
center=C@Vector((-.05,.65,.1))
for at,power in [((2,3,4),600),((-2,1,2),220)]:
 bpy.ops.object.light_add(type='AREA',location=C@Vector(at));lamp=bpy.context.object
 lamp.data.energy=power;lamp.data.size=3;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
# Test actual triangulated geometry over the complete operable angular range.
pawl=bpy.data.objects['M09_P014_review'];original=pawl.matrix_world.copy()
pivot=C@Vector((.37,.82,.39))
def surface(obj):
 mesh=obj.data
 mesh.calc_loop_triangles()
 return BVHTree.FromPolygons([obj.matrix_world@v.co for v in mesh.vertices],[tuple(t.vertices) for t in mesh.loop_triangles],all_triangles=True,epsilon=0.000001)
fixed={name:surface(bpy.data.objects[name]) for name in ['M09_P010_review','M09_Fixed_review']}
collisions=[]
for i in range(241):
 angle=1.15*i/240
 rotation=C.to_4x4()@Matrix.Rotation(angle,4,'Z')@C.to_4x4().inverted()
 pawl.matrix_world=Matrix.Translation(pivot)@rotation@Matrix.Translation(-pivot)@original
 moving=surface(pawl)
 for name,target in fixed.items():
  if moving.overlap(target):collisions.append({'angle':angle,'stock':name})
# A .10-radian manual lift clears the entire tooth envelope at every phase.
rotation=C.to_4x4()@Matrix.Rotation(.10,4,'Z')@C.to_4x4().inverted()
pawl.matrix_world=Matrix.Translation(pivot)@rotation@Matrix.Translation(-pivot)@original
center=Vector((.17,.89))
points=[(C.inverted()@(pawl.matrix_world@v.co)).to_2d() for v in pawl.data.vertices]
minimum=10.
for edge in pawl.data.edges:
 a,b=[points[i] for i in edge.vertices];v=b-a
 t=max(0.,min(1.,(center-a).dot(v)/v.length_squared)) if v.length_squared>1e-15 else 0.
 minimum=min(minimum,(a+v*t-center).length)
assert minimum>.097,minimum
result={'evidence_class':'INERT','scope':'Triangulated native pawl sweep against deck and fixed support stock; not runtime proof','sampled_poses':241,'range_radians':[0,1.15],'collisions':collisions,'clear_angle_radians':.10,'nose_min_radius_at_clear_m':minimum,'ratchet_outer_radius_m':.097}
(out/'native_pawl_sweep.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
assert not collisions,collisions[:10]
pawl.matrix_world=original
for label,eye,target in [('context',(1.4,1.6,2.6),(0,.55,.2)),('control',(.65,1.35,1.15),(.16,.91,.37)),('pawl_open',(.65,1.35,1.15),(.16,.85,.37))]:
 if label=='pawl_open':
  rotation=C.to_4x4()@Matrix.Rotation(1.15,4,'Z')@C.to_4x4().inverted()
  pawl.matrix_world=Matrix.Translation(pivot)@rotation@Matrix.Translation(-pivot)@original
 bpy.ops.object.camera_add(location=C@Vector(eye));camera=bpy.context.object
 camera.data.lens=48;camera.data.clip_start=.01
 camera.rotation_euler=(C@Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 scene.render.filepath=str(out/('native_'+label+'.png'));bpy.ops.render.render(write_still=True)
