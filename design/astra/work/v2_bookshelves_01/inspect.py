"""Freeze scoped evidence; reject failed, noisy or incomplete engine runs."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4];OUT=Path(__file__).resolve().parent
E=ROOT/'design/astra/evidence/v2_bookshelves_01'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
 runs=[]
 for name,expected in [('household_state_02',100),('bookshelves_02',118),('apartment_batch',18332)]:
  p=OUT/(name+'.log');err=OUT/(name+'.log.stderr');text=p.read_text()
  assert not err.read_text().strip() and 'SCRIPT ERROR' not in text
  assert re.search(r'\b'+str(expected)+r' checks, 0 failures\b',text),(name,text[-300:])
  runs.append(dict(name=name,checks=expected,stdout_sha256=sha(p),stderr_sha256=sha(err)))
 cap=json.loads((E/'shelves_01/capture_receipt.json').read_text(encoding='utf-8-sig'))
 assert cap['status']=='PASS' and cap['actual_frames']==8 and not (E/'capture.log.stderr').read_text().strip()
 for f in cap['files']:assert sha(E/'shelves_01'/f['name'])==f['sha256']
 paths=['game/data/orison_v2_blockout.json','game/data/orison_v2/bookshelves.json','game/scripts/building/orison_v2_bookshelf.gd','game/scripts/building/orison_v2_bookshelves.gd','game/scripts/building/orison_v2_household_state.gd','game/scripts/building/orison_v2_runtime_root.gd','game/tests/orison_v2_bookshelves_test.gd','game/tests/orison_v2_bookshelves_shot.gd','game/tests/orison_v2_household_state_test.gd','design/astra/work/v2_bookshelves_01/build.py','design/astra/work/v2_bookshelves_01/source_checks.json','design/astra/work/v2_storage_tables_boards_batch_01/build.py']
 receipt=dict(status='SCOPED_RUNTIME_PASS',base='1ddf9d7',added_shelves=8,added_anchors=16,saved_household_records=124,checks=sum(r['checks'] for r in runs),runs=runs,captures=8,source_sha256={p:sha(ROOT/p) for p in paths},limits='Prepared placement/interaction/collision, sorting UI and save reconstruction checks. No full played-route, listening, performance or human art acceptance. Dark book spines, especially Sacha, remain lighting review. V2 incomplete; V1 default; S2J open.')
 (E/'receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode());print(json.dumps(dict(checks=receipt['checks'],captures=8)))
if __name__=='__main__':run()
