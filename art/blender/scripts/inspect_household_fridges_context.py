"""Installed native refrigerators, floor contacts and full food jitter bounds."""
from pathlib import Path
import json,math,ast
import bpy,numpy as np
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
plan=json.loads((r/'art/data/household_fridges/source_plan.json').read_text(encoding='utf-8'));layout=json.loads((r/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
anchors={x['id']:x for x in layout['anchors']};levels={x['id']:x['y'] for x in layout['levels']};spaces=layout['spaces']
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/household_fridges.blend'));bpy.context.view_layer.update()
draws=[o for o in bpy.context.scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render]
points={row['id']:np.asarray([o.matrix_world@v.co for o in draws if o.name.startswith(row['id']+'__') for v in o.data.vertices]) for row in plan['variants']}
checks=[];foods=[]
for row in plan['instances']:
 a=anchors[row['id']];p=a['position'];pose=Matrix.Translation((p[0],-p[2],p[1]+levels[a['level']]))@Matrix.Rotation(a['yaw'],4,'Z');monitor=row['variant']=='FridgeMonitor'
 floor=levels[a['level']];rooms=[s for s in spaces if s['level']==a['level'] and s['rect'][0]<=p[0]<=s['rect'][2] and s['rect'][1]<=p[2]<=s['rect'][3]];assert rooms,row['id']
 room=min(rooms,key=lambda s:(s['rect'][2]-s['rect'][0])*(s['rect'][3]-s['rect'][1]));rect=room['rect']
 for x in [-.30,.30] if monitor else [-.29,.29]:
  for y in [-.265,.265] if monitor else [-.235,.235]:
   at=pose@Vector((x,y,0));assert abs(at.z-floor)<.00003 and rect[0]<at.x<rect[2] and rect[1]<-at.y<rect[3],(row['id'],at)
   checks.append({'actor':row['id'],'foot':list(at),'floor':room['id']})
 items=plan['source_larder'][row['unit']];inner=.277 if monitor else .259;shelves=plan['visual_fit']['monitor_shelves' if monitor else 'icebox_shelves']
 used={};count={s:sum(1 for item in items if item[4]==s) for s in range(3)}
 for item in items:
  name,color,w,h,s=item;n=used.get(s,0);used[s]=n+1;x=-inner+(n+.5)*(inner*2)/count[s];lim=inner-w/2-.006
  proto=next(v for v in plan['variants'] if v['kind']=='food' and v['source_id']==name and v['width']==w and v['height']==h);pts=points[proto['id']]
  # Bound all source yaw/jitter, not just one conveniently centered picture.
  radial=np.linalg.norm(pts[:,:2],axis=1).max();minx=min(max(x-.012,-lim),lim)-radial;maxx=min(max(x+.012,-lim),lim)+radial
  assert minx>=-inner-.00003 and maxx<=inner+.00003,(row['id'],name,'liner',minx,maxx,inner)
  bottom=shelves[s]+.0045;top=bottom+pts[:,2].max();next_surface=(shelves[s+1]-.009 if s<2 else (1.236 if monitor else .921))
  assert top<=next_surface+.00003,(row['id'],name,'upper shelf',top,next_surface)
  assert radial+.055<(.235 if monitor else .21),(row['id'],name,'rack depth')
  # Every footprint covers at least one full-width longitudinal rack wire.
  pitch=(inner*2-.016)/40;assert w*.40>pitch,(row['id'],name,'rack pitch')
  foods.append({'actor':row['id'],'prototype':proto['id'],'name':name,'shelf':s,'bottom':bottom,'top':float(top),'x_envelope':[float(minx),float(maxx)]})

# Link the accepted surrounding apartment furniture once; validate every
# installed source anchor against real native surfaces before engine import.
helper=r/'art/blender/scripts/inspect_medicine_cabinets_context.py';tree=ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'bp','pose','native_mesh','merge','old_mesh','moved'}],type_ignores=[]),str(helper),'exec'))
supports_by_id={}
native={v['id']:merge([native_mesh(o) for o in draws if o.name.startswith(v['id']+'__')]) for v in plan['variants']}
leaves={}
for variant in ['FridgeIcebox','FridgeMonitor']:
 for owner in ['Door','IceDoor','DripTray']:
  selected=[o for o in draws if o.name.startswith(variant+'__'+owner+'_ON_')]
  if selected:leaves[(variant,owner)]=merge([native_mesh(o) for o in selected])
