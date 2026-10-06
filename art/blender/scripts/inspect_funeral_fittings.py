"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/funeral-fittings-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('FUNERAL_FITTINGS_OUT',str(r)));asset=source/'art/blender/funeral_fittings.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/funeral_fittings_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_funeral_fittings.json').read_text(encoding='utf-8'))
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
lectern,bier=f['assemblies'];original={row['id']:row for row in f['original_records']};l=original[lectern['id']];b=original[bier['id']]
lx=(l['rect'][0]+l['rect'][2])*.5;ly=(l['rect'][1]+l['rect'][3])*.5;bx=(b['rect'][0]+b['rect'][2])*.5;by=(b['rect'][1]+b['rect'][3])*.5
bier_draws=[o for o in draws if o.name.startswith(bier['id']+'__')]
assert max((o.matrix_world@v.co).z for o in bier_draws for v in o.data.vertices)<float(b['z0'])+float(b['h'])+.000003
views=[]
def render(label,eye,target,lens=50):
 group=lectern['id'] if label.startswith('lectern') or label=='book' else bier['id']
 for o in draws:o.hide_render=not o.name.startswith(group+'__')
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens;scene.camera=camera
 scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True);views.append({'id':label,'eye':list(eye),'target':list(target),'file':label+'.png'});bpy.data.objects.remove(camera,do_unlink=True)
render('lectern_front',(lx+2.2,ly-2.2,2.2),(lx,ly,.65))
render('lectern_rear',(lx-2.2,ly+2.2,2.2),(lx,ly,.65))
render('book',(lx+.45,ly-.40,1.65),(lx+.035,ly,1.245))
render('lectern_bearing',(lx+.75,ly-.75,1.0),(lx,ly,1.12))
render('empty_bier_front',(bx+3.0,by-3.2,2.1),(bx,by,.45))
render('empty_bier_rear',(bx-3.0,by+3.2,2.1),(bx,by,.45))
for i in range(2):
 row=original[bier['id']+'_trestle'+str(i)];x=(row['rect'][0]+row['rect'][2])*.5;y=(row['rect'][1]+row['rect'][3])*.5
 render('trestle'+str(i),(x+1.3,y-1.3,1.15),(x,y,.37),45)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_volumes':volumes,'assembly_stock_joins':joins,'independent_stock_surface_pairs':independent_pairs,'actual_support_samples':support_samples,'source_boundary_stocks':len(bpy.data.collections['RetainedSourceBoxes'].objects),'parts':len(draws),'triangles':f['triangles'],'views':views,'empty_bier':'No installed construction lies above the original empty deck.'},indent=2)+'\n')
print('FUNERAL FITTINGS NATIVE QA',len(volumes),'closed connected stocks;',len(joins),'joined assemblies;',len(views),'views')
