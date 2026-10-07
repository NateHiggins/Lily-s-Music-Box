"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/news-chassis-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('NEWS_RECEIVING_OUT',str(r)));asset=source/'art/blender/news_receiving.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/news_receiving_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_news_receiving.json').read_text(encoding='utf-8'))
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

source_record=f['original_records'][0];floor=f['assemblies'][0]['floor'];floor_top=floor['z0']+floor['h']
assert source_record['asm']=='arcade_cab' and source_record['variant']==0 and abs(floor_top-.01)<1e-12
points=[o.matrix_world@v.co for o in draws for v in o.data.vertices]
theta=__import__('math').radians(source_record['yaw']);c,s=__import__('math').cos(theta),__import__('math').sin(theta)
def local(p):
 x=p.x-source_record['at'][0];y=p.y-source_record['at'][1];return Vector((c*x+s*y,-s*x+c*y,p.z))
local_points=[local(p) for p in points]
assert all(-.39003<=p.x<=.39003 and -.50003<=p.y<=.36003 and floor_top-.00003<=p.z<=1.83003 for p in local_points)
assert abs(max(p.z for p in local_points)-1.83)<.00003
assert len(f['contacts'])==4
bezel=bpy.data.objects[source_record['id']+'_CircularScopeBezel'];bezel_points=[local(bezel.matrix_world@v.co) for v in bezel.data.vertices]
radii=[(p.x*p.x+(p.z-1.29)**2)**.5 for p in bezel_points]
assert abs(min(radii)-.1908)<.00003 and abs(max(radii)-.222)<.00003
assert min(radii)>.19 and min(p.y for p in bezel_points)<-.386<max(p.y for p in bezel_points)

def actual_tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons],epsilon=0.)
before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(r/'game/assets/building/floor_01_cells/shop_news_cigars.gltf'))
context=[o for o in bpy.context.scene.objects if o not in before and o.type=='MESH']
source_draws={row['name']:row for row in f['runtime']['original_draws']};retired={};protected={}
for old in context:
 if old.name in source_draws:
  row=source_draws[old.name];old.data.calc_loop_triangles();assert len(old.data.loop_triangles)==row['expected_triangles']
  p=np.asarray([(old.matrix_world@v.co)[:] for v in old.data.vertices]);low=np.asarray(row['low'])[[0,2,1]]*np.array([1,-1,1]);high=np.asarray(row['high'])[[0,2,1]]*np.array([1,-1,1])
  expected_low=np.minimum(low,high);expected_high=np.maximum(low,high)
  assert np.max(np.abs(p.min(axis=0)-expected_low))<.00003 and np.max(np.abs(p.max(axis=0)-expected_high))<.00003,old.name
  retired[old.name]=len(old.data.loop_triangles);old.hide_render=True
 elif old.name==f['runtime']['raw_hull_name']:
  old.data.calc_loop_triangles();assert len(old.data.loop_triangles)==12;retired[old.name]=12;old.hide_render=True
 else:
  protected[old.name]=hashlib.sha256(np.asarray([v.co[:] for v in old.data.vertices],dtype='<f4').tobytes()).hexdigest()
assert len(retired)==9 and sum(retired.values())==412,retired
context=[o for o in context if o.name not in retired]
assert all(hashlib.sha256(np.asarray([v.co[:] for v in o.data.vertices],dtype='<f4').tobytes()).hexdigest()==protected[o.name] for o in context)

