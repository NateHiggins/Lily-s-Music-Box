"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/funeral-drapes-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('FUNERAL_DRAPES_OUT',str(r)));asset=source/'art/blender/funeral_drapes.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/funeral_drapes_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_funeral_drapes.json').read_text(encoding='utf-8'))
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
uv_metrics=[]
for obj in draws:
 assembly=next(a for a in f['assemblies'] if obj.name.startswith(a['id']+'__'));lo=assembly['envelope'][2];hi=assembly['envelope'][3]
 assert all(lo-.000003<=(obj.matrix_world@v.co).y<=hi+.000003 for v in obj.data.vertices),('crossed source run endpoint',obj.name)
 mesh=obj.data;mesh.calc_loop_triangles();points=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float64);indices=np.asarray([t.vertices[:] for t in mesh.loop_triangles]);p=points[indices];uv=np.asarray([[mesh.uv_layers.active.data[i].uv[:] for i in t.loops] for t in mesh.loop_triangles],dtype=np.float64)
 e=np.stack([p[:,1]-p[:,0],p[:,2]-p[:,0]],axis=2);d=np.stack([uv[:,1]-uv[:,0],uv[:,2]-uv[:,0]],axis=2);assert np.all(np.abs(np.linalg.det(d))>1e-12)
 metric=np.linalg.svd(e@np.linalg.inv(d),compute_uv=False);assert np.all((metric>.99)&(metric<1.01)),(obj.name,float(metric.min()),float(metric.max()))
 uv_metrics.append({'part':obj.name,'minimum_metres_per_uv':float(metric.min()),'maximum_metres_per_uv':float(metric.max()),'triangles':len(metric)})
def actual_tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons],epsilon=0.)
before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(r/'game/assets/building/floor_01_cells/shop_funeral_parlour.gltf'));context=[o for o in bpy.context.scene.objects if o not in before and o.type=='MESH']
ceiling=next(o for o in context if o.name.removesuffix('-col')=='F01_OWN_SHOP_FUNERAL_PARLOUR_retail_shop_funeral_parlour_tin_ceiling');ceiling_tree=actual_tree(ceiling)
old=next(o for o in context if o.name.removesuffix('-col')=='F01_OWN_SHOP_FUNERAL_PARLOUR_retail_shop_funeral_parlour_vinyl_oxblood');old_mesh=old.data.copy();bm=bmesh.new();bm.from_mesh(old.data);remove=[];counts={row['id']:0 for row in f['original_records']}
for face in bm.faces:
 points=[old.matrix_world@v.co for v in face.verts];n=(points[1]-points[0]).cross(points[2]-points[0]).normalized();axis=max(range(3),key=lambda i:abs(n[i]));matches=[]
 for row in f['original_records']:
  q=row['rect'];low=Vector((q[0],q[1],row['z0']));high=Vector((q[2],q[3],row['z0']+row['h']));plane=high[axis] if n[axis]>0 else low[axis]
  if abs(n[axis])>.999 and all(abs(p[axis]-plane)<.00003 and all(low[i]-.00003<=p[i]<=high[i]+.00003 for i in range(3)) for p in points):matches.append(row['id'])
 if matches:assert len(matches)==1;remove.append(face);counts[matches[0]]+=1
assert len(counts)==10 and all(count==12 for count in counts.values()),counts
bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(old.data);bm.free()
support_samples=[]
for contact in f['contacts']:
 at=Vector((contact['point'][0],-contact['point'][2],contact['point'][1]));hit=ceiling_tree.ray_cast(at-Vector((0,0,.004)),Vector((0,0,1)),.008)
 assert hit[0] is not None and (hit[0]-at).length<.00003,contact
 distances=[]
 for row in f['closed_stocks']:
  if row['assembly']!=contact['assembly'] or '_CeilingPlate' not in row['name']:continue
  plate=actual_tree(bpy.data.objects[row['name']]);hit=plate.ray_cast(at+Vector((0,0,.004)),Vector((0,0,-1)),.008)
  if hit[0] is not None:distances.append((hit[0]-at).length)
 assert distances and min(distances)<.00002,contact
 support_samples.append({'label':contact['label'],'assembly':contact['assembly'],'point':contact['point'],'plate_distance_m':min(distances)})
