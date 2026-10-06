"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/radio-apparatus-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('RADIO_APPARATUS_OUT',str(r)));asset=source/'art/blender/radio_apparatus.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/radio_apparatus_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_radio_apparatus.json').read_text(encoding='utf-8'))
for rel,h in f['source_bindings'].items():
 data=(r/rel).read_bytes();data=data if Path(rel).suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n');assert hashlib.sha256(data).hexdigest()==h,rel
for image in bpy.data.images:
 if image.source=='FILE':assert image.filepath.startswith('//') and Path(bpy.path.abspath(image.filepath)).is_file(),image.filepath
volumes=[];trees={}
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
joins=[]
for a in f['assemblies']:
 stocks=[row['name'] for row in f['closed_stocks'] if row['assembly']==a['id']];adj={name:set() for name in stocks};edges=[]
 for i,left in enumerate(stocks):
  for right in stocks[i+1:]:
   if trees[left].overlap(trees[right]):adj[left].add(right);adj[right].add(left);edges.append([left,right])
 seen={stocks[0]};pending=list(seen)
 while pending:
  for neighbour in adj[pending.pop()]-seen:seen.add(neighbour);pending.append(neighbour)
 assert len(seen)==len(stocks),(a['id'],'disconnected',sorted(set(adj)-seen))
 joins.append({'assembly':a['id'],'connected_components':1,'surface_contact_edges':edges})
# Actual stock surfaces of separate fittings must not intersect. This catches
# the original backing/plinth overlap that an isolated vessel preview missed.
independent_pairs=0
for i,left in enumerate(f['closed_stocks']):
 for right in f['closed_stocks'][i+1:]:
  if left['assembly']==right['assembly']:continue
  assert not trees[left['name']].overlap(trees[right['name']]),('intersecting fittings',left['name'],right['name'])
  independent_pairs+=1
draws=[o for o in bpy.context.scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render];assert len(draws)==len(f['parts'])
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=1100;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.55,.6,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
bpy.ops.object.light_add(type='SUN',location=(0,0,50));bpy.context.object.data.energy=2.3;bpy.context.object.rotation_euler=(.4,-.6,.3)
support_samples=[]
# The contact graph intentionally admits the source's 20-micrometre joint
# tolerance. Ray samples query the exact stock surface: inflating that surface
# shifts a floor hit by the graph epsilon itself.
ray_trees={o.name:BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons],epsilon=0.) for o in bpy.data.collections['ClosedConstruction'].objects}
for contact in f['contacts']:
 at=Vector((contact['point'][0],-contact['point'][2],contact['point'][1]));direction=Vector((contact['direction'][0],-contact['direction'][2],contact['direction'][1]));hits=[]
 for row in f['closed_stocks']:
  if row['assembly']!=contact['assembly']:continue
  hit=ray_trees[row['name']].ray_cast(at-direction*.005,direction,.010)
  if hit[0] is not None:hits.append((hit[0]-at).length)
 assert hits and min(hits)<.00002,contact
 support_samples.append({'label':contact['label'],'assembly':contact['assembly'],'distance_m':min(hits)})

uv_metrics=[]
for obj in draws:
 mesh=obj.data;mesh.calc_loop_triangles();points=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float64);indices=np.asarray([t.vertices[:] for t in mesh.loop_triangles]);p=points[indices];uv=np.asarray([[mesh.uv_layers.active.data[i].uv[:] for i in t.loops] for t in mesh.loop_triangles],dtype=np.float64)
 e=np.stack([p[:,1]-p[:,0],p[:,2]-p[:,0]],axis=2);d=np.stack([uv[:,1]-uv[:,0],uv[:,2]-uv[:,0]],axis=2);assert np.all(np.abs(np.linalg.det(d))>1e-12)
 metric=np.linalg.svd(e@np.linalg.inv(d),compute_uv=False);assert np.all((metric>.99)&(metric<1.01)),(obj.name,float(metric.min()),float(metric.max()))
 uv_metrics.append({'part':obj.name,'minimum_metres_per_uv':float(metric.min()),'maximum_metres_per_uv':float(metric.max()),'triangles':len(metric)})
