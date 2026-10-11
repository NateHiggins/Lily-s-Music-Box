"""Thirteen table variants shared by 62 existing and completion actors."""
from pathlib import Path
import collections,hashlib,json,math,re,sys
# Godot may normalize a provisional import UID without changing any geometry.
# Refresh only that import provenance after import; other drift still refuses.
if '--refresh-import-binding' in sys.argv:
 root=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
 paths=[root/'art/blender/domestic_tables_construction.json',root/'game/tests/fixtures/orison_domestic_tables.json']
 reports=[json.loads(p.read_text(encoding='utf-8')) for p in paths];assert reports[0]==reports[1]
 report=reports[0];assert hashlib.sha256((root/'game/assets/props/domestic_tables.glb').read_bytes()).hexdigest()==report['asset_sha256']
 permitted={'art/blender/scripts/build_domestic_tables.py','game/assets/props/domestic_tables.glb.import'}
 changed=[]
 for relative,expected in report['source_bindings'].items():
  path=root/relative;data=path.read_bytes();actual=hashlib.sha256(data if path.suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n')).hexdigest()
  if actual!=expected:
   assert relative in permitted,('unexpected source drift',relative)
   report['source_bindings'][relative]=actual;changed.append(relative)
 assert 'game/assets/props/domestic_tables.glb.import' in changed,'no normalized import binding to refresh'
 for path in paths:path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
 print('Refreshed normalized import provenance:',changed,'; mesh and every other source binding unchanged.')
 raise SystemExit(0)
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
from fabrication_grain import stock_grain_frame, stock_grain_chart
from fabrication_normals import stock_corner_normals
from fabrication_chart_batch import triangle_charts, revolved_charts
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
import os
OUT=Path(os.environ.get('DOMESTIC_TABLES_OUT',str(ROOT)))
plan_path=Path(os.environ.get('DOMESTIC_TABLES_PLAN',str(ROOT/'art/data/domestic_tables/source_plan.json')));layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text(encoding='utf-8'));layout=json.loads(layout_path.read_text(encoding='utf-8'));assert plan['classification']=='ADAPTATION'
rows={record['id']:record for floor in layout['floors'] for record in floor['furniture']}
domestic=json.loads((ROOT/'game/data/orison_v2/domestic_furniture.json').read_text(encoding='utf-8'));table_records={row['id']:row for row in domestic['furniture']};variants={row['id']:row for row in plan['variants']}
source_gltf=json.loads((ROOT/'game/assets/building/floor_b1.gltf').read_text(encoding='utf-8'))
sets={};material_definitions=[]
catalog_path=Path(os.environ.get('DOMESTIC_TABLES_CATALOG',str(ROOT/'game/data/runtime_material_sets.json')));catalog=json.loads(catalog_path.read_text(encoding='utf-8'))['materials']
for key in plan['runtime_keys']:
 if key in plan['catalog_variants']:
  spec=catalog[plan['catalog_variants'][key]];sets[key]={'files':spec['files'],'meters_per_tile':spec['meters_per_tile'],'metallic':spec['metallic'],'normal_scale':.35,'roughness':spec['roughness_multiplier']};definition=ROOT/f'art/textures/{spec["catalog_mapping"]}/material.json'
 else:
  source_key=plan.get('material_aliases',{}).get(key,key)
  shipping=next(m for m in source_gltf['materials'] if m['name'] in ['M_'+source_key+'_b','M_'+source_key]);pbr=shipping['pbrMetallicRoughness'];files=[]
  for texture in [pbr.get('baseColorTexture'),pbr['metallicRoughnessTexture'],shipping['normalTexture']]:files.append(Path(source_gltf['images'][source_gltf['textures'][texture['index']]['source']]['uri']).name if texture is not None else None)
  if source_key=='glassish':
   assert files==[None,'T_glass_rough.png','T_glass_normal.png'] and shipping['alphaMode']=='BLEND'
   definition=ROOT/'art/tools/build_glass_maps.py';tile=1.6
  else:
   mapping=files[0].removeprefix('T_').removesuffix('_albedo.png').replace('ai_materials_','ai_materials/',1)
   definition=ROOT/f'art/textures/{mapping}/material.json';tile=json.loads(definition.read_text(encoding='utf-8'))['meters_per_tile']
  sets[key]={'files':files,'meters_per_tile':tile,'metallic':pbr.get('metallicFactor',1),'roughness':pbr.get('roughnessFactor',1),'normal_scale':shipping['normalTexture'].get('scale',1),'source_color':pbr.get('baseColorFactor',[1,1,1,1]),'alpha':shipping.get('alphaMode')=='BLEND'}
 if not definition.is_file(): definition=definition.with_name('asset.json')
 assert definition.is_file(),definition
 material_definitions.append(definition)
 sets[key].update(plan.get('finish_parameters',{}).get(key,{}))