# Add the actual accepted native seating and lectern/bier for clearance checks;
# old source boxes remain as a conservative additional context boundary.
accepted=[]
for context_asset,fixture in [('shop_seating','orison_shop_seating'),('funeral_fittings','orison_funeral_fittings')]:
 inventory=json.loads((r/'game/tests/fixtures'/f'{fixture}.json').read_text());names={p['name'] for p in inventory['parts'] if p['cell']=='shop_funeral_parlour'}
 before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(r/'game/assets/props'/f'{context_asset}.glb'));loaded=[o for o in bpy.context.scene.objects if o not in before]
 chosen=[o for o in loaded if o.type=='MESH' and o.name in names];assert {o.name for o in chosen}==names,(context_asset,names,{o.name for o in chosen});accepted.extend(chosen)
 for obj in loaded:obj.hide_render=True
cloth=[o for o in draws if o.name.endswith('__curtain_cloth')];assert len(cloth)==2
intersections=[]
for obj in cloth:
 tree=actual_tree(obj)
 for other in context+accepted:
  if not other.data.polygons:continue
  pairs=tree.overlap(actual_tree(other))
  if pairs:intersections.append({'cloth':obj.name,'context':other.name,'triangle_pairs':len(pairs)})
assert not intersections,intersections
for obj in context:obj.hide_render=True
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=1100;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('CurtainReview');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.55,.6,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
bpy.ops.object.light_add(type='SUN',location=(0,0,50));bpy.context.object.data.energy=2.3;bpy.context.object.rotation_euler=(.4,-.6,.3)
views=[]
def render(label,eye,target,group=None,metal_only=False,ceiling_context=False,lens=50):
 for obj in draws:obj.hide_render=(group is not None and not obj.name.startswith(group+'__')) or (metal_only and not obj.name.endswith('__curtain_iron'))
 ceiling.hide_render=not ceiling_context
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens;camera.data.clip_start=.002;scene.camera=camera
 scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True);views.append({'id':label,'eye':list(eye),'target':list(target),'file':label+'.png','scope':'metal-only cutaway with actual retained ceiling' if metal_only else 'native fitting with retained ceiling' if ceiling_context else 'isolated native fitting'})
for i,assembly in enumerate(f['assemblies']):
 sources=[q for q in f['original_records'] if q['id'] in json.loads((source/'art/data/funeral_drapes/source_plan.json').read_text())['groups'][i]['sources']];lo=min(q['rect'][1] for q in sources);hi=max(q['rect'][3] for q in sources);cy=(lo+hi)*.5;identity=assembly['id'];width=hi-lo
 render('run'+str(i)+'_front',(4.215+max(8.,width*4.),cy-.55,1.8),(4.215,cy,1.6),identity)
 render('run'+str(i)+'_rear',(4.215-max(8.,width*4.),cy+.55,1.8),(4.215,cy,1.6),identity)
 render('run'+str(i)+'_hem',(4.85,cy-.30,.26),(4.215,cy,.08),identity)
 render('run'+str(i)+'_header',(4.90,cy-.30,3.10),(4.215,cy,2.94),identity)
 plan=json.loads((source/'art/data/funeral_drapes/source_plan.json').read_text());p=plan['groups'][i]['ceiling_points'][0];y=-p[2]
 render('run'+str(i)+'_ceiling_bearing',(4.65,y-.25,3.14),(4.215,y,3.24),identity,True,True)
render('both_runs_opening',(12.,-61.7,1.8),(4.215,-61.7,1.6))
assert len(views)==11
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_volumes':volumes,'assembly_stock_joins':joins,'independent_stock_surface_pairs':independent_pairs,'actual_ceiling_support_samples':support_samples,'source_boundary_stocks':len(f['original_records']),'removed_original_triangles':sum(counts.values()),'parts':len(draws),'triangles':f['triangles'],'cloth_context_intersections':intersections,'uv_metrics':uv_metrics,'accepted_native_context_parts':len(accepted),'views':views,'limits':'Isolated native renders; ceiling bearings are explicitly metal-only cutaways. Source and accepted native context are checked for cloth intersection, not continuous routes, moving curtains or engineering capacity.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('FUNERAL DRAPES NATIVE QA',len(volumes),'closed connected stocks;',len(joins),'joined assemblies;',len(support_samples),'ceiling samples;',len(views),'views')
