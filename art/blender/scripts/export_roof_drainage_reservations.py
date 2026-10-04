"""Qualified source-owned roof drainage construction and bedding reservations.

Bounded envelopes carry actual bedding bottoms; they are not exact hollow
solid subtraction volumes. No hydraulic capacity acceptance.
"""
from pathlib import Path
import json,hashlib
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());D=R/'art/blender';F=json.loads((D/'roof_drainage_receivers_construction.json').read_bytes())
stock={r['name']:r for r in F['closed_stocks']};rows=[]
for bed in F['main_saddle_beds']:
 rows.append({'owner':'RoofCollector/'+bed['id'],'bounds':stock[bed['id']]['bounds'],'kind':'source_bound_saddle_bedding_reservation','note':'Actual saved flat bed underside supplies its soil support datum; this is the bounded bedding envelope, not its hollow solid volume.'})
for trunk in F['trunks']:
 for index,(a,b) in enumerate(zip(trunk['path'],trunk['path'][1:])):
  radius=.195
  # Follow the falling pipe in short bounded steps. A flat reservation for
  # the full 33 m run would cut below its upstream concrete bedding.
  length=sum((b[i]-a[i])**2 for i in range(3))**.5;count=__import__('math').ceil(length/6)
  for step in range(count):
   p=[a[i]+(b[i]-a[i])*step/count for i in range(3)];q=[a[i]+(b[i]-a[i])*(step+1)/count for i in range(3)]
   rows.append({'owner':'RoofCollector/'+trunk['id']+'/Trench'+str(index)+'_'+str(step),'bounds':[min(p[i],q[i])-radius for i in range(3)]+[max(p[i],q[i])+radius for i in range(3)],'kind':'source_bound_collector_service_clearance','note':'Independent 304.8 mm bore with bells and construction clearance; follows the actual fall in <=6 m steps above all actual bedding bottoms.'})
for branch in F['receivers']:
 for index,(a,b) in enumerate(zip(branch['axis'],branch['axis'][1:])):
  radius=.11
  rows.append({'owner':'RoofCollector/'+branch['id']+'/Branch'+str(index),'bounds':[min(a[i],b[i])-radius for i in range(3)]+[max(a[i],b[i])+radius for i in range(3)],'kind':'source_bound_drain_leg_clearance'})
for cleanout in F['cleanouts']:
 points=cleanout['riser_axis'];radius=.18
 rows.append({'owner':'RoofCollector/'+cleanout['id']+'/Riser','bounds':[min(a[i] for a in points)-radius for i in range(3)]+[max(a[i] for a in points)+radius for i in range(3)],'kind':'source_bound_cleanout_clearance'})
ports=[]
for q in F['receivers']+F['cleanouts']:
 bounds=stock[q['bed_owner']]['bounds'];rect=[bounds[0],bounds[2],bounds[3],bounds[5]]
 owner='Ground' if q['id'].startswith('W') else 'FrontPavement' if q['id'].startswith('S_') else 'ServiceAlley'
 row={'owner':'RoofCollector/'+q['id']+'/GradeBed','bounds':bounds,'kind':'source_bound_receiver_bedding_reservation','provider':owner,'rect':rect,'id':q['id']};rows.append(row);ports.append(row)
reservation_path=D/'roof_drainage_reservations.json';reservation={'evidence_class':'INERT','reservations':rows,'grade_ports':ports,'bindings':{p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() if p.suffix=='.blend' else hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [D/'roof_drainage_receivers.blend',D/'roof_drainage_receivers_construction.json',Path(__file__)]}}
reservation_path.write_text(json.dumps(reservation,indent=2)+'\n',newline='\n')
