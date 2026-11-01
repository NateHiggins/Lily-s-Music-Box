"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,math,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/household-stoves-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('HOUSEHOLD_STOVES_OUT',str(r)));asset=source/'art/blender/household_stoves.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/household_stoves_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_household_stoves.json').read_text(encoding='utf-8'))
for rel,h in f['source_bindings'].items():
 data=(r/rel).read_bytes();data=data if Path(rel).suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n');assert hashlib.sha256(data).hexdigest()==h,rel
for image in bpy.data.images:
 if image.source=='FILE':assert image.filepath.startswith('//') and Path(bpy.path.abspath(image.filepath)).is_file(),image.filepath
volumes=[];trees={};signatures={};contact_cache={};contact_cache_hits=0
bpy.context.view_layer.update()
for o in bpy.data.collections['ClosedConstruction'].objects:
 o.data.calc_loop_triangles();bm=bmesh.new();bm.from_mesh(o.data);assert all(e.is_manifold and e.is_contiguous for e in bm.edges) and bm.calc_volume(signed=True)>0,o.name
 unseen=set(bm.verts);components=0
 while unseen:
  components+=1;stack=[unseen.pop()]
  while stack:
   v=stack.pop()
   for edge in v.link_edges:
    other=edge.other_vert(v)
    if other in unseen:unseen.remove(other);stack.append(other)
 assert components==1,o.name
 for tri in o.data.loop_triangles:assert tri.area>0,o.name
 volume=bm.calc_volume(signed=True);expected=next(x['volume_m3'] for x in f['closed_stocks'] if x['name']==o.name);assert abs(volume-expected)<1e-10
 volumes.append({'name':o.name,'volume_m3':volume});bm.free()
 trees[o.name]=BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons],epsilon=.00002)
 # Seven finish variants share immutable base geometry. Reuse only queries
 # whose complete world vertices and face topology are byte-identical.
 points=np.asarray([o.matrix_world@v.co for v in o.data.vertices],dtype='<f8')
 faces=[list(p.vertices) for p in o.data.polygons];signature=hashlib.sha256()
 for data in [np.asarray([len(points),len(faces)],dtype='<u4'),points,np.asarray([len(face) for face in faces],dtype='<u4'),np.asarray([i for face in faces for i in face],dtype='<u4')]:signature.update(data.tobytes())
 signatures[o.name]=signature.hexdigest()
joins=[];join_failures=[]
def inside_closed_stock(at,tree):
 # Signed-nearest candidates need parity confirmation; an annular void is empty.
 for direction in [Vector((1,.371,.217)).normalized(),Vector((.193,1,.427)).normalized(),Vector((.317,.239,1)).normalized()]:
  cursor=at.copy();crossings=0
  for _ in range(64):
   hit,_,_,_=tree.ray_cast(cursor,direction)
   if hit is None:break
   crossings+=1;cursor=hit+direction*.0000002
  else:return False
  if crossings%2!=1:return False
 return True

def measure_contact(left,right):
 a=bpy.data.objects[left];b=bpy.data.objects[right]
 pa=np.asarray([tuple(a.matrix_world@Vector(p)) for p in a.bound_box]);pb=np.asarray([tuple(b.matrix_world@Vector(p)) for p in b.bound_box])
 if np.any(pa.max(0)+.00003<pb.min(0)) or np.any(pb.max(0)+.00003<pa.min(0)):return False
 if trees[left].overlap(trees[right]):return True
 # Exactly coplanar annular faces need not cross. Confirm reciprocal contact
 # instead of forcing interpenetration merely to satisfy an overlap predicate.
 for obj,other_tree in [(a,trees[right]),(b,trees[left])]:
  linear=obj.matrix_world.to_3x3().inverted().transposed()
  probes=[(obj.matrix_world@face.center,(linear@face.normal).normalized()) for face in obj.data.polygons]
  probes.extend((sum((obj.matrix_world@obj.data.vertices[i].co for i in tri.vertices),Vector())/3,(linear@tri.normal).normalized()) for tri in obj.data.loop_triangles)
  for at,normal in probes:
   hit,other,_,distance=other_tree.find_nearest(at,.00003)
   if hit is not None and distance<.00003 and normal.dot(other)<-.9:return True
  # Physical occupied contact only; this does not establish a designed bearing.
  for vertex in obj.data.vertices:
   at=obj.matrix_world@vertex.co;hit,normal,_,distance=other_tree.find_nearest(at)
   if hit is not None and normal.dot(at-hit)<-.00003 and inside_closed_stock(at,other_tree):return True
 return False

def touches(left,right):
 global contact_cache_hits
 key=tuple(sorted((signatures[left],signatures[right])))
 if key in contact_cache:
  contact_cache_hits+=1;return contact_cache[key]
 result=measure_contact(left,right);contact_cache[key]=result;return result

