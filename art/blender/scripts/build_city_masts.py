"""Restore source-authored city masts and guys against actual saved roof faces.

The generated city layout and its registered closed masses stay authoritative.
Source endpoints/radii are retained as inputs; base/anchor construction is fitted
to actual native faces. There is no new occupied space, control or utility cut.
"""
from pathlib import Path
import collections,hashlib,json,math,re
import bpy,bmesh,numpy as np
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
plan_path=ROOT/'art/data/city_masts/source_plan.json'
layout_path=ROOT/'art/data/building_layout.json'
registration_path=ROOT/'art/blender/city_shells_registration.json'
native_path=ROOT/'art/blender/city_shells.blend'
v2_path=ROOT/'game/data/orison_v2_blockout.json'
plan=json.loads(plan_path.read_text());layout=json.loads(layout_path.read_text())
registration=json.loads(registration_path.read_text())
def digest(path):return hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n') if path.suffix not in ['.blend','.glb'] else path.read_bytes()).hexdigest()
assert plan['classification']=='ADAPTATION' and digest(native_path)==registration['source_native_sha256']
for path,value in registration['bindings'].items():
 if path!='game/data/orison_v2_blockout.json':assert digest(ROOT/path)==value,path
# The historical registration predates later blockout ports. Re-derive every
# consumed registration value from the current authority; do not silently reuse
# an old whole-file binding. Actual saved bounds are checked below as well.
v2=json.loads(v2_path.read_text());regions=json.loads((ROOT/'game/data/orison_v2/exterior/regions.json').read_text())
spaces={r['id']:r for r in v2['spaces']}
instance=next(r for r in regions['instances'] if r['semantic_identity']=='SHOP_BODEGA')
street=next(t for t in regions['surface_templates'] if t['id']=='TEMPLATE_STREET_SEGMENT_V1')
pavement=next(s for s in street['surfaces'] if s['id']=='pavement')
east=float(pavement['point_m'][0])+float(instance['offset_uvn_m'][0])-17.4
west=-(spaces['F01_D_MAIN']['rect'][2]+2.35+.24+.08)-.08-(-15.2)
source_rows=next(row for row in layout['floors'] if row['id']=='F01')['furniture']
ne=[r for r in source_rows if re.match(r'^site_ne\d+_',r['id']) and 'rect' in r and not r['id'].endswith('_beacon')]
region=next(r for r in regions['regions'] if r['id']=='REGION_STREET')
northeast=max(p[0] for p in region['boundary'])+.08-min(r['rect'][0] for r in ne)
derived={'site_nbr_e':east,'site_nbr_w':west}
derived.update({re.match(r'^(site_nw\d+)_',r['id']).group(1):west for r in source_rows if re.match(r'^site_nw\d+_',r['id'])})
derived.update({re.match(r'^(site_ne\d+)_',r['id']).group(1):northeast for r in ne})
assert set(derived)==set(registration['offsets'])
assert all(abs(derived[k]-registration['offsets'][k])<1e-9 for k in derived)
floor=next(row for row in layout['floors'] if row['id']=='F01')
def selected(identity):return identity.startswith(('site_nbr_','site_back_','site_far_')) or re.match(r'^site_(?:nw|ne|sw|se)\d+_',identity)
def group(identity):return '_'.join(identity.split('_')[:3]) if identity.startswith(('site_nbr_','site_back_','site_far_')) else '_'.join(identity.split('_')[:2])
records=[row for row in floor['furniture'] if selected(row['id']) and row.get('asm')=='pipe' and row['id'].rsplit('_',1)[-1] in plan['roles']]
assert len(records)==100
groups=sorted({group(row['id']) for row in records});assert len(groups)==25
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
context=bpy.data.collections.new('RetainedCityReference');bpy.context.scene.collection.children.link(context)
context.hide_render=True
with bpy.data.libraries.load(str(native_path),link=True) as (available,loaded):
 loaded.objects=[identity for identity in available.objects if selected(identity)]
references=loaded.objects
shell_rows={r['id']:r for r in floor['furniture'] if selected(r['id']) and 'rect' in r and not r['id'].endswith('_beacon')}
assert len(references)==335 and {o.name for o in references}==set(shell_rows)
max_bounds_error=0.0
for obj in references:
 row=shell_rows[obj.name];dx=derived.get(group(obj.name),0);x0,y0,x1,y1=row['rect'];z0=float(row.get('z0',0));h=row['h']
 expected=[x0+dx,y0,z0,x1+dx,y1,z0+h]
 pose=Matrix.LocRotScale(obj.location,obj.rotation_euler.to_quaternion(),obj.scale)
 points=[pose@v.co for v in obj.data.vertices]
 actual=[min(p[i] for p in points) for i in range(3)]+[max(p[i] for p in points) for i in range(3)]
 error=max(abs(a-b) for a,b in zip(expected,actual));max_bounds_error=max(max_bounds_error,error)
 assert error<.00002,(obj.name,error)
