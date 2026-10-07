"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=Path(__import__('os').environ.get('RADIO_WIRE_REVIEW',str(r/'tmp/v2-finish-review/radio-wire-native')));out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('RADIO_WIRE_OUT',str(r)));asset=source/'art/blender/radio_wire.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/radio_wire_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_radio_wire.json').read_text(encoding='utf-8'))
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

# Original stations/maxima and finite spindle/ring stock stay source-owned.
stock_extents=[]
for assembly in f['assemblies']:
 row=next(x for x in f['original_records'] if x['id']==assembly['id']);q=row['rect'];objects=[bpy.data.objects[x['name']] for x in f['closed_stocks'] if x['assembly']==assembly['id']]
 points=[o.matrix_world@v.co for o in objects for v in o.data.vertices];maximum=max(p.z for p in points)
 assert all(q[0]-.00003<=p.x<=q[2]+.00003 and q[1]-.00003<=p.y<=q[3]+.00003 and assembly['floor']['z0']+assembly['floor']['h']-.00003<=p.z<=row['z0']+row['h']+.00003 for p in points)
 assert abs(maximum-(row['z0']+row['h']))<.00003
 stock_extents.append({'assembly':assembly['id'],'source_maximum':row['z0']+row['h'],'native_maximum':maximum,'floor_extension':'declared feet bridge original 70mm gap'})

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
assert len(counts)==2 and all(count==12 for count in counts.values()),counts
def actual_tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons],epsilon=0.)
# Compare with the actual accepted fittings, not their retired source boxes.
accepted=[];retirement_rows=[]
for stem in ['radio_bench','radio_apparatus','radio_stock','radio_battery']:
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
assert len(accepted_retired)==39 and all(value==12 for value in accepted_retired.values()),accepted_retired
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
assert not intersections,intersections[:20]
for obj in context:obj.hide_render=True
views=[]
def render(label,eye,target,lens=50):
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens;scene.camera=camera
 if label in ['stock_front','stock_rear','stock_side','floor_feet']:
  subject=draws if label!='floor_feet' else [o for o in bpy.data.collections['ClosedConstruction'].objects if '_FloorFoot' in o.name]
  corners=[o.matrix_world@Vector(corner) for o in subject for corner in o.bound_box];axis=(camera.location-Vector(target)).normalized()
  for attempt in range(100):
   bpy.context.view_layer.update();projected=[world_to_camera_view(scene,camera,p) for p in corners]
   if all(.07<=p.x<=.93 and .07<=p.y<=.93 and p.z>0 for p in projected):break
   camera.location=Vector(target)+(camera.location-Vector(target)).length*1.06*axis
  else:raise AssertionError(('unframed native subject',label))
 scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True);views.append({'id':label,'eye':list(camera.location),'target':list(target),'file':label+'.png','scope':'isolated native passive wire and iron-ring stock'});bpy.data.objects.remove(camera,do_unlink=True)

render('stock_front',(18.9,-55.4,1.4),(20.52,-57.2,.3),45)
render('stock_rear',(22.5,-59.3,1.35),(20.52,-57.2,.3),45)
render('stock_side',(23.2,-56.3,1.2),(20.52,-57.2,.3),45)
render('floor_feet',(19.3,-55.9,.5),(20.52,-57.2,.04),45)
render('two_closed_reels',(19.9,-56.4,.85),(20.77,-57.2,.38))
render('copper_winding',(20.35,-56.75,.65),(20.77,-57.06,.38))
render('fixed_spindle_bearing',(20.2,-56.7,.56),(20.77,-56.93,.38))
render('finite_iron_ring',(19.6,-56.4,.9),(20.27,-57.2,.24))
render('open_ring_centre',(20.27,-57.2,1.25),(20.27,-57.2,.18))
render('native_floor_bearings',(20.0,-56.5,.16),(20.52,-57.2,.05),45)

(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_volumes':volumes,'assembly_stock_joins':joins,'actual_native_support_samples':support_samples,'actual_owner_support_samples':owner_support,'actual_stock_extents':stock_extents,'accepted_native_context_objects':len(accepted),'source_boundary_stocks':2,'removed_original_triangles':24,'parts':len(draws),'triangles':f['triangles'],'context_intersections':intersections,'declared_contact_pairs':allowed,'uv_metrics':uv_metrics,'views':views,'limits':'Original source wall, door/handle, cabinet and other stock remain conservative context; only actual floor contact pairs admitted. Finite reel, spindle and iron-ring stock establish passive geometry only; no live wire route, heater, fuel, temperature, electrical operation, capacity or acceptance.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('RADIO WIRE NATIVE QA',len(volumes),'closed connected stocks;',len(joins),'joined assembly;',len(owner_support),'retained owner contacts;',len(views),'views')
