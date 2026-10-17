"""Read-only qualification of committed archives; original tmp paths are not needed."""
import hashlib,json,sys,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4];PACKET=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools'))
from audit_orison_v2_completeness import runtime_inputs_sha256,runtime_receipt_errors
from spatial_access_evidence import validate as validate_access
from v2_surface_evidence import inputs,qualify as qualify_surface,PACKET as SURFACE

def qualify():
    runtime=runtime_inputs_sha256(ROOT);surface=inputs(ROOT)['sha256'];errors=[];results=[]
    cases=[('surface',SURFACE,'surface_checkpoint.log',SURFACE,'runtime_contract.json'),
           ('front',PACKET/'current_front','front_checkpoint.log',PACKET/'current_front','runtime_contract.json')]
    cases.extend((tag,PACKET,tag+'.log',PACKET/tag,'runtime_authority_receipt.json' if tag=='firstslice' else 'runtime_contract.json') for tag in ['firstslice','save','apartments','remaining','dumbwaiter','roof'])
    for tag,logs,stem,directory,filename in cases:
        local=[]
        try:
            receipt=json.loads((directory/filename).read_text());wrapper=json.loads((logs/(stem+'.receipt.json')).read_text())
            for kind,data in [('test',receipt),('wrapper',wrapper)]:
                execution=data['execution']
                if execution.get('completed') is not True or type(execution.get('exit_code')) is not int or execution['exit_code']!=0 or execution.get('timed_out') is not False:local.append(kind+' execution did not pass')
                if data['source'].get('runtime_inputs_sha256')!=runtime:local.append(kind+' runtime input binding is stale')
            if receipt.get('schema_version')!=2 or receipt.get('evidence_kind')!='runtime_contract' or receipt.get('selector')!='v2' or receipt.get('production_runtime') is not True:local.append('invalid production V2 contract identity')
            if receipt.get('failures'):local.append('recorded test failures')
            if wrapper['log'].get('script_error_count') or wrapper['log'].get('fail_count'):local.append('wrapper recorded failures/script errors')
            for kind,suffix in [('stdout',''),('stderr','.stderr')]:
                if hashlib.sha256((logs/(stem+suffix)).read_bytes()).hexdigest()!=wrapper['log'][kind+'_sha256']:local.append(kind+' log bytes changed')
            if tag=='surface':local.extend(qualify_surface(SURFACE,ROOT)['defects'])
            elif tag=='front':
                report=json.loads(subprocess.check_output([sys.executable,str(PACKET/'qualify_front.py')],text=True,cwd=ROOT));local.extend(report['errors'])
            elif tag in ['firstslice','dumbwaiter','roof']:
                local.extend(runtime_receipt_errors(receipt,ROOT))
                if tag!='firstslice':
                    c=receipt['contracts'].get('physical_interaction',{})
                    if c.get('executed') is not True or c.get('status')!='PASS':local.append('physical interaction not passed')
                    bindings=receipt['source'].get('test_dependencies',{})
                    if not bindings:local.append('missing test dependencies')
                    for path,digest in bindings.items():
                        if hashlib.sha256((ROOT/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=digest:local.append('stale dependency '+path)
            elif tag in ['apartments','remaining']:local.extend(validate_access(receipt,ROOT,runtime,surface))
            elif tag=='save':
                for name in ['production_composition','direct_manipulation','save_reconstruction']:
                    c=receipt['contracts'].get(name,{})
                    if c.get('executed') is not True or c.get('status')!='PASS':local.append('unexecuted '+name)
                bindings=receipt['source'].get('test_sources',{})
                if len(bindings)!=3:local.append('missing inherited test sources')
                for path,digest in bindings.items():
                    if hashlib.sha256((ROOT/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=digest:local.append('stale dependency '+path)
                observations=receipt.get('observations',[])
                if not observations or any(row.get('ok') is not True for row in observations):local.append('failed/missing observations')
            results.append(dict(suite=tag,result='FAIL' if local else 'PASS',scope=receipt['scope'],errors=local))
        except (OSError,KeyError,ValueError,TypeError,subprocess.CalledProcessError) as exc:local.append(str(exc));results.append(dict(suite=tag,result='FAIL',errors=local))
        errors.extend(tag+': '+error for error in local)
    return dict(evidence_class='INERT',result='FAIL' if errors else 'PASS',runtime_inputs_sha256=runtime,surface_inputs_sha256=surface,scope='Independent archive/source checks for eight separate executed scopes; no new ledger, artistic, performance or human acceptance.',runs=results,errors=errors)
if __name__=='__main__':
    report=qualify();print(json.dumps(report,indent=2));raise SystemExit(bool(report['errors']))
