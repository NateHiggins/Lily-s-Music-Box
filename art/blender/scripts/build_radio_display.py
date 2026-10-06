"""Source-owned fitted counter and passive horn/cone display."""
from pathlib import Path
import collections,hashlib,json,math,re,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
import os
OUT=Path(os.environ.get('RADIO_DISPLAY_OUT',str(ROOT)))
plan_path=Path(os.environ.get('RADIO_DISPLAY_PLAN',str(ROOT/'art/data/radio_display/source_plan.json')));layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text(encoding='utf-8'));layout=json.loads(layout_path.read_text(encoding='utf-8'));assert plan['classification']=='ADAPTATION'
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_radio_service.gltf';source_gltf=json.loads(source_gltf_path.read_text(encoding='utf-8'));sets={};material_definitions=[]
catalog_path=Path(os.environ.get('RADIO_DISPLAY_CATALOG',str(ROOT/'game/data/runtime_material_sets.json')));catalog=json.loads(catalog_path.read_text(encoding='utf-8'))['materials']
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
 volume=bm.calc_volume(signed=True)
 if volume<0:
  # Concave radial sections can be consistently wound inward by recalc.
  # Reverse their actual faces; retain the signed-positive solid assertion.
  bmesh.ops.reverse_faces(bm,faces=list(bm.faces));volume=bm.calc_volume(signed=True)
  print('CLOSED STOCK ORIENTATION',name,'reversed inward faces; signed_volume_m3=',volume)
 if volume<=1e-12 or not all(e.is_manifold for e in bm.edges):print('CLOSED STOCK DIAGNOSTIC',name,'signed_volume_m3=',volume,'non_manifold_edges=',sum(not e.is_manifold for e in bm.edges))
 assert all(e.is_manifold for e in bm.edges) and volume>1e-12,name
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

def turned_x(name,x_positions,radii,centres,identity,key,n=96):
 # Finite closed radial section. Each section carries its actual axis centre.
 assert len(x_positions)==len(radii)==len(centres)
 verts=[(x,cy+radius*math.cos(i*math.tau/n),cz+radius*math.sin(i*math.tau/n)) for x,radius,(cy,cz) in zip(x_positions,radii,centres) for i in range(n)]
 faces=[]
 for k in range(len(radii)):
  next_k=(k+1)%len(radii)
  for i in range(n):
   j=(i+1)%n;faces.append((k*n+i,k*n+j,next_k*n+j,next_k*n+i))
 return solid(name,verts,faces,identity,key)

