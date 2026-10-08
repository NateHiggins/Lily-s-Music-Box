"""Neutral native views from below; no production lighting acceptance implied."""
from pathlib import Path
import bpy,json,os
from mathutils import Vector
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
out=r/'tmp/v2-finish-review/fixed-lighting-native';out.mkdir(parents=True,exist_ok=True)
plan=json.loads((r/'art/data/fixed_lighting/source_plan.json').read_text(encoding='utf-8'))
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/fixed_lighting.blend'));scene=bpy.context.scene
draws=[o for o in scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render]
scene.render.engine='CYCLES';scene.cycles.samples=int(os.environ.get('FIXED_LIGHTING_SAMPLES','32'))
scene.render.resolution_x=1100;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral light inspection');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.60,.65,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
for at,power,size in [((1.8,2.7,-.4),230,2.5),((-1.8,.6,-1.),140,1.8)]:
 bpy.ops.object.light_add(type='AREA',location=at);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.shape='DISK';lamp.data.size=size;lamp.rotation_euler=(Vector((0,0,-.4))-lamp.location).to_track_quat('-Z','Y').to_euler()
views=[]
requested=os.environ.get('FIXED_LIGHTING_RENDER_IDS','').split(',')
for row in plan['variants']:
 identity=row['id']
 if requested!=[''] and identity not in requested:continue
 selected=[o for o in draws if o.name.startswith(identity+'__')]
 for obj in draws:obj.hide_render=obj not in selected
 points=[o.matrix_world@v.co for o in selected for v in o.data.vertices]
 low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
 center=(low+high)*.5;span=max(high-low)
 direction=Vector((1.8,-3.,-.9)).normalized() if row['kind']=='sconce_globe' else Vector((1.8,3.,-1.5)).normalized()
 bpy.ops.object.camera_add(location=center+direction*max(span*2.6,.25));camera=bpy.context.object;camera.data.lens=48;camera.data.clip_start=.001
 camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 scene.render.filepath=str(out/(identity+'.png'));bpy.ops.render.render(write_still=True)
 views.append({'id':identity,'file':identity+'.png','source':row['source_id'],'state':'neutral unpowered stock'})
 bpy.data.objects.remove(camera,do_unlink=True)
(out/'views.json').write_text(json.dumps({'evidence_class':'INERT','views':views,'scope':'Native form and finish review only. Powered production views and all supports remain separate.'},indent=2)+'\n',encoding='utf-8',newline='\n')
