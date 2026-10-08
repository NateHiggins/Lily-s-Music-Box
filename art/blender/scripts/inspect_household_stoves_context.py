"""All installed native ranges, actual neighboring furniture and oven sweeps."""
from pathlib import Path
import ast,json,math
import bpy,numpy as np
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
plan=json.loads((r/'art/data/household_stoves/source_plan.json').read_text(encoding='utf-8'));layout=json.loads((r/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
anchors={x['id']:x for x in layout['anchors']};levels={x['id']:x['y'] for x in layout['levels']};spaces=layout['spaces']
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/household_stoves.blend'));bpy.context.view_layer.update()
draws=[o for o in bpy.context.scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render]
helper=r/'art/blender/scripts/inspect_medicine_cabinets_context.py';tree=ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'bp','pose','native_mesh','merge','old_mesh','moved'}],type_ignores=[]),str(helper),'exec'))
native={'HouseholdGasRange':merge([native_mesh(o) for o in draws])};owners={};supports_by_id={}
oven=merge([native_mesh(o) for o in draws if '__OvenDoor_ON_' in o.name])[0]
helper=r/'art/blender/scripts/inspect_household_fridge_motion.py';tree=ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'rotate','arc_bounds'}],type_ignores=[]),str(helper),'exec'))
qlow,qhigh=arc_bounds(np.asarray(oven)[:,[1,2,0]],np.array((.318,.34,0)),math.radians(-86),0)
olo,ohi=qlow[[2,0,1]],qhigh[[2,0,1]]
for family in ['domestic_objects','household_wardrobes','prep_cabinets','domestic_storage','domestic_seating','domestic_tables','work_tables','household_fridges']:
 with bpy.data.libraries.load(str(r/f'art/blender/{family}.blend'),link=False) as (src,dst):dst.objects=[n for n in src.objects if '__' in n]
 for o in dst.objects:bpy.context.scene.collection.objects.link(o)
 bpy.context.view_layer.update();fixture=json.loads((r/f'game/tests/fixtures/orison_{family}.json').read_text(encoding='utf-8'))
 for row in fixture['assemblies']:native[row['id']]=merge([native_mesh(o) for o in dst.objects if o.name.startswith(row['id']+'__')])
 if family=='work_tables':
  for row in fixture['assemblies']:owners[row['id']]=row['id']
  owners['b1_repair_bench']='3B_workbench'
 else:
  for row in fixture['runtime']['instances']:owners[row['id']]=row['variant']
furniture={x['id']:x for x in json.loads((r/'game/data/orison_v2/domestic_furniture.json').read_text(encoding='utf-8'))['furniture']}
completion=json.loads((r/'game/data/orison_v2/completion_interiors.json').read_text(encoding='utf-8'))
for row in completion['furniture']:furniture[row['id']]={**furniture[row['template']],'id':row['id']}
world={identity:moved(native[owners[identity]] if identity in owners else old_mesh(row),identity) for identity,row in furniture.items()}
for identity,variant in owners.items():
 if variant in ['FridgeIcebox','FridgeMonitor']:world[identity]=moved(native[variant],identity)
checks=[];failures=[];bearings=[]
for row in plan['instances']:
 identity=row['id'];a=anchors[identity];p=a['position'];matrix=pose(identity);stove=moved(native['HouseholdGasRange'],identity)
 rooms=[s for s in spaces if s['level']==a['level'] and s['rect'][0]<=p[0]<=s['rect'][2] and s['rect'][1]<=p[2]<=s['rect'][3]]
 assert rooms,identity
 room=min(rooms,key=lambda s:(s['rect'][2]-s['rect'][0])*(s['rect'][3]-s['rect'][1]));rect=room['rect']
 for x in [-.275,.275]:
  for y in [-.245,.245]:
   at=matrix@Vector((x,y,0));assert abs(at.z-levels[a['level']])<.00003 and rect[0]<at.x<rect[2] and rect[1]<-at.y<rect[3],identity
   bearings.append({'actor':identity,'point':list(at),'room':room['id']})
 for other,right in world.items():
  if np.any(stove['high']<=right['low']+.00003) or np.any(right['high']<=stove['low']+.00003):continue
  hits=stove['tree'].overlap(right['tree']);checks.append([identity,other,'closed surfaces',len(hits)])
  if hits:failures.append(checks[-1])
 corners=np.asarray([matrix@Vector((x,y,z)) for x in [olo[0],ohi[0]] for y in [olo[1],ohi[1]] for z in [olo[2],ohi[2]]]);lo=corners.min(0);hi=corners.max(0)
 for other,right in world.items():
  if not (np.any(hi<=right['low']+.00003) or np.any(right['high']<=lo+.00003)):failures.append([identity,other,'oven envelope needs refinement'])
 lo=np.minimum(lo,stove['low']);hi=np.maximum(hi,stove['high'])
 for room in spaces:
  if room['level']!=a['level'] or room.get('open_shell'):continue
  rect=room['rect'];margin=layout['dimensions']['partition_wall']*.5
  for segment in [{'side':name} for name in room.get('wall_sides',['west','east','north','south'])]+room.get('wall_extensions',[]):
   side=segment['side'];xside=side in ['west','east'];fixed=rect[{'west':0,'east':2,'south':1,'north':3}[side]]
   start=segment.get('start',rect[1 if xside else 0]);end=segment.get('end',rect[3 if xside else 2])
   wlo=np.array((fixed-margin,-end,levels[a['level']])) if xside else np.array((start,-fixed-margin,levels[a['level']]))
   whi=np.array((fixed+margin,-start,levels[a['level']]+layout['dimensions']['clear_height'])) if xside else np.array((end,-fixed+margin,levels[a['level']]+layout['dimensions']['clear_height']))
   if not (np.any(hi<=wlo+.00003) or np.any(whi<=lo+.00003)):failures.append([identity,room['id'],side,'wall envelope requires refinement'])
out={'evidence_class':'INERT','floor_bearings':bearings,'native_neighbor_clearances':checks,'failures':failures,'scope':'All eighteen source placements, seventy-two feet, native furniture/refrigerator adjacency and full 86-degree oven envelope. Burner service travel remains a separate preflight.'}
(r/'tmp/v2-finish-review/household-stoves-context.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n')
assert not failures,failures
print('STOVE CONTEXT:',len(bearings),'bearings,',len(checks),'close neighboring surface checks')
