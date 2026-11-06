"""Prepare fresh-engine runtime14 only after explicit engine and metadata admission.

No Godot launch or receipt publication occurs here. Existing tests execute the
real scope; failed artifacts are preserved in their fresh output directory.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib,io,json,os,re,struct,subprocess,sys,time
from PIL import Image, ImageFile
ROOT=Path('C:/PleaseRemainOnTheLine');BASE=Path(__file__).parent
sys.path.insert(0,str(ROOT/'tools'))
import run_receipt,v2_surface_evidence,v2_physical_inputs

ROOTS=['game/tests/CompileChangedScripts.tscn','game/tests/compile_changed_scripts.gd',
       'game/tests/native_debug_window.gd','game/tests/orison_v2_first_slice_contract_test.tscn',
       'game/tests/orison_v2_first_slice_contract_test.gd',
       'game/tests/OrisonV2RemainingApartmentAccessContractTest.tscn',
       'game/tests/orison_v2_remaining_apartment_access_contract_test.gd',
       'game/tests/OrisonV2SurfaceInventory.tscn','game/tests/orison_v2_surface_inventory.gd',
       'game/tests/MaterialLibraryTest.tscn','game/tests/material_library_test.gd',
       'game/tests/RadiatorInsertRouteBench.tscn','game/tests/radiator_hand_bench.gd',
       'game/tests/ServiceDoorRouteBench.tscn','game/tests/service_door_route_bench.gd',
       'tools/audit_orison_v2_completeness.py','tools/spatial_access_evidence.py',
       'game/tests/InstalledCameraProbe.tscn','game/tests/installed_camera_probe.gd']

PARENT_PRODUCER_SHA='68fa120731e0ea6282f56ad0cf12bb6273838f9fb40cafc6cbf74fdd713e1f23'
EXPECTED_PIXELS=(3440,1440)
DIAGNOSTIC_AUDIO_OUTPUT='Headphones (BD9)'
EXPECTED_ENGINE_MAIN_SHA='e954c1db69ebe4b60878ae92cdc3a0e464fe92bd06b78c19402055e9f7bafce1'
EXPECTED_ENGINE_CONSOLE_SHA='7965e75a4f847484a4d1596729b508cb1ef23ae17ab6407eaffd9683364f0f8c'
APARTMENT_PNG_NAMES=tuple(sorted(f'{unit}_F0{unit[0]}_{unit[1]}_{room}.png'
    for unit in ['3A','3B','4A','5A','5B','5C','6A','6B','6C'] for room in ['MAIN','BATH']))
CAPTURE_ADMISSION={'evidence_class':'INERT','expected_pixels':list(EXPECTED_PIXELS),
    'apartment_png_names':list(APARTMENT_PNG_NAMES),
    'scope':'CPU actual PNG header and Pillow verify/load only; no new runtime contract or artistic acceptance'}

# Explicit reviewed camera/probe source pins, not old-engine runtime reuse.
CAMERA_SOURCE_PINS = {'game/tests/installed_camera_probe.gd': 'c6a20468d6acafac52af62af67660bec8f130694eba0cd1e5bec21416d8d97cc', 'game/tests/radiator_hand_bench.gd': 'fae8226fe500a9015fe9c562d4bef4207e41c9e2dbb33c57e514648a4cb620b1', 'game/tests/service_door_route_bench.gd': '3834746ec8887c825be09f1bee2fd4cff009aebcfb551e5e9a6705d4d4cfce9d', 'game/tests/orison_v2_first_slice_contract_test.gd': 'ef4ee722b46c92ed9309759c04ce57ca6e7f83c53437c5cfd33802a031628d9c', 'game/tests/InstalledCameraProbe.tscn': 'bc044e80b3e83d299f32a21a7fad42d94e1bc6a156c0c935ab56d8530b3790c6', 'game/tests/RadiatorInsertRouteBench.tscn': '7cbaf95ba769f1e676768a0254900cda8e66ce437b3ed3153c3908b5e972ff22', 'game/tests/ServiceDoorRouteBench.tscn': 'b15923c616891bba07258a46739ae2785e2fb9e75b6ae1553231fd279dcf05eb', 'game/scripts/player/player_controller.gd': '71b7ff9d392b3f7452d2983d5efaf9e31fc28ae39351e996d9d841a86ff58caa'}
ENGINE_BUILD_ROOT = Path('C:/devkit/tentacle-audio-20261104-01')
OLD_ENGINE_MAIN_SHA = 'e130d0253a9c863cc3df59b010a366734a25fc415b479e3d163f02941fb27b62'


def engine_binding():
    manifest_path=ROOT/'.godot-engine.json'
    raw=manifest_path.read_bytes();manifest=json.loads(raw)
    console=Path(manifest['path']).resolve()
    assert console.is_relative_to(ENGINE_BUILD_ROOT.resolve()),'Admit the versioned candidate engine before preparation'
    assert console.name=='godot.windows.editor.x86_64.llvm.console.exe'
    main=console.with_name('godot.windows.editor.x86_64.llvm.exe')
    claimed={Path(p).resolve():str(h).lower() for p,h in manifest['binaries'].items()}
    assert set(claimed)=={console,main},'Both adjacent engine files must be pinned, with no unbound companion'
    actual={p:hashlib.sha256(p.read_bytes()).hexdigest() for p in claimed}
    assert actual==claimed,'Actual admitted engine binary hash mismatch'
    assert actual[console]==str(manifest['sha256']).lower()
    assert actual[main]!=OLD_ENGINE_MAIN_SHA,'Old renderer-only engine is historical, not this new qualification'
    assert actual[main]==EXPECTED_ENGINE_MAIN_SHA and actual[console]==EXPECTED_ENGINE_CONSOLE_SHA,'Only the executed and reviewed shutdown-fix build is admitted'
    override=os.environ.get('ORISON_GODOT_EXE','')
    if override:assert Path(override).resolve()==console,'Inherited engine override disagrees with admitted manifest'
    return {'manifest_path':str(manifest_path),'manifest_raw_sha256':hashlib.sha256(raw).hexdigest(),
            'manifest_lf_sha256':hashlib.sha256(raw.replace(b'\r\n',b'\n')).hexdigest(),
            'path':str(console),'binaries':{str(p):actual[p] for p in sorted(actual)}}


def check_camera_pins():
    for path,digest in CAMERA_SOURCE_PINS.items():
        assert v2_surface_evidence.file_hash(ROOT/path)==digest,'Reviewed installed/probe camera input changed: '+path


def isolated_profiles(run):
    return {name:str(run/'profiles'/name/'appdata') for name in ['compile','probe','door','installed','first_slice','apartments','surface']}

def validate_native_png(path):
    raw=path.read_bytes()
    assert len(raw)>=33 and raw[:8]==b'\x89PNG\r\n\x1a\n' and raw[8:16]==b'\x00\x00\x00\rIHDR','Malformed PNG signature/IHDR: '+str(path)
    assert struct.unpack('>II',raw[16:24])==EXPECTED_PIXELS,'Actual PNG IHDR dimensions mismatch: '+str(path)
    assert ImageFile.LOAD_TRUNCATED_IMAGES is False,'Truncated-image loading must remain disabled'
    with Image.open(io.BytesIO(raw)) as pixels:
        assert pixels.format=='PNG' and pixels.size==EXPECTED_PIXELS,'Decoded PNG identity/dimensions mismatch: '+str(path)
        pixels.verify()
    with Image.open(io.BytesIO(raw)) as pixels:
        pixels.load()
        assert pixels.format=='PNG' and pixels.size==EXPECTED_PIXELS,'Loaded PNG dimensions mismatch: '+str(path)
    return {'file':str(path),'sha256':hashlib.sha256(raw).hexdigest(),'pixels':list(EXPECTED_PIXELS)}

def admit_native_pngs(run,freeze):
    assert freeze['capture_admission']==CAPTURE_ADMISSION,'Frozen expected capture dimensions/cohort changed'
    apartments=run/'apartments';surface=run/'surface';entry=surface/'entry_preparation'
    assert apartments.is_dir() and surface.is_dir() and entry.is_dir(),'Original capture directories required'
    apartment_files={p.relative_to(apartments).as_posix():p for p in apartments.rglob('*') if p.is_file() and p.suffix.lower()=='.png'}
    assert set(apartment_files)==set(APARTMENT_PNG_NAMES),'Exactly18 original nine-unit MAIN/BATH PNGs required; no extras'
    root_surface=[p for p in surface.iterdir() if p.is_file() and p.suffix.lower()=='.png']
    assert root_surface,'Nonempty original root surface native PNG cohort required'
    entry_files={p.relative_to(entry).as_posix():p for p in entry.rglob('*') if p.is_file() and p.suffix.lower()=='.png'}
    entry_names={f'preparation_{index:02d}.png' for index in range(5)}
    assert set(entry_files)==entry_names,'Exactly five original entry-preparation PNGs required; no extras'
    views=json.loads((entry/'preparation_views.json').read_text(encoding='utf-8'))
    assert len(views['images'])==5 and {row['file'] for row in views['images']}==entry_names,'Original entry report/image associations required'
    for row in views['images']:
        assert hashlib.sha256(entry_files[row['file']].read_bytes()).hexdigest()==row['sha256'],'Entry image/report hash mismatch'
    surface_files=sorted(p for p in surface.rglob('*') if p.is_file() and p.suffix.lower()=='.png')
    verified=[validate_native_png(p) for p in sorted(apartment_files.values())+surface_files]
    return {'evidence_class':'INERT','kind':'cpu_native_png_admission.v1','expected_pixels':list(EXPECTED_PIXELS),
        'apartment_count':len(apartment_files),'surface_count':len(surface_files),'entry_count':len(entry_files),'images':verified,
        'scope':'Actual original PNG bytes only; not a new schema2 runtime proof or artistic acceptance'}

def snapshot():
    with ThreadPoolExecutor(max_workers=3) as pool:
        runtime=pool.submit(run_receipt.runtime_inputs_sha256,ROOT)
        physical=pool.submit(v2_physical_inputs.snapshot,ROOT)
        surface=pool.submit(v2_surface_evidence.inputs,ROOT)
        values=dict(runtime=runtime.result(),physical=physical.result()['sha256'],surface=surface.result()['sha256'])
    paths=v2_surface_evidence.test_dependency_paths(ROOT,{ROOT/p for p in ROOTS})
    values['tests']={p.relative_to(ROOT).as_posix():v2_surface_evidence.file_hash(p) for p in sorted(paths)}
    return values

def check_sources(run):
    assert run.resolve()==(BASE/'runtime_14').resolve(),'Only explicit fresh runtime_14 is admitted'
    assert hashlib.sha256((BASE/'prepare_runtime13.py').read_bytes()).hexdigest()==PARENT_PRODUCER_SHA,'Immutable parent producer changed'
    freeze=json.loads((run/'SOURCE_FREEZE.json').read_text(encoding='utf-8'))
    assert hashlib.sha256(Path(__file__).read_bytes()).hexdigest()==freeze['preparer_sha256'],'External guard changed'
    for name in ['batch.json','launch.ps1']:
        assert hashlib.sha256((run/name).read_bytes()).hexdigest()==freeze['external_sha256'][name],name+' changed'
    assert snapshot()==freeze['inputs'],'A consumed source, geometry, surface or helper changed'
    assert freeze['isolated_profiles']==isolated_profiles(run)
    assert freeze['capture_admission']==CAPTURE_ADMISSION
    assert freeze['diagnostic_audio_output']==DIAGNOSTIC_AUDIO_OUTPUT
    batch=json.loads((run/'batch.json').read_text(encoding='utf-8'))
    for name,profile in freeze['isolated_profiles'].items():
        matching=[job for job in batch if job.get('log')==str(run/(name+'.log'))]
        assert len(matching)==1 and matching[0]['environment']['APPDATA']==profile,'Per-job pre-autoload profile binding changed: '+name
        assert matching[0]['environment']['ORISON_NATIVE_AUDIO_OUTPUT']==(None if name=='compile' else DIAGNOSTIC_AUDIO_OUTPUT),'Process-only real audio endpoint binding changed: '+name
    assert engine_binding()==freeze['engine'],'Admitted manifest or either actual binary changed'
    assert freeze['camera_source_pins']==CAMERA_SOURCE_PINS
    check_camera_pins()
    validate_history(freeze)
    return freeze

def completed(run,name):
    receipt=json.loads((run/(name+'.log.receipt.json')).read_text(encoding='utf-8-sig'))
    execution=receipt['execution'];logs=receipt['log']
    assert execution['completed'] and execution['exit_code']==0 and not execution['timed_out'],(name,execution)
    assert logs['script_error_count']==0 and logs['fail_count']==0,(name,logs)
    for stream in ['stdout','stderr']:
        raw=Path(logs[stream]).read_bytes()
        assert hashlib.sha256(raw).hexdigest()==logs[stream+'_sha256']
        assert not any(line.lstrip().startswith(('ERROR:','SCRIPT ERROR:')) for line in raw.decode('utf-8','replace').splitlines()),name
    if name in ['probe','door','installed','first_slice','apartments','surface']:
        assert re.search(r'NATIVE DEBUG WINDOW:\s*\(3440(?:\.0)?,\s*1440(?:\.0)?\)',Path(logs['stdout']).read_text(encoding='utf-8')),name+' native viewport not confirmed'
        assert 'NATIVE DEBUG AUDIO OUTPUT: '+DIAGNOSTIC_AUDIO_OUTPUT in Path(logs['stdout']).read_text(encoding='utf-8'),name+' real WASAPI endpoint not confirmed'
    return receipt

def bounded_review(run,wait=False):
    # Generated technical observation; never substitutes for original contracts.
    for name in ['compile','probe','door','installed']:completed(run,name)
    installed=json.loads((run/'installed/installed_camera_probe.json').read_text(encoding='utf-8'))
    assert installed['result']=='admitted' and installed['space_result']['entered']
    assert installed['helper_failures']==0 and all(row['ok'] for row in installed['checks'])
    assert all(installed['transfer'].get(k) is True for k in ['parked','delivered','caught','passed'])
    assert len(installed['phase_attempts'])==2 and all(not row['production_first_hit'] and row['ray_predicts_admitted'] for row in installed['phase_attempts'])
    assert all(installed['teardown'].values()) and len(installed['frames'])==5
    frames=sorted(p for name in ['probe','door','installed'] for p in (run/name).rglob('*.png'))
    assert len(frames)>=12,'Missing bounded render controls'
    expected={p.relative_to(run).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in frames}
    path=run/'BOUNDED_FRAME_REVIEW.json'
    if wait:
        (run/'BOUNDED_REVIEW_READY.json').write_text(json.dumps({'evidence_class':'INERT','bounded_receipts_checked':True,'frames':expected,'scope':'Readiness only; actual technical image review still required.'},indent=2)+'\n',encoding='utf-8')
    deadline=time.monotonic()+(140 if wait else 0)
    if wait:print('BOUNDED FRAME REVIEW READY: input passed; waiting at most140s before long suites',flush=True)
    while not path.exists() and time.monotonic()<deadline:time.sleep(1)
    assert path.is_file(),'No actual frame review: long stages remain unexecuted'
    review=json.loads(path.read_text(encoding='utf-8'))
    assert review.get('evidence_class')=='INERT' and review.get('technical_visibility_ok') is True
    assert review.get('human_played') is False and review.get('artistically_accepted') is False
    assert review.get('reviewer') in ['integration_lead','installed_camera_architect']
    assert review.get('frames')==expected,'Review must bind every actual bounded frame'
    assert {p.relative_to(run).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in frames}==expected,'Frame bytes changed during review'
    if wait:check_sources(run)
    print('BOUNDED TECHNICAL FRAME REVIEW PASS; no human play/artistic acceptance',flush=True)


# Historical evidence is byte-bound only: it grants no pass for the new engine.
ORIGINAL=BASE/'runtime_11'
FAILED_RENEWAL=BASE/'runtime_13'


def build_history():
    names=['compile','probe','door','installed','first_slice']
    files={ORIGINAL/'SOURCE_FREEZE.json',ORIGINAL/'batch.json',ORIGINAL/'launch.ps1',BASE/'prepare_runtime10.py',
           ORIGINAL/'BOUNDED_FRAME_REVIEW.json',ORIGINAL/'first_slice/runtime_authority_receipt.json',
           ORIGINAL/'probe/insert_route.json',ORIGINAL/'door/service_door_route.json',
           ORIGINAL/'installed/installed_camera_probe.json',ORIGINAL/'apartments/runtime_contract.json',
           ORIGINAL/'apartments.log.receipt.json',ORIGINAL/'apartments.log',ORIGINAL/'apartments.log.stderr'}
    for name in names:
        p=ORIGINAL/(name+'.log.receipt.json');files.add(p)
        receipt=json.loads(p.read_text(encoding='utf-8-sig'))
        files.update(Path(receipt['log'][stream]) for stream in ['stdout','stderr'])
    for name in ['probe','door','installed']:files.update((ORIGINAL/name).rglob('*.png'))
    files.update(FAILED_RENEWAL/p for p in ['SOURCE_FREEZE.json','batch.json','launch.ps1','after.log',
                 'apartments/runtime_contract.json','surface/runtime_contract.json'])
    for name in ['compile','apartments','surface']:
        p=FAILED_RENEWAL/(name+'.log.receipt.json');files.add(p)
        receipt=json.loads(p.read_text(encoding='utf-8-sig'))
        files.update(Path(receipt['log'][stream]) for stream in ['stdout','stderr'])
    return {'evidence_class':'INERT','current_qualification_credit':False,
            'references':[{'run':str(ORIGINAL),'scope':'Original bounded/frame/first-slice and failed69-apartment source history only'},
                          {'run':str(FAILED_RENEWAL),'scope':'Original60room/9leg gameplay and rejected audio teardown/afterguard retained; not current proof'}],
            'files':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}}


def validate_history(freeze):
    value=freeze['historical_evidence']
    assert value['current_qualification_credit'] is False and value['files']
    for path,digest in value['files'].items():
        assert hashlib.sha256(Path(path).read_bytes()).hexdigest()==digest,'Historical original evidence changed: '+path
    failed=json.loads((ORIGINAL/'apartments/runtime_contract.json').read_text(encoding='utf-8'))
    assert failed['failures']==69 and not failed['contracts']['room_access']['rooms'],'Original apartment failure was not preserved'
    # Deliberately no comparison with new runtime, engine or test digests and
    # no old receipt is evaluated as a current-engine PASS.


if len(sys.argv)>1 and sys.argv[1]!='prepare':
    run=Path(sys.argv[1]);freeze=check_sources(run)
    if sys.argv[2]=='review':bounded_review(run,wait=True)
    elif sys.argv[2]=='after':
        for name in ['compile','probe','door','installed','first_slice','apartments','surface']:completed(run,name)
        bounded_review(run)
        probe=json.loads((run/'probe/insert_route.json').read_text(encoding='utf-8'))
        assert all(probe.get(key) is True for key in ['passed','borrow_release','returned','normal_release','pose_reload','delivery','caught','stale_grip_refused','threaded']),'Bounded current-driver preflight failed'
        door=json.loads((run/'door/service_door_route.json').read_text(encoding='utf-8'))
        assert door.get('passed') is True and door.get('original_helper_failures')==0 and door.get('failures')==[], 'Bounded real service-door/stock preflight failed'
        import audit_orison_v2_completeness as ledger
        from spatial_access_evidence import validate as validate_access
        first=json.loads((run/'first_slice/runtime_authority_receipt.json').read_text(encoding='utf-8'))
        assert ledger.runtime_receipt_errors(first,ROOT)==[], 'First-slice runtime contract rejected'
        apartments=json.loads((run/'apartments/runtime_contract.json').read_text(encoding='utf-8'))
        assert validate_access(apartments,ROOT,freeze['inputs']['runtime'],freeze['inputs']['surface'])==[], 'Apartment played contract rejected'
        assert len(apartments['contracts']['room_access']['rooms'])==60 and len(apartments['legs'])==9
        surface=json.loads((run/'surface/runtime_contract.json').read_text(encoding='utf-8'))
        assert surface['schema_version']==2 and surface['evidence_kind']=='runtime_contract' and surface['checks']>0 and not surface['failures']
        assert surface['execution']['completed'] and surface['execution']['exit_code']==0 and not surface['execution']['timed_out']
        assert surface['source']['runtime_inputs_sha256']==freeze['inputs']['runtime'] and surface['surface_inputs_sha256']==freeze['inputs']['surface']
        assert surface['qualification_mode']=='physical_surfaces_only'
        for key in ['production_composition','surface_requirements','teardown']:
            assert surface['contracts'][key]['executed'] and surface['contracts'][key]['status']=='PASS'
        assert not surface['interaction_programmes']['fire_service']['executed'] and not surface['interaction_programmes']['other_family_programmes']['executed']
        views=json.loads((run/'surface/entry_preparation/preparation_views.json').read_text(encoding='utf-8'))
        assert len(views['images'])==5 and views['preparation']['completed'] and views['preparation']['render_calls']==10 and views['preparation']['node_pose_unchanged']
        for row in views['images']:
            assert hashlib.sha256((run/'surface/entry_preparation'/row['file']).read_bytes()).hexdigest()==row['sha256']
        print('V2 NATIVE PNG CPU ADMISSION',json.dumps(admit_native_pngs(run,freeze),sort_keys=True))
    else:
        assert sys.argv[2]=='before'
        for profile in freeze['isolated_profiles'].values():
            if not Path(profile).is_dir() or any(Path(profile).iterdir()):raise AssertionError('Fresh empty pre-autoload APPDATA required: '+profile)
    print('V2 RENEWAL SOURCE/CONTRACT GUARD PASS',sys.argv[2])
else:
    assert hashlib.sha256((BASE/'prepare_runtime13.py').read_bytes()).hexdigest()==PARENT_PRODUCER_SHA,'Immutable parent producer changed'
    native=sys.argv[2] if len(sys.argv)>2 else 'native_export_06'
    assert re.fullmatch(r'native_export_\d+',native)
    admission=json.loads((BASE/native/'ADMISSION.json').read_text(encoding='utf-8'))
    assert admission['status']=='APPLIED' and admission['unchanged_geometry_and_alias_artifacts']==35
    for row in admission['changes']:
        assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['after_sha256'],row['path']
    assert not subprocess.check_output(['git','status','--porcelain'],cwd=ROOT).strip(),'Commit the admitted source checkpoint before queueing'
    assert len(sys.argv)>3,'Explicit fresh runtime_NN is mandatory'
    run_name=sys.argv[3]
    assert run_name=='runtime_14','Explicit fresh runtime_14 is mandatory'
    admitted_engine=engine_binding()
    check_camera_pins()
    history=build_history()
    run=BASE/run_name;run.mkdir(exist_ok=False)
    freeze={'evidence_class':'INERT','repository_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'preparer_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'inputs':snapshot(),'scope':'Fresh admitted-engine compile, bounded radiator/door/installed input and technical frames, original first-slice authority/save, nine-unit access and composed physical/city/entry surfaces. Prior evidence remains historical only. Not whole-V2, vertical navigation, human play or artistic acceptance.'}
    freeze['isolated_profiles']=isolated_profiles(run)
    freeze['capture_admission']=CAPTURE_ADMISSION
    freeze['diagnostic_audio_output']=DIAGNOSTIC_AUDIO_OUTPUT
    for profile in freeze['isolated_profiles'].values():Path(profile).mkdir(parents=True,exist_ok=False)
    freeze['engine']=admitted_engine
    freeze['camera_source_pins']=CAMERA_SOURCE_PINS
    freeze['historical_evidence']=history
    validate_history(freeze)
    jobs=[]
    def guard(stage):jobs.append({'gpu':[sys.executable,str(Path(__file__)),str(run),stage],'scene':'V2 qualification '+stage+' guard','log':str(run/(stage+'.log')),'timeout':240 if stage=='review' else 180,'environment':{'ORISON_GODOT_EXE':freeze['engine']['path']}})
    def scene(name,resource,windowed=False,flags=None):
        spec={'project':str(ROOT/'game'),'scene':'res://tests/'+resource,'runner':'long' if windowed else 'serial','timeout':1500 if windowed else 180,'log':str(run/(name+'.log'))}
        if windowed:
            spec.update(windowed=True,shot_dir=str(run/name),extra_args=['--script','res://tests/native_debug_window.gd','--fullscreen','--resolution','3440x1440'])
        spec['environment']={'ORISON_VISIBLE_GODOT':None,'APPDATA':freeze['isolated_profiles'][name],'ORISON_GODOT_EXE':freeze['engine']['path'],'ORISON_NATIVE_AUDIO_OUTPUT':DIAGNOSTIC_AUDIO_OUTPUT if windowed else None}
        if flags:spec['environment'].update(flags)
        jobs.append(spec)
    guard('before')
    scripts=['res://tests/service_door_route_bench.gd', 'res://tests/radiator_hand_bench.gd', 'res://tests/orison_v2_first_slice_contract_test.gd', 'res://scripts/building/orison_v2_domestic_doors.gd', 'res://scripts/building/orison_v2_fitted_door.gd', 'res://scripts/building/orison_v2_anchor_adapter.gd', 'res://scripts/props/door_prop.gd', 'res://scripts/props/easy_door_motion.gd', 'res://scripts/props/radiator_vent_stock.gd', 'res://scripts/props/radiator_vent_insert.gd', 'res://scripts/props/radiator_prop.gd', 'res://scripts/player/player_controller.gd', 'res://tests/native_debug_window.gd', 'res://tests/orison_v2_remaining_apartment_access_contract_test.gd', 'res://tests/v2_remaining_apartment_walk.gd']
    scripts.append('res://tests/installed_camera_probe.gd')
    scene('compile','CompileChangedScripts.tscn',flags={'ORISON_SCRIPT_CHECK':json.dumps(scripts)})
    scene('probe','RadiatorInsertRouteBench.tscn',True,{'ORISON_RADIATOR_INSERT_ROUTE':'1'})
    scene('door','ServiceDoorRouteBench.tscn',True,{'ORISON_RADIATOR_INSERT_ROUTE':'1'})
    scene('installed','InstalledCameraProbe.tscn',True,{'ORISON_INSTALLED_CAMERA_TRANSFER':'1'})
    guard('review')
    scene('first_slice','orison_v2_first_slice_contract_test.tscn',True)
    scene('apartments','OrisonV2RemainingApartmentAccessContractTest.tscn',True)
    flags={'ORISON_SURFACE_PHYSICAL_ONLY':'1','ORISON_SURFACE_CITY_REVIEW':'1','ORISON_SURFACE_ENTRY_FRAMING':'1'}
    for name in ['CITY_ONLY','FIRE_ONLY','CITY_CONSTRUCTION','CITY_CIVIC_ACCESS','PREVIEW_PROBE']:flags['ORISON_SURFACE_'+name]=None
    scene('surface','OrisonV2SurfaceInventory.tscn',True,flags)
    guard('after')
    (run/'batch.json').write_text(json.dumps(jobs,indent=2)+'\n',encoding='utf-8',newline='\n')
    launch="$ErrorActionPreference = 'Stop'\nSet-Location -LiteralPath 'C:/PleaseRemainOnTheLine'\n& 'C:/Users/nate_/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe' -NoProfile -File tools/lane.ps1 batch -BatchFile '"+str(run/'batch.json').replace('\\','/')+"' -WaitMinutes 240\nexit $LASTEXITCODE\n"
    (run/'launch.ps1').write_text(launch,encoding='utf-8',newline='\n')
    freeze['external_sha256']={name:hashlib.sha256((run/name).read_bytes()).hexdigest() for name in ['batch.json','launch.ps1']}
    (run/'SOURCE_FREEZE.json').write_text(json.dumps(freeze,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Prepared',len(jobs),'fresh-engine fail-closed stages; historical evidence only, no launch or publication')