for obj in references:context.objects.link(obj);obj.hide_set(True)
for library in bpy.data.libraries:library.filepath=bpy.path.relpath(library.filepath,start=str(ROOT/'art/blender'))
trees={};roof_faces=collections.defaultdict(list);flat_faces=collections.defaultdict(list)
for identity in groups:
 vertices=[];faces=[];owners=[]
 for obj in references:
  if group(obj.name)!=identity:continue
  pose=Matrix.LocRotScale(obj.location,obj.rotation_euler.to_quaternion(),obj.scale)
  offset=len(vertices);vertices.extend(pose@v.co for v in obj.data.vertices)
  for face in obj.data.polygons:
   faces.append([offset+i for i in face.vertices]);owners.append(obj.name)
   if max(abs(value) for value in face.normal)>.99999:
    pts=[pose@obj.data.vertices[i].co for i in face.vertices]
    flat_faces[identity].append({'owner':obj.name,'normal':face.normal.copy(),'low':Vector(tuple(min(p[i] for p in pts) for i in range(3))),'high':Vector(tuple(max(p[i] for p in pts) for i in range(3)))})
   if face.normal.z>.99999:
    pts=[pose@obj.data.vertices[i].co for i in face.vertices]
    roof_faces[identity].append({'owner':obj.name,'rect':[min(p.x for p in pts),min(p.y for p in pts),max(p.x for p in pts),max(p.y for p in pts)],'z':pts[0].z})
 assert faces,identity
 trees[identity]=(BVHTree.FromPolygons(vertices,faces,all_triangles=False,epsilon=0),owners)
closed=bpy.data.collections.new('ClosedConstruction');bpy.context.scene.collection.children.link(closed);closed.hide_render=True
welded=bpy.data.collections.new('ClosedFabricatedTrees');bpy.context.scene.collection.children.link(welded);welded.hide_render=True
mat=bpy.data.materials.new(plan['runtime_key']);mat.use_nodes=True
node=mat.node_tree.nodes['Principled BSDF'];node.inputs['Base Color'].default_value=(.23,.24,.22,1);node.inputs['Metallic'].default_value=.8;node.inputs['Roughness'].default_value=.62
sets=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials'];spec=sets[plan['runtime_key']]
node.inputs['Metallic'].default_value=spec['metallic']
texcoord=mat.node_tree.nodes.new('ShaderNodeTexCoord');scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile']
mat.node_tree.links.new(texcoord.outputs['UV'],scale.inputs[0])
for index,target in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
 image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True)
 image.filepath=bpy.path.relpath(image.filepath,start=str(ROOT/'art/blender'))
 if index:image.colorspace_settings.name='Non-Color'
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;mat.node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
 if index==2:
  normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35
  mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs[0],node.inputs[target])
 else:mat.node_tree.links.new(tex.outputs['Color'],node.inputs[target])
pieces=collections.defaultdict(list);contacts=[];source_records=[];inventory=[]
def create(name,vertices,faces,identity):
 origin=Vector(tuple(round(sum(p[i] for p in vertices)/len(vertices),3) for i in range(3)))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(float(p[i])-float(origin[i]) for i in range(3)) for p in vertices],[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 assert all(edge.is_manifold for edge in bm.edges) and bm.calc_volume(signed=True)>1e-12,name
 bm.to_mesh(mesh);bm.free()
 obj=bpy.data.objects.new(name,mesh);closed.objects.link(obj);obj.location=origin;obj.hide_render=True
 mesh.materials.append(mat);pieces[identity].append(obj)
 return obj
def loft(name,a,b,profile,identity,segments=None):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();length=(b-a).length
 seed=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0))
 u=(seed-axis*seed.dot(axis)).normalized();v=axis.cross(u);count=segments or plan['segments']
 expanded=[]
 for (s,r),(t,q) in zip(profile,profile[1:]):
  expanded.append((s,r))
  steps=math.ceil((t-s)/plan['maximum_segment_length'])
  for i in range(1,steps):expanded.append((s+(t-s)*i/steps,r+(q-r)*i/steps))
 expanded.append(profile[-1]);verts=[]
 for along,radius in expanded:
  verts.extend(a+axis*along+radius*(u*math.cos(i*math.tau/count)+v*math.sin(i*math.tau/count)) for i in range(count))
 faces=[tuple(reversed(range(count)))]
 for ring in range(len(expanded)-1):
  for i in range(count):faces.append((ring*count+i,ring*count+(i+1)%count,(ring+1)*count+(i+1)%count,(ring+1)*count+i))
 faces.append(tuple(range((len(expanded)-1)*count,len(expanded)*count)))
 return create(name,verts,faces,identity)
