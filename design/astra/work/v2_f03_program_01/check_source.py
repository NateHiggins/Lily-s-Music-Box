"""Independent F03 source geometry checks. No Godot or physics simulation."""
import itertools
import json
from pathlib import Path
import subprocess
import sys
import hashlib

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).parent
BASE = '7e8377e7441e1e1c86cd73e67458fe5d2befd6d5'
layout = json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
old = json.loads(subprocess.check_output(['git','show',BASE+':game/data/orison_v2_blockout.json'],cwd=ROOT))
additions = json.loads((OUT/'additions.json').read_text())
expected = json.loads(json.dumps(old))
for table, records in additions.items():
    expected[table] += records
assert expected == layout, 'Unrelated geometry changed'
indexed = {}
for table, records in layout.items():
    if isinstance(records,list):
        for record in records:
            if isinstance(record,dict) and 'id' in record:
                assert record['id'] not in indexed, record['id']
                indexed[record['id']] = record
spaces = [s for s in layout['spaces'] if s['level']=='F03']
for a,b in itertools.combinations(spaces,2):
    if a.get('open_shell') or b.get('open_shell'):
        continue
    ar,br = a['rect'],b['rect']
    area = max(0,min(ar[2],br[2])-max(ar[0],br[0])) * max(0,min(ar[3],br[3])-max(ar[1],br[1]))
    assert area < .0001, (a['id'],b['id'],area)

def boundary(a,b):
    for fixed,other,axis in [(0,2,'z'),(2,0,'z'),(1,3,'x'),(3,1,'x')]:
        if abs(a[fixed]-b[other]) < .0001:
            low,high = (1,3) if axis=='z' else (0,2)
            start,finish = max(a[low],b[low]), min(a[high],b[high])
            if finish>start:
                return axis,a[fixed],start,finish
    raise AssertionError(('No shared boundary',a,b))

adjacency = {s['id']:set() for s in spaces}
for record in additions['doors']+additions['openings']:
    a,b = [indexed[k] for k in record['connects']]
    axis,fixed,start,finish = boundary(a['rect'],b['rect'])
    coordinate = record['center'][0 if axis=='z' else 1]
    along = record['center'][1 if axis=='z' else 0]
    assert abs(fixed-coordinate)<.0001, record['id']
    assert along-record['width']/2 >= start-.0001 and along+record['width']/2 <= finish+.0001, record['id']
    assert record.get('axis',axis)==axis
    adjacency[a['id']].add(b['id']); adjacency[b['id']].add(a['id'])

def reachable(start,blocked=()):
    seen={start}; todo=[start]
    while todo:
        for target in adjacency[todo.pop()]-seen-set(blocked):
            seen.add(target); todo.append(target)
    return seen

assert 'F03_B_MAIN' in reachable('F03_PUBLIC_CORE')
assert 'F03_SERVICE_CORE' in reachable('F03_PUBLIC_CORE', [s['id'] for s in spaces if s['id'].startswith('F03_B_')])
assert 'F03_B_KITCHEN' in reachable('F03_SERVICE_CORE',['F03_B_ALCOVE','F03_B_BATH','F03_B_MAIN'])
assert {'F03_B_BATH','F03_B_KITCHEN'} <= reachable('F03_B_MAIN',['F03_B_ALCOVE'])
for station in additions['capsule_stations']:
    x,y,z=station['position']
    assert any(s['rect'][0] <= x <= s['rect'][2] and s['rect'][1] <= z <= s['rect'][3] for s in spaces),station['id']
    floors = [s for s in spaces if not s.get('no_floor',False)] + [p for p in layout['platforms'] if p['level']=='F03']
    assert any(f['rect'][0]+.33 <= x <= f['rect'][2]-.33 and f['rect'][1]+.33 <= z <= f['rect'][3]-.33 for f in floors), ('Unsupported station',station['id'])
    for riser in layout['risers']:
        if not riser.get('solid',True):
            continue
        r=riser['rect']
        dx=max(r[0]-x,0,x-r[2]); dz=max(r[1]-z,0,z-r[3])
        assert dx*dx+dz*dz >= .33**2, (station['id'],riser['id'])
for anchor in additions['anchors']:
    r=indexed[anchor['space']]['rect']; x,_,z=anchor['position']
    assert r[0]<=x<=r[2] and r[1]<=z<=r[3], anchor['id']
for connection in additions['route_edges']+additions['service_connections']:
    assert all(connection[key] in indexed for key in ('from','to'))
    if 'via' in connection: assert connection['via'] in indexed
for ident, minimum in [('F03_B_MAIN',(3.6,5.4)),('F03_B_KITCHEN',(2.4,3.3)),('F03_B_BATH',(1.8,2.4)),('F03_B_ALCOVE',(3.0,3.6))]:
    r=indexed[ident]['rect']; wall=layout['dimensions']['partition_wall']
    actual=sorted([r[2]-r[0]-wall,r[3]-r[1]-wall])
    assert all(a+.0001>=b for a,b in zip(actual,minimum)),(ident,actual)
sys.path.insert(0,'C:/Users/nate_/.cache/orison-source-tools/gdtoolkit')
from gdtoolkit.parser import parser
runtime=ROOT/'game/scripts/building/orison_v2_runtime_root.gd'
parser.parse(runtime.read_text())
parser.parse((ROOT/'game/tests/orison_v2_connected_world_test.gd').read_text())
protected=['game/scripts/building/building_root_selector.gd','game/scripts/building/building_root.gd','game/data/building_layout.json','art/data/building_layout.json']
protected += [f'game/assets/building/floor_{f}.{e}' for f in ['01','02','03','04','05','06','b1'] for e in ['gltf','bin']]
subprocess.run(['git','diff','--exit-code',BASE,'--',*protected],cwd=ROOT,check=True)
receipt={'status':'SOURCE_GEOMETRY_CHECKS_PASS_NATIVE_UNRUN','base_head':BASE,'additions':{k:len(v) for k,v in additions.items()},
    'checks':['original records unchanged','global unique IDs','F03 room rectangles disjoint','apertures on shared boundaries',
              'public and independent service route topology','capsule footprint floor support','station-to-riser clearance','anchor containment','finished-clear room minimum dimensions','protected sources unchanged'],
    'native_godot_started':False,'limits':'Source topology and station clearance are not capsule traversal, service-function proof, furnishing or human acceptance.',
    'files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['game/data/orison_v2_blockout.json','game/scripts/building/orison_v2_runtime_root.gd','game/tests/orison_v2_connected_world_test.gd']}}
(OUT/'source_checks.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(receipt,indent=2))
