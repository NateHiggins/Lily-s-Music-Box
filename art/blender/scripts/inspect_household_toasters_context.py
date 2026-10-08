"""Passive apartment objects against their real walls, floors and coffee table."""
from pathlib import Path
import json, math
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
layout=json.loads((r/'game/data/orison_v2_blockout.json').read_text())
anchors={x['id']:x for x in layout['anchors']};levels={x['id']:x['y'] for x in layout['levels']};spaces={x['id']:x for x in layout['spaces']}
source=json.loads((r/'game/data/orison_v2/domestic_furniture.json').read_text())['furniture'];furniture={x['id']:x for x in source}
for row in json.loads((r/'game/data/orison_v2/completion_interiors.json').read_text())['furniture']:
 furniture[row['id']]={**furniture[row['template']],'id':row['id']}

def bp(p):return Vector((p[0],-p[2],p[1]))
def pose(identity):
 if identity in supports_by_id:
  row=next(x for x in toaster_rows if x['id']==identity)
  return pose(row['support'])@Matrix.Translation(bp(row['position']))@Matrix.Rotation(float(row['yaw']),4,'Z')
 a=anchors[identity];at=bp(a['position']);at.z+=levels[a['level']]
 return Matrix.Translation(at)@Matrix.Rotation(float(a['yaw']),4,'Z')

def native_mesh(obj):
 return ([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])

def merge(meshes):
 points=[];faces=[]
 for vertices,polygons in meshes:
  offset=len(points);points.extend(vertices);faces.extend([[offset+i for i in p] for p in polygons])
 return points,faces

