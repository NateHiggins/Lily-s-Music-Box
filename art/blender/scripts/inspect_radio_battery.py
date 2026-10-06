"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/radio-battery-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('RADIO_BATTERY_OUT',str(r)));asset=source/'art/blender/radio_battery.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/radio_battery_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_radio_battery.json').read_text(encoding='utf-8'))
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


# Actual hollow glass bottoms, native timber seats, inserted cap collars,
# retained terminal maxima and the four source-described display links.
battery_bearings=[];series_bearings=[];up=Vector((0,0,1));rack=f['assemblies'][0]['id']
layout=json.loads((r/'art/data/building_layout.json').read_text(encoding='utf-8'));original_rows={row['id']:row for floor in layout['floors'] if floor['id']=='F01' for row in floor['furniture']}
dx=original_rows['storm_shop_radio_service_counter_top']['rect'][2]+.15-original_rows[rack]['rect'][0]
assert len(f['fitted_records'])==len(f['original_records'])==11
for original,fitted in zip(f['original_records'],f['fitted_records']):
 assert original==original_rows[original['id']] and fitted['id']==original['id']
 expected=dict(original);expected['rect']=[original['rect'][0]+dx,original['rect'][1],original['rect'][2]+dx,original['rect'][3]];assert fitted==expected,original['id']
jar_rows=[next(x for x in f['fitted_records'] if x['id']=='storm_shop_radio_service_wet_cell'+str(i)) for i in range(5)]
for index,row in enumerate(jar_rows):
 q=row['rect'];cx=(q[0]+q[2])*.5;cy=(q[1]+q[3])*.5;base=row['z0'];crown=base+row['h'];cap='storm_shop_radio_service_cell_cap'+str(index)
 at=Vector((cx,cy,base));glass=ray_trees[row['id']+'_HollowGlass'];pad=ray_trees[row['id']+'_FittedBearingPad'];collar=ray_trees[cap+'_InsertedCollar'];plate=ray_trees[cap+'_CapPlate']
 glass_bottom=glass.ray_cast(at-up*.005,up,.015)[0];pad_top=pad.ray_cast(at+up*.005,-up,.015)[0]
 lip=glass.ray_cast(Vector((cx+.101,cy,crown+.01)),-up,.03)[0];collar_bottom=collar.ray_cast(Vector((cx+.095,cy,1.24)),up,.05)[0];cap_bottom=plate.ray_cast(Vector((cx,cy,1.24)),up,.05)[0]
 assert glass_bottom is not None and pad_top is not None and (glass_bottom-at).length<.00002 and (pad_top-at).length<.00002,row['id']
 assert lip is not None and abs(lip.z-crown)<.00002 and collar_bottom is not None and abs(collar_bottom.z-1.255)<.00002 and cap_bottom is not None and abs(cap_bottom.z-1.272)<.00002,row['id']
 assert ray_trees[row['id']+'_HollowGlass'].overlap(ray_trees[cap+'_InsertedCollar']),('unseated inserted cap',cap)
 terminal_tops=[]
 for terminal,xx in enumerate([cx-.05,cx+.05]):
  tree=ray_trees[cap+'_Terminal'+str(terminal)];hit=tree.ray_cast(Vector((xx,cy,1.35)),-up,.10)[0];assert hit is not None and abs(hit.z-1.33)<.00002,cap
  terminal_tops.append(list(hit))
 battery_bearings.append({'jar':row['id'],'glass_bottom':list(glass_bottom),'native_pad_top':list(pad_top),'original_jar_crown':list(lip),'inserted_collar_bottom':list(collar_bottom),'cap_plate_bottom':list(cap_bottom),'original_cap_maxima':terminal_tops})