def digest(path):
 data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n')).hexdigest()
selected=[rows[identity] for identity in plan['source_ids']]
assert len(selected)==27 and len(plan['instances'])==75
assemblies=[{'id':v['id'],'kind':v['kind'],'cell':'shared','members':[table_records[v['source_id']]],'body':{'rect':[0,0,0,0],'z0':0.}} for v in plan['variants']]
# Reject future source/template drift before sharing a native variant.
completion={row['id']:row['template'] for row in json.loads((ROOT/'game/data/orison_v2/completion_interiors.json').read_text(encoding='utf-8'))['furniture']}
for instance in plan['instances']:
 source_id=instance['id'] if instance['id'] in table_records else completion[instance['id']]
 actual=table_records[source_id];exemplar=table_records[variants[instance['variant']]['source_id']]
 assert all(actual[key]==exemplar[key] for key in ['kind','bounds','surfaces']),('source variant requires regrouping',instance['id'])
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

# Native Cycles approximation of the already registered clear dielectric runtime owner.
for key,mat in materials.items():
 if key=='glassish':
  node=mat.node_tree.nodes['Principled BSDF']
  for link in list(node.inputs['Roughness'].links):mat.node_tree.links.remove(link)
  node.inputs['Roughness'].default_value=.06;node.inputs['Alpha'].default_value=1.;node.inputs['Base Color'].default_value=(1.,1.,1.,1.);node.inputs['Transmission Weight'].default_value=1.;node.inputs['IOR'].default_value=1.5

def solid(name,verts,faces,identity,key,collection=closed):
 # A one-micrometre height grid removes float32 subtraction residue when
 # source books are repacked onto a different shelf, below fit tolerances.
 verts=[Vector((v[0],v[1],round(v[2],6))) for v in verts];origin=Vector(tuple(round(sum(v[i] for v in verts)/len(verts),4) for i in range(3)))
 # Every horizontal bearing shares the same float32 height datum. Different
 # per-stock Z origins otherwise turn an exact coplanar join into a tiny gap.
 origin.z=0.
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([v-origin for v in verts],[],faces);mesh.update()
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
def torus(name,center,rx,ry,r,identity,key):
 n=64;m=12;verts=[]
 for i in range(n):
  angle=i*math.tau/n;normal=Vector((math.cos(angle)/rx,math.sin(angle)/ry,0)).normalized();at=Vector(center)+Vector((rx*math.cos(angle),ry*math.sin(angle),0))
  verts.extend(at+r*(normal*math.cos(j*math.tau/m)+Vector((0,0,math.sin(j*math.tau/m)))) for j in range(m))
 faces=[(i*m+j,((i+1)%n)*m+j,((i+1)%n)*m+(j+1)%m,i*m+(j+1)%m) for i in range(n) for j in range(m)]
 return solid(name,verts,faces,identity,key)
def support(identity,owner,point,direction,label):
 contacts.append({'assembly':identity,'owner':owner,'point':[point[0],point[2],-point[1]],'direction':[direction[0],direction[2],-direction[1]],'label':label})
def curved_wire(name,path,radius,identity,key='chrome'):
 points=[]
 for p in path:
  at=Vector(p)
  if not points or (at-points[-1]).length>1e-9:points.append(at)
 assert len(points)>=2,name
 verts=[];n=12
 closed=(points[-1]-points[0]).length<1e-8
 if closed:points.pop()
 plane_normal=Vector(np.linalg.svd(np.asarray(points)-np.asarray(points).mean(0))[2][-1]) if closed else None
 for i,p in enumerate(points):
  tangent=(points[(i+1)%len(points)]-points[(i-1)%len(points)]).normalized() if closed else (points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
  seed=plane_normal if closed else (Vector((0,1,0)) if abs(tangent.y)<.9 else Vector((1,0,0)))
  u=tangent.cross(seed).normalized();v=tangent.cross(u)
  verts.extend(p+radius*(u*math.cos(j*math.tau/n)+v*math.sin(j*math.tau/n)) for j in range(n))
 faces=[(i*n+j,i*n+(j+1)%n,((i+1)%len(points))*n+(j+1)%n,((i+1)%len(points))*n+j) for i in range(len(points) if closed else len(points)-1) for j in range(n)]
 if not closed:faces=[tuple(reversed(range(n)))]+faces+[tuple(range((len(points)-1)*n,len(points)*n))]
 return solid(name,verts,faces,identity,key)

def prism(name,outline,z0,z1,identity,key,bevel=0):
 n=len(outline);obj=solid(name,[(x,y,z) for z in [z0,z1] for x,y in outline],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)],identity,key)
 if bevel:
  bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Worked perimeter','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj





