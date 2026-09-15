"""Verify final native receiver evidence and freeze its source hashes."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4];OUT=Path(__file__).resolve().parent;E=ROOT/'design/astra/evidence/v2_upper_radios_01'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
 runs=[]
 for name,count in [('apartment_batch_final',18954),('upper_approaches',1001)]:
  p=OUT/(name+'.log');err=OUT/(name+'.log.stderr');text=p.read_text()
  assert not err.read_text().strip() and 'SCRIPT ERROR' not in text
  assert re.search(r'\b'+str(count)+r' checks, 0 failures\b',text)
  runs.append(dict(name=name,checks=count,stdout_sha256=sha(p),stderr_sha256=sha(err)))
 cap=json.loads((E/'radios_04/capture_receipt.json').read_text(encoding='utf-8-sig'))
 assert cap['status']=='PASS' and cap['actual_frames']==12 and not (E/'capture_clean.log.stderr').read_text().strip()
 for f in cap['files']:assert sha(E/'radios_04'/f['name'])==f['sha256']
 files=['game/data/orison_v2_blockout.json','game/data/orison_v2/domestic_furniture.json','game/data/orison_v2/domestic_radios.json','game/scripts/building/orison_v2_radio_prop.gd','game/scripts/building/orison_v2_radios.gd','game/tests/orison_v2_apartment_batch_test.gd','game/tests/orison_v2_upper_kitchen_test.gd','game/tests/orison_v2_upper_radios_shot.gd','game/tests/OrisonV2UpperRadiosShot.tscn','game/tests/data/v2_upper_radio_probes.json','design/astra/work/v2_upper_radios_01/build.py','design/astra/work/v2_upper_radios_01/source_checks.json','design/astra/work/v2_storage_tables_boards_batch_01/build.py']
 receipt=dict(status='SCOPED_RUNTIME_PASS',base='b3aae2a',added_receivers=6,household_receiver_total=12,added_tables=6,furniture_total=175,added_anchors=12,route_destinations=151,route_points=26686,checks=sum(r['checks'] for r in runs),runs=runs,final_captures=12,source_sha256={p:sha(ROOT/p) for p in files},limits='Native local programme murmur and power interaction, not historical broadcast-content completion. No radio persistence added. Prepared source routes, capsules, rays and captures are not full played-route, listening, performance or human art acceptance. V2 incomplete; V1 default; S2J open.')
 (E/'receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode());print(json.dumps(dict(checks=receipt['checks'],captures=12)))
if __name__=='__main__':run()
