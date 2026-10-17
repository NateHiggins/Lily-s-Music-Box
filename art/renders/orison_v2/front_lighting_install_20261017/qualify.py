"""Independently check this scoped lighting contract; grants no ledger promotion."""
import hashlib
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[4]
PACKET=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools'))
from audit_orison_v2_completeness import runtime_inputs_sha256

def qualify():
    receipt=json.loads((PACKET/'runtime_contract.json').read_text())
    wrapper=json.loads((PACKET/'polished.log.receipt.json').read_text())
    errors=[]
    if (receipt.get('schema_version'),receipt.get('evidence_kind'),receipt.get('selector'),receipt.get('production_runtime'))!=(2,'runtime_contract','v2',True):
        errors.append('invalid contract identity')
    for name,data in [('test',receipt),('wrapper',wrapper)]:
        execution=data.get('execution',{})
        if execution.get('completed') is not True or type(execution.get('exit_code')) is not int or execution['exit_code']!=0 or execution.get('timed_out') is not False:
            errors.append(name+' did not complete successfully')
    for name in ['production_composition','direct_manipulation','save_reconstruction']:
        contract=receipt.get('contracts',{}).get(name,{})
        if contract.get('executed') is not True or contract.get('status')!='PASS':errors.append('unexecuted '+name)
    source=receipt.get('source',{})
    current=runtime_inputs_sha256(ROOT)
    if source.get('runtime_inputs_sha256')!=current or wrapper.get('source',{}).get('runtime_inputs_sha256')!=current:
        errors.append('runtime inputs are stale')
    expected={'game/tests/'+name for name in ['front_lighting_integration_test.gd','heating_hand_driver.gd','watch_station_hand_test.gd','v2_front_restoration_review.gd']}
    bindings=source.get('test_sources',{})
    if set(bindings)!=expected:errors.append('missing test dependencies')
    for path,digest in bindings.items():
        if path not in expected or hashlib.sha256((ROOT/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=digest:
            errors.append('stale test dependency '+path)
    entry='game/tests/front_lighting_integration_test.gd'
    if source.get('test_path')!=entry or source.get('test_sha256')!=bindings.get(entry):errors.append('root test binding differs')
    observations=receipt.get('observations',[])
    if receipt.get('failures')!=[] or not observations or receipt.get('checks')!=len(observations) or any(row.get('ok') is not True for row in observations):
        errors.append('failed or missing executed observations')
    plan=json.loads((ROOT/'art/data/front_lighting_plan.json').read_text())
    labels=[row.get('label','') for row in observations]
    for switch in plan['switches']:
        for suffix in ['actual pointer grabs toggle','follows constrained mouse motion','second click releases','room circuit follows contact']:
            if labels.count(switch['id']+' '+suffix) not in [2,3]:errors.append('missing switch motion '+switch['id'])
    for fixture in plan['fixtures']:
        for prefix in ['disk preserves fixture contact: ','reconstructed fixture preserves contact: ']:
            if labels.count(prefix+fixture['id'])!=1:errors.append('missing durable fixture '+fixture['id'])
    for kind in ['stdout','stderr']:
        log=PACKET/('polished.log'+('.stderr' if kind=='stderr' else ''))
        if hashlib.sha256(log.read_bytes()).hexdigest()!=wrapper['log'][kind+'_sha256']:errors.append('log bytes changed: '+kind)
    result=dict(evidence_class='INERT',result='FAIL' if errors else 'PASS',checks=receipt.get('checks'),errors=errors,
                scope=receipt['scope'],runtime_contract_sha256=hashlib.sha256((PACKET/'runtime_contract.json').read_bytes()).hexdigest())
    print(json.dumps(result,indent=2))
    return bool(errors)

if __name__=='__main__':sys.exit(qualify())
