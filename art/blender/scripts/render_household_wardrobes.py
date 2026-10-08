"""Two case finishes and all thirteen source-owned open clothing arrangements."""
from pathlib import Path
import json,math,os
import bpy
from mathutils import Vector,Matrix
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/household-wardrobes-native';out.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/household_wardrobes.blend'));scene=bpy.context.scene
draws=[o for o in scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render];original={o.name:o.matrix_world.copy() for o in draws}
scene.render.engine='CYCLES';scene.cycles.samples=int(os.environ.get('WARDROBE_SAMPLES','32'));scene.render.resolution_x=1000;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.60,.65,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
for at,power,size in [((1.8,2.7,3.5),230,2.5),((-1.8,.6,2.3),140,1.8)]:
 bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=10,location=(0,0,-.00004));plane=bpy.context.object;mat=bpy.data.materials.new('Review ground');mat.use_nodes=True;mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.23,.25,.26,1);mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.75;plane.data.materials.append(mat)
views=[];spec=[('Wardrobe00','closed'),('Wardrobe01','closed')]+[(f'Wardrobe{i:02}','open') for i in range(13)]
if os.environ.get('WARDROBE_DRAFT'):spec=[('Wardrobe00','closed'),('Wardrobe00','open')]
for identity,state in spec:
 selected=[o for o in draws if o.name.startswith(identity+'__')]
 for obj in draws:
  obj.hide_render=obj not in selected;obj.matrix_world=original[obj.name]
  if state=='open' and obj in selected:
   component=obj.name.split('__')[1].split('_ON_')[0]
   if component in ['LeftLeaf','RightLeaf']:
    side=-1 if component=='LeftLeaf' else 1;p=Vector((side*.615,.305,.10))
    obj.matrix_world=Matrix.Translation(p)@Matrix.Rotation(-side*math.radians(92),4,'Z')@Matrix.Translation(-p)@original[obj.name]
 bpy.context.view_layer.update()
 center=Vector((0,.1,1));eye=center+Vector((.45,3.7,1.5))
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.data.lens=48;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 scene.render.filepath=str(out/f'{identity}_{state}.png');bpy.ops.render.render(write_still=True);views.append({'id':identity,'state':state,'file':f'{identity}_{state}.png'});bpy.data.objects.remove(camera,do_unlink=True)
(out/'views.json').write_text(json.dumps({'evidence_class':'INERT','views':views,'scope':'Native closed finishes and all open source clothing arrangements. Runtime review remains required.'},indent=2)+'\n',encoding='utf-8',newline='\n')
