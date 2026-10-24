"""INERT receipt/source hygiene, retaining failed diagnostic verdicts."""
import gzip, hashlib, json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
PACKETS=[ROOT/'art/reviews/v2_bathroom_moisture_20261024',Path(__file__).resolve().parent]
digest=lambda raw:hashlib.sha256(raw).hexdigest()
archives={}
for packet in PACKETS:
 for path in packet.rglob('*.gz'):
  raw=gzip.decompress(path.read_bytes())
  for data in [raw,raw.replace(b'\r\n',b'\n')]:archives.setdefault(digest(data),[]).append(str(path.relative_to(ROOT)))
checks=[]
for packet in PACKETS:
 for path in sorted(packet.glob('*.receipt.json')):
  receipt=json.loads(path.read_text(encoding='utf-8'));row={'receipt':str(path.relative_to(ROOT)),'execution':receipt['execution'],'script_errors':receipt['log']['script_error_count']}
  for name in ['stdout','stderr']:
   file=Path(receipt['log'][name]);assert file.is_file(),file
   assert digest(file.read_bytes())==receipt['log'][name+'_sha256'],file
  source=receipt['source'];wanted=source.get('test_sha256')
  if wanted:
   matches=archives.get(wanted,[])
   live=ROOT/source['test_path']
   if live.exists() and wanted in [digest(live.read_bytes()),digest(live.read_bytes().replace(b'\r\n',b'\n'))]:matches=matches+[source['test_path']]
   row['test_source_matches']=matches
   if not matches:row['limitation']='Historical diagnostic source not reconstructed; no source-bound qualification claim.'
  else:row['test_source_matches']=None
  checks.append(row)
protected=json.loads((ROOT/'art/reviews/v2_nook_shelf_dressing_20261024/source_controls.json').read_text())['protected']
for row in protected:
 raw=(ROOT/row['path']).read_bytes()
 assert digest(raw if row['hash_mode']=='raw' else raw.replace(b'\r\n',b'\n'))==row['sha256'],row['path']
original=json.loads(gzip.decompress((PACKETS[0]/'source_before/tools__orison_spatial_dependency_manifest.json.gz').read_bytes()))
current=json.loads((ROOT/'tools/orison_spatial_dependency_manifest.json').read_text(encoding='utf-8'))
assert current['records'][:len(original['records'])]==original['records']
result={'evidence_class':'INERT','scope':'Wrapper logs, top-level test source matches, protected paths and preserved manifest records only; no reconstruction of unrelated dirty inputs or runtime_contract.','checks':checks,'protected_unchanged':len(protected),'original_shared_manifest_records_preserved':len(original['records']),'new_own_manifest_records':len(current['records'])-len(original['records'])}
(PACKETS[1]/'source_checks.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print('Receipt log hashes verified:',len(checks),'protected:',len(protected),'own manifest additions:',result['new_own_manifest_records'])
