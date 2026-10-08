"""Neutral native material/form views; context validation is a separate stage."""
from pathlib import Path
import json,math
import bpy
from mathutils import Vector
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/domestic-storage-native';out.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/domestic_storage.blend'));scene=bpy.context.scene
draws=[o for o in scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render]
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=1000;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.60,.65,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
for at,power,size in [((1.4,2.0,3.2),160,2.),((-1.5,-1.,2.7),100,1.8)]:
 bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=10,location=(0,0,-.00004));plane=bpy.context.object;material=bpy.data.materials.new('Review ground');material.diffuse_color=(.23,.25,.26,1);material.use_nodes=True;material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.23,.25,.26,1);material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.75;plane.data.materials.append(material)
views=[]
for identity,side in [(name,'front') for name in ['Shelf01', 'Shelf02', 'Counter03', 'Shelf04', 'Counter05', 'Cupboard06', 'Shelf07', 'Cupboard08']]:
 selected=[o for o in draws if o.name.startswith(identity+'__')]
 for obj in draws:obj.hide_render=obj not in selected
 points=[o.matrix_world@v.co for o in selected for v in o.data.vertices];low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)));center=(low+high)*.5;span=max(high-low)
 eye=center+Vector((1.3,2 if side=="front" else -2,1.4)).normalized()*max(span*2.15,.25)
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.data.lens=48;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 scene.render.filepath=str(out/(identity+'_'+side+'.png'));bpy.ops.render.render(write_still=True);views.append({'id':identity,'file':identity+'_'+side+'.png'});bpy.data.objects.remove(camera,do_unlink=True)
(out/'views.json').write_text(json.dumps({'evidence_class':'INERT','views':views,'scope':'Eight passive storage variants; all 43 installed actors still require composed validation.'},indent=2)+'\n',newline='\n')
