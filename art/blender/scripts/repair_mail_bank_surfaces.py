"""Isolated metric UV/tangent repair; current stock geometry and mail owners stay."""
from pathlib import Path
import sys,json,struct,ast,math,hashlib,bpy,numpy as np
sys.dont_write_bytecode=True
from mathutils import Vector,Matrix
R=Path('C:/PleaseRemainOnTheLine');O=Path(__file__).resolve().parent;baseline=O/'baseline';baseline.mkdir(exist_ok=True)
if not (baseline/'INPUTS.json').exists():
 rows=[]
 for relative in ['art/blender/mail_bank.blend','game/assets/props/mail_bank.glb']:
  target=baseline/Path(relative).name;target.write_bytes((R/relative).read_bytes());rows.append({'canonical_source':relative,'file':target.name,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
 (baseline/'INPUTS.json').write_text(json.dumps({'evidence_class':'INERT','files':rows},indent=2)+'\n')
snapshots=json.loads((baseline/'INPUTS.json').read_text())['files']
for row in snapshots:assert hashlib.sha256((baseline/row['file']).read_bytes()).hexdigest()==row['sha256']
sys.path.insert(0,str(R/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
from metric_gltf_export import CatalogueMetricUV
source=Path('C:/ov/asset-prototypes/bath-lavatory-v2-refit-20261101/verify_export.py');tree=ast.parse(source.read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='read'],type_ignores=[]),str(source),'exec'))
def p(v):return (v[0],-v[2],v[1])
def g(v):return (v[0],v[2],-v[1])
bpy.ops.wm.open_mainfile(filepath=str(baseline/'mail_bank.blend'));bpy.context.preferences.filepaths.save_version=0;scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
raw=bpy.data.collections.new('00_EDITABLE_ORIGINAL_STOCKS');scene.collection.children.link(raw);oldstocks=list(scene.objects)
for ob in oldstocks:
 for col in list(ob.users_collection):col.objects.unlink(ob)
 raw.objects.link(ob);ob['stock_name']=ob.name;ob.name='OriginalStock__'+ob.name
bpy.context.view_layer.update()
catalog=json.loads((R/'game/data/runtime_material_sets.json').read_text())['materials'];materials={};bindings={}
for key in ['brass_dull','iron_blackened','wood_dark','nickel_plated','paper']:
 spec=dict(catalog[key]);spec['files']=list(spec['files']);normal=.035 if key in ['brass_dull','nickel_plated'] else .10;rough=.90 if key=='paper' else .52 if key=='wood_dark' else .65 if key=='iron_blackened' else .50
 if key=='brass_dull':spec['files'][:2]=['mailbank/T_mailbank_brass_albedo.png','mailbank/T_mailbank_brass_rough.png'];spec['meters_per_tile']=.35;spec['metallic']=.55
 mat=bpy.data.materials[key];mat.use_nodes=True;nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=nodes['Principled BSDF'];bs.inputs['Metallic'].default_value=spec['metallic'];bs.inputs['Roughness'].default_value=rough;coord=nodes.new('ShaderNodeTexCoord');scale=nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];links.new(coord.outputs['UV'],scale.inputs[0])
 for index,target in enumerate(['Base Color','Roughness','Normal']):
  image=bpy.data.images.load(str(R/'game/assets/building/textures'/spec['files'][index]),check_existing=True)
  if index:image.colorspace_settings.name='Non-Color'
  tex=nodes.new('ShaderNodeTexImage');tex.image=image;links.new(scale.outputs[0],tex.inputs['Vector'])
  if index==0:links.new(tex.outputs['Color'],bs.inputs[target])
  elif index==1:
   mult=nodes.new('ShaderNodeMath');mult.operation='MULTIPLY';mult.inputs[1].default_value=rough;links.new(tex.outputs['Color'],mult.inputs[0]);links.new(mult.outputs[0],bs.inputs[target])
  else:
   n=nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=normal;links.new(tex.outputs['Color'],n.inputs['Color']);links.new(n.outputs[0],bs.inputs[target])
 materials[key]=mat;bindings[key]={'files':spec['files'],'tile_m':spec['meters_per_tile'],'metallic':spec['metallic'],'roughness':rough,'normal':normal,'source':'Current orison_v2_native_mail_bank.gd local finish and retained bank brass recipe.'}
