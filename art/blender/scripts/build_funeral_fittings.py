"""Source-owned funeral lectern and deliberately empty supported bier."""
from pathlib import Path
import collections,hashlib,json,math,re,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
import os
OUT=Path(os.environ.get('FUNERAL_FITTINGS_OUT',str(ROOT)))
plan_path=Path(os.environ.get('FUNERAL_FITTINGS_PLAN',str(ROOT/'art/data/funeral_fittings/source_plan.json')));layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text(encoding='utf-8'));layout=json.loads(layout_path.read_text(encoding='utf-8'));assert plan['classification']=='ADAPTATION'
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_funeral_parlour.gltf';source_gltf=json.loads(source_gltf_path.read_text(encoding='utf-8'));sets={};material_definitions=[]
catalog_path=Path(os.environ.get('FUNERAL_FITTINGS_CATALOG',str(ROOT/'game/data/runtime_material_sets.json')));catalog=json.loads(catalog_path.read_text(encoding='utf-8'))['materials']
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
floor=rows['storm_shop_funeral_parlour_floor'];ceil=rows['storm_shop_funeral_parlour_ceil'];selected=[];assemblies=[]
for group in plan['groups']:
 members=[rows[identity] for identity in group['sources']];selected.extend(members);assemblies.append({'id':members[0]['id'],'kind':group['kind'],'members':members,'body':members[0],'cell':'shop_funeral_parlour','floor':floor})
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
def rod(name,a,b,r,identity,key='timber',n=48):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();seed=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0));u=axis.cross(seed).normalized();v=axis.cross(u)
 verts=[p+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)) for p in [a,b] for i in range(n)]
 return solid(name,verts,[tuple(reversed(range(n)))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]+[tuple(range(n,2*n))],identity,key)
def support(identity,owner,point,direction,label):
 contacts.append({'assembly':identity,'owner':owner,'point':[point[0],point[2],-point[1]],'direction':[direction[0],direction[2],-direction[1]],'label':label})
def beam(name,a,b,width,depth,identity,key):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();u=Vector((0,1,0));v=axis.cross(u).normalized()
 verts=[p+u*sy*depth*.5+v*sx*width*.5 for p in [a,b] for sy in [-1,1] for sx in [-1,1]]
 obj=solid(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],identity,key)
 bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Timber arris','BEVEL');mod.width=.002;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj

