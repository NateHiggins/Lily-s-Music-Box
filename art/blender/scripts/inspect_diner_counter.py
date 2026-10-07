"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=Path(__import__('os').environ.get('DINER_COUNTER_REVIEW',str(r/'tmp/v2-finish-review/diner-counter-native')));out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('DINER_COUNTER_OUT',str(r)));asset=source/'art/blender/diner_counter.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/diner_counter_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_diner_counter.json').read_text(encoding='utf-8'))
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
draws=[o for o in bpy.context.scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render];assert len(draws)==len(f['parts'])
def actual_tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons],epsilon=0.)
layout=json.loads((r/'art/data/building_layout.json').read_text(encoding='utf-8'));rows={row['id']:row for floor in layout['floors'] if floor['id']=='F01' for row in floor['furniture']}
floor=rows['storm_shop_luncheonette_floor'];ground=floor['z0']+floor['h'];seat=rows['storm_shop_luncheonette_counter_top']['z0']+rows['storm_shop_luncheonette_counter_top']['h']
independent_pairs=0;ledger_contacts=[]
for left in f['closed_stocks']:
 for right in f['closed_stocks']:
  if not left['assembly'].endswith('_counter') or not right['assembly'].endswith('_ledger'):continue
  independent_pairs+=1;lo=bpy.data.objects[left['name']];ro=bpy.data.objects[right['name']];lt=actual_tree(lo);rt=actual_tree(ro)
  for li,ri in lt.overlap(rt):
   a=[lo.matrix_world@lo.data.vertices[i].co for i in lo.data.polygons[li].vertices];b=[ro.matrix_world@ro.data.vertices[i].co for i in ro.data.polygons[ri].vertices]
   assert max(p.z for p in a)<=seat+.00003 and min(p.z for p in b)>=seat-.00003,(left['name'],right['name'])
   assert max(p.z for p in a)>=seat-.00003 and min(p.z for p in b)<=seat+.00003
   ledger_contacts.append({'counter':left['name'],'ledger':right['name'],'plane_m':seat})
assert ledger_contacts
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=1100;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.55,.6,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
bpy.ops.object.light_add(type='SUN',location=(0,0,50));bpy.context.object.data.energy=2.3;bpy.context.object.rotation_euler=(.4,-.6,.3)
support_samples=[]
for contact in f['contacts']:
 at=Vector((contact['point'][0],-contact['point'][2],contact['point'][1]));direction=Vector((contact['direction'][0],-contact['direction'][2],contact['direction'][1]));hits=[]
 for row in f['closed_stocks']:
  if row['assembly']!=contact['assembly']:continue
  hit=actual_tree(bpy.data.objects[row['name']]).ray_cast(at-direction*.005,direction,.010)[0]
  if hit is not None:hits.append((hit-at).length)
 assert hits and min(hits)<.00003,contact
 support_samples.append({'label':contact['label'],'distance_m':min(hits)})
uv_metrics=[]
for obj in draws:
 mesh=obj.data;mesh.calc_loop_triangles();points=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float64);indices=np.asarray([t.vertices[:] for t in mesh.loop_triangles]);p=points[indices];uv=np.asarray([[mesh.uv_layers.active.data[i].uv[:] for i in t.loops] for t in mesh.loop_triangles],dtype=np.float64)
 e=np.stack([p[:,1]-p[:,0],p[:,2]-p[:,0]],axis=2);d=np.stack([uv[:,1]-uv[:,0],uv[:,2]-uv[:,0]],axis=2);assert np.all(np.abs(np.linalg.det(d))>1e-12)
 metric=np.linalg.svd(e@np.linalg.inv(d),compute_uv=False);assert np.all((metric>.99)&(metric<1.01)),(obj.name,float(metric.min()),float(metric.max()))
 uv_metrics.append({'part':obj.name,'minimum_metres_per_uv':float(metric.min()),'maximum_metres_per_uv':float(metric.max()),'triangles':len(metric)})
