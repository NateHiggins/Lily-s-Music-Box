from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[3]
paths=['game/scripts/building/orison_v2_runtime_root.gd','game/scripts/building/orison_v2_lamp_atmosphere.gd','game/scripts/lamp/lamp_optical_voxel_field.gd','game/scripts/lamp/carried_lamp_observation.gd','game/shaders/lamp_beam_fog.gdshader','game/shaders/lamp_field.compute','game/shaders/lamp_optical_sample.gdshaderinc','game/shaders/lamp_optical_air.gdshader','game/tests/OrisonV2LampReview.tscn','game/tests/orison_v2_lamp_review.gd']
packet=root/'design/astra/evidence/v2_lamp_integration_01'
receipt={'base_head':'d32cbba','optical_source_head':'4aa4585','source_sha256':{p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths},'status':'PARTICIPATING_AIR_INTEGRATED_FULL_OPTICAL_POLISH_AND_PERFORMANCE_OPEN','ecological_field_modified':False,'building_default':'v1'}
(packet/'source_hashes.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
state_path=root/'design/astra/LIVE_STATE.json'
state=json.loads(state_path.read_text())
current=state['current_v2_completion_resume']
current['latest_committed_head']='d32cbba'
current['lamp_optics']='V2 photographic overlay retired; shared 48x48x64 instantaneous field drives bounded participating air, with native scene shadows. Native Y-axis cone alignment corrected while preserving world bounds/density. Final focused run 18/0 and empty stderr; GPU off-volume zero and six newly tracked resources released. L1 controller/save, particles, remaining material families, tuning and stable performance remain open; not full optical acceptance.'
entry='evidence/v2_lamp_integration_01/README.md'
if entry not in current['evidence']:current['evidence'].append(entry)
current['next']='Continue owner-prioritized flashlight: complete particle and material-family response, deterministic controller/save adapter, stronger visual tuning and stable matched GPU performance. Current field contributes participating air only. Then resume full V2 golden shift and outstanding completion gates.'
state_path.write_text(json.dumps(state,indent=2)+'\n')
paths+=['design/astra/LIVE_STATE.json','design/astra/evidence/v2_lamp_integration_01','design/astra/work/checkpoint_v2_lamp.py']
subprocess.run(['git','add','--',*paths],cwd=root,check=True)
subprocess.run(['git','-c','core.whitespace=cr-at-eol','diff','--cached','--check'],cwd=root,check=True)
subprocess.run(['git','diff','--cached','--stat'],cwd=root,check=True)