def vessel(name,cx,cy,z,profile,identity,key):
 n=96 if max(radius for radius,_ in profile)>.3 else 48;verts=[];rings=[];closed_profile=profile[0]==profile[-1]
 if closed_profile:profile=profile[:-1]
 for radius,height in profile:
  if radius==0:rings.append([len(verts)]);verts.append((cx,cy,z+height))
  else:
   rings.append(list(range(len(verts),len(verts)+n)));verts.extend((cx+radius*math.cos(i*math.tau/n),cy+radius*math.sin(i*math.tau/n),z+height) for i in range(n))
 faces=[]
 for a,b in zip(rings,rings[1:]+(rings[:1] if closed_profile else [])):
  for i in range(n):
   if len(a)==len(b)==1:continue
   elif len(a)==1:faces.append((a[0],b[i],b[(i+1)%n]))
   elif len(b)==1:faces.append((a[i],b[0],a[(i+1)%n]))
   else:faces.append((a[i],b[i],b[(i+1)%n],a[(i+1)%n]))
 obj=solid(name,verts,faces,identity,key);obj['uv_axis']=(0,0,1);obj['uv_center']=(cx,cy,z);return obj

# Turned sections run along Y; the front faces into the shop (-Y).
def axial(name,cx,cz,profile,identity,key,n=64):
 verts=[];rings=[];closed_profile=profile[0]==profile[-1]
 if closed_profile:profile=profile[:-1]
 for radius,yy in profile:
  if radius==0:rings.append([len(verts)]);verts.append((cx,yy,cz))
  else:
   rings.append(list(range(len(verts),len(verts)+n)));verts.extend((cx+radius*math.cos(i*math.tau/n),yy,cz+radius*math.sin(i*math.tau/n)) for i in range(n))
 faces=[]
 for a,b in zip(rings,rings[1:]+(rings[:1] if closed_profile else [])):
  for i in range(n):
   if len(a)==len(b)==1:continue
   elif len(a)==1:faces.append((a[0],b[i],b[(i+1)%n]))
   elif len(b)==1:faces.append((a[i],b[0],a[(i+1)%n]))
   else:faces.append((a[i],b[i],b[(i+1)%n],a[(i+1)%n]))
 obj=solid(name,verts,faces,identity,key);obj['uv_axis']=(0,1,0);obj['uv_center']=(cx,0,cz);return obj
def radial_bar(name,cx,cz,y0,y1,angle,r0,r1,width,identity,key):
 u=Vector((math.sin(angle),0,math.cos(angle)));v=Vector((math.cos(angle),0,-math.sin(angle)))
 verts=[Vector((cx,yy,cz))+u*rr+v*ww for yy in [y0,y1] for rr in [r0,r1] for ww in [-width/2,width/2]]
 return solid(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],identity,key)
def frame(name,x0,y0,x1,y1,z0,z1,width,identity,key):
 box(name+'_Near',(x0,y0,z0),(x1,y0+width,z1),identity,key,.001)
 box(name+'_Far',(x0,y1-width,z0),(x1,y1,z1),identity,key,.001)
 box(name+'_Left',(x0,y0+width-.001,z0),(x0+width,y1-width+.001,z1),identity,key,.001)
 box(name+'_Right',(x1-width,y0+width-.001,z0),(x1,y1-width+.001,z1),identity,key,.001)

def along_x(name,cx,cy,cz,profile,identity,key):
 # Revolved stock built on the existing Y-axis primitive, then rotated onto X.
 obj=axial(name,0,0,profile,identity,key,48)
 for v in obj.data.vertices:
  p=v.co+obj.location;v.co=Vector((p.y,p.x,p.z))
 obj.location=Vector((cx,cy,cz));obj['uv_axis']=(1,0,0);obj['uv_center']=(cx,cy,cz)
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
 return obj

