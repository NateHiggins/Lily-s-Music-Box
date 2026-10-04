"""Fabricate original passive roof tanks against the saved native city faces.

The generated city layout and its registered closed masses stay authoritative.
Source endpoints/radii are retained as inputs; base/anchor construction is fitted
to actual native faces. There is no new occupied space, control or utility cut.
"""
from pathlib import Path
import collections,hashlib,json,math,re
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from fabrication_uvs import chart_for_triangle
import bpy,bmesh,numpy as np
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
plan_path=ROOT/'art/data/city_tanks/source_plan.json'
layout_path=ROOT/'art/data/building_layout.json'
registration_path=ROOT/'art/blender/city_shells_registration.json'
native_path=ROOT/'art/blender/city_shells.blend'
v2_path=ROOT/'game/data/orison_v2_blockout.json'
plan=json.loads(plan_path.read_text());layout=json.loads(layout_path.read_text())
registration=json.loads(registration_path.read_text())
def digest(path):return hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n') if path.suffix not in ['.blend','.glb','.png'] else path.read_bytes()).hexdigest()
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
assert len(records)==plan['original_record_count']
groups=sorted({group(row['id']) for row in records});assert len(groups)==14
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
materials={};sets=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
for key in plan['runtime_keys']:
 mat=bpy.data.materials.new(key);mat.use_nodes=True;materials[key]=mat
 node=mat.node_tree.nodes['Principled BSDF'];spec=sets[key]
 node.inputs['Metallic'].default_value=spec.get('metallic',0)
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
pieces=collections.defaultdict(list);contacts=[];source_records=[];inventory=[];spans=[];tank_inventory=[];assemblies={}
def create(name,vertices,faces,identity,key="galvanized_roof"):
 origin=Vector(tuple(round(sum(p[i] for p in vertices)/len(vertices),3) for i in range(3)))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(float(p[i])-float(origin[i]) for i in range(3)) for p in vertices],[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 assert all(edge.is_manifold for edge in bm.edges) and bm.calc_volume(signed=True)>1e-12,name
 bm.to_mesh(mesh);bm.free()
 obj=bpy.data.objects.new(name,mesh);closed.objects.link(obj);obj.location=origin;obj.hide_render=True
 for material in materials.values():mesh.materials.append(material)
 for face in mesh.polygons:face.material_index=plan['runtime_keys'].index(key)
 pieces[identity].append(obj)
 return obj
def loft(name,a,b,profile,identity,segments=None,key="galvanized_roof"):
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
 return create(name,verts,faces,identity,key)
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
def roof_seat(identity,nominal,upper=None,end_height=None):
  # Some source guys aim beyond their stepped roof's edge. Seat the anchor
  # on the closest actual flat native face, with the whole plate inside it.
  candidates=[];margin=plan['plate_width']/2+plan['anchor_snap_margin']
  for face in roof_faces[identity]:
   a,b,c,d=face['rect']
   if c-a<=2*margin or d-b<=2*margin or face['z']>nominal.z:continue
   at=Vector((min(max(nominal.x,a+margin),c-margin),min(max(nominal.y,b+margin),d-margin),face['z']))
   tree,owners=trees[identity]
   hit,_,index,_=tree.ray_cast(at+Vector((0,0,.003)),Vector((0,0,-1)),.006)
   if hit is None or owners[index]!=face['owner'] or (hit-at).length>=.0001:continue
   high=nominal if upper is None else upper
   low=at+Vector((0,0,plan['plate_thickness']+.001 if end_height is None else end_height))
   hit,_,_,_=tree.ray_cast(high,(low-high).normalized(),(low-high).length-.001)
   if hit is not None:continue
   # Keep a vertical support under its original upper attachment wherever
   # a complete exposed plate fits. A nearby taller bulkhead is not its roof.
   horizontal=Vector((at.x-nominal.x,at.y-nominal.y,0)).length
   candidates.append(((horizontal,(at-nominal).length),at,face['owner']))
  assert candidates,(identity,tuple(nominal))
  distance,point,owner=min(candidates,key=lambda row:row[0]);return point,Vector((0,0,1)),owner
def supported_post(row,identity,assembly,point):
 top=point(row['p1']);base,n,owner=roof_seat(identity,top)
 assert top.z>base.z+.1,row['id']
 footprint=square_plate(row['id']+'_Plate',base,n,assembly)
 contacts.append({'id':row['id'],'group':identity,'assembly':assembly,'owner':owner,'point':list(base),'normal':list(n),'role':'post_base','footprint':footprint,'nominal_endpoint':list(point(row['p0']))})
 return base+n*(plan['plate_thickness']-.0001),top

def span_check(identity,label,high,low):
 direction=(low-high).normalized();hit,_,_,_=trees[identity][0].ray_cast(high, direction,(low-high).length-.001)
 assert hit is None,('aerial crosses retained city solid',label)
 spans.append({'id':label,'group':identity,'high':list(high),'low':list(low)})


hardware=[]
for asset in ['city_masts','city_aerials']:
 with bpy.data.libraries.load(str(ROOT/f'art/blender/{asset}.blend'),link=True) as (available,loaded):loaded.objects=[n for n in available.objects if n.endswith('__ClosedFabricatedTree') and group(n) in groups]
 hardware.extend(loaded.objects)
hardware_reference=bpy.data.collections.new('RetainedHardwareReference');bpy.context.scene.collection.children.link(hardware_reference);hardware_reference.hide_render=True
for obj in hardware:hardware_reference.objects.link(obj);obj.hide_set(True)
for library in bpy.data.libraries:
 name=Path(library.filepath).name
 assert name in ['city_shells.blend','city_masts.blend','city_aerials.blend'],name
 # All three native references live beside this saved file. Do not resolve
 # already-relative child-library paths against an untitled factory scene.
 library.filepath='//'+name
edges={}
for identity in groups:
 starts=[];ends=[]
 for o in hardware:
  if group(o.name)!=identity:continue
  at=Matrix.LocRotScale(o.location,o.rotation_euler.to_quaternion(),o.scale);points=np.asarray([at@v.co for v in o.data.vertices],dtype=np.float64)
  for e in o.data.edges:starts.append(points[e.vertices[0]]);ends.append(points[e.vertices[1]])
 edges[identity]=(np.asarray(starts),np.asarray(ends))
def clear_cylinder(identity,center,radius,low,high):
 a,b=edges[identity];d=b-a;dz=d[:,2];sloped=np.abs(dz)>1e-9
 t0=np.divide(low-a[:,2],dz,out=np.zeros_like(dz),where=sloped);t1=np.divide(high-a[:,2],dz,out=np.zeros_like(dz),where=sloped)
 lo=np.maximum(0,np.minimum(t0,t1));hi=np.minimum(1,np.maximum(t0,t1));flat_inside=(a[:,2]>=low)&(a[:,2]<=high);lo=np.where(sloped,lo,np.where(flat_inside,0,1));hi=np.where(sloped,hi,np.where(flat_inside,1,0));valid=lo<=hi
 if not valid.any():return True
 p=(a+lo[:,None]*d)[valid,:2]-np.asarray(center[:2]);q=(a+hi[:,None]*d)[valid,:2]-np.asarray(center[:2]);delta=q-p;den=np.sum(delta*delta,axis=1);t=np.clip(np.divide(-np.sum(p*delta,axis=1),den,out=np.zeros_like(den),where=den>1e-16),0,1);closest=p+delta*t[:,None]
 return np.min(np.sum(closest*closest,axis=1))>radius**2

def fit_tank(identity):
 rows={row['id'].rsplit('_',1)[-1]:row for row in records if group(row['id'])==identity};shift=derived.get(identity,0);tank=rows['wtank'];base=Vector((tank['p0'][0]+shift,tank['p0'][1],tank['p0'][2]));upper=rows['wcone']['p1'][2]+.02
 found=None;attempts=0
 for ring in range(61):
  for angle in ([0] if ring==0 else [math.pi/2,-math.pi/2,0,math.pi]+[i*math.tau/16 for i in range(16) if i not in [0,4,8,12]]):
   dx=ring*.1*math.cos(angle);dy=ring*.1*math.sin(angle);candidate=base+Vector((dx,dy,0));feet=[];attempts+=1
   for role in ['wleg-1-1','wleg-11','wleg1-1','wleg11']:
    p=Vector((rows[role]['p1'][0]+shift+dx,rows[role]['p1'][1]+dy,rows[role]['p1'][2]))
    foot,n,owner=roof_seat(identity,p)
    if abs(foot.x-p.x)>1e-4 or abs(foot.y-p.y)>1e-4 or p.z-foot.z<.1:break
    feet.append(foot)
   if len(feet)!=4:continue
   if clear_cylinder(identity,candidate,tank['r']+.15,min(p.z for p in feet)-.0002,upper):found=[dx,dy];break
  if found is not None:break
 assert found is not None,identity
 return {'original_center_registered':list(base),'fitted_translation_xy_m':found,'distance_m':math.hypot(*found),'candidate_checks':attempts}

placements={}
boundary_checks={}
def closed_tank_boundary_check(bm,label):
 # A sealed hollow tank has an exterior boundary and a separate inward cavity
 # boundary, while the material volume remains connected. Preserve Boolean
 # winding; normal recalculation on each shell would reverse that cavity.
 assert all(e.is_manifold and e.is_contiguous for e in bm.edges),label
 unseen=set(bm.verts);shells=[]
 while unseen:
  stack=[unseen.pop()];verts=[];faces=set()
  while stack:
   vertex=stack.pop();verts.append(vertex);faces.update(vertex.link_faces)
   for edge in vertex.link_edges:
    other=edge.other_vert(vertex)
    if other in unseen:unseen.remove(other);stack.append(other)
  signed=0.
  for face in faces:
   ps=np.asarray([v.co[:] for v in face.verts],dtype=np.float64)
   for j in range(1,len(ps)-1):signed+=np.dot(ps[0],np.cross(ps[j],ps[j+1]))/6
  shells.append((signed,verts,faces))
 assert len(shells) in [1,2],(label,len(shells))
 outer=[s for s in shells if s[0]>0];inner=[s for s in shells if s[0]<0]
 assert len(outer)==1 and len(inner)==len(shells)-1 and sum(s[0] for s in shells)>0,(label,[s[0] for s in shells])
 if inner:
  outer_vertices=outer[0][1];index={v:i for i,v in enumerate(outer_vertices)}
  tree=BVHTree.FromPolygons([v.co for v in outer_vertices],[[index[v] for v in f.verts] for f in outer[0][2]],all_triangles=False,epsilon=0)
  direction=Vector((.163,.271,.949)).normalized()
  for vertex in inner[0][1]:
   at=vertex.co.copy();crossings=0
   for step in range(100):
    hit,n,i,d=tree.ray_cast(at,direction,1000)
    if hit is None:break
    if step==0:assert d>.0001,(label,'cavity touches exterior')
    crossings+=1;at=hit+direction*.00001
   assert crossings%2==1,(label,'cavity is not contained',list(vertex.co))
 boundary_checks[label]={'surface_components':len(shells),'signed_boundary_volumes_m3':[s[0] for s in shells],'cavity_vertices_checked':len(inner[0][1]) if inner else 0}
 return [s[0] for s in shells]

def box(name,low,high,identity,key='galvanized_roof'):
 points=[Vector((x,y,z)) for z in [low.z,high.z] for x,y in [(low.x,low.y),(high.x,low.y),(high.x,high.y),(low.x,high.y)]]
 return create(name,points,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],identity,key)