for item in assemblies:
 identity=item['id']; source={row['id']:row for row in item['members']}
 body=source['storm_shop_radio_service_counter']; top_row=source['storm_shop_radio_service_counter_top']; book=source['storm_shop_radio_service_ledger']
 x0,y0,x1,y1=body['rect']; tx0,ty0,tx1,ty1=top_row['rect']; floor_top=item['floor']['z0']+item['floor']['h']; worktop=top_row['z0']+top_row['h']
 rear_owner=rows['storm_shop_radio_service_dw']; ty0=max(ty0,rear_owner['rect'][3]+.002)
 # Frame and panels keep the original counter perimeter and worktop datum.
 for i,(xx,yy) in enumerate((x,y) for x in [x0+.075,x1-.075] for y in [y0+.13,y1-.13]):
  box(identity+'_FloorPost'+str(i),(xx-.036,yy-.036,floor_top),(xx+.036,yy+.036,top_row['z0']+.008),identity,'wood_dark',.003)
  support(identity,item['floor']['id'],(xx,yy,floor_top),(0,0,1),'counter post on actual retained floor')
 for i,xx in enumerate([x0+.025,x1-.055]):
  for k,zz in enumerate([body['z0']+.11,top_row['z0']-.08]):
   box(identity+'_LongRail'+str(i)+'_'+str(k),(xx,y0+.02,zz),(xx+.03,y1-.02,zz+.07),identity,'wood_dark',.002)
 for i,yy in enumerate([y0+.025,y1-.055]):
  for k,zz in enumerate([body['z0']+.11,top_row['z0']-.08]):
   box(identity+'_EndRail'+str(i)+'_'+str(k),(x0+.025,yy,zz),(x1-.025,yy+.03,zz+.07),identity,'wood_dark',.002)
 # Static shallow infill expresses millwork without inventing drawer operation.
 for i in range(3):
  a=y0+.055+(y1-y0-.11)*i/3; b=y0+.055+(y1-y0-.11)*(i+1)/3
  box(identity+'_FrontPanel'+str(i),(x0+.035,a,body['z0']+.16),(x0+.055,b,top_row['z0']-.02),identity,'wood_dark',.002)
 for i,yy in enumerate([y0+.035,y1-.055]):
  box(identity+'_EndPanel'+str(i),(x0+.055,yy,body['z0']+.16),(x1-.055,yy+.02,top_row['z0']-.02),identity,'wood_dark',.002)
 box(identity+'_Countertop',(tx0,ty0,top_row['z0']),(tx1,ty1,worktop),identity,'countertop',.003)
 # The source ledger overhangs its support by 140mm. Seat its front edge on
 # the immutable countertop front edge and bridge the unchanged 10mm gap.
 bx0,by0,bx1,by1=book['rect']; shift_y=ty1-by1; by0+=shift_y;by1+=shift_y
 box(identity+'_LedgerPad',(bx0+.008,by0+.008,worktop),(bx1-.008,by1-.008,book['z0']+.003),identity,'wood_dark',.002)
 box(identity+'_Ledger',(bx0,by0,book['z0']),(bx1,by1,book['z0']+book['h']),identity,'paper',.001)
 # Display positions are derived from the accepted countertop. They are an
 # explicit adaptation of the original intersecting floor-display boxes.
 front=tx0+.20; horn_y=ty0+.28; cone_y=ty1-.64
 horn_z=worktop+.30
 horn_x=[front,front+.035,front+.12,front+.22,front+.32,front+.38]
 horn_r=[.24,.23,.17,.105,.064,.055]
 horn_c=[(horn_y,horn_z),(horn_y,horn_z),(horn_y,horn_z-.02),(horn_y,horn_z-.075),(horn_y,horn_z-.14),(horn_y,horn_z-.17)]
 turned_x(identity+'_FiniteHorn',horn_x+list(reversed(horn_x)),horn_r+[r-.008 for r in reversed(horn_r)],horn_c+list(reversed(horn_c)),identity,'brass_dull')
 tube_ring(identity+'_HornLip',(front-.003,horn_y,horn_z),(front+.012,horn_y,horn_z),.244,.230,identity,'brass_dull',96)
 rod(identity+'_HornPlinth',(front+.32,horn_y,worktop),(front+.32,horn_y,worktop+.018),.092,identity,'cast_iron',64)
 rod(identity+'_HornStay',(front+.32,horn_y,worktop+.012),(front+.32,horn_y,worktop+.10),.027,identity,'cast_iron',48)
 cone_z=worktop+.31
 tube_ring(identity+'_ConeFrame',(front,cone_y,cone_z),(front+.026,cone_y,cone_z),.29,.267,identity,'cast_iron',96)
 # Closed thin textile stock retains a finite cone; no driver or voice-coil
 # specification, signal, illumination or interaction is chosen.
 turned_x(identity+'_FiniteTextileCone',[front+.008,front+.105,front+.125,front+.132,front+.132,front+.125,front+.105,front+.008],[.270,.075,.016,.016,.010,.010,.069,.264],[(cone_y,cone_z)]*8,identity,'fabric_warm')
 rod(identity+'_ConePlinth',(front+.015,cone_y,worktop),(front+.015,cone_y,worktop+.023),.14,identity,'cast_iron',64)
 for i,yy in enumerate([cone_y-.10,cone_y+.10]):
  box(identity+'_ConeFoot'+str(i),(front-.010,yy-.015,worktop+.015),(front+.035,yy+.015,worktop+.055),identity,'cast_iron',.002)

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
  key=part_key.split('__',1)[0];vertices=[];faces=[]
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
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/radio_display.blend'))
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
asset=OUT/'game/assets/props/radio_display.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
cells=[]
for identity in sorted({a['cell'] for a in assemblies}):
 items=[a for a in assemblies if a['cell']==identity];replace=[]
 for item in items:
  for row in item['members']:
   x0,y0,x1,y1=row['rect'];z0=row['z0'];replace.append({'id':row['id'],'key':row['mat'],'low':[x0,z0,-y1],'high':[x1,z0+row['h'],-y0],'expected_triangles':12})
 cells.append({'id':identity,'parts':[{'name':p['name'],'key':plan.get('material_aliases',{}).get(p['key'],p['key']),'tile':sets[p['key']]['meters_per_tile'],**({'catalog_key':plan['catalog_variants'][p['key']]} if p['key'] in plan['catalog_variants'] else {}),**({'tint':plan['material_tints'][p['key']]} if p['key'] in plan.get('material_tints',{}) else {}),} for p in inventory if p['cell']==identity],'replace':replace})
runtime={'schema_version':1,'asset':'res://assets/props/radio_display.glb','tolerance':plan['trim_tolerance_m'],'cells':cells}
(OUT/'game/data/orison_v2/radio_display.json').write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',catalog_path,ROOT/'game/scripts/generated/material_sets.gd',OUT/'game/assets/props/radio_display.glb.import',*material_definitions]
for key in plan['runtime_keys']:bindings.extend(ROOT/'game/assets/building/textures'/f for f in sets[key]['files'] if f is not None)
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/{identity}.{suffix}' for identity in sorted({a['cell'] for a in assemblies}) for suffix in ['gltf','bin'])
bindings.append(OUT/'art/blender/scripts/inspect_radio_display.py')
bindings.extend([ROOT/'art/data/shop_interiors.py',ROOT/'game/assets/props/shop_seating.glb',ROOT/'game/data/orison_v2/shop_seating.json',ROOT/'game/assets/props/radio_bench.glb',ROOT/'game/data/orison_v2/radio_bench.json',ROOT/'art/blender/radio_bench.blend',ROOT/'game/assets/props/radio_apparatus.glb',ROOT/'game/data/orison_v2/radio_apparatus.json',ROOT/'art/blender/radio_apparatus.blend',ROOT/'game/assets/props/radio_stock.glb',ROOT/'game/data/orison_v2/radio_stock.json',ROOT/'art/blender/radio_stock.blend',ROOT/'game/assets/props/radio_battery.glb',ROOT/'game/data/orison_v2/radio_battery.json',ROOT/'art/blender/radio_battery.blend',ROOT/'game/assets/props/radio_wire.glb',ROOT/'game/data/orison_v2/radio_wire.json',ROOT/'art/blender/radio_wire.blend'])

report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
report['fitted_datums']={'rear_wainscot':rows['storm_shop_radio_service_dw'],'countertop_rear_y':ty0,'countertop_front_y':ty1,'countertop_top':worktop,'horn_centre':[front,horn_y,horn_z],'cone_centre':[front,cone_y,cone_z],'ledger_translation_y':shift_y,'wall_clearance_m':.002}
for name in ['art/blender/radio_display_construction.json','game/tests/fixtures/orison_radio_display.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('RADIO DISPLAY',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'floor/instrument contacts')
