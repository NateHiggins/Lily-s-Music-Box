"""Isolated watch-stock surface candidate from frozen installed float32 geometry."""
from pathlib import Path
import sys,json,struct,ast,math,hashlib
sys.dont_write_bytecode=True
import bpy,numpy as np
from mathutils import Vector,Matrix
R=Path('C:/PleaseRemainOnTheLine');O=Path(__file__).resolve().parent;B=O/'baseline'
inputs=json.loads((B/'INPUTS.json').read_text(encoding='utf-8'))
for r in inputs['files']:assert hashlib.sha256((B/r['file']).read_bytes()).hexdigest()==r['sha256']
sys.path.insert(0,str(R/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
from metric_gltf_export import CatalogueMetricUV
source=Path(__file__).with_name('refit_verify_export.py');tree=ast.parse(source.read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='read'],type_ignores=[]),str(source),'exec'))
def b(v):return (v[0],-v[2],v[1])
def g(v):return (v[0],v[2],-v[1])
bpy.ops.wm.open_mainfile(filepath=str(B/'watch_stations.blend'));bpy.context.preferences.filepaths.save_version=0;s=bpy.context.scene;s.unit_settings.system='METRIC';s.unit_settings.scale_length=1
raw=bpy.data.collections.new('00_ORIGINAL_CLOSED_STOCK_REFERENCE');s.collection.children.link(raw)
for o in list(s.objects):
 for c in list(o.users_collection):c.objects.unlink(o)
 raw.objects.link(o);o['original_stock_name']=o.name;o.name='OriginalStock__'+o.name
raw.hide_render=True;raw.hide_viewport=True
cat=json.loads((B/'runtime_material_sets.json').read_text(encoding='utf-8'))['materials'];materials={};bindings={}
for key in ['iron_neutral','washer_brass','enamel_appliance','indicator_enamel','iron_blackened']:
 spec=cat[key];m=bpy.data.materials[key];m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;p=n['Principled BSDF'];p.inputs['Metallic'].default_value=spec['metallic'];coord=n.new('ShaderNodeTexCoord');scale=n.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];l.new(coord.outputs['UV'],scale.inputs[0])
 for i,socket in enumerate(['Base Color','Roughness','Normal']):
  tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(R/'game/assets/building/textures'/spec['files'][i]),check_existing=True)
  if i:tex.image.colorspace_settings.name='Non-Color'
  l.new(scale.outputs[0],tex.inputs['Vector'])
  if i==2:
   nm=n.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.25;l.new(tex.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs[0],p.inputs[socket])
  else:l.new(tex.outputs['Color'],p.inputs[socket])
 materials[key]=m;bindings[key]={'files':spec['files'],'tile_m':spec['meters_per_tile'],'metallic':spec['metallic'],'preview_normal_strength':.25,'preview_only':'Existing source review convention; live runtime tint/roughness and optical shader remain authoritative.'}
sys.path.insert(0,str(O));from repair_topology import clean,rebuild_case
col=bpy.data.collections.new('01_WATCH_STOCK_EXPORT');s.collection.children.link(col);stocks={};rows=[]
baseline_doc,baseline_array=read(B/'watch_stations.glb');source_normals={}
for node in baseline_doc['nodes']:
 prim=baseline_doc['meshes'][node['mesh']]['primitives'][0];at=prim['attributes'];pp=baseline_array(at['POSITION']);norm=baseline_array(at['NORMAL']);index=baseline_array(prim['indices']).astype(int).reshape(-1,3);lookup={}
 for tri in index:
  for shift in range(3):
   order=np.roll(tri,shift);lookup[tuple(tuple(p) for p in pp[order])]=norm[order]
 source_normals[node['name']]=lookup
for original in list(raw.objects):
 if original.type!='MESH':continue
 name=original['original_stock_name'];key=original.data.materials[0].name;ob=bpy.data.objects.new(name,original.data.copy());col.objects.link(ob)
 if name=='StationCase':rebuild_case(ob)
 result=clean(ob.data,bindings[key]['tile_m']);assert result['remaining']==0 and result['nonmanifold']==0 and result['volume']>0,(name,result)
 data=ob.data;data.materials.clear();data.materials.append(materials[key]);nn=[];sn=[];uvs=[];guides=[];preserved_normals=0;repaired_normals=0
 for face in data.polygons:
  assert len(face.vertices)==3
  pp=np.array([data.vertices[i].co for i in face.vertices]);n,u,q,_=chart_for_triangle(pp,np.zeros(3),bindings[key]['tile_m']);keypoints=tuple(tuple(g(p)) for p in pp);oldnorm=source_normals[name].get(keypoints)
  for corner in range(3):
   normal=np.array(g(n))
   if oldnorm is not None:
    length=np.linalg.norm(oldnorm[corner]);agreement=np.dot(oldnorm[corner],normal)
    if .999<length<1.001 and agreement>=.01:normal=oldnorm[corner];preserved_normals+=1
    else:repaired_normals+=1
   sn.append(normal);nn.append(b(normal))
  uvs.extend(q);guides.extend([g(u)]*3)
 data.normals_split_custom_set(nn)
 for layer in list(data.uv_layers):data.uv_layers.remove(layer)
 uv=data.uv_layers.new(name='Metres');uv.data.foreach_set('uv',np.asarray(uvs,dtype=np.float32).ravel())
 for label,values in [('_METRE_UV',np.column_stack((uvs,np.zeros(len(uvs))))),('_TANGENT_GUIDE',guides),('_SOURCE_NORMAL',sn)]:
  att=data.attributes.new(label,'FLOAT_VECTOR','CORNER');att.data.foreach_set('vector',np.asarray(values,dtype=np.float32).ravel())
 stocks[name]=ob;rows.append({'name':name,'material_key':key,'triangles':len(data.polygons),'native_repair':result,'case_rebuilt':name=='StationCase','preserved_matching_source_corner_normals':preserved_normals,'repaired_invalid_or_reversed_matching_corner_normals':repaired_normals})
