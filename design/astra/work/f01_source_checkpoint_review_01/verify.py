from pathlib import Path
import hashlib,json,subprocess,time

ROOT=Path('C:/PleaseRemainOnTheLine-astra')
HERE=Path(__file__).resolve().parent
PACKAGE=ROOT/'design/astra/work/f01_source_checkpoint_01'
REF='c34ad283df148496fbd98e68638470835c930c5c'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args,input=None):return subprocess.check_output(['git','-C',str(ROOT),*args],input=input,stderr=subprocess.PIPE)

start=time.monotonic()
selection=json.loads((PACKAGE/'selection.json').read_text())
staging=json.loads((PACKAGE/'staging.json').read_text())
paths=[r['path'] for r in staging['paths']]
actual=git('diff','--cached','--name-only','-z').decode().rstrip('\0').split('\0')
assert len(paths)==len(set(paths))==154 and set(actual)==set(paths)
nul=(PACKAGE/'paths.nul').read_bytes().decode().rstrip('\0').split('\0')
assert set(nul)==set(paths) and len(nul)==154
assert set(paths)-set(selection['selected'])=={'design/astra/work/f01_source_checkpoint_01/selection.json','design/astra/work/f01_source_checkpoint_01/paths.nul'}
assert git('rev-parse','HEAD').decode().strip()==selection['base_head']==staging['base_head']
assert not any(p.startswith('game/') for p in paths)
sources=[p for p in paths if p.startswith(('tools/','art/'))]
assert set(sources)==set(selection['live_sources']) and len(sources)==10
assert not any('f01_provider_parity_01' in p or 'v2_terminal' in p or 'operator_revision' in p for p in paths)
raw={}
for row in staging['paths']:
    p=row['path'];value=sha(ROOT/p);assert value==row['raw_sha256'],p
    if p in selection['selected']:assert value==selection['selected'][p],p
    raw[p]=value
clean=git('hash-object','--stdin-paths',input=('\n'.join(paths)+'\n').encode()).decode().splitlines()
assert len(clean)==154
for row,value in zip(staging['paths'],clean):
    assert value==row['staged_blob'],row['path']
index={}
for row in git('ls-files','--stage','-z','--',*paths).decode().rstrip('\0').split('\0'):
    info,p=row.split('\t',1);mode,blob,stage=info.split();assert stage=='0';index[p]=blob
assert len(index)==154
assert all(index[r['path']]==r['staged_blob'] for r in staging['paths'])
source_blobs={}
for p in sources:
    blob=git('rev-parse',REF+':'+p).decode().strip();assert blob==index[p],p;source_blobs[p]=blob
protected={}
for p,row in selection['protected_17'].items():
    value=sha(ROOT/p);assert value==row['raw_sha256'],p
    values={k:git('rev-parse',ref+':'+p).decode().strip() for k,ref in [('head','HEAD'),('index',''),('c1',REF)]}
    values['working_clean']=git('hash-object','--path='+p,p).decode().strip()
    assert len(set(values.values()))==1 and values['working_clean']==row['working_clean_blob'],p
    protected[p]={'raw_sha256':value,**values}
assert len(protected)==17
result={'status':'CLEAR_EXACT_SOURCE_AND_EVIDENCE_STAGE','head':selection['base_head'],'selected_raw_hashes_verified':152,
    'stage_paths_verified':154,'live_source_paths':10,'game_paths':0,'exact_c1_blobs':source_blobs,'protected_17':protected,
    'selection_sha256':sha(PACKAGE/'selection.json'),'staging_sha256':sha(PACKAGE/'staging.json'),'paths_nul_sha256':sha(PACKAGE/'paths.nul'),
    'verified_staged_raw':raw,'elapsed_seconds':time.monotonic()-start,
    'limits':['No export rerun or reinterpretation. External generated geometry/texture files remain outside Git; selected source-bound receipts bind them.',
        'This verifies the exact current stage, source provenance and protected files, not generic recursive receipt-schema completeness.',
        'Provider and V2 proposals excluded. C1 remains human-pending; no provider/default/selector adoption.']}
(HERE/'review.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'status':result['status'],'staged':154,'source':10,'game':0,'protected':17,'review_sha256':sha(HERE/'review.json')}))
