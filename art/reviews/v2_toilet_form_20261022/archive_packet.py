"""Archive this repair's diagnostics; never treats wrapper receipts as acceptance."""
from pathlib import Path
import gzip,hashlib,json
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
OWNED=['.gitattributes','DOCS.md','art/blender/scripts/build_operable_water_closet.py','art/blender/scripts/water_closet_form.py','art/blender/scripts/review_operable_water_closet.py','art/blender/bath_water_closet_construction.json','game/assets/props/bath_water_closet.glb.import','game/scripts/building/orison_v2_water_closet.gd','game/scripts/player/constrained_grab.gd','game/scripts/props/shower_curtain_motion.gd','game/tests/toilet_inspection_test.gd','game/tests/direct_manipulation_test.gd','game/tests/orison_v2_4b_door_route_test.gd','game/tests/v2_curtain_gesture_bench.gd','game/tests/V2CurtainGestureBench.tscn','game/tests/v2_curtain_gesture_bench.gd.uid','design/V2_TOILET_FORM_AND_GESTURES_2026-10-22.md']
rows=[]
def archive(path,relative):
 data=path.read_bytes();dest=OUT/'archive'/relative;dest=dest.with_name(dest.name+'.gz');dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(gzip.compress(data,mtime=0))
 rows.append(dict(original=path.relative_to(ROOT).as_posix(),archive=dest.relative_to(OUT).as_posix(),sha256=hashlib.sha256(data).hexdigest(),bytes=len(data)))
for path in OWNED:archive(ROOT/path,'source/'+path)
for path in sorted(OUT.glob('*.log*')):
 if path.is_file():archive(path,'runs/'+path.name)
for path in sorted((ROOT/'tmp').glob('toilet*')):
 if path.is_file() and (path.suffix=='.log' or path.name=='toilet_form_spatial.json'):archive(path,'native_logs/'+path.name)
for path in sorted(OUT.glob('native*/native.json')):archive(path,'native/'+path.parent.name+'/native.json')
for path in sorted((OUT/'rejected_tangents_v1').glob('*')):
 if path.is_file():archive(path,'rejected_tangents_v1/'+path.name)
for directory in ['board','final_static']:
 for path in sorted((OUT/directory).glob('*')):
  if path.is_file():archive(path,directory+'/'+path.name)
for directory in ['curtain_final_v1','world_4b_hardware_final','world_4b_dark_final','world_4b_mask_final','world_4b_reach_final']:
 for path in sorted((OUT/directory).glob('*.json')):archive(path,'diagnostics/'+directory+'/'+path.name)
for path in sorted(OUT.glob('*.cancelled.json')):archive(path,'cancellations/'+path.name)
assets={p:dict(sha256=hashlib.sha256((ROOT/p).read_bytes()).hexdigest(),bytes=(ROOT/p).stat().st_size) for p in ['art/blender/bath_water_closet.blend','game/assets/props/bath_water_closet.glb']}
(OUT/'packet.json').write_text(json.dumps(dict(evidence_class='INERT',scope='Native form and actual-input diagnostics; no runtime qualification or full-building acceptance.',assets=assets,records=rows),indent=2)+'\n',encoding='utf-8',newline='\n')
print('Archived',len(rows),'exact records;',sum(r['bytes'] for r in rows),'original bytes')