horizontal={'TimberHeaderRail','TimberCrown'}
for ob in oldstocks:
 if ob.type!='MESH':continue
 assert all(len(f.vertices)==3 for f in ob.data.polygons),ob.name
 uv=ob.data.uv_layers.active;uv.active_render=True
 for face in ob.data.polygons:
  _,_,q,_=chart_for_triangle(np.asarray([ob.matrix_world@ob.data.vertices[i].co for i in face.vertices]),np.zeros(3),bindings[ob.data.materials[0].name]['tile_m'],long_grain=ob['stock_name'] in horizontal)
  for loop,value in zip(face.loop_indices,q):uv.data[loop].uv=value
raw.hide_render=True;raw.hide_viewport=True
col=bpy.data.collections.new('01_MAIL_STOCK_EXPORT');scene.collection.children.link(col);doc,array=read(baseline/'mail_bank.glb');stocks={};parts=[]
for node in doc['nodes']:
 assert node.get('translation',[0,0,0])==[0,0,0] and node.get('rotation',[0,0,0,1])==[0,0,0,1] and node.get('scale',[1,1,1])==[1,1,1]
 name=node['name'];prim=doc['meshes'][node['mesh']]['primitives'][0];at=prim['attributes'];assert set(at)=={'POSITION','NORMAL','TEXCOORD_0'}
 key=doc['materials'][prim['material']]['name'];pos=array(at['POSITION']);normal=array(at['NORMAL']);indices=array(prim['indices']).astype(int).reshape(-1,3);vv=[];ff=[];ns=[];source_ns=[];uvs=[];guide=[]
 for tri in indices:
  pp=np.asarray([p(v) for v in pos[tri]]);_,t,q,_=chart_for_triangle(pp,np.zeros(3),bindings[key]['tile_m'],long_grain=name in horizontal);base=len(vv);vv.extend(pp);ff.append((base,base+1,base+2));ns.extend(p(v) for v in normal[tri]);source_ns.extend(normal[tri]);uvs.extend(q);guide.extend([g(t)]*3)
 data=bpy.data.meshes.new(name);data.from_pydata(vv,[],ff);data.materials.append(materials[key]);data.update();data.normals_split_custom_set(ns);uv=data.uv_layers.new(name='Metres');uv.data.foreach_set('uv',np.asarray(uvs,dtype=np.float32).ravel())
 for attr,values in [('_METRE_UV',np.column_stack((uvs,np.zeros(len(uvs))))),('_TANGENT_GUIDE',guide),('_SOURCE_NORMAL',source_ns)]:
  a=data.attributes.new(attr,'FLOAT_VECTOR','CORNER');a.data.foreach_set('vector',np.asarray(values,dtype=np.float32).ravel())
 ob=bpy.data.objects.new(name,data);col.objects.link(ob);stocks[name]=ob;parts.append({'name':name,'material_key':key,'triangles':len(ff),'grain':'horizontal' if name in horizontal else 'vertical' if key=='wood_dark' else 'nondirectional'})