# Accepted native objects are loaded with their actual meshes. Retire only
# their individually proven original rect boundaries from the raw context.
accepted=[];retirement_rows=[]
for stem in ['shop_seating','news_fittings']:
 fixture=json.loads((r/f'game/tests/fixtures/orison_{stem}.json').read_text(encoding='utf-8'))
 runtime=json.loads((r/f'game/data/orison_v2/{stem}.json').read_text(encoding='utf-8'))
 ids={row['id'] for cell in runtime['cells'] if cell['id']=='shop_news_cigars' for row in cell['replace']}
 retirement_rows.extend(row for row in fixture['original_records'] if row['id'] in ids)
 with bpy.data.libraries.load(str(r/f'art/blender/{stem}.blend'),link=False) as (library,loaded):
  loaded.objects=[name for name in library.objects if '__' in name and (name.startswith('storm_shop_news_cigars_') or name.startswith('storm_shopseat_news_cigars'))]
 for obj in loaded.objects:
  bpy.context.scene.collection.objects.link(obj);bpy.context.view_layer.update();assert obj.type=='MESH' and not obj.hide_render;accepted.append(obj)
accepted_retired={row['id']:0 for row in retirement_rows}
for old in context:
 bm=bmesh.new();bm.from_mesh(old.data);remove=[]
 for face in bm.faces:
  p=[old.matrix_world@v.co for v in face.verts];normal=(p[1]-p[0]).cross(p[2]-p[0]).normalized();axis=max(range(3),key=lambda i:abs(normal[i]))
  for row in retirement_rows:
   if not old.name.removesuffix('-col').endswith('_'+row['mat']):continue
   q=row['rect'];low=Vector((q[0],q[1],row['z0']));high=Vector((q[2],q[3],row['z0']+row['h']));plane=high[axis] if normal[axis]>0 else low[axis]
   if abs(normal[axis])>.999 and all(abs(v[axis]-plane)<.00003 and all(low[i]-.00003<=v[i]<=high[i]+.00003 for i in range(3)) for v in p):remove.append(face);accepted_retired[row['id']]+=1;break
 bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(old.data);bm.free()
assert all(value==12 for value in accepted_retired.values()),accepted_retired
assert accepted
for obj in draws:
 for other in accepted:assert not actual_tree(obj).overlap(actual_tree(other)),('intersection with accepted native fitting',obj.name,other.name)
for obj in accepted:obj.hide_render=True

owner_support=[]
for contact in f['contacts']:
 at=Vector((contact['point'][0],-contact['point'][2],contact['point'][1]));direction=Vector((contact['direction'][0],-contact['direction'][2],contact['direction'][1]));hits=[]
 for obj in context:
  if not obj.name.removesuffix('-col').endswith('_'+floor['mat']):continue
  hit=actual_tree(obj).ray_cast(at+direction*.005,-direction,.010)
  if hit[0] is not None:hits.append((hit[0]-at).length)
 assert hits and min(hits)<.00003,contact
 owner_support.append({'owner':contact['owner'],'label':contact['label'],'distance_m':min(hits)})
allowed=[];intersections=[]
for obj in draws:
 tree=actual_tree(obj)
 for other in context:
  if not other.data.polygons:continue
  for left,right in tree.overlap(actual_tree(other)):
   native=[obj.matrix_world@obj.data.vertices[i].co for i in obj.data.polygons[left].vertices];p=[other.matrix_world@other.data.vertices[i].co for i in other.data.polygons[right].vertices]
   q=floor['rect'];separated=min(v.z for v in native)>=floor_top-.00003 and max(v.z for v in p)<=floor_top+.00003
   touching=min(v.z for v in native)<=floor_top+.00003 and max(v.z for v in p)>=floor_top-.00003
   if other.name.removesuffix('-col').endswith('_'+floor['mat']) and separated and touching and all(q[0]-.00003<=v.x<=q[2]+.00003 and q[1]-.00003<=v.y<=q[3]+.00003 for v in p):allowed.append({'native':obj.name,'context':other.name,'native_face':left,'context_face':right,'owner':floor['id']})
   else:intersections.append({'native':obj.name,'context':other.name,'native_face':left,'context_face':right})
if intersections:(out/'context_diagnostic.json').write_text(json.dumps({'evidence_class':'INERT','context_intersections':intersections},indent=1)+'\n',encoding='utf-8',newline='\n')
assert not intersections,intersections[:20]
for obj in context:obj.hide_render=True

