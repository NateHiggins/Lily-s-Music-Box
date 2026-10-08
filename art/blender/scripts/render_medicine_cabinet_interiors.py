"""Neutral native inspection of every distinct household/studio object."""
from pathlib import Path
import bpy,json,math,os
from mathutils import Vector, Matrix
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/medicine-cabinets-native';out.mkdir(exist_ok=True)
plan=json.loads((r/'art/data/medicine_cabinets/source_plan.json').read_text(encoding='utf-8'));bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/medicine_cabinets.blend'));scene=bpy.context.scene
draws=[o for o in scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render]
scene.render.engine='CYCLES';scene.cycles.samples=int(os.environ.get('MEDICINE_CABINETS_SAMPLES','32'));scene.render.resolution_x=1100;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.60,.65,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
for at,power,size in [((1.8,2.7,3.5),230,2.5),((-1.8,.6,2.3),140,1.8)]:
 bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(Vector((0,0,.5))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=10,location=(0,0,-.00004));ground=bpy.context.object;mat=bpy.data.materials.new('Review neutral');mat.use_nodes=True;mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.23,.25,.26,1);mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.75;ground.data.materials.append(mat)
bpy.ops.mesh.primitive_plane_add(size=10,rotation=(math.pi/2,0,0));wall=bpy.context.object;wall.data.materials.append(mat)
views=[]
for unit,items in plan['original_kept'].items():
 if os.environ.get('MEDICINE_CABINETS_RENDER_UNITS') and unit not in os.environ['MEDICINE_CABINETS_RENDER_UNITS'].split(','):continue
 record=next(row for row in plan['original_accessories'] if row['unit']==unit)
 side=1 if record['hinge_side']=='left' else -1;identity='MedicineLeft' if side==1 else 'MedicineRight'
 selected=[obj for obj in draws if obj.name.startswith(identity+'__')]
 for obj in draws:obj.hide_render=obj not in selected
 wall.hide_render=False;ground.hide_render=True;wall.location=(0,-.05804,1.505)
 original={obj:obj.matrix_world.copy() for obj in selected}
 pivot=Vector((side*.230,.060,1.505));swing=Matrix.Translation(pivot)@Matrix.Rotation(-side*math.radians(95),4,'Z')@Matrix.Translation(-pivot)
 for obj in selected:
  if obj.name.split('__')[1].split('_ON_')[0] in ['CabinetDoor','Mirror']:obj.matrix_world=swing@obj.matrix_world
 copies=[];used={0:0,1:0}
 for index,item in enumerate(items):
  shelf=index%2;n=used[shelf];used[shelf]+=1
  variant='MedicineItem_'+item[0].replace(' ','_')
  for prototype in draws:
   if not prototype.name.startswith(variant+'__'):continue
   obj=prototype.copy();obj.data=prototype.data;scene.collection.objects.link(obj);obj.hide_render=False
   obj.matrix_world=Matrix.Translation((-.155+n*.090,-.005,[1.404,1.594][shelf]))@prototype.matrix_world;copies.append(obj)
 bpy.context.view_layer.update()
 points=[o.matrix_world@v.co for o in selected+copies for v in o.data.vertices]
 low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)));center=(low+high)*.5;span=max(high-low)
 direction=Vector((-side*.9,3.,.45)).normalized()
 bpy.ops.object.camera_add(location=center+direction*span*2.1);camera=bpy.context.object;camera.data.lens=48;camera.data.clip_start=.001;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 name=unit+'_cabinet_open.png';scene.render.filepath=str(out/name);bpy.ops.render.render(write_still=True)
 views.append({'unit':unit,'file':name,'items':[item[0] for item in items],'layout':'source shelf/count; midpoint jitter, zero yaw for native inspection; actual seeded layout remains runtime-owned'})
 bpy.data.objects.remove(camera,do_unlink=True)
 for obj in copies:bpy.data.objects.remove(obj,do_unlink=True)
 for obj,pose in original.items():obj.matrix_world=pose
(out/'interior_views.json').write_text(json.dumps({'evidence_class':'INERT','views':views,'scope':'Native open case, shelf hardware and original household contents. Midpoint layout only; actual source RNG and live mirror require production validation.'},indent=2)+'\n',encoding='utf-8',newline='\n')
