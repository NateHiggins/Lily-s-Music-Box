"""Prepared matched captures; run only in a clear, authorized native window."""
from pathlib import Path
import argparse,json,os,subprocess,sys,time
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.with_name('f01_provider_execution_07')))
import run as execution

def main(mode):
    sha=execution.sha;read=execution.read;dump=execution.dump
    final=ROOT/'design/astra/evidence/f01_provider_execution_07/05_restored/result.json'
    proof=read(final)
    assert proof['actual_native_exit']==proof['assessment']['contract_exit']==proof['lane_contract']['contract_exit']==0
    assert proof['assessment']['checks']==32 and proof['restoration']['status']=='EXACT_ORIGINAL_ROOT_RESTORED'
    for rel,value in proof['artifacts'].items():assert sha(final.parent/rel)==value
    assert dict(execution.core.all_game_rows())==read(final.parents[1]/'install.json')['game_files']
    execution.verify_admission()
    wrapper=ROOT/'design/astra/work/vulkan_composed/run_case.py';gate=wrapper.with_name('gate.py')
    assert sha(wrapper)=='8cb42f642262ccf416f0993699d7a3dff7b8cd3fa42631f6a33c0a8d0d1c6ad9'
    assert sha(gate)=='2197f6ad6b9a13cf83c1d99313808b20b3a8be1472997d7e53d6ef61e035d264'
    name='f01_provider_'+mode+'_03'
    out=ROOT/'design/astra/evidence/vulkan_composed/invocations'/name
    result=ROOT/'design/astra/evidence/vulkan_composed/runs'/name/'result.json'
    assert not out.exists() and not result.parent.exists()
    containers=execution.container_admission();assert not execution.engines(execution.census())
    owner=ROOT/execution.OWNER;fixture=ROOT/'game/tests/vulkan_composed_root_test.gd'
    originals={owner:owner.read_bytes(),fixture:fixture.read_bytes()}
    assert originals[fixture]==(HERE/'fixture_original.gd').read_bytes()
    desired={owner:(execution.BASE/'proposed'/execution.OWNER).read_bytes(),fixture:(HERE/'fixture_candidate.gd').read_bytes()}
    out.mkdir(parents=True)
    for path,data in originals.items():(out/(path.name+'.original')).write_bytes(data)
    receipt={'status':'PREPARED','mode':mode,'input_proof_sha256':sha(final),'container_admission':containers,'orchestrator_sha256':sha(Path(__file__)),'samples':[]}
    save=lambda:dump(out/'invocation.json',receipt)
    try:
        for path,data in desired.items():
            assert path.read_bytes()==originals[path] and not execution.engines(execution.census())
            execution.atomic_write(path,data)
        receipt['installed_sources']={str(p.relative_to(ROOT)):sha(p) for p in desired}
        env,cleared=execution.core.clean_environment(os.environ,'candidate',out/'profile')
        env.pop('ENCROACH_SWEEP_VARIANT',None);env['F01_CAPTURE_MODE']=mode
        command=[sys.executable,'-B',str(wrapper),'v1','candidate',name,'--scope','full']
        receipt.update(command=command,cleared_environment=cleared,status='RUNNING');save()
        with (out/'stdout.log').open('wb') as stdout,(out/'stderr.log').open('wb') as stderr:
            process=subprocess.Popen(command,cwd=ROOT,env=env,stdout=stdout,stderr=stderr)
            receipt['wrapper_pid']=process.pid
            while process.poll() is None:
                receipt['samples'].append({'processes':execution.census()});time.sleep(.1)
        receipt['command_exit']=process.returncode
        receipt['lane_contract']=execution.classify_observations(receipt['samples'],process.pid)
        if result.exists():receipt['result_sha256']=sha(result)
    except BaseException as error:
        receipt['exception']=repr(error);raise
    finally:
        try:
            receipt['restore_census']=execution.engines(execution.census())
            assert not receipt['restore_census']
            for path,data in originals.items():
                assert path.read_bytes() in (data,desired[path]),'Unknown source edit'
                execution.atomic_write(path,data);assert path.read_bytes()==data
            receipt['status']='EXACT_ORIGINAL_SOURCES_RESTORED'
        except BaseException as error:
            receipt.update(status='RESTORATION_REFUSED_OR_FAILED',restoration_error=repr(error));raise
        finally:save()
    assert receipt['command_exit']==receipt['lane_contract']['contract_exit']==0
    captured=read(result);probe=read(result.parent/'frames/probe.json')
    assert captured['actual_engine_exit']==captured['gate']['diagnostic_gate_exit']==0
    assert all(c['passed'] for c in probe['checks'])
    control=next(c for c in probe['owned_controls'] if c.get('kind')=='f01_provider_capture')
    assert control['mode']==mode and control['census']['mode']==mode
    assert (control['census']['registry'].get('targets')==609) if mode=='owner_first_cells' else not control['census']['registry']
    print(json.dumps({'mode':mode,'status':receipt['status'],'checks':len(probe['checks']),'captures':len(probe['captures']),'direct_visual_review':'PENDING'}))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['legacy','owner_first_cells']);args=parser.parse_args();main(args.mode)
