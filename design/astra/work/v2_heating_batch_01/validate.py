"""Preservation and integrated geometry checks; engine behavior remains pending."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import build as batch

ROOT=batch.ROOT
OUT=batch.OUT
BASE=batch.BASE

def old(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
def sha(path):return hashlib.sha256((ROOT/path).read_bytes()).hexdigest()

def entry(origin,target,low,high):
 near,far=0.,1.
 for i in range(3):
  delta=target[i]-origin[i]
  if abs(delta)<1e-9:
   if not low[i]<=origin[i]<=high[i]:return None
  else:
   values=sorted([(low[i]-origin[i])/delta,(high[i]-origin[i])/delta])
   near=max(near,values[0]);far=min(far,values[1])
   if near>far:return None
 return near

def control_clearance(layout,source,body_front=-.10):
 import math
 anchors={a['id']:a for a in layout['anchors']};checks=[]
 for record in source['installed']:
  a=anchors[record['id']];stance=anchors[record['id'].replace('_01','_STANCE')]['position']
  x,z=stance[0]-a['position'][0],stance[2]-a['position'][2];c,s=math.cos(a['yaw']),math.sin(a['yaw'])
  eye=[c*x-s*z,1.41,s*x+c*z];target=[-.53,.39,-.02]
  hit=entry(eye,target,[-.62,.30,-.12],[-.44,.48,.08]);assert hit is not None
  half=(record['sections']-1)*.092*.5
  for low,high in [([-half-.06,.07,body_front],[half+.06,.81,.12]),([-.715,0,-.055],[-.38,.33,.055])]:
   collision=entry(eye,target,low,high)
   assert collision is None or collision>hit,('handwheel occluded by collision',record['id'])
  checks.append(record['id'])
 return checks

def main():
 layout=batch.load(batch.LAYOUT);prior=json.loads(old(batch.LAYOUT))
 assert layout['anchors'][:len(prior['anchors'])]==prior['anchors']
 stripped=copy.deepcopy(layout);stripped['anchors']=stripped['anchors'][:len(prior['anchors'])]
 assert stripped==prior,'old layout changed'
 source=batch.load(batch.TARGET)
 authored=[r for f in batch.load('game/data/building_layout.json')['floors'] for r in f.get('markers',[]) if r.get('kind')=='radiator']
 assert source['network']==authored and len(authored)==23
 assert len(source['installed'])==6 and len(layout['anchors'])==383
 acoustic={r['id'] for r in batch.load('game/data/acoustic_graph.json')['nodes']}
 assert all(r['id'] in acoustic for r in source['installed'])
 protected=['game/data/building_layout.json','game/data/acoustic_graph.json','game/data/resident_schedules.json',
  'game/data/orison_v2/domestic_furniture.json','game/data/orison_v2/domestic_fittings.json',
  'game/data/orison_v2/domestic_radios.json','game/data/orison_v2/domestic_surface_props.json','game/data/orison_v2/room_lighting.json',
  'game/scripts/props/radiator_prop.gd','game/scripts/props/heat_balance.gd','game/scripts/props/boiler_tend.gd',
  'game/scripts/props/boiler_prop.gd','game/scripts/game/maintenance_inventory.gd','game/project.godot']
 for path in protected:assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==old(path).replace(b'\r\n',b'\n'),path
 controls=control_clearance(layout,source)
 negatives=[]
 for label,position in [('sofa_overlap',[-11.8,.75,-3.15]),('riser_overlap',[-6.2,.75,4.5])]:
  bad=copy.deepcopy(layout);next(a for a in bad['anchors'] if a['id']=='F02_A_RADIATOR_01')['position']=position
  try:batch.geometry(bad)
  except AssertionError:negatives.append(label)
  else:raise AssertionError('accepted bad radiator: '+label)
 # A body enlarged in front of the control must fail the ray ordering guard.
 try:control_clearance(layout,source,body_front=-.4)
 except AssertionError:negatives.append('enlarged_hull_intercepts_control')
 else:raise AssertionError('accepted hull that hides handwheel')
 before={p:sha(p) for p in [batch.LAYOUT,batch.TARGET]}
 batch.build(apply=True)
 assert before=={p:sha(p) for p in before},'regeneration changed bytes'
 results=[]
 for name,script in [('apartment_batches','build'),('apartment_seating_batch','build'),('apartment_lighting_batch','build'),
  ('apartment_doors_batch','check'),('apartment_walls_batch','build'),('surface_props_batch','build'),
  ('storage_tables_boards_batch','build'),('household_radios_batch','build'),('prep_cabinets_batch','build'),
  ('specialist_devices_batch','build'),('projectors_batch','build'),('household_completion','build')]:
  path='design/astra/work/v2_'+name+'_01/'+script+'.py'
  run=subprocess.run([sys.executable,str(ROOT/path)],cwd=ROOT,capture_output=True,text=True)
  results.append(dict(script=path,exit_code=run.returncode,stdout=run.stdout,stderr=run.stderr))
 (OUT/'category_checks.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
 assert all(r['exit_code']==0 for r in results),'category failure; see category_checks.json'
 result=dict(status='SOURCE_PASS_RUNTIME_PENDING',godot='NOT_RUN',base=BASE,sha256=before,protected=protected,
  full_roster=23,installed=6,prior_anchors_preserved=375,control_hull_clearance=controls,negative_controls=negatives,
  regeneration='BYTE_IDENTICAL',categories_passed=len(results),
  limits='No engine execution. Heat allocation, live cold/warm response, physical target rays, acoustic restoration, repair isolation, active-tween teardown and performance are prepared tests, not observed proof.')
 (OUT/'source_validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
 print('PASS: full demand roster, preserved owners, six handwheel hull checks, three negatives and twelve category checks')

if __name__=='__main__':main()