for item in assemblies:
 identity=item['id'];row=item['body'];x0,y0,x1,y1=row['rect'];z=row['z0'];top=z+row['h'];floor_top=float(floor['z0'])+float(floor['h']);cx=(x0+x1)*.5;cy=(y0+y1)*.5
 if item['kind']=='lectern':
  box(identity+'_FloorBase',(x0,y0,floor_top),(x1,y1,.090),identity,'lectern_body',.004)
  box(identity+'_Upright',(cx-.065,cy-.100,.070),(cx+.065,cy+.100,top+.010),identity,'lectern_body',.003)
  box(identity+'_Crown',(x0+.010,y0+.035,top-.065),(x1-.010,y1-.035,top+.008),identity,'lectern_body',.003)
  counter=item['members'][1];a,b,c,e=counter['rect'];base=counter['z0']
  box(identity+'_WorkedDesk',(a,b,base),(c,e,base+counter['h']),identity,'lectern_top',.003)
  # Dossier slice 64 (CITY_SHOP_FUNERAL_PARLOUR-002): the register lies open at the day's page on the desk,
  # its binding flat under both leaves, blank rules and one signature stroke. No lettering.
  book=item['members'][2];a,b,c,e=book['rect'];base=book['z0'];mid=(b+e)*.5;b2=mid-.28;e2=mid+.28
  box(identity+'_RegisterBinding',(a,b2,base),(c,e2,base+.005),identity,'book_cover',.0007)
  box(identity+'_LeftLeaves',(a+.004,b2+.004,base+.0045),(c-.004,mid-.002,base+.016),identity,'book_pages',.0006)
  box(identity+'_RightLeaves',(a+.004,mid+.002,base+.0045),(c-.004,e2-.004,base+.012),identity,'book_pages',.0006)
  box(identity+'_Gutter',(a+.003,mid-.0035,base+.0045),(c-.003,mid+.0035,base+.008),identity,'book_pages',.0004)
  for side,(p0,p1,top) in enumerate([(b2+.012,mid-.012,base+.016),(mid+.012,e2-.012,base+.012)]):
   for i in range(11):
    xx=a+.02+i*(c-a-.035)/10
    box(identity+f'_Rule{side}_{i}',(xx,p0,top-.0002),(xx+.0006,p1,top+.0002),identity,'register_rule',0)
  sx=a+.02+4*(c-a-.035)/10-.0035
  for k in range(9):
   y0s=mid+.03+k*.012
   rod(identity+f'_Signature{k}',(sx+.0028*math.sin(k*1.7),y0s,base+.0122),(sx+.0028*math.sin((k+1)*1.7),y0s+.013,base+.0122),.00055,identity,'register_ink',8)
  for xx,yy in [(x0+.045,y0+.045),(x1-.045,y0+.045),(x0+.045,y1-.045),(x1-.045,y1-.045)]:support(identity,floor['id'],(xx,yy,floor_top),(0,0,1),'lectern base on original shop floor')
 else:
  assert item['kind']=='empty_bier'
  for i,trestle in enumerate(item['members'][1:]):
   a,b,c,e=trestle['rect'];tcx=(a+c)*.5;tcy=(b+e)*.5;crown=trestle['z0']+trestle['h']
   for j,(foot,head) in enumerate([(a+.065,a+.140),(c-.065,c-.140)]):
    box(identity+'_FootPad'+str(i)+str(j),(foot-.035,b,floor_top),(foot+.035,e,.065),identity,'bier_frame',.002)
    beam(identity+'_SplayedLeg'+str(i)+str(j),(foot,tcy,.047),(head,tcy,crown-.018),.060,.100,identity,'bier_frame')
    for yy in [b+.035,e-.035]:support(identity,floor['id'],(foot,yy,floor_top),(0,0,1),'trestle foot pad on original shop floor')
   box(identity+'_LowStretcher'+str(i),(a+.060,tcy-.028,.175),(c-.060,tcy+.028,.212),identity,'bier_frame',.002)
   box(identity+'_CrownBeam'+str(i),(a+.015,tcy-.055,crown-.055),(c-.015,tcy+.055,crown),identity,'bier_frame',.002)
   box(identity+'_BearingCleat'+str(i),(a+.015,tcy-.045,crown-.013),(c-.015,tcy+.045,z+.002),identity,'bier_frame',.001)
  for j,(a,c) in enumerate([(x0+.050,x0+.085),(x1-.085,x1-.050)]):box(identity+'_LongRail'+str(j),(a,y0+.010,z-.030),(c,y1-.010,z+.021),identity,'bier_frame',.002)
  for i in range(5):
   a=x0+(x1-x0)*i/5;b=x0+(x1-x0)*(i+1)/5
   box(identity+'_EmptyDeckPlank'+str(i),(a+(0 if i==0 else .0015),y0,z),(b-(0 if i==4 else .0015),y1,top),identity,'bier_deck',.003)

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
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/funeral_fittings.blend'))
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
asset=OUT/'game/assets/props/funeral_fittings.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
cells=[]
for identity in sorted({a['cell'] for a in assemblies}):
 items=[a for a in assemblies if a['cell']==identity];replace=[]
 for item in items:
  for row in item['members']:
   x0,y0,x1,y1=row['rect'];z0=row['z0'];replace.append({'id':row['id'],'key':row['mat'],'low':[x0,z0,-y1],'high':[x1,z0+row['h'],-y0],'expected_triangles':12})
 cells.append({'id':identity,'parts':[{'name':p['name'],'key':plan.get('material_aliases',{}).get(p['key'],p['key']),'tile':sets[p['key']]['meters_per_tile'],**({'catalog_key':plan['catalog_variants'][p['key']]} if p['key'] in plan['catalog_variants'] else {}),**({'tint':plan['material_tints'][p['key']]} if p['key'] in plan.get('material_tints',{}) else {}),} for p in inventory if p['cell']==identity],'replace':replace})
runtime={'schema_version':1,'asset':'res://assets/props/funeral_fittings.glb','tolerance':plan['trim_tolerance_m'],'cells':cells}
(OUT/'game/data/orison_v2/funeral_fittings.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',catalog_path,ROOT/'game/scripts/generated/material_sets.gd',OUT/'game/assets/props/funeral_fittings.glb.import',*material_definitions]
for key in plan['runtime_keys']:bindings.extend(ROOT/'game/assets/building/textures'/f for f in sets[key]['files'] if f is not None)
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/{identity}.{suffix}' for identity in sorted({a['cell'] for a in assemblies}) for suffix in ['gltf','bin'])
bindings.append(OUT/'art/blender/scripts/inspect_funeral_fittings.py')
bindings.extend([ROOT/'art/data/shop_interiors.py',ROOT/'game/assets/props/shop_seating.glb',ROOT/'game/data/orison_v2/shop_seating.json'])

report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/funeral_fittings_construction.json','game/tests/fixtures/orison_funeral_fittings.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('FUNERAL FITTINGS',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'foot contacts')
