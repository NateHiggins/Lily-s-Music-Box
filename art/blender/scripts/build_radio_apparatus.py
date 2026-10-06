"""Original radio test instruments and an open-back set with seated valves."""
from pathlib import Path
import collections,hashlib,json,math,re,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
import os
OUT=Path(os.environ.get('RADIO_APPARATUS_OUT',str(ROOT)))
plan_path=Path(os.environ.get('RADIO_APPARATUS_PLAN',str(ROOT/'art/data/radio_apparatus/source_plan.json')));layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text(encoding='utf-8'));layout=json.loads(layout_path.read_text(encoding='utf-8'));assert plan['classification']=='ADAPTATION'
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_radio_service.gltf';source_gltf=json.loads(source_gltf_path.read_text(encoding='utf-8'));sets={};material_definitions=[]
catalog_path=Path(os.environ.get('RADIO_APPARATUS_CATALOG',str(ROOT/'game/data/runtime_material_sets.json')));catalog=json.loads(catalog_path.read_text(encoding='utf-8'))['materials']
for key in plan['runtime_keys']:
 if key in plan['catalog_variants']:
  spec=catalog[plan['catalog_variants'][key]];sets[key]={'files':spec['files'],'meters_per_tile':spec['meters_per_tile'],'metallic':spec['metallic'],'normal_scale':.35,'roughness':spec['roughness_multiplier']};definition=ROOT/f'art/textures/{spec["catalog_mapping"]}/material.json';definition=definition if definition.is_file() else definition.with_name('asset.json');assert definition.is_file()
 else:
  source_key=plan.get('material_aliases',{}).get(key,key)
  shipping=next(m for m in source_gltf['materials'] if m['name'] in ['M_'+source_key+'_b','M_'+source_key]);pbr=shipping['pbrMetallicRoughness'];files=[]
  for texture in [pbr.get('baseColorTexture'),pbr['metallicRoughnessTexture'],shipping['normalTexture']]:files.append(Path(source_gltf['images'][source_gltf['textures'][texture['index']]['source']]['uri']).name if texture is not None else None)
  if source_key=='glassish':
   assert files==[None,'T_glass_rough.png','T_glass_normal.png'] and shipping['alphaMode']=='BLEND'
   definition=ROOT/'art/tools/build_glass_maps.py';tile=1.6
  else:
   mapping=files[0].removeprefix('T_').removesuffix('_albedo.png').replace('ai_materials_','ai_materials/',1)
   if source_key in catalog:
    definition=ROOT/f'art/textures/{catalog[source_key]["catalog_mapping"]}/material.json';definition=definition if definition.is_file() else definition.with_name('asset.json');assert definition.is_file();tile=catalog[source_key]['meters_per_tile']
   else:
    suffix='_b' if shipping['name'].endswith('_b') else '';definition=ROOT/f'art/textures/ai_materials/{source_key}{suffix}/material.json';assert definition.is_file();tile=json.loads(definition.read_text(encoding='utf-8'))['meters_per_tile']
  sets[key]={'files':files,'meters_per_tile':tile,'metallic':pbr.get('metallicFactor',1),'roughness':pbr.get('roughnessFactor',1),'normal_scale':shipping['normalTexture'].get('scale',1),'source_color':pbr.get('baseColorFactor',[1,1,1,1]),'alpha':shipping.get('alphaMode')=='BLEND'}
 material_definitions.append(definition)

def digest(path):
 data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n')).hexdigest()
floor=rows['storm_shop_radio_service_floor'];ceil=rows['storm_shop_radio_service_ceil'];selected=[];assemblies=[]
for group in plan['groups']:
 members=[rows[identity] for identity in group['sources']];selected.extend(members);assemblies.append({'id':members[0]['id'],'kind':group['kind'],'members':members,'body':members[0],'cell':'shop_radio_service','floor':floor})
