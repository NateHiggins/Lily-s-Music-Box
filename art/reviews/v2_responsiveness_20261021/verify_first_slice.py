"""Check an original first-slice packet against current authority and raw logs."""
from pathlib import Path
import argparse,gzip,hashlib,json,sys
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools'))
from audit_orison_v2_completeness import runtime_receipt_errors

def verify(packet):
    contract=json.loads((packet/'runtime_authority_receipt.json').read_text())
    run=json.loads((packet/'suite_run.receipt.json').read_text())
    problems=runtime_receipt_errors(contract,ROOT)
    if run.get('evidence_kind')!='suite_run' or run.get('scene')!='res://tests/orison_v2_first_slice_contract_test.tscn' or not run.get('windowed'):
        problems.append('wrong wrapper identity')
    e=run.get('execution',{})
    if e.get('completed') is not True or e.get('exit_code')!=0 or e.get('timed_out') is not False:
        problems.append('wrapper not completed successfully')
    for key in ['test_path','test_sha256','runtime_inputs_sha256']:
        if not contract.get('source',{}).get(key) or contract['source'][key]!=run.get('source',{}).get(key):
            problems.append('wrapper/source mismatch: '+key)
    log=run.get('log',{})
    if log.get('script_error_count')!=0 or log.get('fail_count')!=0 or log.get('stale_cache_suspect'):
        problems.append('wrapper reports errors or stale cache')
    for channel in ['stdout','stderr']:
        raw=gzip.decompress((packet/f'suite_run.{channel}.log.gz').read_bytes())
        if hashlib.sha256(raw).hexdigest()!=log.get(channel+'_sha256'):problems.append('raw log hash mismatch: '+channel)
        if any(line.lstrip().startswith(('ERROR:','SCRIPT ERROR:')) for line in raw.decode('utf8','replace').splitlines()):
            problems.append('Godot errors in '+channel)
    if problems:raise ValueError('; '.join(problems))
    return {'evidence_class':'INERT','result':'PASS','checks':len(contract['checks']),'scope':contract['scope']}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--packet',type=Path,default=ROOT/'art/renders/orison_v2/first_slice_contract_20261011')
    print(json.dumps(verify(parser.parse_args().packet),indent=2))
