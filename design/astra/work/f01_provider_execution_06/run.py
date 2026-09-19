"""Bounded native F01 provider admission. Each phase restores the original root."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys,time
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
BASE=ROOT/'design/astra/work/f01_provider_parity_01/revisions/imported_resource_controls_02'
OUT=ROOT/'design/astra/evidence/f01_provider_execution_06'
OWNER='game/scripts/building/building_root.gd'
sys.path.insert(0,str(ROOT/'design/astra/work/v2_reservation_runtime_03/runtime'))
import core
core.ROOT=ROOT
sys.path.insert(0,str(HERE.parent))
from capture_v2_reservation_01 import census,engines,container_admission,atomic_write
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
def dump(p,d):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
def classify_observations(samples,wrapper_pid):
    all_rows={r['ProcessId']:r for s in samples for r in s['processes']}
    def owned(pid):
        seen=set()
        while pid in all_rows and pid not in seen:
            seen.add(pid);pid=all_rows[pid]['ParentProcessId']
            if pid==wrapper_pid:return True
        return False
    conflicts=[r for s in samples for r in s['processes'] if any(r.get(k)!=all_rows[r['ProcessId']].get(k) for k in ('ParentProcessId','Name','CommandLine'))]
    foreign=[r for r in engines(list(all_rows.values())) if not owned(r['ProcessId'])]
    actual=[r for r in all_rows.values() if r['Name'].lower()=='godot_v4.7.1-stable_win64.exe' and owned(r['ProcessId'])]
    return {'foreign_engines':foreign,'conflicting_pid_observations':conflicts,'actual_owned_engines':actual,'contract_exit':int(bool(foreign or conflicts or len(actual)!=1)),'scope':'Sampled native ancestry only; no absolute exclusivity or performance acceptance.'}
def verify_admission():
    a=read(HERE/'preflight.json')
    assert core.git('rev-parse','HEAD').decode().strip()==a['head']
    assert sha(BASE/'sealed.json')==a['seal_sha256']
    for rel,value in a['additional_inputs'].items(): assert sha(ROOT/rel)==value,rel
    for rel,row in a['protected'].items():
        assert sha(ROOT/rel)==row['sha256'],rel
        assert core.git('rev-parse','HEAD:'+rel).decode().strip()==row['head']
        assert core.git('rev-parse',':'+rel).decode().strip()==row['index']
    return a
def install():
    a=verify_admission()
    containers=container_admission()
    assert not engines(census())
    assert sha(ROOT/OWNER)==read(BASE/'sealed.json')['source_root_sha256']
    assert not OUT.exists()
    for row in a['install_paths']:
        assert sha(Path(row['source']))==row['expected_sha256']
        if row['target']!=OWNER: assert not (ROOT/row['target']).exists()
    OUT.mkdir()
    (OUT/'original_root.gd').write_bytes((ROOT/OWNER).read_bytes())
    receipt={'status':'INSTALLING','container_admission':containers,'copied':[],'preflight_sha256':sha(HERE/'preflight.json')}
    try:
        for row in a['install_paths']:
            if row['target']==OWNER: continue
            target=ROOT/row['target']; target.parent.mkdir(parents=True,exist_ok=True)
            assert not target.exists()
            atomic_write(target,Path(row['source']).read_bytes())
            assert sha(target)==row['expected_sha256']
            receipt['copied'].append(row['target'])
        receipt['status']='OPTIONAL_INPUTS_INSTALLED_ORIGINAL_ROOT_RETAINED'
        receipt['game_files']=dict(core.all_game_rows())
        receipt['engines']=core.engine_manifest()
        assert sorted(x['sha256'] for x in receipt['engines'])==['323f9c4cc5db674e98815cdd8e69da007d5efc779abedc8c0e42883b7fdea12a','35dab11e04ece16a2b93035e65204f4a944a3e00b020d43e54409193379d5eef']
    except BaseException as error:
        receipt['status']='INSTALL_FAILED_INPUTS_RETAINED_FOR_REVIEW'
        receipt['error']=repr(error)
        raise
    finally: dump(OUT/'install.json',receipt)
    print(receipt['status'])
def assess(out,phase,native,before,after):
    logs='\n'.join((out/n).read_text(encoding='utf-8-sig',errors='replace') if (out/n).exists() else '' for n in ['stdout.log','stdout.log.stderr','wrapper.stdout.log','wrapper.stderr.log'])
    known=read(ROOT/'design/astra/work/v2_reservation_runtime_03/runtime/known_diagnostics.json')
    allowed={tuple(p) for p in known['errors']+known['warnings']}
    debt_binding=read(HERE/'inherited_art_warning.json')
    assert sha(ROOT/debt_binding['historical_stderr'])==debt_binding['historical_stderr_sha256']
    allowed.add(tuple(debt_binding['warning_pair']))
    lines=logs.splitlines(); unknown=[]; debt=[]
    for i,line in enumerate(lines):
        if line.startswith(('ERROR:','SCRIPT ERROR:','WARNING:')):
            pair=(line,lines[i+1].strip() if i+1<len(lines) else '')
            (debt if pair in allowed else unknown).append(pair)
    retention=[s for s in lines if any(t in s for t in ['ObjectDB instances leaked','resources still in use at exit','Unreferenced static string'])]
    reasons=[]
    if unknown: reasons.append('unknown_native_diagnostics')
    if retention: reasons.append('retention_diagnostics')
    if before!=after: reasons.append('game_source_changed')
    if 'Godot Engine v4.7.1.stable.official.a13da4feb' not in logs: reasons.append('engine_identity_missing')
    expected_native=1 if phase=='04_omission' else 0
    if native!=expected_native: reasons.append('unexpected_native_exit')
    probe=None
    if phase!='00_import':
        mode='registry' if phase=='01_registry' else ('legacy' if phase=='02_legacy' else 'owner_first_cells')
        path=out/'frames'/('registry_contract.json' if mode=='registry' else 'provider.json')
        try: probe=read(path)
        except (OSError,ValueError): reasons.append('missing_probe')
        if probe is not None:
            labels=read(BASE/'expected_contract.json')['ordered_labels'][mode]
            rows=probe.get('checks',[])
            failed=[r['label'] for r in rows if r.get('pass') is not True]
            expected_failed=['initial/all explicit exterior exemptions reach current root','reconstructed/all explicit exterior exemptions reach current root'] if phase=='04_omission' else []
            if [r.get('label') for r in rows]!=labels or any(type(r.get('pass')) is not bool for r in rows): reasons.append('check_contract')
            if failed!=expected_failed or probe.get('failures')!=len(failed): reasons.append('unexpected_failed_checks')
            prefix='F01_REGISTRY_COMPLETE=' if mode=='registry' else 'F01_PROVIDER_COMPLETE='
            footers=[json.loads(s[len(prefix):]) for s in lines if s.startswith(prefix)]
            if len(footers)!=1 or footers[0].get('checks')!=len(labels) or footers[0].get('failures')!=len(failed): reasons.append('completion_footer')
            if probe.get('setup_failures'): reasons.append('setup_failed')
            if mode!='registry' and (probe.get('root_retired') is not True or len(probe.get('observations',[]))!=2): reasons.append('reconstruction_incomplete')
            if mode=='owner_first_cells':
                try:
                    source=(ROOT/'game/data/floor01_provider_registry.tres').read_text(encoding='utf-8')
                    definition=json.loads(re.sub(r'ExtResource\("cell_(\d+)"\)',r'"cell_\1"',source.split('definition = ',1)[1]))
                    for observation in probe['observations']:
                        registry=observation['census']['registry']
                        assert all(registry[k]==v for k,v in {'cells':17,'targets':609,'aliases':531,'semantics':189}.items())
                        assert len(registry['target_ids'])==len(set(registry['target_ids']))==609
                        targets=observation['targets']
                        assert len(targets)==609 and {t['key'] for t in targets}==set(definition['targets'])
                        assert {t['instance_id'] for t in targets}==set(registry['target_ids'])
                        assert len({t['path'] for t in targets})==609
                        for target in targets:
                            expected=definition['targets'][target['key']]
                            assert expected['aliases']==[target['alias']]
                            assert target['path'].split('/')[-1]==expected['import_name_candidates'][0]
                            assert target['import_owner_and_class'] is True and target['passage_membership'] is True and target['collision_shapes_present'] is True
                            if phase!='04_omission': assert target['envelope_exemption'] is True
                    assert set(probe['observations'][0]['census']['registry']['target_ids']).isdisjoint(probe['observations'][1]['census']['registry']['target_ids'])
                except (AssertionError,KeyError,TypeError,ValueError):reasons.append('independent_imported_target_witness_failed')
    return {'contract_exit':int(bool(reasons)),'ordinary_product_exit':int(bool(reasons) or native!=0),'reasons':reasons,'unknown_diagnostics':unknown,'known_diagnostic_debt':debt,'retention':retention,'checks':len(probe.get('checks',[])) if probe else 0,'failed_labels':[r['label'] for r in probe.get('checks',[]) if r.get('pass') is not True] if probe else []}
def phase_run(phase):
    a=verify_admission(); installed=read(OUT/'install.json')
    assert installed['status']=='OPTIONAL_INPUTS_INSTALLED_ORIGINAL_ROOT_RETAINED'
    assert sha(ROOT/OWNER)==sha(OUT/'original_root.gd')
    order=['03_candidate','04_omission','05_restored']
    for name in order[:order.index(phase)]:
        prior=read(OUT/name/'result.json')
        if name=='02_legacy':
            admission=read(HERE/'inherited_art_warning.json')
            assert sha(OUT/name/'result.json')==admission['legacy_result_sha256']
            assert prior['assessment']['reasons']==['unknown_native_diagnostics']
            assert prior['assessment']['unknown_diagnostics']==[admission['warning_pair']]*2
            reassessed=assess(OUT/name,name,prior['actual_native_exit'],read(OUT/name/'run_before.json'),read(OUT/name/'run_after.json'))
            assert reassessed['contract_exit']==0
        else:
            assert prior['assessment']['contract_exit']==0,name
        assert prior['restoration']['status']=='EXACT_ORIGINAL_ROOT_RESTORED',name
        for rel,value in prior['artifacts'].items(): assert sha(OUT/name/rel)==value,rel
    row=next(r for r in a['install_paths'] if r['target']==OWNER)
    desired=Path(row['source']) if phase!='04_omission' else Path(read(BASE/'sealed.json')['control']['source'])
    if phase=='00_import': desired=OUT/'original_root.gd'
    containers=container_admission(); assert not engines(census())
    out=OUT/phase; out.mkdir(exist_ok=False)
    profile=out/'profile';profile.mkdir();(out/'frames').mkdir()
    before=dict(core.all_game_rows());dump(out/'before.json',before)
    assert before==installed['game_files'],'Unexpected source changes since reviewed installation'
    for source_row in a['install_paths']:
        if source_row['target']!=OWNER:
            assert sha(ROOT/source_row['target'])==source_row['expected_sha256'],source_row['target']
    receipt={'phase':phase,'container_admission':containers,'orchestrator_sha256':sha(Path(__file__)),'restoration':{},'engine_manifest':core.engine_manifest()}
    assert receipt['engine_manifest']==installed['engines']
    native=1
    try:
        atomic_write(ROOT/OWNER,desired.read_bytes())
        run_before=dict(core.all_game_rows());dump(out/'run_before.json',run_before)
        (out/'building_root.gd').write_bytes((ROOT/OWNER).read_bytes())
        extra=['--verbose','--audio-driver','Dummy']
        scene=''
        if phase=='00_import':extra+=['--editor','--import']
        else:
            extra+=['--resolution','1280x720','--rendering-method','forward_plus','--rendering-driver','vulkan']
            scene='res://tests/Floor01RegistryContractTest.tscn' if phase=='01_registry' else 'res://tests/Floor01ProviderParityTest.tscn'
        invocation={'runner':str(ROOT/'tools/run_godot_serial.ps1'),'parameters':{'ProjectPath':str(ROOT/'game'),'Scene':scene,'LogPath':str(out/'stdout.log'),'TimeoutSeconds':180,'Windowed':phase!='00_import','ExtraArgs':extra}}
        dump(out/'invocation.json',invocation)
        bridge=ROOT/'design/astra/work/v2_reservation_runtime_03/runtime/runner_bridge.ps1'
        command=[str(core.PWSH),'-NoProfile','-File',str(bridge),'-InvocationPath',str(out/'invocation.json')]
        env,cleared=core.clean_environment(os.environ,'candidate',profile)
        env.pop('ENCROACH_SWEEP_VARIANT',None)
        for k in list(env):
            if k.startswith(('F01_PROVIDER_','CASE_FORCE','VULKAN_')): env.pop(k)
        env.update(F01_PROVIDER_RECEIPT_DIR=str(out/'frames'),F01_PROVIDER_MODE='legacy' if phase=='02_legacy' else 'owner_first_cells',WEATHER_SEED='19281110',TITLE_SCREEN_SILENT='1')
        receipt.update(command=command,cleared_environment=cleared,samples=[])
        assert not engines(census())
        started=time.monotonic()
        with (out/'wrapper.stdout.log').open('wb') as stdout,(out/'wrapper.stderr.log').open('wb') as stderr:
            process=subprocess.Popen(command,cwd=ROOT,env=env,stdout=stdout,stderr=stderr)
            receipt['wrapper_pid']=process.pid
            while process.poll() is None:
                rows=census()
                receipt['samples'].append({'elapsed':time.monotonic()-started,'processes':rows})
                time.sleep(.1)
        native=process.returncode
        receipt['actual_native_exit']=native
        receipt['elapsed_seconds']=time.monotonic()-started
        after=dict(core.all_game_rows());dump(out/'run_after.json',after)
        receipt['assessment']=assess(out,phase,native,run_before,after)
        receipt['lane_contract']=classify_observations(receipt['samples'],process.pid)
        if receipt['lane_contract']['contract_exit']:
            receipt['assessment']['reasons'].append('native_lane_ancestry_failed');receipt['assessment']['contract_exit']=1
    except BaseException as error:
        receipt['exception']=repr(error)
        raise
    finally:
        try:
            remaining=engines(census());receipt['restoration']['process_census']=remaining
            assert not remaining,'Active engine prevents source restoration'
            assert sha(ROOT/OWNER) in (sha(desired),sha(OUT/'original_root.gd')),'Unknown source prevents restoration'
            atomic_write(ROOT/OWNER,(OUT/'original_root.gd').read_bytes())
            assert sha(ROOT/OWNER)==sha(OUT/'original_root.gd')
            receipt['restoration'].update(status='EXACT_ORIGINAL_ROOT_RESTORED',sha256=sha(ROOT/OWNER))
        except BaseException as error:
            receipt['restoration'].update(status='RESTORATION_REFUSED_OR_FAILED',error=repr(error))
            raise
        finally:
            receipt['artifacts']={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file() and 'profile' not in p.relative_to(out).parts and p.name!='result.json'}
            dump(out/'result.json',receipt)
    print(json.dumps({'phase':phase,'native_exit':native,'contract_exit':receipt['assessment']['contract_exit'],'checks':receipt['assessment']['checks'],'failed_labels':receipt['assessment']['failed_labels'],'reasons':receipt['assessment']['reasons'],'unknown_diagnostic_count':len(receipt['assessment']['unknown_diagnostics']),'restoration':receipt['restoration']['status']}))
    return receipt['assessment']['contract_exit']
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('phase',choices=['install','00_import','01_registry','02_legacy','03_candidate','04_omission','05_restored']);args=p.parse_args()
    if args.phase=='install':install()
    else:raise SystemExit(phase_run(args.phase))