def actual_tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons],epsilon=0.)
before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(r/'game/assets/building/floor_01_cells/shop_radio_service.gltf'));context=[o for o in bpy.context.scene.objects if o not in before and o.type=='MESH']
layout=__import__('json').loads((r/'art/data/building_layout.json').read_text(encoding='utf-8'));rows={row['id']:row for floor in layout['floors'] if floor['id']=='F01' for row in floor['furniture']}
bench=__import__('json').loads((r/'art/blender/radio_bench_construction.json').read_text(encoding='utf-8'));retired=f['original_records']+bench['original_records'];counts={row['id']:0 for row in retired}
for old in context:
 bm=bmesh.new();bm.from_mesh(old.data);remove=[]
 for face in bm.faces:
  points=[old.matrix_world@v.co for v in face.verts];n=(points[1]-points[0]).cross(points[2]-points[0]).normalized();axis=max(range(3),key=lambda i:abs(n[i]));matches=[]
  for row in retired:
   if not old.name.removesuffix('-col').endswith('_'+row['mat']):continue
   q=row['rect'];low=Vector((q[0],q[1],row['z0']));high=Vector((q[2],q[3],row['z0']+row['h']));plane=high[axis] if n[axis]>0 else low[axis]
   if abs(n[axis])>.999 and all(abs(p[axis]-plane)<.00003 and all(low[i]-.00003<=p[i]<=high[i]+.00003 for i in range(3)) for p in points):matches.append(row['id'])
  if matches:assert len(matches)==1;remove.append(face);counts[matches[0]]+=1
 bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(old.data);bm.free()
assert len(counts)==10 and all(count==12 for count in counts.values()),counts
before_bench=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(r/'game/assets/props/radio_bench.glb'));native_context=[o for o in bpy.context.scene.objects if o not in before_bench and o.type=='MESH'];assert len(native_context)==2
context.extend(native_context)
def actual_tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons],epsilon=0.)
owner_support=[]
bench_part='storm_shop_radio_service_bench__bench_top'
chosen=[o for o in native_context if o.name==bench_part];assert len(chosen)==1
for contact in f['contacts']:
 assert contact['native_owner_asset']=='radio_bench' and contact['native_owner_part']==bench_part
 at=Vector((contact['point'][0],-contact['point'][2],contact['point'][1]));direction=Vector((contact['direction'][0],-contact['direction'][2],contact['direction'][1]));hits=[]
 for obj in chosen:
  hit=actual_tree(obj).ray_cast(at+direction*.005,-direction,.010)
  if hit[0] is not None:hits.append((hit[0]-at).length)
 assert hits and min(hits)<.00003,contact
 owner_support.append({'owner':contact['owner'],'native_part':bench_part,'label':contact['label'],'distance_m':min(hits)})
# The immutable accepted bench determines the side-leaf bearing surface.
# Only actual triangle pairs separated by its 1.01m datum may touch.
allowed=[];intersections=[]
face=rows['storm_shop_radio_service_scope_face'];q=face['rect'];face_low=Vector((q[0],q[1],face['z0']));face_high=Vector((q[2],q[3],face['z0']+face['h']))
for obj in draws:
 tree=actual_tree(obj)
 for other in context:
  if not other.data.polygons:continue
  for left,right in tree.overlap(actual_tree(other)):
   native=[obj.matrix_world@obj.data.vertices[i].co for i in obj.data.polygons[left].vertices];source_points=[other.matrix_world@other.data.vertices[i].co for i in other.data.polygons[right].vertices]
   separated=min(p.z for p in native)>=1.01-.00003 and max(p.z for p in source_points)<=1.01+.00003
   touching=min(p.z for p in native)<=1.01+.00003 and max(p.z for p in source_points)>=1.01-.00003
   display_contact=False
   if other.name.removesuffix('-col').endswith('_screen') and all(all(face_low[i]-.00003<=p[i]<=face_high[i]+.00003 for i in range(3)) for p in source_points):
    for axis in range(3):
     for edge,positive in [(face_low[axis],False),(face_high[axis],True)]:
      if positive:
       separated_face=min(p[axis] for p in native)>=edge-.00003 and max(p[axis] for p in source_points)<=edge+.00003
       touching_face=min(p[axis] for p in native)<=edge+.00003 and max(p[axis] for p in source_points)>=edge-.00003
      else:
       separated_face=max(p[axis] for p in native)<=edge+.00003 and min(p[axis] for p in source_points)>=edge-.00003
       touching_face=max(p[axis] for p in native)>=edge-.00003 and min(p[axis] for p in source_points)<=edge+.00003
      display_contact=display_contact or (separated_face and touching_face)
   if other in chosen and separated and touching:allowed.append({'native':obj.name,'context':other.name,'native_face':left,'context_face':right,'owner_part':bench_part})
   elif display_contact:allowed.append({'native':obj.name,'context':other.name,'native_face':left,'context_face':right,'owner_record':face['id']})
   else:intersections.append({'native':obj.name,'context':other.name,'native_face':left,'context_face':right})
