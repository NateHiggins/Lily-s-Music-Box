"""Neutral native material/form views; context validation is a separate stage."""
from pathlib import Path
import json,math
import bpy
from mathutils import Vector
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/surface-stock-native';out.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/surface_stock.blend'));scene=bpy.context.scene
draws=[o for o in scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render]
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=1000;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.60,.65,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
for at,power,size in [((.7,-.6,1.1),35,.65),((-.6,.3,.8),18,.6)]:
 bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=10,location=(0,0,-.00004));plane=bpy.context.object;material=bpy.data.materials.new('Review ground');material.diffuse_color=(.23,.25,.26,1);material.use_nodes=True;material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.23,.25,.26,1);material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.75;plane.data.materials.append(material)
views=[]
for identity in ['2A_mug','2A_phones','2A_papers','3B_jars','3B_tray1','3B_manuals','2A_k_kdishrack','3B_coil','6A_cans','3A_story_cuttings','5A_model']:
 selected=[o for o in draws if o.name.startswith(identity+'__')]
 for obj in draws:obj.hide_render=obj not in selected
 points=[o.matrix_world@v.co for o in selected for v in o.data.vertices];low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)));center=(low+high)*.5;span=max(high-low)
 eye=center+Vector((1.3,-2,1.4)).normalized()*max(span*2.15,.25)
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.data.lens=48;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 scene.render.filepath=str(out/(identity+'.png'));bpy.ops.render.render(write_still=True);views.append({'id':identity,'file':identity+'.png'});bpy.data.objects.remove(camera,do_unlink=True)
(out/'views.json').write_text(json.dumps({'evidence_class':'INERT','views':views,'scope':'Eleven representative native form/material views; all 55 instances still require composed runtime validation.'},indent=2)+'\n',newline='\n')
