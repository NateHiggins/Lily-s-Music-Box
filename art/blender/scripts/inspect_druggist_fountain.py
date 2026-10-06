"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/druggist-fountain-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('DRUGGIST_FOUNTAIN_OUT',str(r)));asset=source/'art/blender/druggist_fountain.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/druggist_fountain_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_druggist_fountain.json').read_text(encoding='utf-8'))
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
identity=f['assemblies'][0]['id'];cavity_samples=[]
for i in range(3):
 row=next(row for row in f['original_records'] if row['id']==identity+'_tap'+str(i));x0,y0,x1,y1=row['rect'];cx=(x0+x1)*.5;cy=(y0+y1)*.5
 for kind,at,limit in [('open_mouth',(cx+.160,cy,1.245),1.455),('annular_rim',(cx+.172,cy,1.245),1.290)]:
  hit=trees[identity+'_OpenGooseneck'+str(i)].ray_cast(Vector(at),Vector((0,0,1)),limit-at[2]);assert hit[0] is not None,(i,kind)
  if kind=='open_mouth':assert 1.37<hit[0].z<1.455,(i,hit)
  else:assert abs(hit[0].z-1.270)<.00003,(i,hit)
  cavity_samples.append({'tap':i,'sample':kind,'hit':[float(x) for x in hit[0]]})
 hit=trees[identity+'_RemovableCatchTray'+str(i)].ray_cast(Vector((cx+.160,cy,1.13)),Vector((0,0,-1)),.06);assert hit[0] is not None and abs(hit[0].z-1.085)<.00003,(i,'tray',hit)
 cavity_samples.append({'tap':i,'sample':'tray_inner_floor','hit':[float(x) for x in hit[0]]})
views=[]
def render_group(label,visible,offset):
 for o in draws:o.hide_render=o not in visible
 vertices=[o.matrix_world@v.co for o in visible for v in o.data.vertices];low=Vector(tuple(min(v[i] for v in vertices) for i in range(3)));high=Vector(tuple(max(v[i] for v in vertices) for i in range(3)));center=(low+high)*.5
 size=max(high-low);distance=max(.18,size)*2.35
 name=label+'.png';views.append(name);bpy.ops.object.camera_add(location=center+Vector(offset)*distance);cam=bpy.context.object;cam.data.lens=42;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam;scene.render.filepath=str(out/name);bpy.ops.render.render(write_still=True);bpy.data.objects.remove(cam,do_unlink=True)
render_group('cabinet_front',draws,(1,-.8,.50));render_group('cabinet_rear',draws,(-1,.8,.50))
hardware=[o for o in draws if any(o.name.endswith('__'+key) for key in ['tap0','tap1','tap2','nozzle0','nozzle1','nozzle2','catch_trays'])]
render_group('hardware_front',hardware,(1,-.65,.45));render_group('hardware_rear',hardware,(-1,.65,.45))
for i in range(3):render_group('open_nozzle'+str(i),[o for o in draws if o.name.endswith('__nozzle'+str(i))],(.8,.7,-.65))
render_group('open_catch_trays',[o for o in draws if o.name.endswith('__catch_trays')],(.3,.5,1.0))
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_volumes':volumes,'assembly_stock_joins':joins,'independent_stock_surface_pairs':independent_pairs,'actual_cavity_samples':cavity_samples,'source_boundary_stocks':len(bpy.data.collections['RetainedSourceBoxes'].objects),'parts':len(draws),'triangles':f['triangles'],'views':views},indent=2)+'\n')
print('DRUGGIST FOUNTAIN NATIVE QA',len(volumes),'closed connected stocks;',len(joins),'joined assemblies;',len(views),'views')