owners={}
for family in ['domestic_objects','household_wardrobes','prep_cabinets','domestic_storage','domestic_seating','domestic_tables','work_tables']:
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
for row in json.loads((r/'game/data/orison_v2/completion_interiors.json').read_text(encoding='utf-8'))['furniture']:furniture[row['id']]={**furniture[row['template']],'id':row['id']}
world={identity:moved(native[owners[identity]] if identity in owners else old_mesh(row),identity) for identity,row in furniture.items()}
helper=r/'art/blender/scripts/inspect_household_fridge_motion.py';tree=ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'rotate','arc_bounds'}],type_ignores=[]),str(helper),'exec'))
clearances=[];sweeps=[];failures=[];service=[]
for row in plan['instances']:
 identity=row['id'];variant=row['variant'];a=anchors[identity];matrix=pose(identity);monitor=variant=='FridgeMonitor'
 fridge=moved(native[variant],identity)
 for other,right in world.items():
  if np.any(fridge['high']<=right['low']+.00003) or np.any(right['high']<=fridge['low']+.00003):continue
  hits=fridge['tree'].overlap(right['tree']);clearances.append([identity,other,len(hits)])
  if hits:failures.append([identity,other,'closed native surfaces cross',len(hits)])
 # A closed case must leave every same-level door and opening passage clear: its clear width, 0.30 m
 # either side of the wall plane, to the passage head (3fbba2e5 stood three in a kitchen-hall opening).
 for door in layout['doors']+layout['openings']:
  if door['level']!=a['level']:continue
  across=door['axis']=='z' if 'axis' in door else abs(float(door.get('yaw',0)))>.785
  cx,cz=door['center'];half=door['width']*.5;fl=levels[a['level']]
  gx=(cx-.30,cx+.30) if across else (cx-half,cx+half);gz=(cz-half,cz+half) if across else (cz-.30,cz+.30)
  plo=np.array((gx[0],-gz[1],fl));phi=np.array((gx[1],-gz[0],fl+door['height']))
  if not (np.any(fridge['high']<=plo+.00003) or np.any(phi<=fridge['low']+.00003)):failures.append([identity,door['id'],'closed case stands in a door or opening passage'])
 for (v,owner),(pp,faces) in leaves.items():
  if v!=variant:continue
  pts=np.asarray([matrix@p for p in pp]);pivot=np.asarray(matrix@Vector((-.36,.32,0) if monitor else (-.35,.29,0)))
  if owner=='DripTray':
   q=pts+np.asarray(matrix.to_3x3()@Vector((0,.30,0)));low=np.minimum(pts.min(0),q.min(0));high=np.maximum(pts.max(0),q.max(0))
  else:low,high=arc_bounds(pts,pivot,0,math.radians(98 if owner=='IceDoor' else 105))
  for other,right in world.items():
   if not (np.any(high<=right['low']+.00003) or np.any(right['high']<=low+.00003)):failures.append([identity,owner,other,'continuous envelope requires refinement'])
  if row['unit'] in ['1A','3D','4D']:
   fittings=json.loads((r/'game/data/orison_v2/completion_interiors.json').read_text(encoding='utf-8'))['fittings']
   stove=next(f for f in fittings if f['unit']==row['unit'] and f['kind']=='stove');sm=pose(stove['id'])
   # Conservative source range envelope includes its complete downward
   # oven/broiler swing and the high condiment shelf. A disjoint box proves
   # that neither source appliance can strike the other in any service pose.
   sp=np.asarray([sm@Vector((x,y,z)) for x in [-.32,.32] for y in [-.32,.72] for z in [0,1.16]])
   full_low=np.minimum(low,fridge['low']);full_high=np.maximum(high,fridge['high'])
   clear=bool(np.any(full_high<=sp.min(0)+.00003) or np.any(sp.max(0)<=full_low+.00003))
   service.append([identity,owner,stove['id'],clear]);assert clear,service[-1]
  # Include the fixed case when testing retained wall volumes too.
  lo=np.minimum(low,fridge['low']);hi=np.maximum(high,fridge['high'])
  for room in spaces:
   if room['level']!=a['level'] or room.get('open_shell'):continue
   rect=room['rect'];margin=layout['dimensions']['partition_wall']*.5
   for segment in [{'side':name} for name in room.get('wall_sides',['west','east','north','south'])]+room.get('wall_extensions',[]):
    side=segment['side'];xside=side in ['west','east'];fixed=rect[{'west':0,'east':2,'south':1,'north':3}[side]]
    start=segment.get('start',rect[1 if xside else 0]);end=segment.get('end',rect[3 if xside else 2])
    wlo=np.array((fixed-margin,-end,levels[a['level']])) if xside else np.array((start,-fixed-margin,levels[a['level']]))
    whi=np.array((fixed+margin,-start,levels[a['level']]+layout['dimensions']['clear_height'])) if xside else np.array((end,-fixed+margin,levels[a['level']]+layout['dimensions']['clear_height']))
    if not (np.any(hi<=wlo+.00003) or np.any(whi<=lo+.00003)):failures.append([identity,owner,room['id'],side,'continuous wall envelope requires refinement'])
  sweeps.append({'actor':identity,'owner':owner,'low':low.tolist(),'high':high.tolist()})
out=r/'tmp/v2-finish-review/household-fridges-context.json';out.write_text(json.dumps({'evidence_class':'INERT','floor_bearings':checks,'food_envelopes':foods,'scope':'All source floor placements and full food yaw/jitter radial bounds. External door sweeps are inspected separately before engine acceptance.'},indent=2)+'\n',encoding='utf-8',newline='\n')
data=json.loads(out.read_text(encoding='utf-8'));data.update({'native_neighbor_clearances':clearances,'continuous_external_sweeps':sweeps,'relocated_appliance_service_clearances':service,'failures':failures});out.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
assert not failures,failures
print('REFRIGERATORS CONTEXT:',len(checks),'floor bearings;',len(foods),'full food placement envelopes')