assert len(selected)==plan['original_records'] and len({row['id'] for row in selected})==len(selected)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
closed=bpy.data.collections.new('ClosedConstruction');bpy.context.scene.collection.children.link(closed);closed.hide_render=True
retained=bpy.data.collections.new('RetainedSourceBoxes');bpy.context.scene.collection.children.link(retained);retained.hide_render=True
materials={};pieces=collections.defaultdict(list);stock_checks=[];contacts=[]
# Actual catalogue images remain in the editable native source. Runtime assigns
# the same existing keys and receives only metre charts, normals and tangents.
for key in plan['runtime_keys']:
 mat=bpy.data.materials.new(key);mat.use_nodes=True;materials[key]=mat
 node=mat.node_tree.nodes['Principled BSDF'];spec=sets[key];node.inputs['Metallic'].default_value=spec.get('metallic',0)
 coord=mat.node_tree.nodes.new('ShaderNodeTexCoord');scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];mat.node_tree.links.new(coord.outputs['UV'],scale.inputs[0])
 if spec.get('alpha'):
  node.inputs['Base Color'].default_value=spec['source_color'];node.inputs['Alpha'].default_value=spec['source_color'][3];mat.surface_render_method='DITHERED'
 for index,target in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
  if spec['files'][index] is None:continue
  image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True);image.filepath=bpy.path.relpath(image.filepath,start=str(OUT/'art/blender'))
  if index:image.colorspace_settings.name='Non-Color'
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;mat.node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
  if index==2:
   normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=spec['normal_scale'];mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs[0],node.inputs[target])
  elif index==1:
   multiply=mat.node_tree.nodes.new('ShaderNodeMath');multiply.operation='MULTIPLY';multiply.inputs[1].default_value=spec['roughness'];mat.node_tree.links.new(tex.outputs['Color'],multiply.inputs[0]);mat.node_tree.links.new(multiply.outputs[0],node.inputs[target])
  elif key in plan.get('material_tints',{}):
   multiply=mat.node_tree.nodes.new('ShaderNodeMixRGB');multiply.blend_type='MULTIPLY';multiply.inputs[0].default_value=1.;multiply.inputs[2].default_value=plan['material_tints'][key];mat.node_tree.links.new(tex.outputs['Color'],multiply.inputs[1]);mat.node_tree.links.new(multiply.outputs[0],node.inputs[target])
  else:mat.node_tree.links.new(tex.outputs['Color'],node.inputs[target])

def solid(name,verts,faces,identity,key,collection=closed):
 raw=np.asarray(verts,dtype=np.float64);origin=Vector(tuple(round(float(np.mean(raw[:,i])),4) for i in range(3)))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata((raw-np.asarray(origin,dtype=np.float64)).tolist(),[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 volume=bm.calc_volume(signed=True);assert all(e.is_manifold for e in bm.edges) and volume>1e-12,name
 bm.to_mesh(mesh);bm.free();mesh.materials.append(materials[key])
 obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj);obj.location=origin;obj.hide_render=True
 if collection==closed:
  pieces[identity].append((obj,key));stock_checks.append({'name':name,'assembly':identity,'key':key,'volume_m3':volume})
 return obj
def box(name,low,high,identity,key='timber',bevel=.003,collection=closed):
 verts=[(x,y,z) for z in [low[2],high[2]] for y in [low[1],high[1]] for x in [low[0],high[0]]]
 obj=solid(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],identity,key,collection)
 if bevel:
  bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Worked edge','BEVEL');mod.width=min(bevel,min(high[i]-low[i] for i in range(3))*.4);mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj
def support(identity,owner,point,direction,label):
 contacts.append({'assembly':identity,'owner':owner,'point':[point[0],point[2],-point[1]],'direction':[direction[0],direction[2],-direction[1]],'label':label})
def rod(name,a,b,r,identity,key,n=48):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();seed=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0));u=axis.cross(seed).normalized();v=axis.cross(u)
 verts=[p+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)) for p in [a,b] for i in range(n)]
 return solid(name,verts,[tuple(reversed(range(n)))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]+[tuple(range(n,2*n))],identity,key)

