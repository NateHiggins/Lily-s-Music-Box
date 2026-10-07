"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/signal-terminal-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('SIGNAL_TERMINAL_OUT',str(r)));asset=source/'art/blender/signal_terminal.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/signal_terminal_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_signal_terminal.json').read_text(encoding='utf-8'))
for rel,h in f['source_bindings'].items():
 data=(r/rel).read_bytes();data=data if Path(rel).suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n');assert hashlib.sha256(data).hexdigest()==h,rel
for image in bpy.data.images:
 if image.source=='FILE':assert image.filepath.startswith('//') and Path(bpy.path.abspath(image.filepath)).is_file(),image.filepath
volumes=[];trees={}
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
joins=[];join_failures=[]
def touches(left,right):
 a=bpy.data.objects[left];b=bpy.data.objects[right]
 pa=np.asarray([tuple(a.matrix_world@Vector(p)) for p in a.bound_box]);pb=np.asarray([tuple(b.matrix_world@Vector(p)) for p in b.bound_box])
 if np.any(pa.max(0)+.00003<pb.min(0)) or np.any(pb.max(0)+.00003<pa.min(0)):return False
 if trees[left].overlap(trees[right]):return True
 # Exactly coplanar annular faces need not cross. Confirm reciprocal contact
 # instead of forcing interpenetration merely to satisfy an overlap predicate.
 for face in a.data.polygons:
  at=a.matrix_world@face.center;normal=a.matrix_world.to_3x3()@face.normal
  hit,other,_,distance=trees[right].find_nearest(at,.00003)
  if hit is not None and distance<.00003 and normal.dot(other)<-.9:return True
 return False
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
 uv_metrics.append({'part':obj.name,'minimum_metres_per_uv':float(metric.min()),'maximum_metres_per_uv':float(metric.max())})

# Probe the prop's own underside. Actual external supports are inspected in
# a separate linked context stage before any export is imported into Godot.
supports=[];local_trees={a['id']:[actual_tree(o) for o in draws if o.name.startswith(a['id']+'__')] for a in f['assemblies']}
for c in f['contacts']:
 p=c['point'];at=Vector((p[0],-p[2],p[1]));assert c['owner']=='support'
 hits=[t.ray_cast(at-Vector((0,0,.004)),Vector((0,0,1)),.008) for t in local_trees[c['assembly']]]
 assert any(hit is not None and (hit-at).length<.00004 and normal.z<-.9 for hit,normal,_,_ in hits),(c,'missing prop underside')
 supports.append(c)
points=[o.matrix_world@v.co for o in draws for v in o.data.vertices];assert min(p.z for p in points)>=-.00003,('stock below local support plane',min(p.z for p in points))
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','closed_stocks':len(volumes),'connected_groups':joins,'distinct_object_separations':separations,'uv':uv_metrics,'local_bearings':supports,'views':[],'scope':'Local construction and chart preflight only. External support context and rendering are still required.'},indent=2)+'\n',newline='\n')
print('SURFACE STOCK LOCAL:',len(volumes),'closed stocks;',len(joins),'physical groups;',len(supports),'local bearings;',len(draws),'mapped parts')
