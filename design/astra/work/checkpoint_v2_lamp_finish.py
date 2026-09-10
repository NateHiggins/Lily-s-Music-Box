from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[3]
paths=['game/scripts/building/orison_v2_lamp_atmosphere.gd','game/shaders/lamp_optical_air.gdshader','game/tests/orison_v2_lamp_review.gd']
packet=root/'design/astra/evidence/v2_lamp_finish_01'
receipt={'base_head':'f42e055','status':'BASE_BEAM_TUNED_FULL_OPTICAL_ACCEPTANCE_OPEN',
 'source_sha256':{p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths},
 'evidence_sha256':{p.relative_to(packet).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
 for p in sorted(packet.rglob('*')) if p.is_file() and p.name!='source_hashes.json'}}
(packet/'source_hashes.json').write_text(json.dumps(receipt,indent=2)+'\n')
path=root/'design/astra/LIVE_STATE.json'
state=json.loads(path.read_text())
current=state['current_v2_completion_resume']
current['latest_committed_head']='f42e055'
current['lamp_tuning']='V2 base energy 1.5, finite aperture .018 m, neutral scattering. Frozen thermal/pose review, 32 composed checks, 73-waypoint physical repair pass; stderr empty. Forced composed voxel compute median .019744 ms/max .060608 ms; total-effect GPU overhead not established. Base beam tuning checkpoint, not complete cellular/material optical acceptance.'
entry='evidence/v2_lamp_finish_01/README.md'
if entry not in current['evidence']:current['evidence'].append(entry)
current['next']='Continue V2 earned conversation/recurrence and physical manifestation placement; retain full optical material, human visual and total-effect performance gates as open.'
path.write_text(json.dumps(state,indent=2)+'\n')
paths+=['design/astra/LIVE_STATE.json','design/astra/evidence/v2_lamp_finish_01','design/astra/work/checkpoint_v2_lamp_finish.py']
subprocess.run(['git','add','--',*paths],cwd=root,check=True)
subprocess.run(['git','-c','core.whitespace=cr-at-eol','diff','--cached','--check'],cwd=root,check=True)