def tube_ring(name,a,b,outer,inner,identity,key,n=48):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();seed=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0));u=axis.cross(seed).normalized();v=axis.cross(u)
 verts=[p+radius*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)) for p in [a,b] for radius in [outer,inner] for i in range(n)]
 faces=[]
 for i in range(n):
  j=(i+1)%n;faces.extend([(i,j,2*n+j,2*n+i),(n+i,3*n+i,3*n+j,n+j),(i,n+i,n+j,j),(2*n+i,2*n+j,3*n+j,3*n+i)])
 return solid(name,verts,faces,identity,key)

def opal_valve(name,cx,cy,base,top,identity):
 # Finite opaque opal stock retains the original milk-glass owner. No
 # filament, emissive signal or vacuum/electrical operation is inferred.
 profile=[(.018,.013,base),(.018,.013,base+.014),(.038,.025,base+.029),(.048,.031,top-.074)]
 profile.extend((.048*math.cos(j*math.acos(.004/.048)/16),.031*math.cos(j*math.acos(.004/.048)/16),top-.074+.074*math.sin(j*math.acos(.004/.048)/16)/math.sin(math.acos(.004/.048))) for j in range(1,17))
 n=48;verts=[(cx+rx*math.cos(i*math.tau/n),cy+ry*math.sin(i*math.tau/n),z) for rx,ry,z in profile for i in range(n)]
 faces=[tuple(reversed(range(n))),tuple(range((len(profile)-1)*n,len(profile)*n))]
 for j in range(len(profile)-1):
  for i in range(n):k=(i+1)%n;faces.append((j*n+i,j*n+k,(j+1)*n+k,(j+1)*n+i))
 return solid(name,verts,faces,identity,'valve_opal')

def knob(name,x,y,z,r,identity):
 rod(name+'_Stem',(x,y+.015,z),(x,y-.011,z),r*.36,identity,'control_nickel',32)
 rod(name+'_Grip',(x,y+.006,z),(x,y-.019,z),r,identity,'control_bakelite',48)
 rod(name+'_Cap',(x,y-.018,z),(x,y-.021,z),r*.72,identity,'control_bakelite',48)