exec(compile((ROOT/'art/blender/scripts/domestic_tables_geometry.py').read_text(encoding='utf-8'),str(ROOT/'art/blender/scripts/domestic_tables_geometry.py'),'exec'))

# Record the actual finished stock, after bevels, rather than its raw blank.
assert len({record['name'] for record in stock_checks})==len(stock_checks),'duplicate construction stock identity'
for record in stock_checks:
 obj=bpy.data.objects[record['name']];bm=bmesh.new();bm.from_mesh(obj.data)
 assert all(e.is_manifold for e in bm.edges),record['name']
 record['volume_m3']=bm.calc_volume(signed=True);assert record['volume_m3']>1e-12,record['name']
 bm.free()
def partition_of(obj,key):return key

def table_grain_frame(vertices,albedo):
 if albedo!='T_ai_materials_oak_work_surface_albedo.png':return stock_grain_frame(vertices,albedo)
 # This existing albedo was inspected: its boards run vertically (V). Keep
 # the override local so shared batch imports cannot alter other recipes.
 points=np.asarray(vertices,dtype=np.float64);_,singular,basis=np.linalg.svd(points-points.mean(axis=0),full_matrices=False)
 if singular[1]<=0 or singular[0]/singular[1]<1.5:return None
 length=basis[0]
 if length[np.argmax(np.abs(length))]<0:length=-length
 lateral=np.cross(np.eye(3)[np.argmin(np.abs(length))],length);lateral/=np.linalg.norm(lateral)
 return np.stack((lateral,np.cross(length,lateral),length)),1

draws=[];inventory=[];fallbacks=0;total_triangles=0
for item in assemblies:
 identity=item['id'];keys=sorted({partition_of(obj,key) for obj,key in pieces[identity]});rect=item['body']['rect'];origin=np.array(((rect[0]+rect[2])*.5,(rect[1]+rect[3])*.5,item['body']['z0']))
 for part_key in keys:
  key=part_key;vertices=[];faces=[];grain_frames=[];chart_origins=[];uv_axes=[];uv_centers=[]
  for obj,material_key in pieces[identity]:
   if partition_of(obj,material_key)!=part_key:continue
   # Sum in doubles before rebasing the assembled draw. World-coordinate
   # float32 addition otherwise collapses tiny bevel faces fifty metres out.
   offset=len(vertices);vertices.extend(tuple(np.asarray(obj.location,dtype=np.float64)+np.asarray(v.co,dtype=np.float64)) for v in obj.data.vertices)
   frame=table_grain_frame([v.co[:] for v in obj.data.vertices],sets[key]['files'][0]);grain_frames.extend([frame]*len(obj.data.vertices))
   uv_axes.extend([obj.get('uv_axis',(0,0,0))]*len(obj.data.vertices));uv_centers.extend([obj.get('uv_center',(0,0,0))]*len(obj.data.vertices))
   points=np.asarray([tuple(obj.location+v.co) for v in obj.data.vertices]);chart_origins.extend([points.min(0)]*len(obj.data.vertices))
   faces.extend(tuple(offset+i for i in face.vertices) for face in obj.data.polygons)
  name=identity+'__'+part_key;mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(np.asarray(p)-origin) for p in vertices],[],faces);mesh.update();mesh.materials.append(materials[key])
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
  uv=mesh.uv_layers.new(name='Metres');uv.active_render=True;guides=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER');normals=[None]*len(mesh.loops)
  coordinates=np.empty(len(mesh.vertices)*3);mesh.vertices.foreach_get('co',coordinates);coordinates=coordinates.reshape((-1,3))
  indices=np.empty(len(mesh.loops),dtype=np.int32);mesh.loops.foreach_get('vertex_index',indices);indices=indices.reshape((-1,3));points=coordinates[indices]
  frames_for_faces=[grain_frames[i] for i in indices[:,0]]
  rotations=np.stack([frame[0] if frame is not None else np.eye(3) for frame in frames_for_faces])
  long_grain=np.asarray([frame is not None and frame[1]==0 for frame in frames_for_faces])
  ns,us,values,local=triangle_charts(points,origin,sets[key]['meters_per_tile'],rotations,long_grain);fallbacks+=local
  revolved_charts(points,ns,us,values,np.asarray(uv_axes)[indices[:,0]],np.asarray(uv_centers)[indices[:,0]]-origin,sets[key]['meters_per_tile'])
  if key.startswith('book_'):
   # One decorated catalogue cover per stock; no repeat seam through its face.
   for i in range(len(indices)):
    n=ns[i];tile=sets[key]['meters_per_tile'];low=chart_origins[indices[i,0]]
    if abs(n[2])>.999999:
     us[i]=(1.,0.,0.);v=np.cross(n,us[i]);values[i]=np.column_stack(((points[i]-low)@us[i],(points[i]-low)@v))
     if n[2]<0:values[i,:,1]+=np.max(values[i,:,1])-np.min(values[i,:,1])
     values[i]+=tile*.035
    else:values[i]-=values[i].min(0);values[i]+=tile*np.array((.20,.44))
  uv.data.foreach_set('uv',values.astype(np.float32).ravel())
  guide=np.repeat(us[:,[0,2,1]],3,axis=0);guide[:,2]*=-1;guides.data.foreach_set('vector',guide.astype(np.float32).ravel())
  normals=stock_corner_normals(mesh);mesh.normals_split_custom_set(normals);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;draws.append(obj)
  mesh.calc_loop_triangles();total_triangles+=len(mesh.loop_triangles);inventory.append({'name':name,'assembly':identity,'cell':item['cell'],'key':key,'triangles':len(mesh.loop_triangles)})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/domestic_tables.blend'))
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
asset=OUT/'game/assets/props/domestic_tables.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
records=[]
for item in assemblies:
 parts=[]
 for part in inventory:
  if part['assembly']!=item['id']:continue
  key=part['key'];parts.append({'name':part['name'],'key':key,'tile':sets[key]['meters_per_tile'],**({'catalog_key':plan['catalog_variants'][key]} if key in plan['catalog_variants'] else {}),**({'tint':plan['material_tints'][key]} if key in plan['material_tints'] else {}),**({'finish':plan['finish_parameters'][key]} if key in plan.get('finish_parameters',{}) else {})})
 records.append({'id':item['id'],'parts':parts,**frames[item['id']]})
