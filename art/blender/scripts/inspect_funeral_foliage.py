"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/funeral-foliage-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('FUNERAL_FOLIAGE_OUT',str(r)));asset=source/'art/blender/funeral_foliage.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/funeral_foliage_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_funeral_foliage.json').read_text(encoding='utf-8'))
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
 at=Vector((contact['point'][0],-contact['point'][2],contact['point'][1]));hits=[]
 for row in f['closed_stocks']:
  if row['assembly']!=contact['assembly']:continue
  hit=ray_trees[row['name']].ray_cast(at-Vector((0,0,.005)),Vector((0,0,1)),.010)
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
before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(r/'game/assets/building/floor_01_cells/shop_funeral_parlour.gltf'));context=[o for o in bpy.context.scene.objects if o not in before and o.type=='MESH']
floor_owner=f['assemblies'][0]['floor'];floor_obj=next(o for o in context if o.name.removesuffix('-col')=='F01_OWN_SHOP_FUNERAL_PARLOUR_retail_shop_funeral_parlour_'+floor_owner['mat']);floor_tree=actual_tree(floor_obj)
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
assert len(counts)==8 and all(count==12 for count in counts.values()),counts
for contact in f['contacts']:
 at=Vector((contact['point'][0],-contact['point'][2],contact['point'][1]));hit=floor_tree.ray_cast(at+Vector((0,0,.004)),Vector((0,0,-1)),.008);assert hit[0] is not None and (hit[0]-at).length<.00003,contact
accepted=[]
for context_asset,fixture in [('shop_seating','orison_shop_seating'),('funeral_fittings','orison_funeral_fittings'),('funeral_drapes','orison_funeral_drapes')]:
 inventory=json.loads((r/'game/tests/fixtures'/f'{fixture}.json').read_text());names={p['name'] for p in inventory['parts'] if p['cell']=='shop_funeral_parlour'}
 before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(r/'game/assets/props'/f'{context_asset}.glb'));loaded=[o for o in bpy.context.scene.objects if o not in before];chosen=[o for o in loaded if o.type=='MESH' and o.name in names];assert {o.name for o in chosen}==names;accepted.extend(chosen)
 for obj in loaded:obj.hide_render=True
intersections=[]
for obj in [o for o in draws if o.name.endswith('__foliage')]:
 tree=actual_tree(obj)
 for other in context+accepted:
  if not other.data.polygons:continue
  pairs=tree.overlap(actual_tree(other))
  if pairs:intersections.append({'foliage':obj.name,'context':other.name,'triangle_pairs':len(pairs)})
assert not intersections,intersections
for obj in context:obj.hide_render=True
original={row['id']:row for row in f['original_records']};plan=json.loads((source/'art/data/funeral_foliage/source_plan.json').read_text());envelopes=[]
for assembly,group in zip(f['assemblies'],plan['groups']):
 row=original[group['sources'][1]];a,b,c,e=row['rect'];high=row['z0']+row['h'];chosen=[o for o in draws if o.name==assembly['id']+'__foliage'];assert len(chosen)==1
 verts=[chosen[0].matrix_world@v.co for v in chosen[0].data.vertices];assert all(a-.000003<=v.x<=c+.000003 and b-.000003<=v.y<=e+.000003 and v.z<=high+.000003 for v in verts),('foliage outside source envelope',assembly['id'])
 envelopes.append({'assembly':assembly['id'],'low':[min(v[i] for v in verts) for i in range(3)],'high':[max(v[i] for v in verts) for i in range(3)],'source_maximum':high})
views=[]
def render(label,eye,target,identity,lens=50):
 for obj in draws:obj.hide_render=not obj.name.startswith(identity+'__')
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens;camera.data.clip_start=.002;scene.camera=camera
 scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True);views.append({'id':label,'eye':list(eye),'target':list(target),'file':label+'.png','scope':'isolated native foliage fitting'});bpy.data.objects.remove(camera,do_unlink=True)
for i,assembly in enumerate(f['assemblies']):
 row=original[assembly['id']];cx=(row['rect'][0]+row['rect'][2])*.5;cy=(row['rect'][1]+row['rect'][3])*.5;identity=assembly['id']
 if assembly['kind']=='laid_wreath':
  render('wreath'+str(i)+'_front',(cx+2.3,cy-2.3,1.8),(cx,cy,.55),identity)
  render('wreath'+str(i)+'_leaf_ring',(cx+.6,cy-.6,1.7),(cx,cy,.97),identity)
  render('wreath'+str(i)+'_stand',(cx+.9,cy-.9,.45),(cx,cy,.40),identity)
 else:
  render('palm'+str(i)+'_front',(cx+3.4,cy-3.4,2.2),(cx,cy,.93),identity)
  render('palm'+str(i)+'_rear',(cx-3.4,cy+3.4,2.2),(cx,cy,.93),identity)
  render('palm'+str(i)+'_open_pot',(cx+.7,cy-.7,1.1),(cx,cy,.57),identity)
  render('palm'+str(i)+'_pinnae',(cx+.8,cy-.8,1.9),(cx,cy,1.45),identity)
assert len(views)==14
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_volumes':volumes,'assembly_stock_joins':joins,'independent_stock_surface_pairs':independent_pairs,'actual_floor_support_samples':support_samples,'source_boundary_stocks':len(f['original_records']),'removed_original_triangles':sum(counts.values()),'parts':len(draws),'triangles':f['triangles'],'foliage_context_intersections':intersections,'foliage_envelopes':envelopes,'uv_metrics':uv_metrics,'accepted_native_context_parts':len(accepted),'views':views,'limits':'Isolated native renders and original envelope/support/context samples; no whole-room acceptance, continuous routes, growth, ritual, operation or engineering capacity.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('FUNERAL FOLIAGE NATIVE QA',len(volumes),'closed connected stocks;',len(joins),'joined assemblies;',len(support_samples),'floor samples;',len(views),'views')