for item in assemblies:
 identity=item['id'];row=item['body'];x0,y0,x1,y1=row['rect'];z=float(row['z0']);top=z+float(row['h']);cx=(x0+x1)*.5
 # Full bottom pans keep the original 1.01m bearing datum, including its
 # centre sample used by the accepted bench's original-instrument contract.
 body_key='scope_case' if item['kind']=='scope' else 'case_bakelite'
 box(identity+'_BottomPan',(x0,y0,z),(x1,y1,z+.020),identity,body_key,.002)
 for xx in [x0+.035,x1-.035]:
  for yy in [y0+.035,y1-.035]:
   support(identity,rows['storm_shop_radio_service_bench_top']['id'],(xx,yy,z),(0,0,1),'original instrument bottom on retained native bench')
   contacts[-1]['native_owner_asset']='radio_bench';contacts[-1]['native_owner_part']='storm_shop_radio_service_bench__bench_top'
 if item['kind']=='open_back_set':
  box(identity+'_FrontPanel',(x0,y0+.023,z+.010),(x1,y0+.041,top),identity,'case_bakelite',.002)
  for j,xx in enumerate([x0,x1-.012]):box(identity+'_SidePanel'+str(j),(xx,y0+.024,z+.012),(xx+.012,y1,top),identity,'case_bakelite',.002)
  box(identity+'_ValveDeck',(x0+.008,y0+.032,top-.025),(x1-.008,y1-.006,top),identity,'chassis_metal',.002)
  for j,xx in enumerate([x0+.065,x0+.235]):
   box(identity+'_TransformerFoot'+str(j),(xx,y0+.095,z+.014),(xx+.115,y0+.265,z+.040),identity,'chassis_metal',.002)
   box(identity+'_TransformerCase'+str(j),(xx+.009,y0+.107,z+.032),(xx+.106,y0+.253,z+.180),identity,'chassis_metal',.003)
  for j,xx in enumerate([x0+.15,x1-.15]):knob(identity+'_TuningControl'+str(j),xx,y0+.022,z+.13,.029,identity)
  for j,(xx,h) in enumerate([(x0+.025,z+.035),(x1-.025,z+.035),(x0+.025,top-.025),(x1-.025,top-.025)]):rod(identity+'_PanelFastener'+str(j),(xx,y0+.026,h),(xx,y0+.020,h),.0042,identity,'control_nickel',32)
  for j,valve in enumerate(item['members'][1:]):
   r=valve['rect'];vx=(r[0]+r[2])*.5;vy=(r[1]+r[3])*.5;vtop=float(valve['z0'])+float(valve['h'])
   rod(identity+'_ValveSocket'+str(j),(vx,vy,top-.003),(vx,vy,float(valve['z0'])+.022),.030,identity,'control_bakelite')
   opal_valve(identity+'_OpalValve'+str(j),vx,vy,float(valve['z0'])+.018,vtop,identity)
 elif item['kind']=='scope':
  box(identity+'_Roof',(x0,y0,top-.014),(x1,y1,top),identity,'scope_case',.003)
  box(identity+'_RearPanel',(x0,y1-.012,z+.010),(x1,y1,top-.008),identity,'scope_case',.002)
  box(identity+'_RightSide',(x1-.012,y0,z+.010),(x1,y1,top-.008),identity,'scope_case',.002)
  for j,yy in enumerate([y0,y1-.027]):box(identity+'_VentEnd'+str(j),(x0,yy,z+.010),(x0+.012,yy+.027,top-.008),identity,'scope_case',.001)
  for j in range(9):
   h=z+.025+j*(top-z-.060)/8
   box(identity+'_SideVentSlat'+str(j),(x0,y0+.019,h),(x0+.012,y1-.019,h+.023),identity,'scope_case',.001)
  face=rows['storm_shop_radio_service_scope_face'];a,b,c,e=face['rect'];lo=float(face['z0']);hi=lo+float(face['h'])
  for j,(left,right,bottom,upper) in enumerate([(x0,a,z,top),(c,x1,z,top),(a,c,z,lo),(a,c,hi,top)]):
   box(identity+'_FrontSurround'+str(j),(left,y0,bottom),(right,y0+.015,upper),identity,'scope_case',.002)
  for j,(left,right,bottom,upper) in enumerate([(a-.010,a,lo-.010,hi+.010),(c,c+.010,lo-.010,hi+.010),(a,c,lo-.010,lo),(a,c,hi,hi+.010)]):
   box(identity+'_ScreenRim'+str(j),(left,b-.001,bottom),(right,e+.006,upper),identity,'control_nickel',.001)
  for j,xx in enumerate([x0+.10,x1-.10]):knob(identity+'_Control'+str(j),xx,y0,z+.085,.023,identity)
  for j,(xx,h) in enumerate([(x0+.025,z+.035),(x1-.025,z+.035),(x0+.025,top-.025),(x1-.025,top-.025)]):rod(identity+'_PanelFastener'+str(j),(xx,y0+.003,h),(xx,y0-.003,h),.0042,identity,'control_nickel',32)
 elif item['kind']=='signal_generator':
  box(identity+'_Roof',(x0,y0,top-.014),(x1,y1,top),identity,'case_bakelite',.003)
  box(identity+'_RearPanel',(x0,y1-.012,z+.010),(x1,y1,top-.008),identity,'case_bakelite',.002)
  for j,xx in enumerate([x0,x1-.012]):box(identity+'_Side'+str(j),(xx,y0,z+.010),(xx+.012,y1,top-.008),identity,'case_bakelite',.002)
  box(identity+'_FacePlate',(x0+.008,y0+.026,z+.013),(x1-.008,y0+.041,top-.008),identity,'scope_case',.002)
  dial_z=z+.255
  tube_ring(identity+'_UnletteredDialRim',(cx,y0+.025,dial_z),(cx,y0+.014,dial_z),.085,.069,identity,'control_nickel')
  rod(identity+'_BlankDial',(cx,y0+.027,dial_z),(cx,y0+.018,dial_z),.071,identity,'control_bakelite')
  for j in range(12):
   angle=j*math.tau/12;start=(cx+.077*math.cos(angle),y0+.015,dial_z+.077*math.sin(angle));end=(cx+.083*math.cos(angle),y0+.015,dial_z+.083*math.sin(angle))
   rod(identity+'_RaisedIndex'+str(j),start,end,.0015,identity,'control_nickel',16)
  rod(identity+'_FixedDialPointer',(cx,y0+.017,dial_z),(cx+.032,y0+.017,dial_z+.046),.0015,identity,'control_nickel',16)
  rod(identity+'_PointerBoss',(cx,y0+.022,dial_z),(cx,y0+.015,dial_z),.008,identity,'control_nickel',32)
  for j,xx in enumerate([x0+.070,cx,x1-.070]):knob(identity+'_Control'+str(j),xx,y0+.022,z+.075,.022,identity)
  for j,(xx,h) in enumerate([(x0+.025,z+.035),(x1-.025,z+.035),(x0+.025,top-.025),(x1-.025,top-.025)]):rod(identity+'_PanelFastener'+str(j),(xx,y0+.029,h),(xx,y0+.023,h),.0042,identity,'control_nickel',32)
 else:raise AssertionError(item['kind'])


