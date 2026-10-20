"""Native source-stock/UV review and five period table/tool views."""
from pathlib import Path
import json,math
import bpy,bmesh
from mathutils import Vector
r=Path(__file__).resolve().parents[3];out=r/'tmp/v2-kitchen-prep-20261019/native';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/kitchen_prep_stations.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral inspection');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.6,.65,.7,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
for at,power,size in [((1.7,-2.,3.),200,2.),((-1.7,1.,2.5),125,1.8)]:
 bpy.ops.object.light_add(type='AREA',location=at);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
draws=[o for o in scene.objects if o.type=='MESH' and '__' in o.name]
plan=json.loads((r/'art/data/kitchen_prep/source_plan.json').read_text());rows=[]
for identity in [x['id'] for x in plan['templates']]+['Tools']:
 selected=[o for o in draws if o.name.startswith(identity+'__') or (identity=='Tools' and o.name.split('__')[0] in ['Breadboard','RollingPin','SinkBridge','MixingBowl'])]
 for o in draws:o.hide_render=o not in selected
 if identity=='Tools':
  for o in selected:
   if o.name.startswith('Breadboard'):o.location.y=-.5
   elif o.name.startswith('RollingPin'):o.location.y=-.5;o.location.z=.05
   elif o.name.startswith('MixingBowl'):o.location.y=.45
 bpy.context.view_layer.update();points=[o.matrix_world@v.co for o in selected for v in o.data.vertices]
 lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)));center=(lo+hi)*.5
 bpy.ops.object.camera_add(location=center+Vector((1.2,-1.7,1.3)).normalized()*max(hi-lo)*2.5);cam=bpy.context.object;cam.data.lens=50;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam
 scene.render.filepath=str(out/(identity+'.png'));bpy.ops.render.render(write_still=True);bpy.data.objects.remove(cam,do_unlink=True)
 rows.append({'id':identity,'file':identity+'.png'})
(out/'review.json').write_text(json.dumps({'evidence_class':'INERT','views':rows},indent=2)+'\n')
