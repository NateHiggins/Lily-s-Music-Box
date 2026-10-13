"""Review retained tower/collector around native movable roof service parts."""
from pathlib import Path
import bpy,json
from mathutils import Vector,Matrix
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
out=ROOT/'tmp/v2-roof-hand-20261013';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/service_instruments.blend'))
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
for obj in bpy.data.collections['Composed review'].objects:obj.hide_render=obj.get('actor')!='M02' or obj.hide_render
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets/props/house_tank.glb'))
context=set(bpy.data.objects)-before
for obj in context:
 if obj.parent is None:obj.location+=C@Vector((1,-1.3,-1.15))
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1200;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral roof service review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.42,.46,.50,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
scene.view_settings.view_transform='AgX'
center=C@Vector((-.05,.65,.1))
for at,power in [((2,3,4),600),((-2,1,2),220)]:
 bpy.ops.object.light_add(type='AREA',location=C@Vector(at));lamp=bpy.context.object
 lamp.data.energy=power;lamp.data.size=3;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
for label,eye,target in [('context',(2,2,5),(0,.6,-.2)),('control',(.7,.1,2),(.05,-.22,.1))]:
 bpy.ops.object.camera_add(location=C@Vector(eye));camera=bpy.context.object
 camera.data.lens=48;camera.data.clip_start=.01
 camera.rotation_euler=(C@Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 scene.render.filepath=str(out/('native_'+label+'.png'));bpy.ops.render.render(write_still=True)
# Retained collector east face is actor x=-.10. Actual wheel bounds must clear.
wheel=bpy.data.objects['M02_P013_review']
points=[C.inverted()@(wheel.matrix_world@v.co) for v in wheel.data.vertices]
clearance=min(v.x for v in points)-(-.10)
assert clearance>.20,clearance
result={'evidence_class':'INERT','scope':'native control fit against retained tower and collector; not runtime proof','wheel_collector_horizontal_clearance_m':clearance,'wheel_center':list(C.inverted()@wheel.location),'views':['native_context.png','native_control.png']}
(out/'native_fit.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print('ROOF CONTROL NATIVE FIT',result)
