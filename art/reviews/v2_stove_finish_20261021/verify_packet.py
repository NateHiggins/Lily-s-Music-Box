"""Read-only independent checks of the original executed installation contract."""
import gzip,hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools'))
from run_receipt import runtime_inputs_sha256
from v2_surface_evidence import inputs as surface_inputs

def verify():
    packet=Path(__file__).resolve().parent
    contract=json.loads((packet/'world2/runtime_contract.json').read_bytes())
    wrapper=json.loads((packet/'runs/world2.log.receipt.json').read_bytes())
    assert contract['schema_version']==2 and contract['evidence_kind']=='runtime_contract'
    assert contract['selector']=='v2' and contract['production_runtime'] is True
    assert contract['execution']['completed'] and contract['execution']['exit_code']==0 and not contract['execution']['timed_out']
    assert wrapper['execution']['completed'] and wrapper['execution']['exit_code']==0 and not wrapper['execution']['timed_out']
    assert wrapper['log']['script_error_count']==0
    assert contract['failures']==0 and all(r['ok'] for r in contract['checks'])
    assert contract['source']['runtime_inputs_sha256']==runtime_inputs_sha256(ROOT)
    assert contract['source']['surface_inputs_sha256']==surface_inputs(ROOT)['sha256']
    for relative,expected in contract['source']['test_dependencies'].items():
        assert hashlib.sha256((ROOT/relative).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==expected,relative
    for kind in ['stdout','stderr']:
        raw=gzip.decompress((packet/('runs/world2.'+('log' if kind=='stdout' else 'stderr')+'.gz')).read_bytes())
        assert hashlib.sha256(raw).hexdigest()==wrapper['log'][kind+'_sha256']
    c=contract['contracts']
    assert all(v['executed'] and v['status']=='PASS' for v in c.values())
    assert c['c_stove_installation']['furnished_room_hands']==5
    assert c['c_stove_installation']['bore_rays']==25 and c['c_stove_installation']['vertical_airway_rays']==9
    assert len(c['c_stove_installation']['release_observations'])==5
    for row in c['c_stove_installation']['release_observations']:
        assert not row['held'] and 0<=row['pose']<=1
        assert row['release_tween_replaced'] or abs(row['pose'])<.00001
    assert c['flue_topology']['nodes']==24 and len(set(c['flue_topology']['observed_nodes']))==24
    f=c['c_stove_surfaces']
    assert f['parts']==4 and len(f['textures'])==12
    for name,row in f['textures'].items():
        assert row['mips'] and row['levels']>0
        if 'stove_clinker' in name or 'stove_lime' in name:assert (row['width'],row['height'],row['levels'])==(1024,1024,10)
    s=c['soil_foundations']
    assert (s['fixed_stations'],s['terrain_contacts'],s['embedded_stations'],s['original_discovery_reproduced'],s['source_qualified_roof_contacts'])==(48,43,2,45,3)
    result={'evidence_class':'INERT','scope':'Independent byte/source consistency check of the original executed scoped contract; no new runtime or human acceptance.',
        'checks':len(contract['checks']),'test_dependencies':len(contract['source']['test_dependencies']),
        'runtime_inputs_sha256':contract['source']['runtime_inputs_sha256'],'surface_inputs_sha256':contract['source']['surface_inputs_sha256'],
        'contract_sha256':hashlib.sha256((packet/'world2/runtime_contract.json').read_bytes()).hexdigest(),
        'original_wrapper_sha256':hashlib.sha256((packet/'runs/world2.log.receipt.json').read_bytes()).hexdigest(),
        'all_current':True}
    (packet/'publication_check.json').write_text(json.dumps(result,indent=2)+'\n',newline='\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':verify()
