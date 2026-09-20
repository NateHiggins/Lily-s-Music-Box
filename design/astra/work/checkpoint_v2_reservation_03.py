"""Select and stage exact named reservation correction paths; never stage other work."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'design/astra/work/v2_reservation_checkpoint_03'
sha = lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
git = lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)
assert git('rev-parse','HEAD').decode().strip()=='02fcb18a209624c9b609b65fb44b05b45c65de09'
assert not git('diff','--cached','--name-only').strip()
files = [
 'game/scripts/building/orison_v2_blockout.gd',
 'game/scripts/building/orison_v2_runtime_root.gd',
 'game/tests/orison_v2_reservation_display_test.gd',
 'game/tests/OrisonV2ReservationDisplayTest.tscn',
 'design/astra/DECISION_LOG.md','design/astra/LIVE_STATE.json',
 'design/astra/reviews/v2_reservation_first_run_01.json',
 'design/astra/reviews/v2_reservation_completed_03.json',
 'design/astra/work/review_v2_reservation_first_run_01.py',
 'design/astra/work/review_v2_reservation_completed_03.py',
 'design/astra/work/capture_v2_reservation_01.py',
 'design/astra/work/finalize_reservation_runtime_03.py',
 'design/astra/work/checkpoint_v2_reservation_03.py',
]
directories = [
 'design/astra/work/v2_reservation_display_01',
 'design/astra/work/v2_reservation_runtime_01',
 'design/astra/work/v2_reservation_runtime_02',
 'design/astra/work/v2_reservation_runtime_03',
 'design/astra/work/v2_reservation_checkpoint_review_01',
 'design/astra/evidence/v2_reservation_display_02',
 'design/astra/evidence/v2_reservation_display_03',
 'design/astra/evidence/vulkan_composed/runs/reservation_operator_view_v2_01',
 'design/astra/evidence/vulkan_composed/invocations/reservation_operator_view_v2_01',
]
for rel in directories:
    assert (ROOT/rel).is_dir(), rel
    files += [p.relative_to(ROOT).as_posix() for p in (ROOT/rel).rglob('*') if p.is_file() and not {'APPDATA','__pycache__'}.intersection(p.parts)]
files = sorted(set(files))
assert all((ROOT/rel).is_file() for rel in files)
tracked_game = set(git('diff','--name-only','--','game','tools','art').decode().splitlines())
assert tracked_game==set(files[:0]+['game/scripts/building/orison_v2_blockout.gd','game/scripts/building/orison_v2_runtime_root.gd']),tracked_game
OUT.mkdir(exist_ok=False)
selected = {rel:sha(ROOT/rel) for rel in files}
(OUT/'selection.json').write_text(json.dumps({'parent':git('rev-parse','HEAD').decode().strip(),'files_sha256':selected},indent=2)+'\n',encoding='utf-8')
for offset in range(0,len(files),40):
    subprocess.run(['git','-c','core.autocrlf=false','add','-f','--',*files[offset:offset+40]],cwd=ROOT,check=True,capture_output=True)
staged = set(git('diff','--cached','--name-only','-z').decode().rstrip('\x00').split('\x00'))
assert staged==set(files),(staged-set(files),set(files)-staged)
for rel,value in selected.items():
    assert hashlib.sha256(git('show',':'+rel)).hexdigest()==value,rel
print(json.dumps({'status':'EXACT_NAMED_STAGE_VERIFIED','files':len(files),'bytes':sum((ROOT/r).stat().st_size for r in files),'selection_sha256':sha(OUT/'selection.json')}))