local_materials={key:{'files':sets[key]['files'],'metallic':sets[key]['metallic'],'roughness':sets[key]['roughness'],'normal_scale':sets[key]['normal_scale'],'color':sets[key]['source_color'],'alpha':sets[key]['alpha']} for key in plan['runtime_keys'] if key not in plan['catalog_variants']}
runtime={'schema_version':1,'asset':'res://assets/props/domestic_tables.glb','floor_y':plan['placement']['floor_y'],'assemblies':records,'instances':plan['instances'],'tint_space':plan['tint_space'],'local_materials':local_materials,'optics':plan['optics']}
(OUT/'game/data/orison_v2/domestic_tables.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',ROOT/'art/blender/scripts/fabrication_grain.py',ROOT/'art/blender/scripts/fabrication_normals.py',ROOT/'art/blender/scripts/fabrication_chart_batch.py',catalog_path,ROOT/'game/scripts/generated/material_sets.gd',OUT/'game/assets/props/domestic_tables.glb.import',*material_definitions]
for key in plan['runtime_keys']:bindings.extend(ROOT/'game/assets/building/textures'/f for f in sets[key]['files'] if f is not None)
bindings.append(ROOT/'art/tools/fix_runtime_texture_imports.py')
bindings.extend([ROOT/'art/data/material_catalog.json',ROOT/'art/textures/catalog_mapping.json',ROOT/'art/tools/generate_runtime_materials.py'])
bindings.extend(ROOT/name for name in ['art/blender/scripts/inspect_domestic_tables.py','art/blender/scripts/render_domestic_tables.py','art/blender/scripts/domestic_tables_geometry.py','art/blender/scripts/build_orison.py','game/data/orison_v2/domestic_furniture.json','game/data/orison_v2/completion_interiors.json','art/data/orison_v2/completion_interiors_source.json'])
bindings.extend(ROOT/name for name in ['game/assets/building/floor_b1.gltf','game/scripts/building/orison_v2_architectural_materials.gd','game/shaders/lamp_glass_surface.gdshader'])
bindings.extend(ROOT/name for name in ['art/blender/scripts/inspect_domestic_furniture_context.py','game/data/orison_v2_blockout.json','art/blender/work_tables.blend','game/data/orison_v2/domestic_surface_props.json','game/tests/fixtures/orison_surface_stock.json'])
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'source_record':a['members'][0]['id']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'retained_stock':retained_stock,'construction_groups':construction_groups,'placement':plan['placement'],'open_work':plan['open_work']}
for name in ['art/blender/domestic_tables_construction.json','game/tests/fixtures/orison_domestic_tables.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('SURFACE STOCK',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'foot contacts')
