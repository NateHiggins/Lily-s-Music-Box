"""Neutral native inspection of every distinct household/studio object."""
from pathlib import Path
import bpy,json,math,os
from mathutils import Vector
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/household-toasters-native';out.mkdir(exist_ok=True)
plan=json.loads((r/'art/data/household_toasters/source_plan.json').read_text(encoding='utf-8'));bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/household_toasters.blend'));scene=bpy.context.scene
draws=[o for o in scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render]
scene.render.engine='CYCLES';scene.cycles.samples=int(os.environ.get('HOUSEHOLD_TOASTERS_SAMPLES','32'));scene.render.resolution_x=1100;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.60,.65,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
for at,power,size in [((1.8,2.7,3.5),230,2.5),((-1.8,.6,2.3),140,1.8)]:
 bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(Vector((0,0,.5))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=10,location=(0,0,-.00004));ground=bpy.context.object;mat=bpy.data.materials.new('Review neutral');mat.use_nodes=True;mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.23,.25,.26,1);mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.75;ground.data.materials.append(mat)
bpy.ops.mesh.primitive_plane_add(size=10,rotation=(math.pi/2,0,0));wall=bpy.context.object;wall.data.materials.append(mat)
views=[]
for row in plan['variants']:
 identity=row['id'];selected=[o for o in draws if o.name.startswith(identity+'__')]
 for obj in draws:obj.hide_render=obj not in selected
 wall.hide_render='rear_wall_y' not in row;ground.hide_render=not wall.hide_render
 if not wall.hide_render:wall.location=(0,row['rear_wall_y']-.00004,.5)
 points=[o.matrix_world@v.co for o in selected for v in o.data.vertices];low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)));center=(low+high)*.5;span=max(high-low)
 direction=Vector((2.,3.,1.8)).normalized()
 if row['kind'] in ['pinboard','toolboard']:direction=Vector((.3,3,.4)).normalized()
 elif row['kind']=='softbox':direction=Vector((1.3,3.5,.1)).normalized()
 eye=center+direction*max(span*2.1,.25)
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.data.lens=48;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 for state in (['closed','latched_open','release_peak'] if row['kind']=='toaster' else ['closed']):
  poses={obj:obj.location.copy() for obj in selected}
  if state!='closed':
   for obj in selected:
    component=obj.name.split('__')[1].split('_ON_')[0]
    if component=='BreadCarrier':obj.location.z+=-.087 if state=='latched_open' else .024
    elif component=='CarriageLever':obj.location.z+=-.046 if state=='latched_open' else .010
    elif component=='OrisonRetrofitCrumbTray' and state=='latched_open':obj.location+=Vector((-.160,0,0) if row['tray_axis']=='-x' else (0,.160,0))
  # Keep the open tray and the rear plug entirely inside the inspection frame.
  camera.location=center+direction*max(span*2.7,.25)
  camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
  name=identity+('_'+state if state!='closed' else '')+'.png'
  scene.render.filepath=str(out/name);bpy.ops.render.render(write_still=True)
  views.append({'id':identity,'source':row['source_id'],'file':name,'state':state})
  for obj,at in poses.items():obj.location=at
 bpy.data.objects.remove(camera,do_unlink=True)
(out/'views.json').write_text(json.dumps({'evidence_class':'INERT','views':views,'scope':'Native isolated form/material views. Production review remains required.'},indent=2)+'\n',encoding='utf-8',newline='\n')