def square_plate(name,hit,normal,identity):
 n=normal.normalized();seed=Vector((0,0,1)) if abs(n.z)<.9 else Vector((1,0,0))
 u=(seed-n*seed.dot(n)).normalized();v=n.cross(u);half=plan['plate_width']/2;depth=plan['plate_thickness']
 corners=[hit+u*x+v*y+n*z for z in [0,depth] for x,y in [(-half,-half),(half,-half),(half,half),(-half,half)]]
 faces=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
 create(name,corners,faces,identity)
 for sx in [-1,1]:
  for sy in [-1,1]:
   point=hit+u*(sx*.061)+v*(sy*.061)+n*(depth-.0001)
   loft(name+f'_Bolt{sx}{sy}',point,point+n*plan['bolt_height'],[(0,plan['bolt_radius']),(plan['bolt_height'],plan['bolt_radius'])],identity,6)
 return [list(hit+u*x+v*y) for x,y in [(-half,-half),(half,-half),(half,half),(-half,half)]]
def roof_seat(identity,nominal):
  # Some source guys aim beyond their stepped roof's edge. Seat the anchor
  # on the closest actual flat native face, with the whole plate inside it.
  candidates=[];margin=plan['plate_width']/2+plan['anchor_snap_margin']
  for face in roof_faces[identity]:
   a,b,c,d=face['rect']
   if c-a<=2*margin or d-b<=2*margin or face['z']>nominal.z:continue
   at=Vector((min(max(nominal.x,a+margin),c-margin),min(max(nominal.y,b+margin),d-margin),face['z']))
   candidates.append(((at-nominal).length,at,face['owner']))
  assert candidates,(identity,tuple(nominal))
  distance,point,owner=min(candidates,key=lambda row:row[0]);return point,Vector((0,0,1)),owner
def surface(identity,high,direction,nominal=None):
 tree,owners=trees[identity];point,normal,index,distance=tree.ray_cast(high,direction,100)
 if point is None and nominal is not None:return roof_seat(identity,nominal)
 assert point is not None,(identity,tuple(high),tuple(direction))
 if normal.dot(direction)>0:normal=-normal
 # Seat the entire plate inside the actual flat face, including its bevel
 # setback. A centre hit alone can leave two corners over a parapet edge.
 owner=owners[index];margin=plan['plate_width']/2+plan['anchor_snap_margin']
 candidates=[];alternatives=[]
 for face in flat_faces[identity]:
  face_normal=face['normal'];axis=max(range(3),key=lambda i:abs(face_normal[i]));tangent=[i for i in range(3) if i!=axis]
  if any(face['high'][i]-face['low'][i]<=2*margin for i in tangent):continue
  at=point.copy();at[axis]=face['low'][axis]
  for i in tangent:at[i]=min(max(at[i],face['low'][i]+margin),face['high'][i]-margin)
  if nominal is not None:
   low=at+face_normal*(plan['plate_thickness']+plan['eye_height'])
   hit,_,_,_=tree.ray_cast(high,(low-high).normalized(),(low-high).length-.001)
   if hit is not None:continue
  target=candidates if face['owner']==owner and face_normal.dot(normal)>.99999 else alternatives
  target.append(((at-point).length,at,face_normal,face['owner']))
 if not candidates:candidates=alternatives
 assert candidates,(identity,owner,tuple(normal))
 _,point,normal,owner=min(candidates,key=lambda row:row[0])
 return point,normal,owner
