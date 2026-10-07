"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/task-lamps-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('TASK_LAMPS_OUT',str(r)));asset=source/'art/blender/task_lamps.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/task_lamps_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_task_lamps.json').read_text(encoding='utf-8'))
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
for a in f['assemblies']:
 stocks=[row['name'] for row in f['closed_stocks'] if row['assembly']==a['id']];adj={name:set() for name in stocks};edges=[]
 for i,left in enumerate(stocks):
  for right in stocks[i+1:]:
   if trees[left].overlap(trees[right]):adj[left].add(right);adj[right].add(left);edges.append([left,right])
 seen={stocks[0]};pending=list(seen)
 while pending:
  for neighbour in adj[pending.pop()]-seen:seen.add(neighbour);pending.append(neighbour)
 if len(seen)!=len(stocks):join_failures.append((a['id'],'disconnected',sorted(set(adj)-seen)))
 joins.append({'assembly':a['id'],'connected_components':1,'surface_contact_edges':edges})
assert not join_failures,join_failures
draws=[o for o in bpy.context.scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render];assert len(draws)==len(f['parts'])
def actual_tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons],epsilon=0.)
furniture=json.loads((r/'game/data/orison_v2/domestic_furniture.json').read_text(encoding='utf-8'))
bench=next(row for row in furniture['furniture'] if row['id']=='3B_workbench')
bench_points=[];bench_faces=[]
for surface in bench['surfaces']:
 raw=np.asarray(surface['vertices']).reshape((-1,3));normals=np.asarray(surface['normals']).reshape((-1,3))
 for i in range(0,len(raw),3):
  tri=raw[i:i+3];indices=[len(bench_points)+j for j in range(3)]
  if np.dot(np.cross(tri[1]-tri[0],tri[2]-tri[0]),normals[i])<0:indices.reverse()
  bench_faces.append(indices);bench_points.extend(Vector((v[0]-.6,-(v[2]-.18),v[1]-.91)) for v in tri)
bench_tree=BVHTree.FromPolygons(bench_points,bench_faces,epsilon=0.)
bench_support=[]
for contact in [c for c in f['contacts'] if c['assembly']=='TaskLamp_bench_friction']:
 p=contact['point'];at=Vector((p[0],-p[2],p[1]));hit,normal,_,_=bench_tree.ray_cast(at+Vector((0,0,.004)),Vector((0,0,-1)),.008)
 assert hit is not None and (hit-at).length<.00003 and normal.z>.9,('visible workbench support',at,hit,normal)
 assert abs(bench['bounds'][1][1]-.91)<1e-10,'collision ceiling differs from visible bearing'
 bench_support.append({'lamp':contact['assembly'],'support':'3B_workbench','local_point':list(at),'visible_hit':list(hit),'visible_normal':list(normal)})
uv_metrics=[]
for obj in draws:
 mesh=obj.data;mesh.calc_loop_triangles();points=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float64);indices=np.asarray([t.vertices[:] for t in mesh.loop_triangles]);p=points[indices];uv=np.asarray([[mesh.uv_layers.active.data[i].uv[:] for i in t.loops] for t in mesh.loop_triangles],dtype=np.float64)
 e=np.stack([p[:,1]-p[:,0],p[:,2]-p[:,0]],axis=2);d=np.stack([uv[:,1]-uv[:,0],uv[:,2]-uv[:,0]],axis=2);assert np.all(np.abs(np.linalg.det(d))>1e-12)
 metric=np.linalg.svd(e@np.linalg.inv(d),compute_uv=False);assert np.all((metric>.99)&(metric<1.01)),(obj.name,float(metric.min()),float(metric.max()))
 for triangle in mesh.loop_triangles:
  for loop in triangle.loops:assert triangle.normal.dot(mesh.corner_normals[loop].vector)>.05,(obj.name,'inverted smooth corner',loop)
 uv_metrics.append({'part':obj.name,'minimum_metres_per_uv':float(metric.min()),'maximum_metres_per_uv':float(metric.max())})

scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1000;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral inspection');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.60,.65,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
for at,power,size in [((1,-1.5,2),70,1.5),((-1,.5,1),35,1.2)]:
 bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size
 light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
views=[];supports=[]
for assembly in f['assemblies']:
 identity=assembly['id'];local=[o for o in draws if o.name.startswith(identity+'__')]
 points=[o.matrix_world@v.co for o in local for v in o.data.vertices]
 assert min(p.z for p in points)>=-.00003,(identity,'stock below support plane',min(p.z for p in points))
 owner=next(o for o in local if o.name.endswith('__wood_dark' if assembly['cell']=='architect_counterweight' else ('__brass' if assembly['cell'] in ['emeralite','office_green'] else ('__enamel' if assembly['cell']=='landlord_enamel' else '__iron_blackened'))))
 tree=actual_tree(owner)
 for c in [c for c in f['contacts'] if c['assembly']==identity]:
  p=c['point'];at=Vector((p[0],-p[2],p[1]));hit,normal,_,_=tree.ray_cast(at-Vector((0,0,.004)),Vector((0,0,1)),.008)
  assert hit is not None and abs(hit.z)<.00003 and normal.z<-.9,(identity,'base bearing',c,hit)
  supports.append(c)
 if os.environ.get('TASK_LAMPS_RENDER','1')=='0':continue
 for obj in draws:obj.hide_render=obj not in local
 target=Vector((0,0,(max(p.z for p in points)+min(p.z for p in points))*.5))
 for side,eye in [('front',(1.1,-1.7,.95)),('rear',(-1.2,1.6,.90))]:
  bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.data.lens=55;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
  axis=(camera.location-target).normalized();distance=(camera.location-target).length
  for attempt in range(80):
   camera.location=target+axis*distance;bpy.context.view_layer.update();projected=[world_to_camera_view(scene,camera,p) for p in points]
   if all(.07<p.x<.93 and .07<p.y<.93 and p.z>0 for p in projected):distance*=.96
   else:distance/=.96;camera.location=target+axis*distance;break
  name=assembly['cell']+'_'+side;scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
  views.append({'id':name,'eye':list(camera.location),'target':list(target),'file':name+'.png'});bpy.data.objects.remove(camera,do_unlink=True)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','closed_stocks':len(volumes),'joined_assemblies':joins,'uv':uv_metrics,'supports':supports,'visible_workbench_bearings':bench_support,'views':views,'scope':'Native five-variant geometry, base datums and existing visible workbench bearing. Does not prove external room wiring, behavior or final optics.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('TASK LAMPS NATIVE',len(volumes),'closed stocks;',len(joins),'joined variants;',len(supports),'base probes;',len(views),'views')
