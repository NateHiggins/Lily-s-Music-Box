"""Retained poison cupboard and six tactile coloured bottles."""
from pathlib import Path
import collections,hashlib,json,math,re,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
import os
OUT=Path(os.environ.get('DRUGGIST_CUPBOARD_OUT',str(ROOT)))
plan_path=Path(os.environ.get('DRUGGIST_CUPBOARD_PLAN',str(ROOT/'art/data/druggist_cupboard/source_plan.json')));layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text(encoding='utf-8'));layout=json.loads(layout_path.read_text(encoding='utf-8'));assert plan['classification']=='ADAPTATION'
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_otis_son.gltf';source_gltf=json.loads(source_gltf_path.read_text(encoding='utf-8'));sets={};material_definitions=[]
catalog_path=Path(os.environ.get('DRUGGIST_CUPBOARD_CATALOG',str(ROOT/'game/data/runtime_material_sets.json')));catalog=json.loads(catalog_path.read_text(encoding='utf-8'))['materials']
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
floor=rows['storm_shop_otis___son_floor'];ceil=rows['storm_shop_otis___son_ceil'];selected=[];assemblies=[]
for group in plan['groups']:
 members=[rows[identity] for identity in group['sources']];selected.extend(members);assemblies.append({'id':members[0]['id'],'kind':group['kind'],'members':members,'body':members[0],'cell':'shop_otis_son','floor':floor})
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
 verts=[];n=8
 closed=(points[-1]-points[0]).length<1e-8
 if closed:points.pop()
 for i,p in enumerate(points):
  tangent=(points[(i+1)%len(points)]-points[(i-1)%len(points)]).normalized() if closed else (points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
  seed=Vector((0,1,0)) if abs(tangent.y)<.9 else Vector((1,0,0));u=tangent.cross(seed).normalized();v=tangent.cross(u)
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
 n=96;verts=[];rings=[];closed_profile=profile[0]==profile[-1]
 if closed_profile:profile=profile[:-1]
 start_cap=not closed_profile and profile[0][0]==0 and profile[0][1]==profile[1][1]
 end_cap=not closed_profile and profile[-1][0]==0 and profile[-1][1]==profile[-2][1]
 if start_cap:profile=profile[1:]
 if end_cap:profile=profile[:-1]
 for radius,height in profile:
  if radius==0:rings.append([len(verts)]);verts.append((cx,cy,z+height))
  else:
   rings.append(list(range(len(verts),len(verts)+n)));verts.extend((cx+radius*math.cos(i*math.tau/n),cy+radius*math.sin(i*math.tau/n),z+height) for i in range(n))
 faces=[tuple(reversed(rings[0]))] if start_cap else []
 for a,b in zip(rings,rings[1:]+(rings[:1] if closed_profile else [])):
  if len(a)==1 and len(b)==1:continue
  for i in range(n):
   if len(a)==1:faces.append((a[0],b[i],b[(i+1)%n]))
   elif len(b)==1:faces.append((a[i],b[0],a[(i+1)%n]))
   else:faces.append((a[i],b[i],b[(i+1)%n],a[(i+1)%n]))
 if end_cap:faces.append(tuple(rings[-1]))
 return solid(name,verts,faces,identity,key)

prefix="storm_shop_otis___son_"
for item,group in zip(assemblies,plan['groups']):
 identity=item['id'];row=item['body'];x0,y0,x1,y1=row['rect']
 if item['kind']=='cupboard':
  # Return the rear edge clear of the fitted closed-door knob; front and bottles stay fixed.
  y1-=.060
  base=row['z0'];top=base+row['h']
  for i,(xx,yy) in enumerate([(x0+.05,y0+.05),(x1-.05,y0+.05),(x0+.05,y1-.05),(x1-.05,y1-.05)]):
   box(identity+'_FloorFoot'+str(i),(xx-.025,yy-.025,.01),(xx+.025,yy+.025,base+.010),identity,'wood_dark',.002)
   support(identity,floor['id'],(xx,yy,.01),(0,0,1),'cupboard foot on actual original floor')
  box(identity+'_SeatedPlinth',(x0,y0,base),(x1,y1,base+.035),identity,'wood_dark',.002)
  for i,(a,b) in enumerate([(x0,x0+.034),(x1-.034,x1)]):box(identity+'_Side'+str(i),(a,y0,base+.030),(b,y1,top-.010),identity,'wood_dark',.002)
  box(identity+'_Back',(x0+.02,y1-.020,base+.03),(x1-.02,y1,top-.015),identity,'wood_dark',.001)
  box(identity+'_Crown',(x0,y0,top-.035),(x1,y1,top),identity,'wood_dark',.002)
  for i,(a,b) in enumerate([(.25,.59),(1.49,1.925)]):box(identity+'_FrontPanel'+str(i),(x0+.025,y0,a),(x1-.025,y0+.030,b),identity,'wood_dark',.002)
  for i,(a,b) in enumerate([(22.425,22.462),(23.098,23.135)]):box(identity+'_FixedLeafStile'+str(i),(a,-45.218,.568),(b,-45.190,1.512),identity,'wood_dark',.001)
  for i,(a,b) in enumerate([(.568,.586),(1.494,1.512)]):box(identity+'_FixedLeafRail'+str(i),(22.425,-45.218,a),(23.135,-45.190,b),identity,'wood_dark',.001)
  box(identity+'_ThinInsetPane',(22.460,-45.205,.580),(23.100,-45.199,1.500),identity,'glassish',0)
  for i,z in enumerate([.63,1.01]):box(identity+'_BottleShelf'+str(i),(x0+.020,y0+.030,z),(x1-.020,y1-.010,z+.030),identity,'wood_dark',.001)
  for i,z in enumerate([.62,1.40]):
   box(identity+'_HingeLeaf'+str(i),(22.430,-45.219,z),(22.448,-45.213,z+.065),identity,'brass_dull',.0005)
   rod(identity+'_HingeKnuckle'+str(i),(22.442,-45.207,z+.002),(22.442,-45.207,z+.063),.006,identity,'brass_dull',32)
  # A four-piece escutcheon leaves a real slot; this fixed leaf has no new
  # gameplay access owner. All hardware remains inside the source footprint.
  for i,(a,b,c,d) in enumerate([(23.103,23.124,1.12,1.143),(23.103,23.124,1.157,1.18),(23.103,23.110,1.139,1.161),(23.117,23.124,1.139,1.161)]):
   box(identity+'_PassiveLockPlate'+str(i),(a,-45.219,c),(b,-45.214,d),identity,'brass_dull',.0005)
 elif item['kind']=='bottle':
  cx=(x0+x1)*.5;cy=(y0+y1)*.5;z=row['z0'];color='red' if row['mat']=='lacquer_red' else 'teal'
  vessel(identity+'_HollowTactileBottle',cx,cy,z,[(0,0),(.024,0),(.0325,.006),(.0335,.030),(.0335,.225),(.0215,.265),(.0125,.279),(.0125,.310),(.0085,.310),(.0085,.283),(.0175,.270),(.0275,.226),(.0275,.012),(0,.012)],identity,'glass_'+color)
  vessel(identity+'_SeparateStopper',cx,cy,z+.300,[(0,0),(.009,0),(.009,.040),(0,.040)],identity,'wood_dark')
  for i in range(12):
   a=i*math.tau/12;outline=[(cx+r*math.cos(t),cy+r*math.sin(t)) for r,t in [(.0325,a-.035),(.0345,a-.035),(.0345,a+.035),(.0325,a+.035)]]
   prism(identity+'_TactileRib'+str(i),outline,z+.040,z+.213,identity,'ribs_'+color,0)
  outline=[(cx+r*math.sin(a),cy-r*math.cos(a)) for r,angles in [(.036,[-.2,-.1,0,.1,.2]),(.0325,[.2,.1,0,-.1,-.2])] for a in angles]
  prism(identity+'_BlankPorcelainPlate',outline,z+.060,z+.110,identity,'porcelain',0)
  support(identity,prefix+'poison_cupboard',(cx,cy,z),(0,0,1),'bottle on actual cupboard shelf at retained seat')
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

def turned_chart(points,origin):
 """Unfold each lathe frustum as a continuous, isometric sector strip."""
 p=points+origin;n=np.cross(points[1]-points[0],points[2]-points[0]);n/=np.linalg.norm(n)
 radial=p[:,:2]-np.array((cx,cy));radius=np.linalg.norm(radial,axis=1);height=p[:,2]
 if max(height)-min(height)<.0000003:
  values=p[:,:2].copy()
 else:
  low=min(height);high=max(height);r0=float(np.mean(radius[abs(height-low)<.0000003]));r1=float(np.mean(radius[abs(height-high)<.0000003]))
  angles=np.arctan2(radial[:,1],radial[:,0])%math.tau;index=np.rint(angles/math.tau*96).astype(int)%96
  if max(index)-min(index)>48:index=np.where(index<48,index+96,index)
  if abs(r1-r0)<.0000003:
   values=np.column_stack((index*(2*r0*math.sin(math.pi/96)),height-low))
  else:
   length=math.hypot(r1-r0,high-low);factor=length/abs(r1-r0);step=2*math.asin(math.sin(math.pi/96)/factor)
   distance=radius*factor;angle=index*step;values=np.column_stack((distance*np.sin(angle),distance*np.cos(angle)))
 values-=np.floor(values.min(axis=0)/sets[key]['meters_per_tile'])*sets[key]['meters_per_tile']
 def derivatives():
  a=values[1]-values[0];b=values[2]-values[0];det=a[0]*b[1]-b[0]*a[1];assert abs(det)>1e-12,(name,p.tolist(),values.tolist(),radius.tolist(),height.tolist())
  u=((points[1]-points[0])*b[1]-(points[2]-points[0])*a[1])/det
  v=((points[2]-points[0])*a[0]-(points[1]-points[0])*b[0])/det
  return u/np.linalg.norm(u),v
 u,v=derivatives()
 if np.dot(np.cross(n,u),v)<0:values[:,1]=-values[:,1];u,v=derivatives()
 for a,b in [(0,1),(1,2),(2,0)]:assert abs(np.linalg.norm(values[b]-values[a])-np.linalg.norm(points[b]-points[a]))<.000004,(p.tolist(),values.tolist(),radius.tolist(),height.tolist(),a,b)
 normals=[]
 for xy in radial:
  normal=n.copy()
  if abs(n[2])<.99 and np.linalg.norm(xy)>.00001:
   sign=1 if np.dot(n[:2],xy)>0 else -1;normal[:2]=xy/np.linalg.norm(xy)*math.sqrt(1-n[2]**2)*sign
  normals.append(normal)
 return n,u,values,normals

draws=[];inventory=[];fallbacks=0;total_triangles=0
for item in assemblies:
 identity=item['id'];keys=sorted({partition_of(obj,key) for obj,key in pieces[identity]});rect=item['body']['rect'];origin=np.array(((rect[0]+rect[2])*.5,(rect[1]+rect[3])*.5,item['body']['z0']))
 for part_key in keys:
  key=part_key;vertices=[];faces=[]
  turned=item['kind']=='bottle' and key in ['glass_red','glass_teal','wood_dark']
  if item['kind']=='bottle':cx=(rect[0]+rect[2])*.5;cy=(rect[1]+rect[3])*.5
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
   if turned:n,u,values,smooth=turned_chart(points,origin)
   else:
    n,u,values,local=chart_for_triangle(points,origin,sets[key]['meters_per_tile'],key in ['timber','wood_dark']);fallbacks+=local;smooth=[n,n,n]
   for j,loop in enumerate(face.loop_indices):uv.data[loop].uv=tuple(values[j]);guides.data[loop].vector=(float(u[0]),float(u[2]),float(-u[1]));normals[loop]=tuple(smooth[j])
  mesh.normals_split_custom_set(normals);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;draws.append(obj)
  mesh.calc_loop_triangles();total_triangles+=len(mesh.loop_triangles);inventory.append({'name':name,'assembly':identity,'cell':item['cell'],'key':key,'triangles':len(mesh.loop_triangles)})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/druggist_cupboard.blend'))
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
asset=OUT/'game/assets/props/druggist_cupboard.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
cells=[]
for identity in sorted({a['cell'] for a in assemblies}):
 items=[a for a in assemblies if a['cell']==identity];replace=[]
 for item in items:
  for row in item['members']:
   x0,y0,x1,y1=row['rect'];z0=row['z0'];replace.append({'id':row['id'],'key':row['mat'],'low':[x0,z0,-y1],'high':[x1,z0+row['h'],-y0],'expected_triangles':12})
 cells.append({'id':identity,'parts':[{'name':p['name'],'key':plan.get('material_aliases',{}).get(p['key'],p['key']),'tile':sets[p['key']]['meters_per_tile'],**({'plain_alpha':True} if p['key']=='glassish' else {}),**({'catalog_key':plan['catalog_variants'][p['key']]} if p['key'] in plan['catalog_variants'] else {}),**({'tint':plan['material_tints'][p['key']]} if p['key'] in plan.get('material_tints',{}) else {}),} for p in inventory if p['cell']==identity],'replace':replace})
runtime={'schema_version':1,'asset':'res://assets/props/druggist_cupboard.glb','tolerance':plan['trim_tolerance_m'],'cells':cells}
(OUT/'game/data/orison_v2/druggist_cupboard.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',catalog_path,ROOT/'game/scripts/generated/material_sets.gd',OUT/'game/assets/props/druggist_cupboard.glb.import',*material_definitions]
for key in plan['runtime_keys']:bindings.extend(ROOT/'game/assets/building/textures'/f for f in sets[key]['files'] if f is not None)
bindings.extend([ROOT/'art/tools/build_iron_blackened.py',ROOT/'art/data/material_catalog.json',ROOT/'art/textures/catalog_mapping.json',ROOT/'art/tools/generate_runtime_materials.py'])
bindings.extend(ROOT/f'art/textures/procedural/iron_blackened/{name}.png' for name in ['albedo','roughness','normal','height'])
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/{identity}.{suffix}' for identity in sorted({a['cell'] for a in assemblies}) for suffix in ['gltf','bin'])
bindings.append(OUT/'art/blender/scripts/inspect_druggist_cupboard.py')
bindings.extend([ROOT/'game/assets/props/druggist_dispensary.glb',ROOT/'game/data/orison_v2/druggist_dispensary.json'])
bindings.extend([ROOT/'game/scripts/building/orison_v2_architectural_materials.gd',ROOT/'game/shaders/lamp_glass_surface.gdshader'])

report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/druggist_cupboard_construction.json','game/tests/fixtures/orison_druggist_cupboard.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('DRUGGIST CUPBOARD',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'foot contacts')
