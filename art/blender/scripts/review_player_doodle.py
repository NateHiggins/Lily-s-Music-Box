"""Native orientation and deformation views, before actual mirror captures."""
from pathlib import Path
import bpy,json
from mathutils import Vector
root=Path(__file__).resolve().parents[3];out=root/'art/reviews/v2_player_doodle_20261023'
bpy.ops.wm.open_mainfile(filepath=str(root/'art/blender/player_doodle.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.3,.3,.3,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
for pos in [(2,-2,3),(-2,2,3)]:
    bpy.ops.object.light_add(type='AREA',location=pos);light=bpy.context.object;light.data.energy=140;light.data.size=2
    light.rotation_euler=(Vector((0,0,.8))-light.location).to_track_quat('-Z','Y').to_euler()
for name,pos,frame in [('negative_y',(0,-3,1.1),30),('positive_y',(0,3,1.1),30),('idle_middle',(0,-3,1.1),150)]:
    scene.frame_set(frame);bpy.ops.object.camera_add(location=pos);camera=bpy.context.object;camera.data.lens=55
    camera.rotation_euler=(Vector((0,0,.8))-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
    scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True);bpy.data.objects.remove(camera,do_unlink=True)
