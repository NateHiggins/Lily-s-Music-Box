"""Lit native-stock review, assembled in original maintenance-owner frames."""
from pathlib import Path
import json,math
import bpy
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'tmp/v2-fire-service-20261011/blender';OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/fire_service.blend'))
stocks={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
data=json.loads((ROOT/'game/data/orison_v2/fire_service.json').read_text(encoding='utf-8'))
cat=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
for spec in data['materials']:
 mat=bpy.data.materials[spec['key']];p=mat.node_tree.nodes['Principled BSDF']
 p.inputs['Metallic'].default_value=spec['metallic'];p.inputs['Roughness'].default_value=spec['roughness']
 files=list(cat[spec['catalog']]['files'])
 if spec['key']=='Brass':files[:2]=['mailbank/T_mailbank_brass_albedo.png','mailbank/T_mailbank_brass_rough.png']
 for i,socket in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
  t=mat.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/files[i]),check_existing=True)
  if i:t.image.colorspace_settings.name='Non-Color'
  if i==2:
   n=mat.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=spec['normal'];mat.node_tree.links.new(t.outputs['Color'],n.inputs['Color']);mat.node_tree.links.new(n.outputs['Normal'],p.inputs[socket])
  elif i==0:
   mix=mat.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=spec['tint'];mat.node_tree.links.new(t.outputs['Color'],mix.inputs[1]);mat.node_tree.links.new(mix.outputs[0],p.inputs[socket])
  else:mat.node_tree.links.new(t.outputs['Color'],p.inputs[socket])
for o in stocks.values():
 o.hide_render=True
 tile=next(r['tile'] for r in data['materials'] if r['key']==o.data.materials[0].name)
 for loop in o.data.uv_layers.active.data:loop.uv/=tile
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));made=[]
def part(key,pose):
 o=stocks[key].copy();bpy.context.collection.objects.link(o);o.hide_render=False;o.matrix_world=C@pose@C.inverted();made.append(o);return o
def assemble(opened):
 for o in made:bpy.data.objects.remove(o,do_unlink=True)
 made.clear()
 for p in json.loads((ROOT/'art/data/fire_service/source_plan.json').read_text(encoding='utf-8'))['parts']:
  i=p['index']
  if i in [0,57,58]:continue
  basis=p['pose_basis'];pose=Matrix([[basis[col][row] for col in range(3)]+[p['pose_position'][row]] for row in range(3)]+[[0,0,0,1]])
  if i>=65 and opened:
   pivot=Matrix.Translation(Vector((.305,.390,.206)));pose=pivot@Matrix.Rotation(1.78,4,'Y')@pivot.inverted()@pose
  part(f'F{i:03d}',pose)
  if p['name'].startswith('Fold_'):part('FoldCrown',pose@Matrix.Translation(Vector((0,.131,0))))
 part('HoseLead00',Matrix.Identity(4));part('HoseTail00',Matrix.Identity(4))
 part('StationTee',Matrix.Translation(Vector((.540,.350,.140))))
 o=part('PipeUnit',Matrix.Translation(Vector((.540,.390,.140))));o.scale.z=1.25
 for y in [-.04,.94]:part('WallSaddle',Matrix.Translation(Vector((.540,y,.140))))
for at,power in [((1,-1.5,2),200),((-1,-.5,1.5),80)]:
 d=bpy.data.lights.new('Softbox','AREA');d.energy=power;d.size=1;o=bpy.data.objects.new('Softbox',d);bpy.context.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector((.15,-.1,.4))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('Review');camera=bpy.data.objects.new('Review',d);bpy.context.collection.objects.link(camera)
s=bpy.context.scene;s.camera=camera;s.render.engine='CYCLES';s.cycles.samples=24;s.render.resolution_x=1100;s.render.resolution_y=1000;s.render.resolution_percentage=100
s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.12,.12,1)
for label,opened,at,target,scale in [('closed',False,(1,-2,1.15),(.18,-.1,.4),1.35),('open',True,(-.55,-1.8,1.1),(.08,-.1,.4),1.3),('hose_detail',True,(-.28,-1.2,.54),(-.1,-.1,.25),.55),('branch_detail',True,(1,-1,.8),(.36,-.1,.5),.62)]:
 assemble(opened);camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=scale
 s.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
