"""Replay focused runtime evidence and bind directly reviewed matched captures."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT/'design/astra/work/v2_reservation_runtime_03'
sys.path.insert(0,str(BASE/'runtime'))
import run
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text(encoding='utf-8'))
seal = read(BASE/'seal.json')
for rel,value in seal['all_package_files_sha256'].items():
    assert sha(BASE/rel) == value, rel
plan, manifest = run.package()
reviews = []
for spec in plan['sequence']:
    out = run.EVIDENCE/'runs'/spec['run_name']
    result = read(out/'result.json')
    run.verify_artifacts(out,result)
    probe = read(out/'shots'/spec['receipt_name'])
    text = lambda rel:(out/rel).read_text(encoding='utf-8-sig',errors='replace')
    actual = run.assess.assess(probe,text('godot.stdout.log'),text('godot.stdout.log.stderr'),text('runner.stdout.log')+'\n'+text('runner.stderr.log'),result['actual_runner_exit'],result['before']==result['after'],result['pid_ancestry_verified'],result['before']['engine_binaries']==result['after']['engine_binaries'],spec['run_name'])
    assert actual == result['assessment'] and actual['control_contract_exit']==0
    lane = run.classify_lane(read(out/'process_observations.json'),probe['pid'],result['wrapper_pid'])
    assert lane == result['lane_contract'] and lane['lane_contract_exit']==0
    restored = read(run.EVIDENCE/(spec['run_name']+'.restoration.json'))
    _, sources = run.owner_sources(plan,'01_candidate')
    run.require_restoration(restored,{rel:sha(p) for rel,p in sources.items()})
    reviews.append({'phase':spec['run_name'],'native_exit':result['actual_runner_exit'],'passed':actual['passed'],'total':actual['total'],'artifact_count':len(result['artifacts']),'result_sha256':sha(out/'result.json'),'restoration_sha256':sha(run.EVIDENCE/(spec['run_name']+'.restoration.json'))})

binding = read(BASE/'capture_binding.json')
capture = ROOT/binding['result']
result = read(capture)
assert result['actual_engine_exit']==result['gate']['diagnostic_gate_exit']==0
assert result['source_unchanged'] and result['before']==result['after']
for rel,value in result['artifacts'].items():
    assert sha(capture.parent/rel)==value,rel
probe = read(capture.parent/'frames/probe.json')
assert len(probe['checks'])==21 and all(c['passed'] for c in probe['checks'])
baseline = ROOT/binding['matched_baseline']['result']
assert sha(baseline)==binding['matched_baseline']['result_sha256']
baseline_probe = read(baseline.parent/'frames/probe.json')
assert probe['checks']==baseline_probe['checks']
control = probe['owned_controls'][0]
for key,wanted in [('camera_position',binding['expected_camera_origin']),('capture_anchor_position',binding['expected_operator_position'])]:
    assert all(abs(a-b)<1e-5 for a,b in zip(control[key],wanted))
assert [row['path'].split('/')[-1] for row in control['reservation_geometry']]==binding['expected_hidden_reservations']
for current,old in zip(control['reservation_geometry'],baseline_probe['owned_controls'][0]['reservation_geometry']):
    assert current['visible_in_tree'] is False and old['visible_in_tree'] is True
    assert current['collision_descendants']==[]
    for key in current:
        if key not in ('path','visible_in_tree'): assert current[key]==old[key],key
invocation_path = ROOT/'design/astra/evidence/vulkan_composed/invocations/reservation_operator_view_v2_01/invocation.json'
invocation = read(invocation_path)
assert invocation['status']=='EXACT_FIXTURE_RESTORED' and invocation['source_before']==invocation['source_after']
assert invocation['lane_contract']['lane_contract_exit']==0 and invocation['actual_command_exit']==0
assert invocation['result_sha256']==sha(capture)
assert all(sha(ROOT/rel)==value for rel,value in invocation['source_after'].items())
images = {}
for row in probe['captures']:
    p = Path(row['file'])
    data = p.read_bytes()
    size = [int.from_bytes(data[16:20],'big'),int.from_bytes(data[20:24],'big')]
    assert size==binding['expected_captures'][row['name']] and row['written']
    images[row['name']]={'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p),'size':size,'directly_viewed_by_root':True}
review = {'status':'FOCUSED_RUNTIME_AND_MATCHED_CAPTURE_PASS_VISUAL_DEBT_REMAINS','seal_sha256':sha(BASE/'seal.json'),'runs':reviews,'capture':{'result_sha256':sha(capture),'artifact_count':len(result['artifacts']),'checks':21,'invocation_sha256':sha(invocation_path),'images':images},'visual_findings':['Translucent reservation volumes no longer cross the desk in either directly viewed image.','Terminal face and desktop support-desk prompt remain visible.','Coarse furniture masses, dark lighting and unfinished handset remain visible; no final art acceptance.'],'scope':'Display-only correction on 78 existing non-colliding nodes; unchanged geometry/collision/semantics, terminal39 regression and controlled21 capture. No traversal, performance, human acceptance or release claim.','historical_runtime02_remains_failed':True}
destination = ROOT/'design/astra/reviews/v2_reservation_completed_03.json'
destination.write_text(json.dumps(review,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'status':review['status'],'runtime_artifacts':sum(r['artifact_count'] for r in reviews),'capture_artifacts':len(result['artifacts']),'review_sha256':sha(destination)}))
