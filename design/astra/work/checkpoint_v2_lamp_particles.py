from pathlib import Path
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parents[3]
paths = [
    'game/scripts/building/orison_v2_lamp_atmosphere.gd',
    'game/scripts/building/orison_v2_runtime_root.gd',
    'game/scripts/device/service_set_carrier.gd',
    'game/scripts/device/service_set_prop.gd',
    'game/scripts/game/reality_game_state.gd',
    'game/scripts/lamp/carried_lamp_observation.gd',
    'game/scripts/player/player_controller.gd',
    'game/scripts/lamp/lamp_optical_state.gd',
    'game/scripts/lamp/lamp_optical_snapshot.gd',
    'game/scripts/lamp/carried_lamp_optical_driver.gd',
    'game/shaders/lamp_optical_dust.gdshader',
    'game/tests/orison_v2_lamp_review.gd',
    'game/tests/orison_v2_two_root_matrix_test.gd',
    'game/tests/CarriedLampOpticalDriverTest.tscn',
    'game/tests/carried_lamp_optical_driver_test.gd',
]
packet = root / 'design/astra/evidence/v2_lamp_particles_01'
receipt = {
    'base_head': '63f89f3',
    'optical_source_head': '4aa4585',
    'status': 'AIR_DUST_CONTROLLER_SAVE_LENS_INTEGRATED_VISUAL_PERFORMANCE_OPEN',
    'source_sha256': {p: hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths},
    'building_default': 'v1',
    'evidence_sha256': {str(p.relative_to(packet)).replace('\\','/'): hashlib.sha256(p.read_bytes()).hexdigest()
                        for p in sorted(packet.rglob('*')) if p.is_file() and p.name != 'source_hashes.json'},
}
(packet/'source_hashes.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
state_path = root/'design/astra/LIVE_STATE.json'
state = json.loads(state_path.read_text())
current = state['current_v2_completion_resume']
current['latest_committed_head'] = '63f89f3'
current['lamp_optics'] = ('Shared voxel air and world-space dust now consume the preserved thermal controller; '
    'real spotlight and modeled lens follow the same state. Optional validated disk snapshots restore across '
    'all four V1/V2 directions. Final composed 31/0, focused driver 22/0, save recovery 195/195, matrix 42/0. '
    'Photographic overlay absent; native mesh shadows retained; ecological field untouched. '
    'Full visual/material/performance acceptance remains open. See v2_lamp_particles_01 packet.')
entry = 'evidence/v2_lamp_particles_01/README.md'
if entry not in current['evidence']: current['evidence'].append(entry)
current['next'] = ('Continue flashlight with frozen-state brightness/material comparisons, remaining material '
    'families, visual tuning and stable GPU performance. Then resume full V2 golden shift and completion/default gates.')
state_path.write_text(json.dumps(state,indent=2)+'\n')
paths += ['design/astra/LIVE_STATE.json', 'design/astra/evidence/v2_lamp_particles_01',
          'design/astra/work/checkpoint_v2_lamp_particles.py']
subprocess.run(['git','add','--',*paths],cwd=root,check=True)
subprocess.run(['git','-c','core.whitespace=cr-at-eol','diff','--cached','--check'],cwd=root,check=True)
subprocess.run(['git','diff','--cached','--stat'],cwd=root,check=True)
