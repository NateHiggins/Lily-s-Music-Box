"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/radio-display-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('RADIO_DISPLAY_OUT',str(r)));asset=source/'art/blender/radio_display.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/radio_display_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_radio_display.json').read_text(encoding='utf-8'))
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

# Fitted counter/display bounds derive from the immutable support datums.
stock_extents=[]
rows_by_id={row['id']:row for row in f['original_records']}
top=rows_by_id['storm_shop_radio_service_counter_top']; q=top['rect']; worktop=top['z0']+top['h']
rear=f['fitted_datums']['rear_wainscot']; fitted_rear=rear['rect'][3]+.002
assert abs(f['fitted_datums']['countertop_rear_y']-fitted_rear)<1e-12
points=[o.matrix_world@v.co for o in bpy.data.collections['ClosedConstruction'].objects for v in o.data.vertices]
assert all(q[0]-.00003<=p.x<=q[2]+.00003 and q[1]-.00003<=p.y<=q[3]+.00003 and .01-.00003<=p.z<=worktop+.60+.00003 for p in points)
assert abs(max(p.z for p in points)-(worktop+.60))<.00003
counter=bpy.data.objects['storm_shop_radio_service_counter_Countertop']
assert abs(max((counter.matrix_world@v.co).z for v in counter.data.vertices)-worktop)<.00003
assert abs(min((counter.matrix_world@v.co).y for v in counter.data.vertices)-fitted_rear)<.00003
book=bpy.data.objects['storm_shop_radio_service_counter_Ledger']
assert abs(max((book.matrix_world@v.co).z for v in book.data.vertices)-(rows_by_id['storm_shop_radio_service_ledger']['z0']+rows_by_id['storm_shop_radio_service_ledger']['h']))<.00003
stock_extents.append({'assembly':f['assemblies'][0]['id'],'countertop_datum':worktop,'native_display_maximum':max(p.z for p in points),'placement':'Declared source-derived countertop display; original retirement bounds remain immutable.'})
internal_bearings=[]
for name,x,y in [('HornPlinth',q[0]+.52,fitted_rear+.28),('ConePlinth',q[0]+.215,q[3]-.64),('LedgerPad',(rows_by_id['storm_shop_radio_service_ledger']['rect'][0]+rows_by_id['storm_shop_radio_service_ledger']['rect'][2])*.5,q[3]-.19)]:
 at=Vector((x,y,worktop)); plinth=ray_trees['storm_shop_radio_service_counter_'+name]
 support=ray_trees['storm_shop_radio_service_counter_Countertop']
 lower=plinth.ray_cast(at-Vector((0,0,.02)),Vector((0,0,1)),.04)
 upper=support.ray_cast(at+Vector((0,0,.02)),Vector((0,0,-1)),.04)
 assert lower[0] is not None and upper[0] is not None and (lower[0]-at).length<.00003 and (upper[0]-at).length<.00003,name
 internal_bearings.append({'stock':name,'datum':list(at),'native_lower_distance_m':(lower[0]-at).length,'countertop_upper_distance_m':(upper[0]-at).length})

# Shared counter stock is one assembly; its two independent displays and ledger
# must still remain geometrically disjoint from each other.
display_sets={
 'horn':[o for o in bpy.data.collections['ClosedConstruction'].objects if 'Horn' in o.name],
 'cone':[o for o in bpy.data.collections['ClosedConstruction'].objects if 'Cone' in o.name],
 'ledger':[o for o in bpy.data.collections['ClosedConstruction'].objects if 'Ledger' in o.name]}
independent_display_pairs=0
for left,right in [('horn','cone'),('horn','ledger'),('cone','ledger')]:
 for a in display_sets[left]:
  for b in display_sets[right]:
   assert not ray_trees[a.name].overlap(ray_trees[b.name]),('independent display intersection',a.name,b.name)
   independent_display_pairs+=1

uv_metrics=[]
for obj in draws:
 mesh=obj.data;mesh.calc_loop_triangles();points=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float64);indices=np.asarray([t.vertices[:] for t in mesh.loop_triangles]);p=points[indices];uv=np.asarray([[mesh.uv_layers.active.data[i].uv[:] for i in t.loops] for t in mesh.loop_triangles],dtype=np.float64)
 e=np.stack([p[:,1]-p[:,0],p[:,2]-p[:,0]],axis=2);d=np.stack([uv[:,1]-uv[:,0],uv[:,2]-uv[:,0]],axis=2);assert np.all(np.abs(np.linalg.det(d))>1e-12)
 metric=np.linalg.svd(e@np.linalg.inv(d),compute_uv=False);assert np.all((metric>.99)&(metric<1.01)),(obj.name,float(metric.min()),float(metric.max()))
 uv_metrics.append({'part':obj.name,'minimum_metres_per_uv':float(metric.min()),'maximum_metres_per_uv':float(metric.max()),'triangles':len(metric)})
