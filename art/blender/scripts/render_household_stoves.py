"""Neutral native review of the original range and every service station."""
from pathlib import Path
import bpy,json,math,os,ast
from mathutils import Vector,Matrix
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/household-stoves-native';out.mkdir(parents=True,exist_ok=True)
fit=json.loads((r/'art/data/household_stoves/source_plan.json').read_text(encoding='utf-8'))['native_service']
tree=ast.parse((r/'art/blender/scripts/inspect_household_stove_motion.py').read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['motion','smoothstep']],type_ignores=[]),'native stove motion','exec'))
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/household_stoves.blend'));scene=bpy.context.scene
draws=[o for o in scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render]
scene.render.engine='CYCLES';scene.cycles.samples=int(os.environ.get('HOUSEHOLD_STOVES_SAMPLES','32'))
scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral inspection');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.60,.65,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
for at,power,size in [((2.,3.,3.5),350,2.5),((-2.,1.,2.),180,1.8)]:
 bpy.ops.object.light_add(type='AREA',location=at);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.shape='DISK';lamp.data.size=size;lamp.rotation_euler=(Vector((0,0,.65))-lamp.location).to_track_quat('-Z','Y').to_euler()
original={o:o.matrix_world.copy() for o in draws};views=[]
for state in ['closed','open','service0','service1','service2','service3']:
 for o in draws:
  part=o.name.split('__')[1].split('_ON_')[0];o.matrix_world=original[o]
  if state!='closed' and part=='OvenDoor':
   pivot=Vector((0,.318,.34));o.matrix_world=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(-86),4,'X')@Matrix.Translation(-pivot)@original[o]
  if state.startswith('service'):
   o.matrix_world=motion(part,int(state[-1]),1.)@original[o]
 bpy.context.view_layer.update()
 points=[o.matrix_world@v.co for o in draws for v in o.data.vertices]
 low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)));center=(low+high)*.5;span=max(high-low)
 direction=Vector((1.3,3.,1.8)).normalized();bpy.ops.object.camera_add(location=center+direction*span*2.35);camera=bpy.context.object;camera.data.lens=52;camera.data.clip_start=.001
 camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 scene.render.filepath=str(out/('HouseholdGasRange_'+state+'.png'));bpy.ops.render.render(write_still=True)
 views.append({'id':'HouseholdGasRange','file':'HouseholdGasRange_'+state+'.png','state':state,'scope':'Native fixed and service geometry; original dynamic flame, grease and plugged jet remain runtime owners.'});bpy.data.objects.remove(camera,do_unlink=True)
(out/'views.json').write_text(json.dumps({'evidence_class':'INERT','views':views,'scope':'Native form review. Service fit remains unaccepted until motion and context checks pass.'},indent=2)+'\n',encoding='utf-8',newline='\n')