# Independent occupancy controls include an annular hole, which a box-centre
# or unconfirmed signed-nearest shortcut must never classify as solid material.
control_points=[Vector(p) for p in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
control_faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
control_cube=BVHTree.FromPolygons(control_points,control_faces)
assert inside_closed_stock(Vector((.17,.23,.31)),control_cube)
assert not inside_closed_stock(Vector((1.001,0,0)),control_cube)
ring_points=[];ring_faces=[]
for z in [-.1,.1]:
 for radius in [1.,.5]:
  ring_points.extend(Vector((radius*math.cos(i*math.tau/32),radius*math.sin(i*math.tau/32),z)) for i in range(32))
for i in range(32):
 j=(i+1)%32
 ring_faces.extend([(i,j,64+j,64+i),(32+j,32+i,96+i,96+j),(j,i,32+i,32+j),(64+i,64+j,96+j,96+i)])
control_ring=BVHTree.FromPolygons(ring_points,ring_faces)
assert not inside_closed_stock(Vector((0,0,0)),control_ring),'annular void is empty'
assert inside_closed_stock(Vector((.73,.017,.023)),control_ring),'annular wall is occupied'
for a in f['construction_groups']:
 stocks=a['stocks'];adj={name:set() for name in stocks};edges=[]
 for i,left in enumerate(stocks):
  for right in stocks[i+1:]:
   if touches(left,right):adj[left].add(right);adj[right].add(left);edges.append([left,right])
 seen={stocks[0]};pending=list(seen)
 while pending:
  for neighbour in adj[pending.pop()]-seen:seen.add(neighbour);pending.append(neighbour)
 if len(seen)!=len(stocks):join_failures.append((a['id'],'disconnected',sorted(set(adj)-seen)))
 joins.append({'assembly':a['id'],'connected_components':1,'surface_contact_edges':edges})
assert not join_failures,join_failures

group_trees={}
for group in f['construction_groups']:
 points=[];faces=[]
 for name in group['stocks']:
  obj=bpy.data.objects[name];offset=len(points);points.extend(obj.matrix_world@v.co for v in obj.data.vertices);faces.extend([offset+i for i in p.vertices] for p in obj.data.polygons)
 group_trees[group['id']]=BVHTree.FromPolygons(points,faces)
separations=[]
for i,left in enumerate(f['construction_groups']):
 for right in f['construction_groups'][i+1:]:
  if left['assembly']!=right['assembly']:continue
  assert not group_trees[left['id']].overlap(group_trees[right['id']]),('distinct source objects cross',left['id'],right['id'])
  separations.append([left['id'],right['id']])
draws=[o for o in bpy.context.scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render];assert len(draws)==len(f['parts'])
def actual_tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons],epsilon=0.)
uv_metrics=[]
for obj in draws:
 mesh=obj.data;mesh.calc_loop_triangles();points=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float64);indices=np.asarray([t.vertices[:] for t in mesh.loop_triangles]);p=points[indices];uv=np.asarray([[mesh.uv_layers.active.data[i].uv[:] for i in t.loops] for t in mesh.loop_triangles],dtype=np.float64)
 e=np.stack([p[:,1]-p[:,0],p[:,2]-p[:,0]],axis=2);d=np.stack([uv[:,1]-uv[:,0],uv[:,2]-uv[:,0]],axis=2);assert np.all(np.abs(np.linalg.det(d))>1e-12)
 metric=np.linalg.svd(e@np.linalg.inv(d),compute_uv=False);assert np.all((metric>.99)&(metric<1.01)),(obj.name,float(metric.min()),float(metric.max()))
 # A twisted welt can be manifold while its smoothed normal crosses a face.
 # Catch that tangent-handedness failure here, before Godot imports anything.
 for triangle in mesh.loop_triangles:
  for loop in triangle.loops:assert triangle.normal.dot(mesh.corner_normals[loop].vector)>.05,(obj.name,'inverted smooth corner',loop)
 edge_length=np.linalg.norm(p-np.roll(p,-1,axis=1),axis=2);uv_length=np.linalg.norm(uv-np.roll(uv,-1,axis=1),axis=2)
 excess=float(np.max(uv_length-edge_length));widest=float(np.max(uv_length[edge_length>.00005]/edge_length[edge_length>.00005]))
 # Preflight the engine's absolute edge budget as well as the metric singular values.
 assert excess<.000049 and abs(widest-1)<.0048,(obj.name,'engine edge budget',excess,widest)
 uv_metrics.append({'part':obj.name,'minimum_metres_per_uv':float(metric.min()),'maximum_metres_per_uv':float(metric.max()),'maximum_edge_excess_m':excess,'maximum_edge_ratio':widest})

# Probe the prop's own underside. Actual external supports are inspected in
# a separate linked context stage before any export is imported into Godot.
supports=[];local_trees={a['id']:[actual_tree(o) for o in draws if o.name.startswith(a['id']+'__')] for a in f['assemblies']}
for c in f['contacts']:
 p=c['point'];at=Vector((p[0],-p[2],p[1]));d=c['direction'];direction=Vector((d[0],-d[2],d[1]));assert c['owner'] in ['support']
 hits=[t.ray_cast(at-direction*.004,direction,.008) for t in local_trees[c['assembly']]]
 assert any(hit is not None and (hit-at).length<.00004 and normal.dot(direction)<-.9 for hit,normal,_,_ in hits),(c,'missing prop underside')
 supports.append(c)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','closed_stocks':len(volumes),'contact_controls':4,'contact_tolerance_m':.00003,'reused_identical_contact_queries':contact_cache_hits,'unique_contact_queries':len(contact_cache),'connected_groups':joins,'distinct_object_separations':separations,'uv':uv_metrics,'local_bearings':supports,'views':[],'scope':'Local construction and chart preflight only. External support context and rendering are still required.'},indent=2)+'\n',newline='\n')
print('HOUSEHOLD STOVES LOCAL:',len(volumes),'closed stocks;',len(joins),'physical groups;',len(supports),'local bearings;',len(draws),'mapped parts')