for row in selected:
 x0,y0,x1,y1=row['rect'];z0=row['z0'];box(row['id']+'_RetainedBox',(x0,y0,z0),(x1,y1,z0+row['h']),row['id'],row['mat'],0,retained)

# Record the actual finished stock, after bevels, rather than its raw blank.
for record in stock_checks:
 obj=bpy.data.objects[record['name']];bm=bmesh.new();bm.from_mesh(obj.data)
 assert all(e.is_manifold for e in bm.edges),record['name']
 record['volume_m3']=bm.calc_volume(signed=True);assert record['volume_m3']>1e-12,record['name']
 bm.free()
def partition_of(obj,key):return key

draws=[];inventory=[];fallbacks=0;total_triangles=0
for item in assemblies:
 identity=item['id'];keys=sorted({partition_of(obj,key) for obj,key in pieces[identity]});rect=item['body']['rect'];origin=np.array(((rect[0]+rect[2])*.5,(rect[1]+rect[3])*.5,item['body']['z0']))
 for part_key in keys:
  key=part_key;vertices=[];faces=[]
  cx=(rect[0]+rect[2])*.5;cy=(rect[1]+rect[3])*.5
  for obj,material_key in pieces[identity]:
   if partition_of(obj,material_key)!=part_key:continue
   # Sum in doubles before rebasing the assembled draw. World-coordinate
   # float32 addition otherwise collapses tiny bevel faces fifty metres out.
   offset=len(vertices);vertices.extend(tuple(np.asarray(obj.location,dtype=np.float64)+np.asarray(v.co,dtype=np.float64)) for v in obj.data.vertices);faces.extend(tuple(offset+i for i in face.vertices) for face in obj.data.polygons)
  name=identity+'__'+part_key;mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(np.asarray(p)-origin) for p in vertices],[],faces);mesh.update();mesh.materials.append(materials[key])
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
  uv=mesh.uv_layers.new(name='Metres');uv.active_render=True;guides=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER');normals=[None]*len(mesh.loops)
  for face in mesh.polygons:
   points=np.asarray([mesh.vertices[i].co[:] for i in face.vertices],dtype=np.float64)
   assert np.linalg.norm(np.cross(points[1]-points[0],points[2]-points[0]))>0,(name,face.index,points.tolist())
   n,u,values,local=chart_for_triangle(points,origin,sets[key]['meters_per_tile'],plan.get('material_aliases',{}).get(key,key) in ['timber','wood_dark','oak_quartered']);fallbacks+=local;smooth=[n,n,n]
   for j,loop in enumerate(face.loop_indices):uv.data[loop].uv=tuple(values[j]);guides.data[loop].vector=(float(u[0]),float(u[2]),float(-u[1]));normals[loop]=tuple(smooth[j])
  mesh.normals_split_custom_set(normals);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;draws.append(obj)
  mesh.calc_loop_triangles();total_triangles+=len(mesh.loop_triangles);inventory.append({'name':name,'assembly':identity,'cell':item['cell'],'key':key,'triangles':len(mesh.loop_triangles)})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/radio_apparatus.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in draws:obj.select_set(True)