def actual_tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons],epsilon=0.)
before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(r/'game/assets/building/floor_01_cells/shop_radio_service.gltf'));context=[o for o in bpy.context.scene.objects if o not in before and o.type=='MESH']
layout=__import__('json').loads((r/'art/data/building_layout.json').read_text(encoding='utf-8'));rows={row['id']:row for floor in layout['floors'] if floor['id']=='F01' for row in floor['furniture']}
counts={row['id']:0 for row in f['original_records']}
for old in context:
 bm=bmesh.new();bm.from_mesh(old.data);remove=[]
 for face in bm.faces:
  points=[old.matrix_world@v.co for v in face.verts];n=(points[1]-points[0]).cross(points[2]-points[0]).normalized();axis=max(range(3),key=lambda i:abs(n[i]));matches=[]
  for row in f['original_records']:
   if not old.name.removesuffix('-col').endswith('_'+row['mat']):continue
   q=row['rect'];low=Vector((q[0],q[1],row['z0']));high=Vector((q[2],q[3],row['z0']+row['h']));plane=high[axis] if n[axis]>0 else low[axis]
   if abs(n[axis])>.999 and all(abs(p[axis]-plane)<.00003 and all(low[i]-.00003<=p[i]<=high[i]+.00003 for i in range(3)) for p in points):matches.append(row['id'])
  if matches:assert len(matches)==1;remove.append(face);counts[matches[0]]+=1
 bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(old.data);bm.free()
assert len(counts)==6 and all(count==12 for count in counts.values()),counts
def actual_tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons],epsilon=0.)
# Compare with the actual accepted fittings, not their retired source boxes.
accepted=[];retirement_rows=[]
for stem in ['radio_bench','radio_apparatus','radio_stock','radio_battery','radio_wire']:
 fixture=json.loads((r/f'game/tests/fixtures/orison_{stem}.json').read_text(encoding='utf-8'));retirement_rows.extend(fixture['original_records'])
 with bpy.data.libraries.load(str(r/f'art/blender/{stem}.blend'),link=False) as (library,loaded):loaded.objects=[name for name in library.objects if '__' in name]
 for obj in loaded.objects:
  bpy.context.scene.collection.objects.link(obj);assert obj.type=='MESH' and not obj.hide_render;accepted.append(obj)
accepted_retired={row['id']:0 for row in retirement_rows}
for old in context:
 bm=bmesh.new();bm.from_mesh(old.data);remove=[]
 for face in bm.faces:
  points=[old.matrix_world@v.co for v in face.verts];normal=(points[1]-points[0]).cross(points[2]-points[0]).normalized();axis=max(range(3),key=lambda i:abs(normal[i]))
  for row in retirement_rows:
   if not old.name.removesuffix('-col').endswith('_'+row['mat']):continue
   q=row['rect'];low=Vector((q[0],q[1],row['z0']));high=Vector((q[2],q[3],row['z0']+row['h']));plane=high[axis] if normal[axis]>0 else low[axis]
   if abs(normal[axis])>.999 and all(abs(p[axis]-plane)<.00003 and all(low[i]-.00003<=p[i]<=high[i]+.00003 for i in range(3)) for p in points):remove.append(face);accepted_retired[row['id']]+=1;break
 bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(old.data);bm.free()
assert len(accepted_retired)==41 and all(value==12 for value in accepted_retired.values()),accepted_retired
for obj in draws:
 for other in accepted:assert not actual_tree(obj).overlap(actual_tree(other)),('intersection with accepted native fitting',obj.name,other.name)
for obj in accepted:obj.hide_render=True

owner_support=[]
for contact in f['contacts']:
 at=Vector((contact['point'][0],-contact['point'][2],contact['point'][1]));direction=Vector((contact['direction'][0],-contact['direction'][2],contact['direction'][1]));owner=rows[contact['owner']];chosen=[o for o in context if o.name.removesuffix('-col').endswith('_'+owner['mat'])];hits=[]
 for obj in chosen:
  hit=actual_tree(obj).ray_cast(at+direction*.005,-direction,.010)
  if hit[0] is not None:hits.append((hit[0]-at).length)
 assert hits and min(hits)<.00003,contact
 owner_support.append({'owner':contact['owner'],'label':contact['label'],'distance_m':min(hits)})
