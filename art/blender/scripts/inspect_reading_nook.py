"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/reading-nook-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('READING_NOOK_OUT',str(r)));asset=source/'art/blender/reading_nook.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/reading_nook_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_reading_nook.json').read_text(encoding='utf-8'))
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

scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1000;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral inspection');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.60,.65,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
for at,power,size in [((1,-1.5,2),70,1.5),((-1,.5,1),35,1.2)]:
 bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size
 light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
views=[];supports=[];failures=[]
assembly_trees={a['id']:[actual_tree(o) for o in draws if o.name.startswith(a['id']+'__')] for a in f['assemblies']}
layout=json.loads((r/'game/data/orison_v2_blockout.json').read_text());platform=next(p for p in layout['platforms'] if p['id']=='B1_PUBLIC_LANDING_W_SHAFT_1')
for c in f['contacts']:
 p=c['point'];at=Vector((p[0],-p[2],p[1]));d=c['direction'];direction=Vector((d[0],-d[2],d[1]));owner=c['owner']
 if owner=='floor':
  rect=platform['rect'];valid=rect[0]<=p[0]<=rect[2] and rect[1]<=p[2]<=rect[3] and abs(p[1])<.00003
 else:
  hits=[tree.ray_cast(at+direction*.004,-direction,.008) for tree in assembly_trees[owner]]
  valid=any(hit is not None and (hit-at).length<.00003 and normal.dot(direction)>.9 for hit,normal,_,_ in hits)
 if not valid:failures.append({'contact':c})
 supports.append({**c,'valid':valid})
assert not failures,failures
points=[o.matrix_world@v.co for o in draws for v in o.data.vertices]
assert min(p.z for p in points)>=-.00003,('stock below floor',min(p.z for p in points))
if os.environ.get('READING_NOOK_RENDER','1')!='0':

 # Compose the already accepted lamp in its exact fitted table-local pose.
 from mathutils import Matrix
 installations=json.loads((r/'game/data/orison_v2/task_lamp_installations.json').read_text())
 lamp=next(row for row in installations['lamps'] if row['id']=='B1_NOOK_LAMP')
 table=next(row for row in f['runtime']['assemblies'] if row['id']=='nook_table')
 def pose(row):
  p=row['position'];return Matrix.Translation(Vector((p[0],-p[2],p[1])))@Matrix.Rotation(row['yaw'],4,'Z')
 with bpy.data.libraries.load(str(r/'art/blender/task_lamps.blend'),link=False) as (src,dst):dst.objects=[name for name in src.objects if name.startswith('TaskLamp_emeralite__')]
 for obj in dst.objects:
  scene.collection.objects.link(obj);obj.matrix_world=pose(table)@pose(lamp)@obj.matrix_world
 bpy.context.view_layer.update()
 for name,eye,target in [('context_front',(-3.2,1.0,2.0),(-.48,-2.35,.55)),('context_rear',(2.,-4.8,2.25),(-.48,-2.35,.60)),('shelf',(-1.8,-1.4,1.45),(-.485,-3.3398,.65)),('table',(.8,-.4,.95),(-.5,-1.4898,.36))]:
  bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.data.lens=48;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
  scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True);views.append({'id':name,'file':name+'.png'});bpy.data.objects.remove(camera,do_unlink=True)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','closed_stocks':len(volumes),'joined_assemblies':joins,'uv':uv_metrics,'supports':supports,'views':views,'book_count':len(f['book_stock']),'scope':'Native nook geometry and reciprocal bearings; runtime clearance, lamp and wiring adoption remain unverified.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('READING NOOK NATIVE',len(volumes),'closed stocks;',len(supports),'supports;',len(f['book_stock']),'retained books;',len(views),'views')
