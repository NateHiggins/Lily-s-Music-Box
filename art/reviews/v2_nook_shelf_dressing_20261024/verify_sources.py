"""INERT packet/source controls; no qualification grant."""
from pathlib import Path
import gzip,hashlib,json
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[2]
known={}
for p in OUT.rglob('*.gz'):
 raw=gzip.decompress(p.read_bytes());known.setdefault(hashlib.sha256(raw).hexdigest(),[]).append(p.relative_to(OUT).as_posix())
checks=[]
for p in sorted(OUT.glob('*.log.receipt.json')):
 r=json.loads(p.read_text());source=r['source'];matches=known.get(source['test_sha256'],[]).copy()
 raw=(ROOT/source['test_path']).read_bytes()
 if hashlib.sha256(raw).hexdigest()==source['test_sha256']:matches.append(source['test_path'])
 assert matches,p
 checks.append(dict(receipt=p.name,source_matches=matches,execution=r['execution'],stderr_sha256=r['log']['stderr_sha256']))
for r in json.loads((OUT/'source_final_v2/sources.json').read_text())['files']:
 raw=gzip.decompress((OUT/'source_final_v2'/(r['path'].replace('/','__')+'.gz')).read_bytes())
 assert hashlib.sha256(raw).hexdigest()==r['raw_sha256'],r['path']
 assert hashlib.sha256((ROOT/r['path']).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==r['lf_sha256'],r['path']
controls=json.loads((OUT/'source_controls.json').read_text())
for r in controls['protected']:
 raw=(ROOT/r['path']).read_bytes()
 if r['hash_mode']=='LF-normalized':raw=raw.replace(b'\r\n',b'\n')
 assert hashlib.sha256(raw).hexdigest()==r['sha256'],r['path']
assert (ROOT/'tools/orison_spatial_dependency_manifest.json').read_bytes()==gzip.decompress((OUT/'source_before/tools__orison_spatial_dependency_manifest.json.gz').read_bytes())
(OUT/'source_checks.json').write_text(json.dumps(dict(evidence_class='INERT',scope='Top-level raw sources and final LF sources match; not every unrelated dirty input is reconstructed.',checks=checks,protected_unchanged=17,shared_manifest_unchanged=True),indent=2)+'\n',encoding='utf-8',newline='\n')
print(len(checks),'executed sources match; final LF inputs,17 protected paths and shared manifest match')
