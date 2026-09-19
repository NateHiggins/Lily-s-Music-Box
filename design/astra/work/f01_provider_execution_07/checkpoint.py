"""Stage the named integration evidence, excluding private runtime caches."""
from pathlib import Path
import json, subprocess
ROOT = Path(__file__).resolve().parents[4]
state_path = ROOT/'design/astra/LIVE_STATE.json'
state = json.loads(state_path.read_text(encoding='utf-8-sig'))
resume = state['current_v2_completion_resume']
resume['latest_committed_head'] = '37f0307'
resume['connected_route'] = '37f0307: 18 continuous player-input waypoints, building/street/bodega/return; actual door/counter targeting and wrong-shop inventory authority pass.'
resume['f01_provider'] = 'Exact optional provider integrated after 32/30/32 controlled comparison, paired 305-check/18-image captures, and actual Windows packed-resource validation. Legacy provider and V1 selector defaults retained.'
resume['next'] = 'V2 construction seam/Passage and actual residency, then remaining golden-shift and structural dependencies.'
resume['evidence'].append('evidence/f01_provider_execution_07/README.md')
state_path.write_text(json.dumps(state, indent=2)+'\n', encoding='utf-8')
paths = [state_path]
for name in ['f01_provider_execution_06', 'f01_provider_execution_07', 'f01_provider_capture_02', 'f01_provider_capture_03', 'f01_provider_capture_04', 'f01_provider_export_01']:
    paths += [p for p in (ROOT/'design/astra/work'/name).glob('*') if p.is_file()]
evidence = ROOT/'design/astra/evidence'
for name in ['f01_provider_execution_06', 'f01_provider_execution_07', 'f01_provider_export_01', 'f01_provider_visual_review_01']:
    folder = evidence/name
    paths += [p for p in folder.glob('*') if p.is_file()]
    if 'execution' in name:
        paths += [p for p in folder.glob('*/*') if p.is_file()]
for name in ['f01_provider_legacy_02', 'f01_provider_legacy_03', 'f01_provider_owner_first_cells_04']:
    for kind in ['runs', 'invocations']:
        folder = evidence/'vulkan_composed'/kind/name
        paths += [p for p in folder.glob('*') if p.is_file()]
        paths += [p for p in (folder/'frames').glob('*') if p.is_file()]
relative = sorted({str(p.relative_to(ROOT)).replace('\\','/') for p in paths})
subprocess.run(['git','add','--',*relative], cwd=ROOT, check=True)
print('Named evidence files:',len(relative),'bytes:',sum((ROOT/p).stat().st_size for p in relative))
