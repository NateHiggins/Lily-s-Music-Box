"""Native ledger pen resting/writing review; no runtime acceptance."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector,Matrix
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
out=ROOT/'tmp/v2-patrol-20261013/native';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/service_instruments.blend'))
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
for obj in bpy.data.collections['Composed review'].objects:obj.hide_render=obj.get('actor')!='M04' or obj.hide_render
pen=bpy.data.objects['M04_P039_review']
desk=Matrix.Translation(Vector((.070,.116,.106)))@Matrix.Rotation(.52,4,'X')
rest=Matrix.Translation(Vector((-.04,.0176,0)))@Matrix.Rotation(math.pi/2,4,'Z')
pen.matrix_world=C@desk@rest@C.inverted()
# Check every native vertex in desk space at the two permitted resting edges.
checks=[]
for x in [-.055,.055]:
 for z in [-.058,.058]:
  pose=Matrix.Translation(Vector((x,.0176,z)))@Matrix.Rotation(math.pi/2,4,'Z')
  vertices=[pose@C.inverted()@v.co for v in pen.data.vertices]
  checks.append({'x':x,'z':z,'supported':all(abs(v.x)<=.1101 and abs(v.z-.002)<=.0701 and v.y>=.01399 for v in vertices)})
assert all(c['supported'] for c in checks),checks
(out/'night_pen_fit.json').write_text(json.dumps({'evidence_class':'INERT','resting_edge_checks':checks},indent=2),encoding='utf-8')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=20
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Ledger review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.4,.44,.5,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
scene.view_settings.view_transform='AgX'
center=C.to_3x3()@Vector((.07,.13,.12))
for at,power in [((.8,1,1.5),100),((-.7,.5,.8),60)]:
 bpy.ops.object.light_add(type='AREA',location=C.to_3x3()@Vector(at));lamp=bpy.context.object
 lamp.data.energy=power;lamp.data.size=1;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=C.to_3x3()@Vector((.28,.39,.48)));camera=bpy.context.object
camera.data.lens=45;camera.data.clip_start=.01
camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
scene.render.filepath=str(out/'night_pen_rest.png');bpy.ops.render.render(write_still=True)
print('NIGHT REGISTER PEN REVIEW rendered')

direction=Vector((.20,.96,.18)).normalized()
write=Vector((-.025,.016,0))
pose=Vector((0,1,0)).rotation_difference(direction).to_matrix().to_4x4()
pose.translation=write+direction*.0525
pen.matrix_world=C@desk@pose@C.inverted()
scene.render.filepath=str(out/'night_pen_writing.png');bpy.ops.render.render(write_still=True)