for identity in groups:
 rows=[r for r in records if group(r['id'])==identity];mast=next(r for r in rows if r['id'].endswith('_mast'))
 shift=registration['offsets'].get(identity,0)
 def point(p):return Vector((p[0]+shift,p[1],p[2]))
 top=point(mast['p1']);base,n,owner=surface(identity,top,Vector((0,0,-1)))
 assert n.z>.99999,(identity,n)
 footprint=square_plate(mast['id']+'_Plate',base,n,identity)
 start=base+n*(plan['plate_thickness']-.0001);length=(top-start).length;r=mast['r']
 loft(mast['id'],start,top,[(0,r+.015),(plan['mast_collar_height'],r+.015),(plan['mast_collar_height'],r),(length,r)],identity)
 contacts.append({'id':mast['id'],'owner':owner,'point':list(base),'normal':list(n),'role':'mast_base','footprint':footprint})
 for row in rows:
  source_records.append({**row,'registration_offset_x':shift})
  if row is mast:continue
  high=point(row['p0']);nominal=point(row['p1']);direction=(nominal-high).normalized()
  toe,normal,owner=surface(identity,high,direction,nominal)
  footprint=square_plate(row['id']+'_Plate',toe,normal,identity)
  low=toe+normal*(plan['plate_thickness']+plan['eye_height'])
  hit,_,_,_=trees[identity][0].ray_cast(high,(low-high).normalized(),(low-high).length-.001)
  assert hit is None,('guy crosses retained city solid',row['id'])
  # The short terminal post joins the actual supported plate to the ferrule.
  loft(row['id']+'_Terminal',toe+normal*(plan['plate_thickness']-.0001),low,[(0,row['r']*1.6),(plan['eye_height']+.0001,row['r']*1.6)],identity)
  length=(high-low).length;r=row['r']
  loft(row['id'],low,high,[(0,r*1.7),(.075,r*1.7),(.075,r),(length,r)],identity)
  contacts.append({'id':row['id'],'owner':owner,'point':list(toe),'normal':list(normal),'role':'guy_anchor','footprint':footprint,'nominal_endpoint':list(nominal),'fitted_endpoint':list(low)})

for contact in contacts:
 tree,owners=trees[group(contact['id'])];normal=Vector(contact['normal'])
 for corner in contact['footprint']:
  p=Vector(corner);hit,_,index,_=tree.ray_cast(p+normal*.003,-normal,.006)
  assert hit is not None and (hit-p).length<.0001 and owners[index]==contact['owner'],contact['id']
def clip(polygon,axis,at,sign):
 result=[]
 for a,b in zip(polygon,polygon[1:]+polygon[:1]):
  da=(a[axis]-at)*sign;db=(b[axis]-at)*sign
  if da>=0:result.append(a)
  if (da>0 and db<0) or (da<0 and db>0):
   p=[float(a[i])+(float(b[i])-float(a[i]))*float(da)/(float(da)-float(db)) for i in range(3)];p[axis]=at;result.append(Vector(p))
 cleaned=[]
 for p in result:
  if not cleaned or (p-cleaned[-1]).length>1e-8:cleaned.append(p)
 if len(cleaned)>1 and (cleaned[0]-cleaned[-1]).length<=1e-8:cleaned.pop()
 return cleaned
