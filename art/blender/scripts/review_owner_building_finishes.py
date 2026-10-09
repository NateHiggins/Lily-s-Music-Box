"""Neutral material comparison on exact retained native geometry; no exports."""
from pathlib import Path
import hashlib,json,sys
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from owner_finish_materials import apply_current
out=ROOT/'tmp/v2-improvement/building-native';out.mkdir(parents=True,exist_ok=True)
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
reviews=[]
for family,group in [('front_facade','facade'),('roof_membrane','roof'),('roof_ventilator','roof'),('city_tanks','skyline'),('city_aerials','skyline'),('lift_joinery','lift'),('lift_handrails','lift')]:
 asset=ROOT/'art/blender'/f'{family}.blend';bpy.ops.wm.open_mainfile(filepath=str(asset));scene=bpy.context.scene
 # Older native shape studies have no maps; bind the same registered keys as
 # their runtime adapters, using existing metre charts rather than projection.
 for mat in bpy.data.materials:
  if family=='roof_ventilator' and mat.name=='enamel':mat.name='trim.panel'
  key=mat.name.removeprefix('M_').split('.')[0]
  if mat.library is not None or not mat.use_nodes:continue
  nodes=mat.node_tree.nodes;links=mat.node_tree.links;bsdf=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
  if not bsdf:continue
  if key=='limestone_b':
   mat.name='limestone';key='limestone'
   for n in nodes:
    if n.type=='TEX_IMAGE' and n.image and 'limestone_b' in n.image.filepath:
     suffix={'albedo.png':'albedo','roughness.png':'rough','normal.png':'normal'}.get(Path(n.image.filepath).name)
     if suffix:n.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/f'T_ai_materials_limestone_b_{suffix}.png'),check_existing=True)
  if key not in catalog or not all(catalog[key]['files']) or any(n.type=='TEX_IMAGE' and n.image for n in nodes):continue
  uv=nodes.new('ShaderNodeTexCoord');scale=nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/catalog[key]['meters_per_tile'];links.new(uv.outputs['UV'],scale.inputs[0])
  for i,socket in enumerate(['Base Color','Roughness','Normal']):
   tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/catalog[key]['files'][i]),check_existing=True);links.new(scale.outputs[0],tex.inputs['Vector'])
   if i:tex.image.colorspace_settings.name='Non-Color'
   if i==2:
    normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35;links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bsdf.inputs[socket])
   else:links.new(tex.outputs['Color'],bsdf.inputs[socket])
 changed=apply_current(group)
 if family=='roof_ventilator':
  for mat in bpy.data.materials:
   if mat.library is not None or mat.name.split('.')[0]!='trim' or not mat.use_nodes:continue
   nodes=mat.node_tree.nodes;links=mat.node_tree.links;bsdf=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
   rgb=(.44,.44,.40) if mat.name=='trim.panel' else (.39,.40,.38)
   tint=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
   source=bsdf.inputs['Base Color'].links[0].from_socket;mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=tint;links.new(source,mix.inputs[1]);links.new(mix.outputs[0],bsdf.inputs['Base Color'])
 scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1200;scene.render.resolution_y=850;scene.render.resolution_percentage=100
 scene.world=bpy.data.worlds.new('Neutral inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.48,.52,.57,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
 for o in list(scene.objects):
  if o.type in ['CAMERA','LIGHT']:bpy.data.objects.remove(o,do_unlink=True)
 draws=[o for o in scene.objects if o.type=='MESH' and not o.hide_render and not any(c.hide_render for c in o.users_collection) and o.library is None]
 if family in ['city_tanks','city_aerials']:
  fixture=json.loads((ROOT/'game/tests/fixtures'/f'orison_{family}.json').read_text());identity=next(k for k,v in fixture['assemblies'].items() if v['kind']==('dish' if family=='city_aerials' else 'stave_tank'));selected=[o for o in draws if o.name.startswith(identity+'__')]
 elif family=='front_facade':
  identity='entrance and adjacent stone';selected=[o for o in draws if o.name.startswith(('EntryLeaf','FixedFacade')) and o.bound_box and abs((o.matrix_world@Vector(o.bound_box[0])).x)<4]
 else:identity=family;selected=draws
 assert selected,(family,[o.name for o in draws][:12])
 for o in scene.objects:
  if o.type=='MESH':o.hide_render=o not in selected
 corners=[o.matrix_world@Vector(v) for o in selected for v in o.bound_box];low=Vector([min(v[i] for v in corners) for i in range(3)]);high=Vector([max(v[i] for v in corners) for i in range(3)]);center=(low+high)*.5;span=max(high-low)
 direction=Vector((1.3,-2,1.2)).normalized()
 if family.startswith('lift'):direction=Vector((.15,-2,1.0)).normalized()
 bpy.ops.object.camera_add(location=center+direction*max(span*2,.45));cam=bpy.context.object;cam.data.lens=50;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam
 for attempt in range(80):
  bpy.context.view_layer.update();projected=[world_to_camera_view(scene,cam,v) for v in corners]
  if all(.05<v.x<.95 and .05<v.y<.95 and v.z>0 for v in projected):break
  cam.location=center+(cam.location-center)*1.06
 else:raise AssertionError(('unframed',family))
 for offset,power,size in [(Vector((-1,-1,2)),190,1.5),(Vector((1,1,1)),110,1.)]:
  bpy.ops.object.light_add(type='AREA',location=center+offset*max(span,.5));light=bpy.context.object;light.data.energy=power*max(span,.5)**2;light.data.shape='DISK';light.data.size=size*max(span,.5);light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
 filename=family+'.png';scene.render.filepath=str(out/filename);bpy.ops.render.render(write_still=True)
 reviews.append(dict(family=family,identity=identity,file=filename,changed_materials=changed,native_sha256=hashlib.sha256(asset.read_bytes()).hexdigest(),eye=list(cam.location),target=list(center),scope='Neutral base-finish/native form; source-local weather masks and full assembly verified in Godot.'))
(out/'review.json').write_text(json.dumps(dict(evidence_class='INERT',views=reviews,profile_sha256=hashlib.sha256((ROOT/'game/data/orison_v2/owner_finish_profiles.json').read_bytes()).hexdigest()),indent=2)+'\n',encoding='utf-8',newline='\n')