def old_mesh(record):
 if 'surfaces' not in record:
  lo,hi=record['bounds'];vertices=[bp([x,y,z]) for z in [lo[2],hi[2]] for y in [lo[1],hi[1]] for x in [lo[0],hi[0]]]
  return vertices,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
 vertices=[];faces=[]
 for surface in record['surfaces']:
  values=surface['vertices'];normals=surface['normals'];offset=len(vertices);vertices.extend(bp(values[i:i+3]) for i in range(0,len(values),3))
  for i in range(0,len(values)//3,3):
   ids=[offset+i,offset+i+1,offset+i+2];a,b,c=[vertices[j] for j in ids]
   if (b-a).cross(c-a).dot(bp(normals[i*3:i*3+3]))<0:ids.reverse()
   faces.append(ids)
 return vertices,faces

def moved(mesh,identity):
 points,faces=mesh;matrix=pose(identity);points=[matrix@p for p in points];a=np.asarray(points)
 return {'tree':BVHTree.FromPolygons(points,faces),'low':a.min(0),'high':a.max(0),'points':points,'faces':faces}

bpy.ops.wm.read_factory_settings(use_empty=True)
native={};contacts={};variants={};owners={};moving={};accessories=json.loads((r/'game/data/orison_v2/household_accessories.json').read_text(encoding='utf-8'))['accessories']; toaster_rows=[x for x in accessories if x['kind']=='toaster']; supports_by_id={x['id']:x['support'] for x in toaster_rows}
for family in ['household_toasters','domestic_objects','household_wardrobes','prep_cabinets','domestic_storage','domestic_seating','domestic_tables','work_tables']:
 with bpy.data.libraries.load(str(r/f'art/blender/{family}.blend'),link=False) as (src,dst):dst.objects=[n for n in src.objects if '__' in n]
 objects=dst.objects
 for obj in objects:bpy.context.scene.collection.objects.link(obj)
 bpy.context.view_layer.update()
 fixture=json.loads((r/f'game/tests/fixtures/orison_{family}.json').read_text())
 for row in fixture['assemblies']:
  identity=row['id'];mesh=merge([native_mesh(o) for o in objects if o.name.startswith(identity+'__')]);assert mesh[0],identity
  native[identity]=mesh
  if family=='household_toasters' and identity!='ToasterCrumb':
   moving[identity]={component:merge([native_mesh(o) for o in objects if o.name.startswith(identity+'__'+component+'_ON_')]) for component in ['OrisonRetrofitCrumbTray','CarriageLever','BreadCarrier']}
 if family=='work_tables':
  for row in fixture['assemblies']:owners[row['id']]=row['id']
  # The completion bench is an exact source-template copy of the already
  # reviewed 3B assembly. Validate its distinct production installation too.
  copy=next(x for x in json.loads((r/'game/data/orison_v2/completion_interiors.json').read_text(encoding='utf-8'))['furniture'] if x['id']=='b1_repair_bench')
  assert copy['template']=='3B_workbench'
  owners['b1_repair_bench']='3B_workbench'
 else:
  for row in fixture['runtime']['instances']:
   owners[row['id']]=row['variant']
   if family=='household_toasters':
    variants[row['id']]=row['variant'];contacts[row['id']]=[c for c in fixture['contacts'] if c['assembly']==row['variant']]

world={}
for row in toaster_rows:world[row['id']]=moved(native[variants[row['id']]],row['id'])
for identity,row in furniture.items():
 assert identity in anchors,identity
 world[identity]=moved(native[owners[identity]] if identity in owners else old_mesh(row),identity)

bearings=[];clearances=[];failures=[];sweeps=[]

def wall_bearing(anchor,point,direction):
 # Compare the actual source-owned wall faces, including another room's shared
 # wall. The C kitchens have no west wall; their bathrooms own that partition.
 g=Vector((point.x,point.z,-point.y));d=Vector((direction.x,direction.z,-direction.y))
 matches=[]
 for room in spaces.values():
  if room['level']!=anchor['level'] or room.get('open_shell'):continue
  rect=room['rect'];floor=levels[room['level']];height=layout['dimensions']['clear_height']
  for side in room.get('wall_sides',['south','north','west','east']):
   axis=0 if side in ['west','east'] else 2;other=2-axis
   if abs(d[axis])<.99:continue
   fixed=rect[{'west':0,'east':2,'south':1,'north':3}[side]]
   face=fixed+layout['dimensions']['partition_wall']*.5*d[axis]
   low=rect[1 if axis==0 else 0];high=rect[3 if axis==0 else 2]
   if abs(g[axis]-face)>.00004 or not low<=g[other]<=high or not floor<=g.y<=floor+height:continue
   blocked=False
   for opening in layout['doors']+layout['openings']+layout['windows']:
    if room['id'] not in opening.get('connects',[opening.get('space')]):continue
    center=opening['center'];normal_index=0 if axis==0 else 1;along_index=1-normal_index
    if abs(center[normal_index]-fixed)>.0001:continue
    if abs(g[other]-center[along_index])<float(opening['width'])/2 and float(opening.get('sill',0))<g.y-floor<float(opening.get('sill',0))+float(opening['height']):blocked=True
   if not blocked:matches.append({'space':room['id'],'side':side,'face':face})
 return matches

for identity,variant in variants.items():
 matrix=pose(identity);anchor=anchors[supports_by_id[identity]]
 candidates=[spaces[anchor['space']]] if 'space' in anchor else [s for s in spaces.values() if s['level']==anchor['level'] and s['rect'][0]<=anchor['position'][0]<=s['rect'][2] and s['rect'][1]<=anchor['position'][2]<=s['rect'][3]]
 assert candidates,(identity,'no source floor rectangle')
 space=min(candidates,key=lambda s:(s['rect'][2]-s['rect'][0])*(s['rect'][3]-s['rect'][1]));rect=space['rect'];level_y=levels[anchor['level']]
 for contact in contacts[identity]:
  point=matrix@bp(contact['point'])
  inside=rect[0]-.00004<=point.x<=rect[2]+.00004 and rect[1]-.00004<=-point.y<=rect[3]+.00004
  if contact['owner']=='wall':
   wall=wall_bearing(anchor,point,matrix.to_3x3()@bp(contact['direction']))
   if not wall:failures.append([identity,'missing retained wall bearing',list(point)])
  elif identity in supports_by_id:
   wall=[];owner=world[supports_by_id[identity]];hit,normal,_,_=owner['tree'].ray_cast(point+Vector((0,0,.004)),Vector((0,0,-1)),.008)
   if hit is None or (hit-point).length>.00004 or normal.z<.99:failures.append([identity,supports_by_id[identity],'missing actual furniture support'])
  else:
   wall=[]
   if not inside or abs(point.z-level_y)>.00004:failures.append([identity,'foot outside retained floor',list(point),rect])
  bearings.append({'id':identity,'point':[point.x,point.z,-point.y],'space':space['id'],'owner':contact['owner'],'wall':wall})
 left=world[identity]
 for other,right in world.items():
  if other==identity or (other in variants and other<identity):continue
  if np.any(left['high']<=right['low']+.00002) or np.any(right['high']<=left['low']+.00002):continue
  overlap=left['tree'].overlap(right['tree'])
  # The existing radio sits on the top board. Coplanar bearing triangles are
  # allowed only for that authored support pair; any crossing still refuses.
  bearing_contact=other==supports_by_id.get(identity)
  if overlap and bearing_contact:
   for li,ri in overlap:
    lp=np.asarray([left['points'][i] for i in left['faces'][li]])
    rp=np.asarray([right['points'][i] for i in right['faces'][ri]])
    low=max(lp[:,2].min(),rp[:,2].min());high=min(lp[:,2].max(),rp[:,2].max())
    if high-low>.00003:bearing_contact=False;break
  if overlap and not bearing_contact:failures.append([identity,other,'surface intersections',len(overlap)])
  clearances.append([identity,other,len(overlap),'authored bearing' if bearing_contact else 'clear'])

 # Each whole moving-component envelope is conservative for every intermediate
 # pose. Reject a nearby obstacle for narrower proof instead of frame sampling.
 row=next(x for x in toaster_rows if x['id']==identity)
 deltas={'OrisonRetrofitCrumbTray':[(0,0,0),(-.160,0,0) if row['tray_axis']=='-x' else (0,.160,0)],'BreadCarrier':[(0,0,-.087),(0,0,.024)],'CarriageLever':[(x,0,z) for x in [-.004,.003] for z in [-.046,.010]]}
 for component,(points,_) in moving[variant].items():
  swept=np.asarray([matrix@(p+Vector(delta)) for p in points for delta in deltas[component]]);lo=swept.min(0);hi=swept.max(0);near=[]
  for other,obstacle in world.items():
   if other==identity:continue
   if np.any(hi<=obstacle['low']+.00002) or np.any(obstacle['high']<=lo+.00002):continue
   near.append(other);failures.append([identity,component,other,'continuous external envelope needs narrower proof'])
  for side in space.get('wall_sides',['west','east','north','south']):
   margin=layout['dimensions']['partition_wall']*.5
   clearance={'west':lo[0]-rect[0]-margin,'east':rect[2]-margin-hi[0],'south':-hi[1]-rect[1]-margin,'north':rect[3]-margin+lo[1]}[side]
   if clearance<-.00004:failures.append([identity,component,side,'continuous envelope crosses wall face',clearance])
  sweeps.append({'id':identity,'component':component,'low_blender':lo.tolist(),'high_blender':hi.tolist(),'nearby_furniture':near})


out=r/'tmp/v2-finish-review/household-toasters-context.json'
out.write_text(json.dumps({'evidence_class':'INERT','installations':len(variants),'bearings':bearings,'nearby_pairs':clearances,'continuous_external_sweeps':sweeps,'failures':failures,'scope':'Closed native toasters at original source poses against actual prep cabinets and neighboring native furniture. Full moving-component envelopes also clear source furniture and room walls; internal movement is checked separately.'},indent=2)+'\n',encoding='utf-8',newline='\n')
assert not failures,failures
print('TOASTERS CONTEXT:',len(variants),'installations;',len(bearings),'bearings;',len(clearances),'nearby pairs clear')