def annulus(name,center,z,height,outer,inner,identity,key='galvanized_roof'):
 N=plan['wall_segments'];points=[Vector((center.x+r*math.cos((i+.37)*math.tau/N),center.y+r*math.sin((i+.37)*math.tau/N),at)) for at in [z,z+height] for r in [outer,inner] for i in range(N)];faces=[]
 for i in range(N):
  j=(i+1)%N;faces.extend([(i,j,2*N+j,2*N+i),(N+j,N+i,3*N+i,3*N+j),(2*N+i,2*N+j,3*N+j,3*N+i),(j,i,N+i,N+j)])
 return create(name,points,faces,identity,key)

for identity in groups:
 rows={r['id'].rsplit('_',1)[-1]:r for r in records if group(r['id'])==identity};shift=derived.get(identity,0)
 placement=fit_tank(identity);placements[identity]=placement;dx,dy=placement['fitted_translation_xy_m']
 def point(p):return Vector((p[0]+shift+dx,p[1]+dy,p[2]))
 for row in rows.values():source_records.append({**row,'registration_offset_x':shift})
 assembly=identity+'__Tank';assemblies[assembly]={'group':identity,'kind':'stave_tank'}
 tank=rows['wtank'];bottom=point(tank['p0']);top=point(tank['p1']);R=tank['r'];feet=[];tops=[]
 for role in ['wleg-1-1','wleg-11','wleg1-1','wleg11']:
  row=rows[role];start,end=supported_post(row,identity,assembly,point);length=(end-start).length
  contacts[-1]['nominal_endpoint']=[row['p0'][0]+shift,row['p0'][1],row['p0'][2]]
  contacts[-1]['original_upper_attachment']=[row['p1'][0]+shift,row['p1'][1],row['p1'][2]]
  contacts[-1]['fitted_upper_attachment']=list(end)
  loft(row['id'],start,end+Vector((0,0,.04)),[(0,row['r']+.015),(.05,row['r']+.015),(.05,row['r']),(length+.04,row['r'])],assembly)
  feet.append(start);tops.append(end);span_check(identity,row['id'],end,start+Vector((0,0,.001)))
 for j in [0,2]:
  x0=min(tops[j].x,tops[j+1].x)-.075;x1=max(tops[j].x,tops[j+1].x)+.075
  y0=min(tops[j].y,tops[j+1].y)-.075;y1=max(tops[j].y,tops[j+1].y)+.075
  box(identity+'_Bearer'+str(j),Vector((x0,y0,bottom.z-.06)),Vector((x1,y1,bottom.z+.04)),assembly)
 for j,k in [(0,1),(2,3),(0,2),(1,3)]:
  b=tops[k]-Vector((0,0,.08));clear=[];first_rise=min(.2,(tops[j].z-feet[j].z)*.3)
  for step in range(200):
   a=feet[j]+Vector((0,0,first_rise+step*.025))
   if a.z>tops[j].z-.045:break
   direction=(b-a).normalized();seed=Vector((0,0,1));u=(seed-direction*seed.dot(direction)).normalized();v=direction.cross(u)
   offsets=[Vector((0,0,0))]+[.026*(u*math.cos(i*math.tau/8)+v*math.sin(i*math.tau/8)) for i in range(8)]
   if all(trees[identity][0].ray_cast(a+off,direction,(b-a).length)[0] is None for off in offsets):clear.append(a);break
  assert clear,('No clear brace between retained tank legs',identity,j,k)
  a=clear[0];length=(b-a).length
  loft(identity+'_Diagonal'+str(j)+str(k),a,b,[(0,.025),(length,.025)],assembly);span_check(identity,identity+'_Diagonal'+str(j)+str(k),b,a)
 N=plan['staves'];steps=plan['stave_samples'];count=N*steps;points=[]
 for z,inner in [(bottom.z,False),(top.z,False),(top.z,True),(bottom.z+plan['bottom_thickness'],True)]:
  for i in range(count):
   angle=i*math.tau/count;radius=R-plan['wall_thickness'] if inner else R-(plan['joint_groove_depth'] if i%steps==0 else 0)
   points.append(Vector((bottom.x+radius*math.cos(angle),bottom.y+radius*math.sin(angle),z)))
 points.extend([bottom,bottom+Vector((0,0,plan['bottom_thickness']))])
 faces=[]
 for i in range(count):
  j=(i+1)%count
  for ring in range(3):faces.append((ring*count+i,ring*count+j,(ring+1)*count+j,(ring+1)*count+i))
  faces.extend([(4*count,j,i),(4*count+1,3*count+i,3*count+j)])
 create(tank['id']+'_ClosedStaveBarrel',points,faces,assembly,'tank_staves')
 band=rows['wband'];annulus(band['id'],bottom,band['p0'][2],band['p1'][2]-band['p0'][2],band['r'],R-.003,assembly)
 for name,z in [('LowerHoop',bottom.z+.10),('UpperHoop',top.z-.13)]:annulus(identity+'_'+name,bottom,z,.06,R+.015,R-.003,assembly)
 cone=rows['wcone'];tip=cone['p1'][2];eave=top.z+.01;outer=R+plan['cap_overhang'];N=plan['wall_segments'];sheet=plan['cap_sheet_thickness']
 skirt_top=eave+(tip-eave)*(1-(R+.01)/outer)+.0005
 annulus(identity+'_WeatherCapSkirt',bottom,top.z-.045,skirt_top-(top.z-.045),R+.01,R-.003,assembly)
 points=[Vector((bottom.x+radius*math.cos(i*math.tau/N),bottom.y+radius*math.sin(i*math.tau/N),z)) for radius,z in [(outer,eave),(.03,tip),(.03,tip-sheet),(outer,eave-sheet)] for i in range(N)];faces=[]
 for ring in range(4):
  for i in range(N):
   j=(i+1)%N;faces.append((ring*N+i,ring*N+j,((ring+1)%4)*N+j,((ring+1)%4)*N+i))
 create(cone['id']+'_ClosedWeatherCap',points,faces,assembly)
 a=Vector((bottom.x,bottom.y,tip-sheet-.001));b=Vector((bottom.x,bottom.y,tip+.015));loft(identity+'_CapCrown',a,b,[(0,.031),((b-a).length,.031)],assembly)
 tank_inventory.append({'id':tank['id'],'assembly':assembly,'center':list((bottom+top)/2),'bottom':list(bottom),'top':list(top),'radius':R,'wall_thickness':plan['wall_thickness'],'original_cap_radius':cone['r'],'fitted_cap_radius':outer,'original_apex_height':tip,'skirt_top':skirt_top})