# Admit only surfaces separated by declared floor/instrument contact datums.
# Every other original source surface remains a conservative forbidden context.
allowed=[];intersections=[];owners={c['owner'] for c in f['contacts']}
for obj in draws:
 tree=actual_tree(obj)
 for other in context:
  if not other.data.polygons:continue
  for left,right in tree.overlap(actual_tree(other)):
   native=[obj.matrix_world@obj.data.vertices[i].co for i in obj.data.polygons[left].vertices];source_points=[other.matrix_world@other.data.vertices[i].co for i in other.data.polygons[right].vertices];matches=[]
   for identity in owners:
    owner=rows[identity];q=owner['rect'];plane=owner['z0']+owner['h'] if identity.endswith('_floor') else owner['z0']
    if identity.endswith('_floor'):
     separated=min(p.z for p in native)>=plane-.00003 and max(p.z for p in source_points)<=plane+.00003
     touching=min(p.z for p in native)<=plane+.00003 and max(p.z for p in source_points)>=plane-.00003
    else:
     separated=max(p.z for p in native)<=plane+.00003 and min(p.z for p in source_points)>=plane-.00003
     touching=max(p.z for p in native)>=plane-.00003 and min(p.z for p in source_points)<=plane+.00003
    if other.name.removesuffix('-col').endswith('_'+owner['mat']) and separated and touching and all(q[0]-.00003<=p.x<=q[2]+.00003 and q[1]-.00003<=p.y<=q[3]+.00003 for p in source_points):matches.append(identity)
   if matches:allowed.append({'native':obj.name,'context':other.name,'native_face':left,'context_face':right,'owners':matches})
   else:intersections.append({'native':obj.name,'context':other.name,'native_face':left,'context_face':right})
if intersections:
 (out/'context_diagnostic.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'context_intersections':intersections,'scope':'Actual native/source triangle intersections before any context waiver or fit correction.'},indent=2)+'\n',encoding='utf-8',newline='\n')
assert not intersections,intersections[:20]
for obj in context:obj.hide_render=True
views=[]
def render(label,eye,target,lens=50):
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens;scene.camera=camera
 if label in ['stock_front','stock_rear','stock_side','floor_feet']:
  subject=draws if label!='floor_feet' else [o for o in bpy.data.collections['ClosedConstruction'].objects if '_FloorPost' in o.name]
  corners=[o.matrix_world@Vector(corner) for o in subject for corner in o.bound_box];axis=(camera.location-Vector(target)).normalized()
  for attempt in range(100):
   bpy.context.view_layer.update();projected=[world_to_camera_view(scene,camera,p) for p in corners]
   if all(.07<=p.x<=.93 and .07<=p.y<=.93 and p.z>0 for p in projected):break
   camera.location=Vector(target)+(camera.location-Vector(target)).length*1.06*axis
  else:raise AssertionError(('unframed native subject',label))
 scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True);views.append({'id':label,'eye':list(camera.location),'target':list(target),'file':label+'.png','scope':'isolated native counter and passive horn/cone display'});bpy.data.objects.remove(camera,do_unlink=True)

render('stock_front',(15.8,-56.8,2.3),(18.05,-57.92,1.),45)
render('stock_rear',(20.2,-60.2,2.3),(18.05,-57.92,1.),45)
render('stock_side',(19.8,-55.8,2.0),(18.05,-57.92,1.),45)
render('floor_feet',(16.3,-56.3,.7),(18.05,-57.92,.08),45)
render('horn_lip',(17.1,-58.4,1.5),(17.90,-58.368,1.42))
render('finite_horn_throat',(18.8,-58.15,1.70),(18.10,-58.368,1.42))
render('textile_cone',(17.05,-57.75,1.55),(17.90,-57.80,1.43))
render('open_cone_profile',(18.6,-57.0,1.80),(18.02,-57.80,1.43))
render('seated_ledger',(17.4,-56.8,1.7),(18.1,-57.35,1.15))
render('display_bearings',(17.0,-57.0,1.9),(18.03,-58.0,1.12))

(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_volumes':volumes,'assembly_stock_joins':joins,'actual_native_support_samples':support_samples,'actual_owner_support_samples':owner_support,'actual_stock_extents':stock_extents,'actual_internal_bearings':internal_bearings,'independent_display_pairs':independent_display_pairs,'accepted_native_context_objects':len(accepted),'source_boundary_stocks':6,'removed_original_triangles':72,'parts':len(draws),'triangles':f['triangles'],'context_intersections':intersections,'declared_contact_pairs':allowed,'uv_metrics':uv_metrics,'views':views,'limits':'Original wall, door/handle, cabinet and actual accepted native fittings remain conservative context; only actual floor contact pairs admitted. The source-derived countertop supports passive finite horn/cone stock and a seated ledger. Door poses, imported rendering, ordinary access, signal operation, capacity and acceptance remain separate requirements.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('RADIO DISPLAY NATIVE QA',len(volumes),'closed connected stocks;',len(joins),'joined assembly;',len(owner_support),'retained owner contacts;',len(views),'views')
