"""Scratch physical-fall study, using source decks and real obstacle boundaries.

The retained 200 mm structural slab is never thinned. This studies tapered
overburden, stepped door curbs and eight edge outlets; it installs nothing.
"""
from pathlib import Path
import heapq,json,hashlib,math,os
import numpy as np
from PIL import Image,ImageDraw

R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());out=R/'art/data/orison_roof_drainage';out.mkdir(parents=True,exist_ok=True)
layout=json.loads((R/'game/data/orison_v2_blockout.json').read_bytes())
source=json.loads((R/'art/data/orison_v2/roof_source.json').read_bytes())['records']
decks=[r for r in source['spaces'] if r['id'].startswith('ROOF_DECK_')]
cores=[r for r in source['spaces'] if r['id'].endswith('_CORE')]
datum=source['levels'][0]['y'];thickness=layout['dimensions']['slab_thickness']
holes=[r for r in layout['slab_openings'] if r['surface']=='Floor' and r['space'] in {d['id'] for d in decks}]
outlets=json.loads((out/'source_plan.json').read_bytes())['outlets']
xs=sorted({round(v,6) for v in [-15.65,15.65]+[i*.5 for i in range(-31,32)]+[v for d in decks for v in [d['rect'][0],d['rect'][2]]]+[s['point'][0] for s in outlets]+[v for h in holes for v in [h['rect'][0],h['rect'][2]]]+[-2.27,5.47,9.43,13.27]})
zs=sorted({round(v,6) for v in [-12.35,11.65]+[i*.5 for i in range(-24,24)]+[v for d in decks for v in [d['rect'][1],d['rect'][3]]]+[s['point'][1] for s in outlets]+[v for h in holes for v in [h['rect'][1],h['rect'][3]]]+[-3.92,3.92,.23,10.27]})
blocked=[[-2.27,-3.92,5.47,3.92],[9.43,.23,13.27,10.27]]+[h['rect'] for h in holes]
curb_rects={}
if True:
 for door in source['doors']:
  x,z=door['center'];curb_rects[door['id']]=[x-.35,z-door['width']/2,x+.35,z+door['width']/2]
 blocked+=list(curb_rects.values())
 xs=sorted(set(xs)|{round(v,6) for r in curb_rects.values() for v in [r[0],r[2]]})
 zs=sorted(set(zs)|{round(v,6) for r in curb_rects.values() for v in [r[1],r[3]]})
plant_reservations=[]
if True:
 for anchor in layout['anchors']:
  if 'ROOF_VENT_FAN_' not in anchor['id']:continue
  x,_,z=anchor['position'];plant_reservations.append({'id':anchor['id'],'rect':[x-.36,z-.36,x+.36,z+.36],'kind':'original 720 mm square curb and fitted extension footprint'})
 for fixture in layout['fixtures']:
  if fixture.get('fabrication')!='house_tank' or fixture.get('fabrication_part')!='support':continue
  x,_,z=fixture['position'];sx,_,sz=fixture['size'];plant_reservations.append({'id':fixture['id'],'rect':[x-sx/2,z-sz/2,x+sx/2,z+sz/2],'kind':'retained physical post reservation, within new stand-off weather boot; native bevel is not labelled an exact rectangular solid'})
 blocked += [q['rect'] for q in plant_reservations]
 xs=sorted(set(xs)|{round(v,6) for q in plant_reservations for v in [q['rect'][0],q['rect'][2]]})
 zs=sorted(set(zs)|{round(v,6) for q in plant_reservations for v in [q['rect'][1],q['rect'][3]]})
field_bounds=None
if True:
 half=next(f for f in source['fixtures'] if f['id']=='ROOF_PARAPET_WEST')['size'][0]/2
 field_bounds=[min(d['rect'][0] for d in decks)+half,min(d['rect'][1] for d in decks)+half,max(d['rect'][2] for d in decks)-half,max(d['rect'][3] for d in decks)-half]
 for outlet in outlets:
  outlet['point'][0 if outlet['side'] in ['west','east'] else 1]=field_bounds[{'west':0,'south':1,'east':2,'north':3}[outlet['side']]]
 xs=sorted(set(xs)|{field_bounds[0],field_bounds[2]})
 zs=sorted(set(zs)|{field_bounds[1],field_bounds[3]})
def contains(rect,x,z,strict=False):
 a,b,c,d=rect
 return a+1e-8<x<c-1e-8 and b+1e-8<z<d-1e-8 if strict else a-1e-8<=x<=c+1e-8 and b-1e-8<=z<=d+1e-8