assert len(assemblies)==14 and len(tank_inventory)==14
for contact in contacts:
 tree,owners=trees[contact['group']];normal=Vector(contact['normal'])
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
draws=[];total_triangles=0;precision_chart_fallbacks=0
for identity in sorted(assemblies):
 # Union this static tank once, preserving closed source stocks.
 original=pieces[identity];objects=[]
 for obj in original:
  copy=obj.copy();copy.data=obj.data.copy();bpy.context.scene.collection.objects.link(copy);copy.hide_render=False;copy.hide_set(False);objects.append(copy)
 result=objects[0]
 for other in objects[1:]:
  bpy.context.view_layer.objects.active=result
  mod=result.modifiers.new('Fabricated joint','BOOLEAN');mod.operation='UNION';mod.solver='EXACT';mod.object=other
  bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(other,do_unlink=True)
 bm=bmesh.new();bm.from_mesh(result.data);closed_tank_boundary_check(bm,identity)
 assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,identity
 unseen=set(bm.verts);components=0
 while unseen:
  todo=[unseen.pop()];components+=1
  while todo:
   vertex=todo.pop()
   for edge in vertex.link_edges:
    other=edge.other_vert(vertex)
    if other in unseen:unseen.remove(other);todo.append(other)
 assert components in [1,2],(identity,components)
 # The exact solver handles the thin dish/receiver joints. Check the final
 # triangulated topology as well as its closed n-gon input.
 bmesh.ops.triangulate(bm,faces=list(bm.faces))
 closed_tank_boundary_check(bm,identity)
 assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,identity
 bm.to_mesh(result.data);bm.free()
 assembled=result.copy();assembled.data=result.data.copy();welded.objects.link(assembled);assembled.name=identity+'__ClosedFabricatedTree';assembled.hide_render=True
 # Retained city owns every exact plate backing plane. Export all other faces.
 pose=Matrix.LocRotScale(result.location,result.rotation_euler.to_quaternion(),result.scale)
 faces=[]
 for face in result.data.polygons:
  pts=[pose@result.data.vertices[i].co for i in face.vertices]
  if any(all(abs((p-Vector(c['point'])).dot(Vector(c['normal'])))<2e-7 for p in pts) for c in contacts if c['assembly']==identity):continue
  faces.append((pts,face.material_index))
 bpy.data.objects.remove(result,do_unlink=True)
 partitions=collections.defaultdict(list)
 for polygon,material_index in faces:
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
     partitions[(cell,material_index)].append(clipped)
 for (cell,material_index),polygons in sorted(partitions.items()):
  key=plan['runtime_keys'][material_index]
  name=identity+'__'+('_'.join(map(str,cell)))+'__'+key
  vertices=[];faces=[]
  for polygon in polygons:
   first=len(vertices);vertices.extend(polygon);faces.append(tuple(range(first,first+len(polygon))))
  origin=Vector(tuple(round(sum(p[i] for p in vertices)/len(vertices),3) for i in range(3)))
  mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(float(p[i])-float(origin[i]) for i in range(3)) for p in vertices],[],faces);mesh.update();mesh.materials.append(materials[key])
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
  chart=mesh.uv_layers.new(name='Metres');chart.active_render=True
  guides=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER')
  split_normals=[None]*len(mesh.loops)
  for face in mesh.polygons:
   # Common surface axes preserve texture phase across each stock. The
   # shared helper checks precision and charts microscopic joints locally.
   pts=np.asarray([mesh.vertices[i].co[:] for i in face.vertices],dtype=np.float64)
   n,u,values,local_chart=chart_for_triangle(pts,origin[:],sets[key]['meters_per_tile'],long_grain=(key=='tank_staves'))
   precision_chart_fallbacks+=local_chart
   for j,loop in enumerate(face.loop_indices):
    chart.data[loop].uv=tuple(values[j])
    guides.data[loop].vector=(float(u[0]),float(u[2]),float(-u[1]));split_normals[loop]=tuple(n)
  mesh.normals_split_custom_set(split_normals)
  obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;draws.append(obj)
  mesh.calc_loop_triangles();triangles=len(mesh.loop_triangles);total_triangles+=triangles
  inventory.append({'name':name,'group':assemblies[identity]['group'],'assembly':identity,'key':key,'triangles':triangles})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/city_tanks.blend'))
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
asset=ROOT/'game/assets/props/city_tanks.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True)
assert ExportUVHandedness.corrected==len(draws),(ExportUVHandedness.corrected,len(draws))
bindings=[plan_path,layout_path,registration_path,native_path,v2_path,Path(__file__),Path(__file__).with_name('fabrication_uvs.py'),ROOT/'game/data/runtime_material_sets.json',ROOT/'art/tools/build_tank_staves.py',ROOT/'art/textures/procedural/tank_staves/material.json',ROOT/'art/blender/city_masts.blend',ROOT/'art/blender/city_aerials.blend']
bindings.extend(ROOT/'art/textures/procedural/tank_staves'/name for name in ['albedo.png','roughness.png','height.png','normal.png'])
finish_bindings=[]
finish_bindings.extend([ROOT/'art/tools/build_galvanized_roof.py',ROOT/'art/textures/procedural/galvanized_roof/material.json'])
finish_bindings.extend(ROOT/'art/textures/procedural/galvanized_roof'/name for name in ['albedo.png','roughness.png','height.png','normal.png'])
bindings.extend(finish_bindings)
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':source_records,'original_record_count':len(records),'groups':groups,'closed_source_stocks':sum(len(v) for v in pieces.values()),'closed_fabricated_assemblies':len(assemblies),'assemblies':assemblies,'sealed_cavity_checks':boundary_checks,'fitted_placements':placements,'clear_spans':spans,'tanks':tank_inventory,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':precision_chart_fallbacks,'contacts':contacts,'current_native_derivation':{'bounds_checked':335,'max_bounds_error_m':max_bounds_error,'current_offsets':derived,'historical_blockout_binding_stale':digest(v2_path)!=registration['bindings']['game/data/orison_v2_blockout.json']},'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for path in ['art/blender/city_tanks_construction.json','game/tests/fixtures/orison_city_tanks.json']:(ROOT/path).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('CITY TANKS',len(records),'original components;',len(groups),'roofs;',report['closed_source_stocks'],'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'actual support contacts;',len(assemblies),'connected fabricated assemblies')