for index in range(4):
 a=jar_rows[index]['rect'];b=jar_rows[index+1]['rect'];endpoints=[Vector(((a[0]+a[2])*.5+.05,(a[1]+a[3])*.5,1.324)),Vector(((b[0]+b[2])*.5-.05,(b[1]+b[3])*.5,1.324))]
 name=rack+'_PassiveSeriesLink'+str(index);wire=ray_trees[name];pairs=[]
 for endpoint,cell_index,terminal in zip(endpoints,[index,index+1],[1,0]):
  post=ray_trees['storm_shop_radio_service_cell_cap'+str(cell_index)+'_Terminal'+str(terminal)]
  top=post.ray_cast(endpoint+up*.03,-up,.10)[0];bottom=post.ray_cast(endpoint-up*.06,up,.10)[0];wire_hit=wire.ray_cast(endpoint-up*.01,up,.02)[0]
  assert top is not None and bottom is not None and wire_hit is not None and bottom.z<endpoint.z<top.z and abs(wire_hit.z-endpoint.z)<.003,name
  assert trees[name].overlap(trees['storm_shop_radio_service_cell_cap'+str(cell_index)+'_Terminal'+str(terminal)]),name
  pairs.append({'endpoint':list(endpoint),'terminal_top':list(top),'terminal_bottom':list(bottom),'wire_surface':list(wire_hit)})
 series_bearings.append({'link':name,'seated_endpoints':pairs})

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
assert len(counts)==11 and all(count==12 for count in counts.values()),counts
def actual_tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons],epsilon=0.)
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
 eye=(eye[0]+dx,eye[1],eye[2]);target=(target[0]+dx,target[1],target[2])
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens;scene.camera=camera
 if label in ['charging_front','charging_rear','charging_end','floor_feet']:
  subject=draws if label!='floor_feet' else [o for o in bpy.data.collections['ClosedConstruction'].objects if '_FloorFoot' in o.name]
  assert subject,label
  corners=[o.matrix_world@Vector(corner) for o in subject for corner in o.bound_box];axis=(camera.location-Vector(target)).normalized()
  for attempt in range(100):
   bpy.context.view_layer.update();projected=[world_to_camera_view(scene,camera,p) for p in corners]
   if all(.07<=p.x<=.93 and .07<=p.y<=.93 and p.z>0 for p in projected):break
   camera.location=Vector(target)+(camera.location-Vector(target)).length*1.06*axis
  else:raise AssertionError(('unframed native subject',label))
 scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True);views.append({'id':label,'eye':list(camera.location),'target':list(target),'file':label+'.png','scope':'isolated native passive charging display'});bpy.data.objects.remove(camera,do_unlink=True)


render('charging_front',(19.5,-59.5,2.2),(21.5,-57.20,.66),45)
render('charging_rear',(23.8,-55.0,2.1),(21.5,-57.20,.66),45)
render('charging_end',(20.1,-55.2,1.7),(21.5,-57.20,.66),45)
render('floor_feet',(19.8,-59.3,.60),(21.5,-57.20,.04),45)
render('five_jar_rank',(20.5,-58.5,1.65),(21.5,-57.20,1.1))
render('hollow_jar_and_fill',(20.9,-58.0,1.28),(21.5,-57.59,1.08))
render('inserted_cap_collar',(21.15,-57.9,1.22),(21.5,-57.59,1.26))
render('passive_series_links',(21.0,-58.0,1.60),(21.5,-57.2,1.325))
render('native_jar_seats',(21.0,-58.0,1.0),(21.5,-57.4,.92))
render('rack_legroom',(20.8,-58.4,.58),(21.5,-57.2,.46))

(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_volumes':volumes,'assembly_stock_joins':joins,'actual_native_support_samples':support_samples,'actual_owner_support_samples':owner_support,'actual_battery_bearings':battery_bearings,'actual_series_bearings':series_bearings,'source_boundary_stocks':11,'removed_original_triangles':132,'parts':len(draws),'triangles':f['triangles'],'context_intersections':intersections,'declared_contact_pairs':allowed,'uv_metrics':uv_metrics,'views':views,'limits':'Original source wall, door/handle, cabinet and other stock remain conservative context; only actual floor contact pairs admitted. Exact jar/pad/collar/link contacts establish geometry, not chemistry, electrical operation, charging capacity, utility supply, continuous route or acceptance.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('RADIO BATTERY NATIVE QA',len(volumes),'closed connected stocks;',len(joins),'joined assembly;',len(owner_support),'retained owner contacts;',len(views),'views')