class PreserveNormals(CatalogueMetricUV):
 def gather_mesh_hook(self,mesh,*args):
  from io_scene_gltf2.io.exp.binary_data import BinaryData
  from io_scene_gltf2.io.com.constants import BufferViewTarget
  for prim in mesh.primitives:
   old=prim.attributes.pop('_SOURCE_NORMAL');prim.attributes['NORMAL'].buffer_view=BinaryData(old.buffer_view.data,BufferViewTarget.ARRAY_BUFFER)
  super().gather_mesh_hook(mesh,*args)
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=PreserveNormals
bpy.ops.object.select_all(action='DESELECT')
for ob in col.objects:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'watch_stations.glb'),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='EXPORT',export_animations=False)
col.hide_render=True;col.hide_viewport=True
review=bpy.data.collections.new('02_ASSEMBLED_REVIEW_ONLY');s.collection.children.link(review);made=[];C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
tree=ast.parse((B/'review_watch_stations.py').read_text(encoding='utf-8'));exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['pose','part','assemble']],type_ignores=[]),'frozen_review_functions','exec'))
# Source assembler's diagnostic glass is retained for form review only. Runtime owns its registered optical shader.
source_assemble=assemble
def review_pose(opened,marked=False,crank_angle=0):
 source_assemble(opened,marked,crank_angle)
 if opened:
  # Current runtime owner opens to 1.65 rad, beyond the older review's 1.15.
  old=C@pose((-.108,.160,.118),angle=-1.15)@C.inverted();new=C@pose((-.108,.160,.118),angle=-1.65)@C.inverted()
  for ob in made:
   if ob.name.split('.')[0] in ['DoorLeaf','DoorSash','StationPlate','LatchSpring','DoorHandle','HingeBarrel'] or ob.name.startswith('Cube'):ob.matrix_world=new@old.inverted()@ob.matrix_world
 for ob in made:
  for c in list(ob.users_collection):c.objects.unlink(ob)
  review.objects.link(ob)
 bpy.context.view_layer.update()
lighting=bpy.data.collections.new('03_REVIEW_CAMERA_LIGHTS');s.collection.children.link(lighting)
for at,power in [((.6,-1,.9),30),((-.6,-.4,.5),15)]:
 d=bpy.data.lights.new('REVIEW_SOFTBOX','AREA');d.energy=power;d.size=.6;o=bpy.data.objects.new('REVIEW_SOFTBOX',d);lighting.objects.link(o);o.location=at;o.rotation_euler=(Vector((0,-.05,.18))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('REVIEW_CAMERA');camera=bpy.data.objects.new('REVIEW_CAMERA',d);lighting.objects.link(camera);d.type='ORTHO';d.clip_start=.001;s.camera=camera;s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=12;s.render.threads_mode='FIXED';s.render.threads=2;s.render.resolution_x=850;s.render.resolution_y=750;s.render.resolution_percentage=100;s.world=bpy.data.worlds.new('Watch stock studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.22,.27,.32,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.35
review_pose(True);camera.location=(.48,-.85,.48);camera.rotation_euler=(Vector((-.01,-.04,.18))-camera.location).to_track_quat('-Z','Y').to_euler();d.ortho_scale=.52
(O/'construction.json').write_text(json.dumps({'evidence_class':'INERT','inputs':inputs,'parts':rows,'triangles':sum(r['triangles'] for r in rows),'bindings':bindings,'scope':'29 closed editable stock templates. Original native stocks retained as reference. Single hollow case casting retains outer envelope, cavity floor and hinge datums, with a 1.5 mm hinge-side front setback and internal crank recess. Three other stocks receive local topology repair. Per-corner metre charts; valid source normals retained, grazing/reversed normals repaired. Runtime mechanism authority and optical shader remain unchanged.'},indent=2),encoding='utf-8');bpy.ops.wm.save_as_mainfile(filepath=str(O/'watch_station_surface_refit.blend'))
if '--no-render' not in sys.argv:
 for label,opened,marked,angle,at,target,scale in [('01_closed',False,False,0,(.45,-.9,.45),(0,-.05,.18),.49),('02_open_ready',True,False,0,(.48,-.85,.48),(-.01,-.04,.18),.52),('03_transmission',True,False,math.pi,(.18,-.8,.35),(.01,-.045,.17),.31),('04_marked',True,True,math.tau,(.48,-.85,.48),(-.01,-.04,.18),.52)]:
  review_pose(opened,marked,angle);camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();d.ortho_scale=scale;s.render.filepath=str(O/(label+'.png'));bpy.ops.render.render(write_still=True)
print('WATCH_SURFACE_READY',len(rows),sum(r['triangles'] for r in rows))
