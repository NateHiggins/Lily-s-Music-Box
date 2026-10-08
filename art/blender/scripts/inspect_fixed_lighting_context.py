"""Room fixture contacts against retained room ceilings, floors above and walls."""
from pathlib import Path
import json,math
from mathutils import Matrix,Vector
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
plan=json.loads((r/'art/data/fixed_lighting/source_plan.json').read_text(encoding='utf-8'))
fixture=json.loads((r/'game/tests/fixtures/orison_fixed_lighting.json').read_text(encoding='utf-8'))
layout=json.loads((r/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
anchors={a['id']:a for a in layout['anchors']};spaces={s['id']:s for s in layout['spaces']};levels={a['id']:a['y'] for a in layout['levels']}
contacts=[];failures=[];clear=float(layout['dimensions']['clear_height']);slab=float(layout['dimensions']['slab_thickness'])
for row in plan['instances']:
 if row.get('domain','room')!='room':continue
 anchor=anchors[row['id']];at=Vector(anchor['position']);at.y+=levels[anchor['level']]
 pose=Matrix.Translation(at)@Matrix.Rotation(float(anchor['yaw']),4,'Y')@Matrix.Translation(Vector(row.get('visual_offset',[0,0,0])))
 for contact in fixture['contacts']:
  if contact['assembly']!=row['variant']:continue
  point=pose@Vector(contact['point']);direction=pose.to_3x3()@Vector(contact['direction']);matches=[]
  if contact['owner']=='ceiling':
   for space in layout['spaces']:
    x0,z0,x1,z1=space['rect']
    if not x0<=point.x<=x1 or not z0<=point.z<=z1:continue
    if not space.get('no_ceiling') and abs(point.y-(levels[space['level']]+clear))<.00003:matches.append({'space':space['id'],'surface':'ceiling underside'})
    if not space.get('no_floor') and abs(point.y-(levels[space['level']]-slab))<.00003:matches.append({'space':space['id'],'surface':'upper floor underside'})
   for stair in layout['stairs']:
    x,z=stair['origin'];width=stair['width'];gap=stair['gap'];run=stair['tread']*stair['risers_per_flight'];base=levels[stair['from']]
    underside=base+stair['rise']*stair['risers_per_flight']-slab
    if x<=point.x<=x+2*width+gap and z+run<=point.z<=z+run+stair['landing_depth'] and abs(point.y-underside)<.00003:
     matches.append({'stair':stair['id'],'surface':'half landing underside'})
  elif contact['owner']=='wall':
   for space in layout['spaces']:
    if space['level']!=anchor['level'] or space.get('open_shell'):continue
    rect=space['rect']
    for segment in [{'side':s} for s in space.get('wall_sides',['south','north','west','east'])]+space.get('wall_extensions',[]):
     side=segment['side'];axis=0 if side in ['west','east'] else 2;other=2-axis
     if abs(direction[axis])<.99:continue
     face=rect[{'west':0,'east':2,'south':1,'north':3}[side]]+float(layout['dimensions']['partition_wall'])*.5*direction[axis]
     lo=segment.get('start',rect[1 if axis==0 else 0]);hi=segment.get('end',rect[3 if axis==0 else 2])
     if abs(point[axis]-face)<.00003 and lo<=point[other]<=hi:matches.append({'space':space['id'],'surface':side})
  if contact['owner']=='wall':
   # A nominal wall plane is not a bearing within one of its real apertures.
   for cut in layout['windows']+layout['doors']+layout['openings']:
    if cut.get('level')!=anchor['level']:continue
    axis=0 if cut.get('axis',('z' if abs(float(cut.get('yaw',0)))>1 else 'x'))=='z' else 2;other=2-axis
    center=cut['center'];fixed=center[0 if axis==0 else 1];along=center[1 if axis==0 else 0]
    bottom=levels[anchor['level']]+float(cut.get('sill',0))
    if abs(point[axis]-fixed)<float(layout['dimensions']['partition_wall']) and abs(point[other]-along)<float(cut['width'])/2 and bottom<point.y<bottom+float(cut['height']):matches=[]
  result={'id':row['id'],'variant':row['variant'],'point':list(point),'owner':contact['owner'],'matches':matches};contacts.append(result)
  if not matches:failures.append(result)
out=r/'tmp/v2-finish-review/fixed-lighting-context.json'
room_count=len({c['id'] for c in contacts})
out.write_text(json.dumps({'evidence_class':'INERT','actors':room_count,'contacts':contacts,'failures':failures,'scope':'Authored room fixture supports. City bearings are checked separately against actual exported geometry.'},indent=2)+'\n',encoding='utf-8',newline='\n')
assert not failures,failures
print('FIXED LIGHTING ROOM CONTEXT:',room_count,'actors;',len(contacts),'source surface contacts')