def active(x,z):return any(contains(d['rect'],x,z) for d in decks) and not any(contains(b,x,z,True) for b in blocked) and (field_bounds is None or contains(field_bounds,x,z))
shape=(len(xs),len(zs));valid=np.array([[active(x,z) for z in zs] for x in xs]);distance=np.full(shape,np.inf);previous=np.full(shape+(2,),-1,dtype=np.int32);terminal=np.full(shape,-1,dtype=np.int32)
queue=[]
for k,drain in enumerate(outlets):
 i=xs.index(drain['point'][0]);j=zs.index(drain['point'][1]);assert valid[i,j];distance[i,j]=0.;terminal[i,j]=k;heapq.heappush(queue,(0.,i,j))
while queue:
 d,i,j=heapq.heappop(queue)
 if d!=distance[i,j]:continue
 for a,b in [(i-1,j),(i+1,j),(i,j-1),(i,j+1)]:
  if not (0<=a<len(xs) and 0<=b<len(zs)) or not valid[a,b] or not active((xs[i]+xs[a])/2,(zs[j]+zs[b])/2):continue
  candidate=d+abs(xs[a]-xs[i])+abs(zs[b]-zs[j])
  if candidate<distance[a,b]-1e-10:
   distance[a,b]=candidate;previous[a,b]=[i,j];terminal[a,b]=terminal[i,j];heapq.heappush(queue,(candidate,a,b))
assert np.isfinite(distance[valid]).all(),'A physical roof field is isolated from every outlet'
toe=.006;membrane=.004;fall=.01
height=datum+toe+membrane+fall*distance
paths=[]
for i,j in zip(*np.where(valid)):
 if distance[i,j]==0:continue
 a,b=previous[i,j];assert a>=0 and b>=0 and height[a,b]<height[i,j]-1e-9
 paths.append({'point':[xs[i],float(height[i,j]),zs[j]],'toward':[xs[a],float(height[a,b]),zs[b]],'outlet':outlets[terminal[i,j]]['id'],'fall':fall})
# These are candidate fitted door curbs, not modifications to canonical doors.
def sample(x,z):
 indices=[(i,j) for i in range(len(xs)) for j in range(len(zs)) if valid[i,j]]
 i,j=min(indices,key=lambda p:abs(xs[p[0]]-x)+abs(zs[p[1]]-z))
 return float(height[i,j]),[xs[i],zs[j]]
doors=[]
for row in source['doors']:
 x,z=row['center'];sill,at=sample(x-.08,z)
 # Whole threshold stock stays level at the highest field contact across its
 # 1.1 m opening. A 5 mm weather rise remains below the original leaf's gap.
 if row['id'] in curb_rects:
  ca,cb,cc,cd=curb_rects[row['id']]
  samples=[float(height[i,j]) for i in range(len(xs)) for j in range(len(zs)) if valid[i,j] and contains(curb_rects[row['id']],xs[i],zs[j]) and (abs(xs[i]-ca)<1e-8 or abs(zs[j]-cb)<1e-8 or abs(zs[j]-cd)<1e-8)]
 else:samples=[sample(x-.08,z+delta)[0] for delta in [-row['width']/2,0,row['width']/2]]
 curb=max(samples)+.005
 doors.append({'id':row['id'],'source_record':row,'candidate_curb_top':curb,'candidate_mount_offset':curb-datum,'curb_rect':curb_rects.get(row['id']),'field_samples':samples,'nearest_routing_point':at,'interior_step':curb-datum,'clear_height_preserved':row['height']})
fan_rows=[]
for h in holes:
 a,b,c,d=h['rect'];y,at=sample((a+c)/2,(b+d)/2)
 fan_rows.append({'id':h['id'],'field_top':y,'retained_curb_top':datum+.16,'residual_curb_height':datum+.16-y,'routing_point':at})
data={'evidence_class':'INERT','classification':'ADAPTATION','status':'SOURCE-GENERATED CONSTRUCTION; INDEPENDENT VALIDATION REQUIRED','datum':datum,'retained_structural_thickness':thickness,'overburden_toe':toe,'membrane_thickness':membrane,'fall':fall,'outlets':outlets,'roof_field_bounds':field_bounds,'blocked_routing_rectangles':blocked,'grid_x':xs,'grid_z':zs,'valid_nodes':int(valid.sum()),'maximum_added_height':float(height[valid].max()-datum),'downhill_edges':paths,'doors':doors,'fan_curbs':fan_rows,'source_bindings':{p:hashlib.sha256((R/p).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in ['game/data/orison_v2_blockout.json','art/data/orison_v2/roof_source.json']},'open_work':['native geometry and closed volume','fitted raised door curbs and full moving-leaf clearance','actual parapet ports and weather linings','retained slab and support contacts','sealed fan/tank/plant interfaces','downstream leaders and property connection','production walking and source-bound candidate checks']}
data['source_bindings'].update({p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [out/'source_plan.json',Path(__file__)]})
data['plant_interface_reservations']=plant_reservations
(out/'roof_grade.json').write_text(json.dumps(data,indent=2)+'\n',newline='\n')
print('SOURCE ROOF GRADE',data['valid_nodes'],'nodes;',len(outlets),'outlets')
