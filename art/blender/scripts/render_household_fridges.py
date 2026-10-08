"""Native closed/open cabinet and source food prototypes under neutral light."""
from pathlib import Path
import bpy,json,os,math
from mathutils import Vector,Matrix
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
out=r/'tmp/v2-finish-review/household-fridges-native';out.mkdir(parents=True,exist_ok=True)
plan=json.loads((r/'art/data/household_fridges/source_plan.json').read_text(encoding='utf-8'))
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/household_fridges.blend'));scene=bpy.context.scene
draws=[o for o in scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render]
scene.render.engine='CYCLES';scene.cycles.samples=int(os.environ.get('HOUSEHOLD_FRIDGES_SAMPLES','24'))
scene.render.resolution_x=1000;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral inspection');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.60,.65,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
for at,power,size in [((2.,3.,3.5),350,2.5),((-2.,1.,2.),180,1.8)]:
 bpy.ops.object.light_add(type='AREA',location=at);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.shape='DISK';lamp.data.size=size;lamp.rotation_euler=(Vector((0,0,.75))-lamp.location).to_track_quat('-Z','Y').to_euler()
views=[];requested=os.environ.get('HOUSEHOLD_FRIDGES_RENDER_IDS','').split(',')
for row in plan['variants']:
 identity=row['id']
 if requested!=[''] and identity not in requested:continue
 selected=[o for o in draws if o.name.startswith(identity+'__')]
 if row['kind']=='food':
  for o in selected:
   if o.name.endswith(('_ON_food','_ON_paper','_ON_bottle')):
    material=o.data.materials[0].copy();o.data.materials[0]=material
    shader=material.node_tree.nodes['Principled BSDF'];color=shader.inputs['Base Color'];old=color.links[0].from_socket if color.links else None
    multiply=material.node_tree.nodes.new('ShaderNodeMixRGB');multiply.blend_type='MULTIPLY';multiply.inputs[0].default_value=1.;multiply.inputs[2].default_value=(*row['source_color'],1.)
    if old:material.node_tree.links.new(old,multiply.inputs[1])
    material.node_tree.links.new(multiply.outputs[0],color)
 for obj in draws:obj.hide_render=obj not in selected
 original={o:o.matrix_world.copy() for o in selected}
 for state in (['closed','open'] if row['kind']!='food' else ['stock']):
  for o in selected:
   o.matrix_world=original[o]
   if state=='open':
    component=o.name.split('__')[1].split('_ON_')[0]
    if component in ['Door','IceDoor']:
     pivot=Vector((-.36,.32,0)) if row['kind']=='monitor' else Vector((-.35,.29,0))
     angle=math.radians(105 if component=='Door' else 98)
     o.matrix_world=Matrix.Translation(pivot)@Matrix.Rotation(angle,4,'Z')@Matrix.Translation(-pivot)@original[o]
    elif component=='DripTray':o.matrix_world=Matrix.Translation((0,.30,0))@original[o]
  bpy.context.view_layer.update();points=[o.matrix_world@v.co for o in selected for v in o.data.vertices]
  low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)));center=(low+high)*.5;span=max(high-low)
  direction=Vector((1.3,3.,1.2)).normalized()
  bpy.ops.object.camera_add(location=center+direction*max(span*2.25,.15));camera=bpy.context.object;camera.data.lens=48;camera.data.clip_start=.001
  camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
  scene.render.filepath=str(out/(identity+'_'+state+'.png'));bpy.ops.render.render(write_still=True)
  views.append({'id':identity,'file':identity+'_'+state+'.png','source':row['source_id'],'state':state});bpy.data.objects.remove(camera,do_unlink=True)
 for o in selected:o.matrix_world=original[o]
(out/'views.json').write_text(json.dumps({'evidence_class':'INERT','views':views,'scope':'Native form and mapped finish. Source household tints and actual food arrangement require runtime review.'},indent=2)+'\n',encoding='utf-8',newline='\n')
