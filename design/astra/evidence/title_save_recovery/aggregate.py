"""Rebuild the evidence index without changing or running the Godot project."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[4]
BASE = Path(__file__).resolve().parent
FINAL = ['handlers_final', 'existing_title_final', 'existing_audio_final',
         'actual_continue_v1_final', 'actual_continue_v2_final', 'matrix_calendar_final',
         'title_capture_final', 'existing_save_matrix_final', 'm08f_reconstruction_final']
UI = ['game/scripts/game_boot.gd', 'game/scripts/ui/title_screen.gd',
      'game/scripts/ui/save_status_notice.gd']
PRODUCTION = UI + ['game/scripts/game/reality_game_state.gd',
                  'game/scripts/game/reality_save_storage.gd', 'game/scripts/game/campaign_clock.gd']
cases = {}
for path in sorted((BASE / 'runtime').glob('*/receipt.json')):
    cases[path.parent.name] = json.loads(path.read_text(encoding='utf-8'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], stderr=subprocess.DEVNULL)

def recorded_source(name, path):
    snapshot = cases[name]['before']
    if path in snapshot['files']:
        artifact = BASE / 'runtime' / name / 'source_before_sources' / path
        raw = artifact.read_bytes()
        assert hashlib.sha256(raw).hexdigest() == snapshot['files'][path], (name, path)
        provenance = {'kind': 'raw_source_copy', 'raw_sha256': snapshot['files'][path],
                      'artifact': artifact.relative_to(ROOT).as_posix()}
    else:
        # The runner copies changed sources only. An absent unchanged dependency
        # is identified by its recorded HEAD and Git blob, never a made-up raw SHA.
        diff = (BASE / 'runtime' / name / 'source_before.diff').read_bytes()
        assert ('diff --git a/' + path + ' b/' + path).encode() not in diff, (name, path)
        ref = snapshot['head'] + ':' + path
        raw = git('show', ref)
        provenance = {'kind': 'unchanged_committed_dependency', 'source_head': snapshot['head'],
                      'git_blob': git('rev-parse', ref).decode().strip(),
                      'git_blob_content_sha256': hashlib.sha256(raw).hexdigest()}
    provenance['lf_content_sha256'] = hashlib.sha256(raw.replace(b'\r\n', b'\n')).hexdigest()
    return provenance

entries = []
for name, receipt in cases.items():
    if name.startswith('legacy_'):
        ruling = 'EXPECTED_RED_OLD_UI_OR_BOOT_LOGIC' if receipt['actual_exit'] == 1 else 'UNEXPECTED_CONTROL_OUTCOME'
    elif name == 'title_capture_initial':
        ruling = 'HARNESS_PARSE_FAILURE_TIMEOUT_124_NO_CAPTURE_PROOF'
    elif name == 'title_capture_typed':
        ruling = 'STATE_AND_IMAGE_WRITES_PASS_VISUAL_CORRECTIONS_REQUIRED'
    elif name in FINAL:
        ruling = 'FINAL_RECORDED_SCOPE_GREEN' if receipt['actual_exit'] == 0 else 'FINAL_FAILURE'
    else:
        ruling = 'EARLIER_COMPOSITION_RETAINED_NOT_SILENTLY_PROMOTED_TO_FINAL'
    entries.append({'case': name, 'receipt': f'design/astra/evidence/title_save_recovery/runtime/{name}/receipt.json',
        'receipt_sha256': sha(BASE / 'runtime' / name / 'receipt.json'),
        'source_head_before': receipt['before']['head'], 'source_head_after': receipt['after']['head'],
        'actual_exit': receipt['actual_exit'], 'expected_exit': receipt['expected_exit'],
        'elapsed_seconds': receipt['elapsed_seconds'], 'runtime_source_unchanged': receipt['runtime_source_unchanged'],
        'ruling': ruling, 'summary_lines': receipt['summary_lines'],
        'diagnostic_headers': receipt['diagnostic_headers']})

missing = [name for name in FINAL if name not in cases]
failed = [name for name in FINAL if name in cases and
          (cases[name]['actual_exit'] != 0 or not cases[name]['runtime_source_unchanged'])]
anchor = cases.get('matrix_calendar_final', cases['handlers_final'])
runtime_hashes = {p: anchor['before']['files'][p] for p in PRODUCTION if p in anchor['before']['files']}
provenance = {name: {p: recorded_source(name, p) for p in PRODUCTION} for name in FINAL if name in cases}
anchor_content = provenance['matrix_calendar_final']
same_production = all(provenance[name][p]['lf_content_sha256'] == anchor_content[p]['lf_content_sha256']
                      for name in FINAL if name in cases for p in PRODUCTION)
current_matches = all((ROOT / p).is_file() and
    hashlib.sha256((ROOT / p).read_bytes().replace(b'\r\n', b'\n')).hexdigest() == anchor_content[p]['lf_content_sha256']
    for p in PRODUCTION) and all(sha(ROOT / p) == digest for p, digest in runtime_hashes.items())
final_control_names = ['legacy_title_final_red', 'legacy_boot_final_red']
controls_good = all(name in cases and cases[name]['actual_exit'] == 1
                    and cases[name]['runtime_source_unchanged']
                    and any('preserved source compiled and constructed' in line for line in cases[name]['summary_lines'])
                    and any('failures=2' in line for line in cases[name]['summary_lines'])
                    for name in final_control_names)
visual_path = BASE / 'runtime/title_capture_final/visual_review.json'
visual = json.loads(visual_path.read_text(encoding='utf-8')) if visual_path.is_file() else {}
visual_good = (visual.get('all_10_viewed', False) and len(visual.get('frames', [])) == 10
    and all(sha(BASE / 'runtime/title_capture_final/frames' / item['frame']) == item['sha256']
            for item in visual.get('frames', [])))
result = {
    'schema': 'astra.title_save_recovery.aggregate.v2',
    'status': 'GREEN_FOR_RECORDED_ENGINEERING_AND_UI_SCOPE' if not missing and not failed
              and same_production and controls_good and visual_good else 'INCOMPLETE_OR_SOURCE_REVIEW_REQUIRED',
    'final_case_names': FINAL, 'missing_final_cases': missing, 'failed_final_cases': failed,
    'final_old_source_controls_compiled_and_failed_intended_checks': controls_good,
    'final_cases_share_production_content': same_production,
    'source_head': anchor['before']['head'], 'tested_production_sha256': runtime_hashes,
    'current_working_sources_still_match_final_tested': current_matches,
    'final_visual_receipt': visual_path.relative_to(ROOT).as_posix(),
    'final_visual_receipt_sha256': sha(visual_path) if visual_path.is_file() else None,
    'final_ten_images_directly_viewed_and_hashes_match': visual_good,
    'source_provenance': provenance,
    'source_comparison_scope': 'The runner copied changed files with raw SHA256 and retained the complete diff. Unchanged dependencies use the recorded HEAD Git blob. Cross-commit content equality normalizes CRLF to LF only; no other whitespace is removed. Current files additionally match every available anchor raw SHA256. No original raw working-tree hash is invented for an unchanged dependency.',
    'legacy_sources_manifest': 'design/astra/evidence/title_save_recovery/legacy_sources/manifest.json',
    'ownership': 'Title/GameBoot/save-notice UI and actual matrix extension by branch_forensics; storage/RealityState by authority_debt; calendar authority by root. No staging or commit by branch_forensics.',
    'meaning': {
        'handlers': 'Actual connected buttons, title logic, GameBoot gates, and real storage; only final scene operation intercepted for repeatable failures. Includes global notice lifecycle, real focus actions, explicit developer visibility, and artifact-only first creation.',
        'actual_continue': 'Separate real scene change through GameBoot into CampaignShell for both selected roots. Real world/player, exact calendar plus selected first-shift/core-loop facts, clock binding and title retirement checked. Explicit campaign-time freeze prevents measurement drift.',
        'matrix': 'Actual V1->V1, V2->V2, V1->V2, V2->V1 save/load/reconstruction. Each direction seeds Nov10 1928 23:59 +181.5 minutes and verifies exact saved epoch/start/elapsed and real destination binding to Sunday Nov11 03:00:30; 30 assertions if green.',
        'existing_consumers': 'Existing OpenShiftSaveMatrix17 and M08F composed reconstruction29 run on the committed final storage source in separate fresh profiles, with exact child exits and stderr retained.',
        'captures': 'Ten real title load/action states, checked PNG writes, all images inspected directly. Still capture suppresses music and discloses temp/journal/scene-operation failure seams. No human acceptance, physical traversal or performance release claim.',
    },
    'diagnostics': {
        'headless': 'Final handler/title/audio/V2 Continue expected clean. V1 Continue and matrix retain the known cam_noel_witches wall-placement warning; matrix additionally deliberately tests an invalid selector.',
        'windowed': 'Retain five missing TikTok/Epic Vulkan overlay manifest ERRORs, registry and duplicate OBS warnings, and two RGB8 conversion warnings where recorded. These are not hidden or mislabeled as warning-free graphics.',
        'harness_red': 'Initial capture could not infer state_matches type, then unchanged serial runner timed out at60seconds with124. This is a capture-harness failure, not intended product red evidence.',
    },
    'limits': [
        'Storage is crash-recoverable, not a claim of power-loss durability or atomic Windows replacement. Storage interruption/restart proof belongs to authority_debt evidence.',
        'Before reload, a failed first creation with only an uncommitted candidate can offer Begin as a retry but never Continue. Actual reload protects those artifacts and requires explicit New; no temp promotion is inferred.',
        'No archive-restore UI is provided. Replacement copy explicitly says archived files cannot be resumed from this menu.',
        'GameBoot boolean success means the checked scene operation accepted the request; actual-world observations are separate.',
        'Initial actual Continue receipts before final storage and UI refinements are retained separately; only final-named runs support the final composition.',
        'Elapsed values are process wall time on Godot4.7.1 RTX4080/i7-13700KF, not release performance measurements.',
    ],
    'cases': entries,
}
(BASE / 'receipt.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: result[k] for k in ['status', 'missing_final_cases', 'failed_final_cases',
      'final_cases_share_production_content', 'current_working_sources_still_match_final_tested']}, indent=2))
