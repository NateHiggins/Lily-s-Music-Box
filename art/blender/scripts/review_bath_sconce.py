"""Original replacement form review; does not qualify installed lighting."""
from pathlib import Path
import bpy, json, os
from mathutils import Vector

root=Path(__file__).resolve().parents[3]
packet=Path(os.environ['BATH_SCONCE_REVIEW'])
bpy.ops.wm.open_mainfile(filepath=str(packet/'art/blender/fixed_lighting.blend'))
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=48
scene.render.resolution_x=1000;scene.render.resolution_y=1000
scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.18,.21,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
draws=[o for o in scene.objects if o.type=='MESH' and not o.hide_render]
vertices=[o.matrix_world@v.co for o in draws for v in o.data.vertices]
low=Vector(tuple(min(v[i] for v in vertices) for i in range(3)))
high=Vector(tuple(max(v[i] for v in vertices) for i in range(3)))
center=(low+high)*.5
for at,power,size in [((.25,-.35,.45),18,.4),((-.25,-.15,.1),8,.3),((0,-.25,-.30),3,.2)]:
    bpy.ops.object.light_add(type='AREA',location=at)
    light=bpy.context.object;light.data.energy=power;light.data.size=size
    light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
views=[]
for label,direction in [('front',(1.5,-3,1)),('below',(.8,-3,-1.8)),('side',(3,-1,.5)),('underside',(0,-.15,-3))]:
    bpy.ops.object.camera_add(location=center+Vector(direction).normalized()*.56)
    camera=bpy.context.object;camera.data.lens=48;camera.data.clip_start=.001
    camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.camera=camera;scene.render.filepath=str(packet/(label+'.png'))
    bpy.ops.render.render(write_still=True);views.append(label+'.png')
    bpy.data.objects.remove(camera,do_unlink=True)
(packet/'review.json').write_text(json.dumps({'evidence_class':'INERT','views':views,'bounds_native_m':{'low':list(low),'high':list(high)},'scope':'Unpowered original native replacement form. Not installed, wall-mounted or powered runtime acceptance.'},indent=2)+'\n',encoding='utf-8',newline='\n')
