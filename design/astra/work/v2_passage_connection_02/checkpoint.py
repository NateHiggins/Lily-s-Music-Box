from pathlib import Path
import hashlib, json, subprocess

ROOT = Path(__file__).resolve().parents[4]
EVIDENCE = ROOT/'design/astra/evidence/v2_passage_connection_02'
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
sources = ['game/scripts/building/orison_v2_passage_region.gd',
    'game/scripts/building/orison_v2_runtime_root.gd',
    'game/tests/OrisonV2PassageRouteTest.tscn',
    'game/tests/orison_v2_passage_route_test.gd',
    'game/tests/orison_v2_connected_exterior_route_test.gd',
    'game/tests/orison_v2_two_root_matrix_test.gd']
for stem, final in [('route_04', 'V2 PASSAGE ROUTE: 36 waypoints; 0 failures'),
                    ('composition', 'CONNECTED WORLD: 374 checks; 0 failures'),
                    ('bodega_regression', 'CONNECTED EXTERIOR ROUTE: 18 waypoints; 0 failures')]:
    assert final in (EVIDENCE/(stem+'.log')).read_text()
    assert (EVIDENCE/(stem+'.log.stderr')).stat().st_size == 0
assert 'ORISON V2 TWO-ROOT MATRIX: PASS' in (EVIDENCE/'save_matrix_actual.log').read_text()
assert (EVIDENCE/'cache_verify.log.stderr').stat().st_size == 0
(EVIDENCE/'source_hashes.json').write_text(json.dumps({p:sha(ROOT/p) for p in sources},indent=2)+'\n')
state_path = ROOT/'design/astra/LIVE_STATE.json'
state = json.loads(state_path.read_text())
resume = state['current_v2_completion_resume']
resume['latest_committed_head'] = '13f2070'
resume['passage_route'] = 'Real V2 resident arcade integration: 13 geometry cells, source doors/lights/signs/hours, shared hardware counter. 36 continuous input waypoints with physical capsule acquisition and return; 374 composition checks; 34-check disk/calendar/inventory matrix in all four V1/V2 directions; 18-waypoint bodega regression. Shared shop-service initialization repaired.'
resume['next'] = 'Actual asynchronous residency with physical-state and authority reconstruction; construction shed/world edges and remaining golden-shift/structural dependencies. Arcade and full-width street are now connected resident composition.'
resume['evidence'].extend(['evidence/v2_passage_connection_01/README.md','evidence/v2_passage_connection_02/README.md'])
state_path.write_text(json.dumps(state,indent=2)+'\n')
paths = [ROOT/p for p in sources]+[state_path,Path(__file__),ROOT/'design/astra/work/f01_provider_export_01/verify_floor_cache.gd']
for p in list(paths):
    uid = Path(str(p)+'.uid')
    if p.suffix == '.gd' and uid.exists(): paths.append(uid)
paths += [p for p in EVIDENCE.rglob('*') if p.is_file() and 'cache_before' not in p.relative_to(EVIDENCE).parts]
subprocess.run(['git','add','--',*[p.relative_to(ROOT).as_posix() for p in paths]],cwd=ROOT,check=True)
print('Staged',len(paths),'named source/evidence files; generated old caches retained unstaged')
