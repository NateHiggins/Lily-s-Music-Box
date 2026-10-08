"""Inspect supply routes against the actual native lamps, furniture and tabletop stock."""
from pathlib import Path
import bpy,json,math
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
out=ROOT/'tmp/v2-improvement/supply-native';out.mkdir(parents=True,exist_ok=True)
plan=json.loads((ROOT/'art/data/task_lamp_supply/source_plan.json').read_text())
fixture=json.loads((ROOT/'game/tests/fixtures/orison_task_lamp_supply.json').read_text())
def bp(p):return Vector((p[0],-p[2],p[1]))
def pose(p,yaw):return Matrix.Translation(bp(p))@Matrix.Rotation(yaw,4,'Z')
def append(file,predicate):
 with bpy.data.libraries.load(str(ROOT/'art/blender'/file),link=False) as (src,dst):dst.objects=[n for n in src.objects if predicate(n)]
 for obj in dst.objects:bpy.context.scene.collection.objects.link(obj)
 return dst.objects
def tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/task_lamp_supply.blend'))
supplies=list(bpy.data.collections['Composed review'].objects)
tables=append('work_tables.blend',lambda n:'__' in n and any(n.startswith(row['support']+'__') for row in plan['installations']))
nook=append('reading_nook.blend',lambda n:n.startswith(('nook_table__','nook_rug__','nook_mug__','nook_pile__')))
nook_data=json.loads((ROOT/'game/data/orison_v2/reading_nook.json').read_text())
table_row=next(r for r in nook_data['assemblies'] if r['id']=='nook_table');nook_frame=pose(table_row['position'],table_row['yaw']).inverted()
for obj in nook:obj.matrix_world=nook_frame@obj.matrix_world
lamps=append('task_lamps.blend',lambda n:n.startswith('TaskLamp_') and '__' in n)
terminal=append('signal_terminal.blend',lambda n:'__' in n and not n.endswith('_source'))
for obj in terminal:obj.matrix_world=pose([.075,.75,0],math.pi)@obj.matrix_world
surface_data=json.loads((ROOT/'game/data/orison_v2/domestic_surface_props.json').read_text())['props']
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1100;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral route inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.5,.5,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
scene.view_settings.view_transform='AgX';results=[];views=[];failures=[]
for row,route in zip(plan['installations'],fixture['routes']):
 identity=row['id'];chosen=[o for o in tables if o.name.startswith(row['support']+'__')]+(nook if row['support']=='nook_table' else [])
 body=[o for o in lamps if o.name.startswith('TaskLamp_'+row['variant']+'__')]
 for o in body:o.matrix_world=pose(row['position'],row['yaw'])
 neighbours=terminal if row['support']=='4B_terminal_desk' else []
 for obj in [*tables,*nook,*lamps,*terminal,*supplies]:obj.hide_render=True
 for obj in [*chosen,*body,*neighbours]:obj.hide_render=False
 route_draws=[o for o in supplies if o.get('installation')==identity]
 for obj in route_draws:obj.hide_render=False
 bpy.context.view_layer.update()
 blockers=[(o.name,tree(o)) for o in [*chosen,*body,*neighbours]]
 outlet_draw=next(o for o in route_draws if o.name.startswith('SupplyOutlet'))
 outlet_tree=tree(outlet_draw)
 outlet_clashes=[label for label,bvh in blockers if not label.startswith('nook_rug__') and outlet_tree.overlap(bvh)]
 if outlet_clashes:failures.append({'id':identity,'outlet_clashes':outlet_clashes})
 for prop in surface_data:
  if prop['support']!=row['support']:continue
  points=[];faces=[];transform=pose(prop['position'],prop['yaw'])
  for surface in prop['surfaces']:
   values=surface['vertices']
   for i in range(0,len(values),9):faces.append(tuple(range(len(points),len(points)+3)));points.extend(transform@bp(values[i+j:i+j+3]) for j in [0,3,6])
  blockers.append((prop['id'],BVHTree.FromPolygons(points,faces)))
 points=[bp(p) for p in route['centerline']];crossings=[];distance=0.;nearest=1e9
 for i in range(1,len(points)):
  segment=points[i]-points[i-1];length=segment.length
  for j in range(1,max(2,math.ceil(length/.003))+1):
   point=points[i-1]+segment*(j/max(2,math.ceil(length/.003)))
   if distance+(point-points[i-1]).length<.018:continue # deliberately seated gland only
   for label,bvh in blockers:
    hit,normal,_,gap=bvh.find_nearest(point)
    if hit is None:continue
    nearest=min(nearest,gap)
    if gap<float(route['radius'])-.00004:crossings.append([label,[round(v,5) for v in point],round(gap,6)])
  distance+=length
 if crossings:failures.append({'id':identity,'crossings':crossings[:12]})
 results.append({'id':identity,'length_m':route['length'],'tested_blockers':len(blockers),'crossing_samples':len(crossings),'outlet_clashes':outlet_clashes,'minimum_surface_clearance_m':nearest})
 for view,offset in [('complete',(1.25,1.9,1.2)),('underside',(-1.25,-1.8,.2))]:
  target=bp(row['position'])*.5 if view=='complete' else (bp(route['entry'])+bp(route['outlet']))*.5
  eye=target+Vector(offset);bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.data.lens=48;camera.data.clip_start=.001;camera.rotation_euler=(target-eye).to_track_quat('-Z','Y').to_euler();scene.camera=camera
  lights=[]
  for delta,power in [((-1.2,1.5,2.),150),((1.3,-1.5,.8),110)]:
   bpy.ops.object.light_add(type='AREA',location=target+Vector(delta));light=bpy.context.object;light.data.energy=power;light.data.size=2;light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler();lights.append(light)
  name=identity+'_'+view+'.png';scene.render.filepath=str(out/name);bpy.ops.render.render(write_still=True);views.append({'id':identity,'view':view,'file':name})
  for obj in [camera,*lights]:bpy.data.objects.remove(obj,do_unlink=True)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','routes':results,'failures':failures,'views':views,'scope':'Dense centerline clearance samples against native furniture, lamps and retained tabletop stock; installed floor contacts and original switches require runtime validation.'},indent=2)+'\n')
assert not failures,failures
print('SUPPLY NATIVE',len(results),'routes; zero sampled crossings; ten contextual views')