before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(r/'game/assets/building/floor_01_cells/shop_luncheonette.gltf'));context=[o for o in bpy.context.scene.objects if o not in before and o.type=='MESH']
accepted=[];retirement_rows=list(f['original_records']);receiving=json.loads((r/'game/data/orison_v2/diner_receiving.json').read_text(encoding='utf-8'));whole={row['name']:row['expected_triangles'] for row in receiving['original_draws']};whole[receiving['raw_hull_name']]=24;whole_retired={}
for old in context:
 if old.name not in whole:continue
 old.data.calc_loop_triangles();assert len(old.data.loop_triangles)==whole[old.name];whole_retired[old.name]=whole[old.name];old.hide_render=True
assert whole_retired==whole
context=[o for o in context if o.name not in whole]
for stem,prefix in [('shop_seating','storm_shop_luncheonette_stool'),('diner_receiving','storm_shopcab_luncheonette')]:
 fixture=json.loads((r/f'game/tests/fixtures/orison_{stem}.json').read_text(encoding='utf-8'))
 if stem=='shop_seating':
  runtime=json.loads((r/f'game/data/orison_v2/{stem}.json').read_text(encoding='utf-8'));ids={row['id'] for cell in runtime['cells'] if cell['id']=='shop_luncheonette' for row in cell['replace']};retirement_rows.extend(row for row in fixture['original_records'] if row['id'] in ids)
 with bpy.data.libraries.load(str(r/f'art/blender/{stem}.blend'),link=False) as (library,loaded):loaded.objects=[name for name in library.objects if '__' in name and name.startswith(prefix)]
 for obj in loaded.objects:bpy.context.scene.collection.objects.link(obj);assert obj.type=='MESH' and not obj.hide_render;accepted.append(obj)
counts={row['id']:0 for row in retirement_rows}
for old in context:
 bm=bmesh.new();bm.from_mesh(old.data);remove=[]
 for face in bm.faces:
  p=[old.matrix_world@v.co for v in face.verts];n=(p[1]-p[0]).cross(p[2]-p[0]).normalized();axis=max(range(3),key=lambda i:abs(n[i]));matches=[]
  for row in retirement_rows:
   if not old.name.removesuffix('-col').endswith('_'+row['mat']):continue
   q=row['rect'];low=Vector((q[0],q[1],row['z0']));high=Vector((q[2],q[3],row['z0']+row['h']));plane=high[axis] if n[axis]>0 else low[axis]
   if abs(n[axis])>.999 and all(abs(v[axis]-plane)<.00003 and all(low[i]-.00003<=v[i]<=high[i]+.00003 for i in range(3)) for v in p):matches.append(row['id'])
  if matches:assert len(matches)==1;remove.append(face);counts[matches[0]]+=1
 bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(old.data);bm.free()
assert len(counts)==20 and all(value==12 for value in counts.values()),counts
assert len(accepted)==38
for obj in draws:
 for other in accepted:assert not actual_tree(obj).overlap(actual_tree(other)),('intersection with accepted native fitting',obj.name,other.name)
owner_support=[]
for contact in f['contacts']:
 at=Vector((contact['point'][0],-contact['point'][2],contact['point'][1]));direction=Vector((contact['direction'][0],-contact['direction'][2],contact['direction'][1]));hits=[]
 chosen=[o for o in context if o.name.removesuffix('-col').endswith('_'+floor['mat'])] if contact['owner']==floor['id'] else [bpy.data.objects['storm_shop_luncheonette_counter_CountertopSheet']]
 for obj in chosen:
  hit=actual_tree(obj).ray_cast(at+direction*.005,-direction,.010)[0]
  if hit is not None:hits.append((hit-at).length)
 assert hits and min(hits)<.00003,contact
 owner_support.append({'owner':contact['owner'],'label':contact['label'],'distance_m':min(hits)})
