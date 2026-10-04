"""Reconcile only the front-paving bindings after the two roof receiver cuts.

All original paving masks, full extent and source grade are retained. Ground
construction reads the separately qualified receiver bedding/air reservations.
"""
from pathlib import Path
import json,hashlib
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file())
BASE_MASK_HASH='51ab4e3caf2e10944cb19a46f55c7cdc0ca9dcab41b35b132101cf215ab3be26'
BASE_ENVELOPE=[-25.5, -16.605, 20.299999999999997, -11.650000000000002]
BASE_Y=[-0.16, 0.0]
BASE_VOLUME=29.04393082747179
P=R/'art/data/orison_ground/retained_grade_source.json'
F=R/'art/blender/front_pavement_construction.json'
plan=json.loads(P.read_bytes());front=json.loads(F.read_bytes())
allowed={'art/blender/front_pavement.blend','art/blender/front_pavement_construction.json','game/assets/props/front_pavement.glb'}
def digest(path):
 raw=path.read_bytes()
 return hashlib.sha256(raw if path.suffix in ['.blend','.glb'] else raw.replace(b'\r\n',b'\n')).hexdigest()
for relative,expected in plan['bindings'].items():
 if relative not in allowed:assert digest(R/relative)==expected,relative
base_masks=[q for q in front['masks'] if q.get('kind')!='source_bound_receiver_port']
assert hashlib.sha256(json.dumps(base_masks,sort_keys=True,separators=(',',':')).encode()).hexdigest()==BASE_MASK_HASH
ports=[q for q in front['masks'] if q.get('kind')=='source_bound_receiver_port']
assert {q['owner'] for q in ports}=={'RoofCollector/S_W/GradeBed','RoofCollector/S_E/GradeBed'}
assert front['envelope']==BASE_ENVELOPE and front['y']==BASE_Y
assert json.loads((R/'art/data/orison_roof_drainage/source_plan.json').read_bytes())['front_property_z']==front['envelope'][1]
area=sum((q['bounds'][2]-q['bounds'][0])*(q['bounds'][3]-q['bounds'][1]) for q in ports)
assert abs(front['volume_m3']-(BASE_VOLUME-area*(BASE_Y[1]-BASE_Y[0])))<.000005
assert front['closed_source_non_manifold_edges']==0
assert digest(R/'game/assets/props/front_pavement.glb')==front['asset_sha256']
before_masks=hashlib.sha256(json.dumps({key:plan[key] for key in ['retained_solids','occupation_reservations','surface_exclusions']},sort_keys=True,separators=(',',':')).encode()).hexdigest()
plan['roof_drainage_reconciliation']={'evidence_class':'INERT','method':'Only front-paving bindings changed after two source-owned receiver cuts. All original paving masks, envelope, grade and the classified ground mask map remain unchanged; the ground builder adds separate qualified roof-drainage reservations.','retained_paving_masks_sha256':BASE_MASK_HASH,'retained_ground_masks_sha256':before_masks,'source_receiver_ports':[q['owner'] for q in ports]}
for relative in allowed:plan['bindings'][relative]=digest(R/relative)
P.write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8',newline='\n')
# Existing foundations consume this map's geometric masks. Their geometry is
# unchanged because the complete classified mask map is unchanged; replay
# only that input binding, while verifying every other source dependency.
foundation_path=R/'art/blender/city_foundations_construction.json'
foundation=json.loads(foundation_path.read_bytes())
for relative,expected in foundation['bindings'].items():
 if relative!='art/data/orison_ground/retained_grade_source.json':assert digest(R/relative)==expected,relative
foundation['bindings']['art/data/orison_ground/retained_grade_source.json']=digest(P)
foundation_path.write_text(json.dumps(foundation,indent=2)+'\n',encoding='utf-8',newline='\n')
(R/'game/tests/fixtures/orison_city_foundations_construction.json').write_bytes(foundation_path.read_bytes())
print('Roof drainage ground reconciliation:',len(base_masks),'retained paving masks;',len(ports),'new ports; classified ground masks unchanged')
