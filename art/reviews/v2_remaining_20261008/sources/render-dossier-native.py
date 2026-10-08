from pathlib import Path
import bpy,json,hashlib,math
from mathutils import Vector
R=Path('C:/PleaseRemainOnTheLine');O=R/'tmp/v2-finish-review/dossier-native';O.mkdir(exist_ok=True)
jobs=[('city_tanks','site_back_e__Tank',[(1.6,-2.8,1.5)]),('city_aerials','site_back_e__Dish',[(1.6,-2.8,1.2),(-1.6,2.8,1.2)]),('roof_membrane','ROOF_DECK_EAST__RollFinish',[(1.,-1.,2.0)]),('front_facade','',[(.25,-1.,.2)]),('lift_joinery','',[(1.8,-3.,1.4)])]
results=[]
for name,prefix,directions in jobs:
 path=R/'art/blender'/f'{name}.blend';bpy.ops.wm.open_mainfile(filepath=str(path));scene=bpy.context.scene
 def collection_hidden(o):return any(c.hide_render for c in o.users_collection)
 selected=[o for o in scene.objects if o.type=='MESH' and not o.hide_render and not collection_hidden(o) and o.name.startswith(prefix)]
 # Current exported stock is shown; hidden source references remain hidden.
 for o in scene.objects:
  if o.type=='MESH':o.hide_render=o not in selected
  if o.type in ['LIGHT','CAMERA']:o.hide_render=True
 points=[o.matrix_world@v.co for o in selected for v in o.data.vertices];assert points,name
 lo=Vector(tuple(min(v[i] for v in points) for i in range(3)));hi=Vector(tuple(max(v[i] for v in points) for i in range(3)));center=(lo+hi)/2;span=max(hi-lo)
 scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
 scene.render.resolution_x=1400;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
 scene.world=bpy.data.worlds.new('Dossier neutral lighting');scene.world.use_nodes=True
 scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.6,.65,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
 for direction,power in [((1,-2,3),550),((-2,1,2),250)]:
  bpy.ops.object.light_add(type='AREA',location=center+Vector(direction)*span)
  lamp=bpy.context.object;lamp.data.energy=power*span*span;lamp.data.shape='DISK';lamp.data.size=span*2.;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
 for i,direction in enumerate(directions):
  bpy.ops.object.camera_add(location=center+Vector(direction).normalized()*max(span*3.,1.));camera=bpy.context.object
  camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.clip_end=max(1000,span*20)
  inv=camera.matrix_world.inverted();bpy.context.view_layer.update();inv=camera.matrix_world.inverted()
  projected=[inv@v for v in points];width=max(v.x for v in projected)-min(v.x for v in projected);height=max(v.y for v in projected)-min(v.y for v in projected)
  camera.data.ortho_scale=max(width,height*1400/1100)*1.15;scene.camera=camera
  file=f'{name}_{i}.png';scene.render.filepath=str(O/file);bpy.ops.render.render(write_still=True)
  results.append({'family':name,'selection':prefix or 'visible native scene','source':path.relative_to(R).as_posix(),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'file':file,'objects':[o.name for o in selected]})
(O/'manifest.json').write_text(json.dumps({'evidence_class':'INERT','scope':'Current native files rendered without asset changes; neutral study lighting, no production-light acceptance.','images':results},indent=2)+'\n')