views=[]
def global_point(p):return Vector((source_record['at'][0]+c*p[0]-s*p[1],source_record['at'][1]+s*p[0]+c*p[1],p[2]))
def render(label,eye,target,lens=50,full=False):
 bpy.ops.object.camera_add(location=global_point(eye));camera=bpy.context.object;target=global_point(target);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens;scene.camera=camera
 if full:
  corners=[o.matrix_world@Vector(corner) for o in draws for corner in o.bound_box];axis=(camera.location-target).normalized()
  for attempt in range(100):
   bpy.context.view_layer.update();projected=[world_to_camera_view(scene,camera,p) for p in corners]
   if all(.07<=p.x<=.93 and .07<=p.y<=.93 and p.z>0 for p in projected):break
   camera.location=target+(camera.location-target).length*1.06*axis
  else:raise AssertionError(('unframed native subject',label))
 scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True);views.append({'id':label,'eye':list(camera.location),'target':list(target),'file':label+'.png','scope':'isolated native receiving chassis; service-open view is an offline inspection pose only'});bpy.data.objects.remove(camera,do_unlink=True)
render('chassis_front',(-1.4,-2.5,1.65),(0,0,.92),45,True)
render('chassis_side',(2.4,-1.29,1.6),(0,0,.92),45,True)
render('chassis_rear',(-1.29,2.5,1.6),(0,0,.92),45,True)
render('scope_aperture',(.0,-1.4,1.32),(0,-.37,1.29))
render('floor_feet',(-.9,-1.0,.25),(0,0,.065),45)
render('braided_flex',(-.85,.55,.32),(-.345,.2,.16),50)
render('closed_service_hatch',(1.1,-.3,.72),(.32,0,.6),50)
# The fixture pose and runtime stay closed. Pose only exported stock for the
# isolated native inspection of the inside-lid schematic, valves and base cells.
pivot=global_point((.326,.249,.60));matrix=__import__('mathutils').Matrix.Translation(pivot)@__import__('mathutils').Matrix.Rotation(__import__('math').radians(65),4,'Z')@__import__('mathutils').Matrix.Translation(-pivot)
door_parts=[o for o in draws if o.name.endswith('__service_panel') or o.name.endswith('__service_latch') or o.name.endswith('__paper') or o.name.endswith('__schematic_traces')]
assert len(door_parts)==4
original_matrices={o:o.matrix_world.copy() for o in door_parts}
for o in door_parts:o.matrix_world=matrix@o.matrix_world
render('service_stock_open',(1.4,-.6,.76),(.25,0,.53),50)
render('base_wet_cells',(1.0,-.5,.32),(.04,0,.24),50)
render('inside_lid_schematic',(.39,-.21,.70),(.542,.124,.64),45)
for o,matrix in original_matrices.items():o.matrix_world=matrix
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_volumes':volumes,'assembly_stock_joins':joins,'actual_native_support_samples':support_samples,'actual_owner_support_samples':owner_support,'parts':len(draws),'triangles':f['triangles'],'removed_original_triangles':sum(retired.values()),'retired_original_owners':retired,'accepted_native_context_objects':len(accepted),'accepted_retirement_counts':accepted_retired,'protected_original_owners_before_neighbor_retirement':protected,'context_intersections':intersections,'declared_contact_pairs':allowed,'uv_metrics':uv_metrics,'views':views,'limits':'Exact original decorative assembly and 12-triangle hull retired only in inspected context. All other assembled source and two accepted native libraries remain conservative context. Actual floor contacts only. Service-opening images are isolated offline inspection poses; runtime panel stays closed. Imported ownership, unchanged programme/controls, access/reconstruction and human acceptance remain separate requirements.'},indent=1)+'\n',encoding='utf-8',newline='\n')
print('NEWS RECEIVING NATIVE QA',len(volumes),'closed connected stocks;',len(joins),'joined assembly;',len(owner_support),'retained floor contacts;',len(views),'views')