assert not intersections,intersections[:20]

for obj in context:obj.hide_render=True
# Isolate a read-only preview of the actual retained display, while the full
# original source remains conservative context above. No other cabinet screen
# is part of this native visual review or new export.
display=next(o for o in context if o.name.endswith('_screen-col'));verts=[];faces=[]
for face in display.data.polygons:
 points=[display.matrix_world@display.data.vertices[i].co for i in face.vertices]
 if all(all(face_low[i]-.00003<=p[i]<=face_high[i]+.00003 for i in range(3)) for p in points):
  offset=len(verts);verts.extend(points);faces.append(tuple(offset+i for i in range(len(points))))
assert len(faces)==12,len(faces)
mesh=bpy.data.meshes.new('RetainedLiteralScopeFacePreview');mesh.from_pydata(verts,[],faces);mesh.update();mesh.materials.append(display.data.materials[0])
preview=bpy.data.objects.new('RetainedLiteralScopeFacePreview',mesh);scene.collection.objects.link(preview)

views=[]
def render(label,eye,target,lens=50):
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens;scene.camera=camera;scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True);views.append({'id':label,'eye':list(eye),'target':list(target),'file':label+'.png','scope':'isolated native instruments'});bpy.data.objects.remove(camera,do_unlink=True)
render('instruments_front',(21.4,-58.6,2.0),(20.0,-56.17,1.28),45)
render('instruments_rear',(18.3,-54.5,1.9),(20.0,-56.17,1.28),45)
render('open_set_front',(21.45,-57.5,1.65),(20.59,-56.13,1.30))
render('open_set_rear',(20.60,-54.3,1.70),(20.59,-56.13,1.30),45)
render('seated_opal_valves',(21.20,-56.8,1.95),(20.745,-56.13,1.47))
render('scope_face',(19.70,-57.55,1.50),(19.70,-56.24,1.25))
render('scope_vents',(18.85,-56.85,1.50),(19.70,-56.15,1.25))
render('signal_generator',(19.04,-57.55,1.46),(19.04,-56.14,1.22))
render('generator_case',(18.25,-55.35,1.60),(19.04,-56.14,1.22))
render('instrument_bottoms',(19.85,-59.8,.42),(19.85,-56.15,1.10),45)

(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_volumes':volumes,'assembly_stock_joins':joins,'actual_native_support_samples':support_samples,'actual_owner_support_samples':owner_support,'source_boundary_stocks':8,'removed_original_triangles':96,'retired_accepted_bench_source_boxes':2,'retained_native_context_parts':2,'retained_literal_scope_face':rows['storm_shop_radio_service_scope_face'],'parts':len(draws),'triangles':f['triangles'],'context_intersections':intersections,'declared_contact_pairs':allowed,'uv_metrics':uv_metrics,'views':views,'limits':'Original source wall, door/handle, accepted bench, literal scope face and other stock retained; only pairs separated by the actual bench bearing datum or exact display boundary admitted. Blank screens and fixed controls establish no alignment, signal, operation, continuous route, capacity or acceptance.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('RADIO APPARATUS NATIVE QA',len(volumes),'closed connected stocks;',len(joins),'joined assembly;',len(owner_support),'retained owner contacts;',len(views),'views')