class PreserveNormals(CatalogueMetricUV):
 def gather_mesh_hook(self,mesh,*args):
  from io_scene_gltf2.io.exp.binary_data import BinaryData
  from io_scene_gltf2.io.com.constants import BufferViewTarget
  for prim in mesh.primitives:
   original=prim.attributes.pop('_SOURCE_NORMAL');prim.attributes['NORMAL'].buffer_view=BinaryData(original.buffer_view.data,BufferViewTarget.ARRAY_BUFFER)
  super().gather_mesh_hook(mesh,*args)
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=PreserveNormals
bpy.ops.object.select_all(action='DESELECT')
for ob in col.objects:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'mail_bank_v2.glb'),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='EXPORT',export_animations=False)
col.hide_render=True;col.hide_viewport=True
review=bpy.data.collections.new('02_ASSEMBLED_REVIEW_ONLY');scene.collection.children.link(review)
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));made=[]
# Inspected source review functions only; exclude its repo-writing entry point.
review_source=R/'art/blender/scripts/review_mail_bank.py';tree=ast.parse(review_source.read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['part','leaf','assemble']],type_ignores=[]),str(review_source),'exec'))
def assemble_review(opened,contents=False):
 assemble(opened)
 if contents:
  part('EnvelopeStock',(-.135,1.34975,-.063));part('WorkOrderStock',(-.222,1.399,-.063));part('ParcelStock',(-.145,1.3915,-.049));part('ParcelBand',(-.145,1.3915,-.049))
 for ob in made:
  for collection in list(ob.users_collection):collection.objects.unlink(ob)
  review.objects.link(ob)
 wall=made[-5] if contents else made[-1];assert wall.type=='MESH' and wall.name.startswith('Cube')
 wall.location.y=-.01;mat=wall.data.materials[0];mat.use_nodes=True;mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.07,.10,.12,1);mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.75
 bpy.context.view_layer.update()
lighting=bpy.data.collections.new('03_REVIEW_CAMERA_LIGHTS');scene.collection.children.link(lighting)
for at,power in [((1,2,2.5),180),((-1,.8,1.5),80)]:
 data=bpy.data.lights.new('REVIEW_SOFTBOX','AREA');data.energy=power;data.size=1;ob=bpy.data.objects.new('REVIEW_SOFTBOX',data);lighting.objects.link(ob);ob.location=at;ob.rotation_euler=(Vector((0,.1,1.25))-ob.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('REVIEW_CAMERA');camera=bpy.data.objects.new('REVIEW_CAMERA',data);lighting.objects.link(camera);scene.camera=camera;data.type='ORTHO';data.clip_start=.003
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=12;scene.render.threads_mode='FIXED';scene.render.threads=2;scene.render.resolution_x=900;scene.render.resolution_y=750;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.world=bpy.data.worlds.new('Mail stock studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.3,.35,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
assemble_review(False);camera.location=(.8,2.1,1.65);camera.rotation_euler=(Vector((0,.09,1.24))-camera.location).to_track_quat('-Z','Y').to_euler();data.ortho_scale=1.7
sources=['game/scripts/props/mail_bank_prop.gd','game/scripts/props/mail_bank_hand_controls.gd','game/scripts/building/orison_v2_native_mail_bank.gd','game/scripts/props/static_mesh_batcher.gd','art/blender/scripts/build_mail_bank.py','art/blender/scripts/review_mail_bank.py','game/data/runtime_material_sets.json']
report={'evidence_class':'INERT','parts':parts,'stock_count':len(parts),'triangles':sum(r['triangles'] for r in parts),'bindings':bindings,'geometry_baselines':snapshots,'source_hashes':{path:hashlib.sha256((R/path).read_bytes()).hexdigest() for path in sources},'scope':'20 reusable visual stock templates only. Current runtime bank layout/cards/header lettering/hinges/contents/custody/save owners remain unchanged. Review copies and wall are excluded from export.'}
(O/'construction.json').write_text(json.dumps(report,indent=2)+'\n');bpy.ops.wm.save_as_mainfile(filepath=str(O/'mail_bank_surface_refit.blend'))
for label,opened,contents,at,target,scale in [('01_closed_bank',False,False,(.8,2.1,1.65),(0,.09,1.24),1.70),('02_player_door_open',True,False,(.65,1.8,1.60),(0,.1,1.30),1.52),('03_pocket_and_lock',True,False,(-.6,1.2,1.6),(-.155,.1,1.40),.52),('04_delivery_stock',True,True,(-.6,1.2,1.6),(-.155,.1,1.40),.52)]:
 if '--no-render' in sys.argv:break
 assemble_review(opened,contents);camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();data.ortho_scale=scale;scene.render.filepath=str(O/(label+'.png'));bpy.ops.render.render(write_still=True)
print('MAIL_SURFACE_REPAIR_READY',len(parts),'templates;',report['triangles'],'triangles')
