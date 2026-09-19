"""Author domestic appliance anchors and conservative closed-body footprints."""
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[4]
BASE='5ecd79c938fbbab8b8143e22204eb9a4527e923a'
path=ROOT/'game/data/orison_v2_blockout.json'
original=subprocess.check_output(['git','show',BASE+':game/data/orison_v2_blockout.json'],cwd=ROOT).decode()
source=json.loads(original)
assert json.loads(path.read_text())==source, 'Refuse unrelated layout edits'
placements=[
    ('F03_3B_KITCHEN_SINK_01','F03_B_KITCHEN',[10.25,0,-5.72],0,[9.9,-6.05,11.05,-5.38],[10.25,0,-6.8]),
    ('F03_3B_STOVE_01','F03_B_KITCHEN',[11.65,0,-5.72],0,[11.29,-6.12,12.01,-5.35],[11.65,0,-6.9]),
    ('F03_3B_FRIDGE_01','F03_B_KITCHEN',[12.45,0,-5.72],0,[12.07,-6.12,12.83,-5.35],[12.45,0,-6.95]),
    ('F03_3B_SINK_01','F03_B_BATH',[15.15,0,-10.32],0,[14.79,-10.65,15.51,-9.99],[15.15,0,-11.2]),
    ('F03_3B_SHOWER_01','F03_B_BATH',[13.55,0,-11.8],3.141592653589793,[13.12,-12.23,13.98,-11.37],[13.55,0,-10.8])]
anchors=[]; footprints=[]; stations=[]
for identity,room,position,yaw,footprint,stance in placements:
    anchors += [dict(id=identity,level='F03',space=room,position=position,yaw=yaw,kind='interaction'),
                dict(id=identity+'_STANCE',level='F03',space=room,position=stance,yaw=yaw+3.141592653589793,kind='clearance')]
    stations.append(dict(id=identity+'_CAPSULE',level='F03',position=[stance[0],.85,stance[2]]))
    footprints.append(dict(id=identity,space=room,position=position,yaw=yaw,closed_footprint=footprint,stance=stance,
        note='Conservative source footprint; native mesh bounds and moving mechanisms require verification.'))
for table,records in [('anchors',anchors),('capsule_stations',stations)]:
    start=original.index('  "'+table+'": ['); end=original.index('\n  ]',start)
    original=original[:end].rstrip()+',\n'+',\n'.join('    '+json.dumps(r,separators=(',',':')) for r in records)+original[end:]
old='"rect":[10.55,-7.8,11.65,-5.5],"height":0.02,"class":"clearance","purpose":"1.10 m cooking work aisle"'
new='"rect":[9.8,-7.5,12.75,-6.35],"height":0.02,"class":"clearance","purpose":"1.15 m clear aisle in front of the appliance run"'
assert old in original
original=original.replace(old,new)
path.write_text(original,encoding='utf-8',newline='\n')
(Path(__file__).parent/'placements.json').write_text(json.dumps(footprints,indent=2)+'\n',encoding='utf-8',newline='\n')