draws=[];total_triangles=0
for identity in groups:
 # Union this static fabricated tree once, preserving closed source stocks.
 original=pieces[identity];objects=[]
 for obj in original:
  copy=obj.copy();copy.data=obj.data.copy();bpy.context.scene.collection.objects.link(copy);copy.hide_render=False;copy.hide_set(False);objects.append(copy)
 result=objects[0]
 for other in objects[1:]:
  bpy.context.view_layer.objects.active=result
  mod=result.modifiers.new('Fabricated joint','BOOLEAN');mod.operation='UNION';mod.solver='MANIFOLD';mod.object=other
  bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(other,do_unlink=True)
 bm=bmesh.new();bm.from_mesh(result.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,identity
 bmesh.ops.triangulate(bm,faces=list(bm.faces))
 bm.to_mesh(result.data);bm.free()
 assembled=result.copy();assembled.data=result.data.copy();welded.objects.link(assembled);assembled.name=identity+'__ClosedFabricatedTree';assembled.hide_render=True
 # Retained city owns every exact plate backing plane. Export all other faces.
 pose=Matrix.LocRotScale(result.location,result.rotation_euler.to_quaternion(),result.scale)
 faces=[]
 for face in result.data.polygons:
  pts=[pose@result.data.vertices[i].co for i in face.vertices]
  if any(all(abs((p-Vector(c['point'])).dot(Vector(c['normal'])))<2e-7 for p in pts) for c in contacts if group(c['id'])==identity):continue
  faces.append(pts)
 bpy.data.objects.remove(result,do_unlink=True)
 partitions=collections.defaultdict(list)
 for polygon in faces:
  low=[math.floor(min(p[i] for p in polygon)/4) for i in range(3)];high=[math.floor(max(p[i] for p in polygon)/4) for i in range(3)]
  for x in range(low[0],high[0]+1):
   for y in range(low[1],high[1]+1):
    for z in range(low[2],high[2]+1):
     cell=(x,y,z);clipped=polygon
     for axis,index in enumerate(cell):
      clipped=clip(clipped,axis,index*4.,1);clipped=clip(clipped,axis,(index+1)*4.,-1)
      if len(clipped)<3:break
     if len(clipped)<3:continue
     area=sum((clipped[i]-clipped[0]).cross(clipped[i+1]-clipped[0]).length/2 for i in range(1,len(clipped)-1))
     if area<=1e-13:continue
     partitions[cell].append(clipped)
 for cell,polygons in sorted(partitions.items()):
  name=identity+'__'+('_'.join(map(str,cell)))+'__'+plan['runtime_key']
  vertices=[];faces=[]
  for polygon in polygons:
   first=len(vertices);vertices.extend(polygon);faces.append(tuple(range(first,first+len(polygon))))
  origin=Vector(tuple(round(sum(p[i] for p in vertices)/len(vertices),3) for i in range(3)))
  mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(float(p[i])-float(origin[i]) for i in range(3)) for p in vertices],[],faces);mesh.update();mesh.materials.append(mat)
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
  chart=mesh.uv_layers.new(name='Metres');chart.active_render=True
  guides=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER')
  split_normals=[None]*len(mesh.loops)
  for face in mesh.polygons:
   # Double precision and an edge-aligned local chart preserve narrow joint
   # triangles without subtracting two large almost-equal UV coordinates.
   pts=np.asarray([mesh.vertices[i].co[:] for i in face.vertices],dtype=np.float64)
   n=np.cross(pts[1]-pts[0],pts[2]-pts[0]);n/=np.linalg.norm(n)
   a,b=max([(i,(i+1)%3) for i in range(3)],key=lambda pair:np.linalg.norm(pts[pair[1]]-pts[pair[0]]))
   u=pts[b]-pts[a];u/=np.linalg.norm(u);v=np.cross(n,u)
   for loop in face.loop_indices:
    p=np.asarray(mesh.vertices[mesh.loops[loop].vertex_index].co[:],dtype=np.float64)-pts[a]
    chart.data[loop].uv=(float(np.dot(p,u)),float(np.dot(p,v)))
    guides.data[loop].vector=(float(u[0]),float(u[2]),float(-u[1]));split_normals[loop]=tuple(n)
  mesh.normals_split_custom_set(split_normals)
  obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;draws.append(obj)
  mesh.calc_loop_triangles();triangles=len(mesh.loop_triangles);total_triangles+=triangles
  inventory.append({'name':name,'group':identity,'key':plan['runtime_key'],'triangles':triangles})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/city_masts.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in draws:obj.select_set(True)
class ExportUVHandedness:
 corrected=0
 def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
  # The guide is native authoring data; only the derived standard tangent
  # enters the portable mesh, without an unused custom runtime attribute.
  for primitive in mesh.primitives:
   # Attribute callbacks run in mesh storage order; custom corner data may
   # precede POSITION and NORMAL. Read the completed primitive instead.
   def vectors(key):
    accessor=primitive.attributes[key]
    assert accessor.component_type==5126 and accessor.type=='VEC3'
    array=np.frombuffer(accessor.buffer_view.data,dtype='<f4').reshape((-1,3)).astype(np.float64)
    assert len(array)==primitive.attributes['POSITION'].count
    return array
   n=vectors('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None]
   guide=vectors('_TANGENT_GUIDE')
   tangent=guide-n*np.sum(guide*n,axis=1)[:,None]
   tangent/=np.linalg.norm(tangent,axis=1)[:,None]
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
asset=ROOT/'game/assets/props/city_masts.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True)
assert ExportUVHandedness.corrected==len(draws),(ExportUVHandedness.corrected,len(draws))
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':source_records,'original_record_count':len(records),'groups':groups,'closed_source_stocks':sum(len(v) for v in pieces.values()),'closed_fabricated_trees':len(groups),'parts':inventory,'triangles':total_triangles,'contacts':contacts,'current_native_derivation':{'bounds_checked':335,'max_bounds_error_m':max_bounds_error,'current_offsets':derived,'historical_blockout_binding_stale':digest(v2_path)!=registration['bindings']['game/data/orison_v2_blockout.json']},'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in [plan_path,layout_path,registration_path,native_path,v2_path]},'open_work':plan['open_work']}
for path in ['art/blender/city_masts_construction.json','game/tests/fixtures/orison_city_masts.json']:(ROOT/path).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('CITY MASTS',len(records),'original components;',len(groups),'roofs;',report['closed_source_stocks'],'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'actual support contacts')
