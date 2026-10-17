"""Neutral native material/form views; context validation is a separate stage."""
from pathlib import Path
import json,math,os
import bpy
from mathutils import Vector
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
source=Path(os.environ.get('DOMESTIC_SEATING_OUT',str(r)))
out=Path(os.environ.get('DOMESTIC_SEATING_RENDER_OUT',str(r/'tmp/v2-finish-review/domestic-seating-native')));out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source/'art/blender/domestic_seating.blend'));scene=bpy.context.scene
draws=[o for o in scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render]
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=1000;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.60,.65,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
for at,power,size in [((.7,-.6,1.1),35,.65),((-.6,.3,.8),18,.6)]:
 bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=10,location=(0,0,-.00004));plane=bpy.context.object;material=bpy.data.materials.new('Review ground');material.diffuse_color=(.23,.25,.26,1);material.use_nodes=True;material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.23,.25,.26,1);material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.75;plane.data.materials.append(material)
views=[]
identities=os.environ.get('DOMESTIC_SEATING_VIEW_IDS','ChairDark,ChairOak,Sofa195,Sofa210,Armchair').split(',')
for identity,side in [(name,side) for name in identities for side in ['front','rear']]:
 selected=[o for o in draws if o.name.startswith(identity+'__')]
 for obj in draws:obj.hide_render=obj not in selected
 points=[o.matrix_world@v.co for o in selected for v in o.data.vertices];low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)));center=(low+high)*.5;span=max(high-low)
 eye=center+Vector((1.3,2 if side=="front" else -2,1.4)).normalized()*max(span*2.15,.25)
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.data.lens=48;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 scene.render.filepath=str(out/(identity+'_'+side+'.png'));bpy.ops.render.render(write_still=True);views.append({'id':identity,'file':identity+'_'+side+'.png'});bpy.data.objects.remove(camera,do_unlink=True)
(out/'views.json').write_text(json.dumps({'evidence_class':'INERT','views':views,'scope':'Selected native seating variants in front/rear views; installed actors still require composed validation.'},indent=2)+'\n',newline='\n')