allowed=[];intersections=[]
for obj in draws:
 tree=actual_tree(obj)
 for other in context:
  if not other.data.polygons:continue
  for li,ri in tree.overlap(actual_tree(other)):
   a=[obj.matrix_world@obj.data.vertices[i].co for i in obj.data.polygons[li].vertices];b=[other.matrix_world@other.data.vertices[i].co for i in other.data.polygons[ri].vertices];q=floor['rect']
   floor_contact=other.name.removesuffix('-col').endswith('_'+floor['mat']) and min(p.z for p in a)>=ground-.00003 and max(p.z for p in b)<=ground+.00003 and min(p.z for p in a)<=ground+.00003 and max(p.z for p in b)>=ground-.00003 and all(q[0]-.00003<=p.x<=q[2]+.00003 and q[1]-.00003<=p.y<=q[3]+.00003 for p in b)
   # Original register and cigar case keep their unchanged .01m separation.
   if floor_contact:allowed.append({'native':obj.name,'context':other.name,'owner':floor['id']})
   else:intersections.append({'native':obj.name,'context':other.name,'native_face':li,'context_face':ri})
if intersections:(out/'context_diagnostic.json').write_text(json.dumps({'evidence_class':'INERT','intersections':intersections},indent=1)+'\n',encoding='utf-8',newline='\n')
assert not intersections,intersections[:20]
for obj in context+accepted:obj.hide_render=True
views=[]
def render(label,eye,target,lens=45,full=False):
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;target=Vector(target);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens;scene.camera=camera
 if full:
  corners=[o.matrix_world@Vector(corner) for o in draws if not o.hide_render for corner in o.bound_box];axis=(camera.location-target).normalized()
  for attempt in range(100):
   bpy.context.view_layer.update();p=[world_to_camera_view(scene,camera,v) for v in corners]
   if all(.07<=v.x<=.93 and .07<=v.y<=.93 and v.z>0 for v in p):break
   camera.location=target+(camera.location-target).length*1.06*axis
  else:raise AssertionError(('unframed native subject',label))
 scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True);views.append({'id':label,'eye':list(camera.location),'target':list(target),'file':label+'.png','scope':'isolated passive Diner serving counter and ledger'});bpy.data.objects.remove(camera,do_unlink=True)
render('customer_front',(16.5,-39.5,2.1),(19.25,-42.4,.64),45,True)
render('service_rear',(22.,-44.8,2.2),(19.25,-42.4,.64),45,True)
render('front_end',(19.3,-37.7,1.3),(19.25,-42.4,.64),45,True)
render('back_end',(19.3,-47.2,1.4),(19.25,-42.4,.64),45,True)
render('folded_kick',(17.8,-42.1,.28),(18.88,-42.4,.09),50)
render('framed_floor_feet',(20.9,-41.7,.28),(19.5,-42.4,.13),45)
render('serving_edge',(20.5,-40.4,1.30),(19.5,-41.8,1.11),50)
render('ledger_seat',(19.7,-41.2,1.40),(19.32,-41.8,1.145),50)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_volumes':volumes,'assembly_stock_joins':joins,'actual_native_support_samples':support_samples,'actual_owner_support_samples':owner_support,'parts':len(draws),'triangles':f['triangles'],'removed_original_triangles':48,'retired_context_boundaries':counts,'retired_receiving_owners':whole_retired,'accepted_native_context_objects':len(accepted),'context_intersections':intersections,'declared_floor_contact_pairs':allowed,'ledger_contact_pairs':ledger_contacts,'uv_metrics':uv_metrics,'independent_stock_pairs_checked':independent_pairs,'views':views,'limits':'Exact original four counter/kick/top/ledger boundaries retire only in temporary inspection context. All sixteen original stool boundaries retire against accepted native stools; nine original receiving owners retire against the accepted two native chassis. All other original context remains. Passive supports establish physical bearing only, not service operation/capacity, routes or human acceptance.'},indent=1)+'\n',encoding='utf-8',newline='\n')
print('DINER COUNTER NATIVE QA',len(volumes),'closed connected stocks;',len(joins),'joined assemblies;',len(owner_support),'actual contacts;',len(views),'views')