class ExportUVHandedness:
 corrected=0
 def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
  for primitive in mesh.primitives:
   def vectors(key):
    accessor=primitive.attributes[key];assert accessor.component_type==5126 and accessor.type=='VEC3'
    array=np.frombuffer(accessor.buffer_view.data,dtype='<f4').reshape((-1,3)).astype(np.float64);assert len(array)==primitive.attributes['POSITION'].count;return array
   n=vectors('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None];guide=vectors('_TANGENT_GUIDE')
   tangent=guide-n*np.sum(guide*n,axis=1)[:,None];tangent/=np.linalg.norm(tangent,axis=1)[:,None]
   assert np.isfinite(tangent).all() and np.max(np.abs(np.sum(n*tangent,axis=1)))<1e-7
   tangent=np.column_stack((tangent,-np.ones(len(n)))).astype(np.float32)
   from io_scene_gltf2.io.exp.binary_data import BinaryData
   from io_scene_gltf2.io.com.constants import BufferViewTarget
   primitive.attributes['TANGENT'].buffer_view=BinaryData(tangent.tobytes(),BufferViewTarget.ARRAY_BUFFER)
   type(self).corrected+=1
   for key in list(primitive.attributes):
    if key.upper()=='_TANGENT_GUIDE':del primitive.attributes[key]
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=OUT/'game/assets/props/radio_apparatus.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
cells=[]
for identity in sorted({a['cell'] for a in assemblies}):
 items=[a for a in assemblies if a['cell']==identity];replace=[]
 for item in items:
  for row in item['members']:
   x0,y0,x1,y1=row['rect'];z0=row['z0'];replace.append({'id':row['id'],'key':row['mat'],'low':[x0,z0,-y1],'high':[x1,z0+row['h'],-y0],'expected_triangles':12})
 cells.append({'id':identity,'parts':[{'name':p['name'],'key':plan.get('material_aliases',{}).get(p['key'],p['key']),'tile':sets[p['key']]['meters_per_tile'],**({'catalog_key':plan['catalog_variants'][p['key']]} if p['key'] in plan['catalog_variants'] else {}),**({'tint':plan['material_tints'][p['key']]} if p['key'] in plan.get('material_tints',{}) else {}),} for p in inventory if p['cell']==identity],'replace':replace})
runtime={'schema_version':1,'asset':'res://assets/props/radio_apparatus.glb','tolerance':plan['trim_tolerance_m'],'cells':cells}
(OUT/'game/data/orison_v2/radio_apparatus.json').write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',catalog_path,ROOT/'game/scripts/generated/material_sets.gd',OUT/'game/assets/props/radio_apparatus.glb.import',*material_definitions]
for key in plan['runtime_keys']:bindings.extend(ROOT/'game/assets/building/textures'/f for f in sets[key]['files'] if f is not None)
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/{identity}.{suffix}' for identity in sorted({a['cell'] for a in assemblies}) for suffix in ['gltf','bin'])
bindings.append(OUT/'art/blender/scripts/inspect_radio_apparatus.py')
bindings.extend([ROOT/'art/data/shop_interiors.py',ROOT/'game/assets/props/shop_seating.glb',ROOT/'game/data/orison_v2/shop_seating.json',ROOT/'game/assets/props/radio_bench.glb',ROOT/'game/data/orison_v2/radio_bench.json',ROOT/'art/blender/radio_bench.blend'])

report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/radio_apparatus_construction.json','game/tests/fixtures/orison_radio_apparatus.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('RADIO APPARATUS',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'floor/instrument contacts')
