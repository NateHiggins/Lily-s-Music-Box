"""Aggregate immutable case receipts; does not run Godot or edit game files."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'design/astra/evidence/world_time_coherence'
OWNED = [
    'game/project.godot',
    'game/scripts/game/campaign_clock_driver.gd',
    'game/scripts/building/day_night_director.gd',
    'game/scripts/building/building_root.gd',
    'game/scripts/building/orison_v2_runtime_root.gd',
    'game/scripts/characters/schedule_director.gd',
    'game/scripts/game/open_shift_radiator_ecosystem.gd',
    'game/scripts/game/open_shift_situation.gd',
    'game/scripts/characters/porter_actor.gd',
    'game/scripts/reality/npc_observation_ledger.gd',
    'game/scripts/dream/campaign_shell.gd',
    'game/tests/WorldTimeCoherenceTest.tscn',
    'game/tests/world_time_coherence_test.gd',
    'game/tests/orison_v2_presence_ledger_test.gd',
    'game/tests/orison_v2_two_root_matrix_test.gd',
    'game/tests/open_shift_save_matrix_test.gd',
    'game/tests/schedule_live_probe.gd',
]
ACCEPTED_GREEN = ['focused_initial', 'situation', 'authority', 'ignore', 'abandon',
                  'save_matrix_final', 'presence_actual_scene', 'm08f', 'm11a', 'two_root']
RULINGS = {
    'legacy_duration_exact_exit': 'EXPECTED_RED: preserved old source compiles; three duration/stamp assertions fail; child exit 3 preserved',
    'legacy_presence_exact_exit': 'EXPECTED_RED: preserved old V2 source compiles; Saturday evening presence assertion fails; child exit 1 preserved',
    'legacy_duration_red': 'SUPERSEDED_INSTRUMENTATION: intended assertion failures retained; original PowerShell invocation normalized nonzero child status to 1; use exact-exit repeat',
    'legacy_presence_red': 'SUPERSEDED_INSTRUMENTATION: intended assertion failure retained; original PowerShell invocation omitted explicit exit propagation; use exact-exit repeat',
    'save_matrix': 'RED_HARNESS: fresh-profile save parent missing; actual exit 16',
    'save_matrix_directory_green': 'PARTIAL_REPAIR_RED: checked directory creation removes all write warnings; JSON schema integer-versus-float equality still fails 16 assertions',
    'save_matrix_schema_diagnostic': 'DIAGNOSTIC_RED: exact JSON number-type mismatch printed; no production state loss established by that mismatch',
    'presence': 'INVOCATION_ERROR: nonexistent mixed-case scene path; superseded by presence_actual_scene',
}
scopes = {
    'focused_initial': '27 focused checks: multi-day duration; deterministic advancement ownership; V2 schedule presence; conservative legacy annotations/save-load; actual V1/V2 invalid-calendar refusal; real V2 consumer binding',
    'two_root': '26 checks: initial real V1/V2 provider/owner assertions and actual four-direction CampaignShell semantic reconstruction. Does not assert exact calendar facts in each direction.',
    'save_matrix_final': '17 checks of isolated OpenShift semantic assembly/save-load; not actual root reconstruction',
    'presence_actual_scene': '17 focused presence/ledger checks; its cross-root read helper reuses a save document and is not real-root reconstruction',
    'm08f': '29 checks of composed V2 runtime and lifecycle; no visual or performance claim',
    'm11a': '40 checks of first exterior cell; not whole exterior route acceptance',
}
cases = []
for path in sorted((BASE / 'runtime').glob('*/receipt.json')):
    raw = path.read_bytes()
    receipt = json.loads(raw)
    name = receipt['case']
    cases.append({
        'case': name,
        'receipt': path.relative_to(ROOT).as_posix(),
        'receipt_sha256': hashlib.sha256(raw).hexdigest(),
        'actual_exit': receipt['actual_exit'],
        'elapsed_seconds': receipt['elapsed_seconds'],
        'source_unchanged_during_case': receipt['source_unchanged'],
        'summary_lines': receipt['summary_lines'],
        'diagnostic_headers': receipt['diagnostic_headers'],
        'ruling': 'GREEN_WITH_SCOPED_DIAGNOSTICS' if name in ACCEPTED_GREEN else RULINGS[name],
        'scope': scopes.get(name, 'See exact scene assertions and raw retained outputs'),
    })
latest = json.loads((BASE / 'runtime/two_root/receipt.json').read_text())
focused = json.loads((BASE / 'runtime/focused_initial/receipt.json').read_text())
core = [p for p in OWNED if not p.startswith('game/tests/')]
result = {
    'schema': 'astra.world_time.aggregate.v1',
    'status': 'GREEN_FOR_RECORDED_SCOPE_WITH_EXPLICIT_DEBT',
    'source_head': latest['before']['head'],
    'final_tested_diff_sha256': latest['before']['diff_sha256'],
    'source_hashes': {p: latest['before']['files'][p] for p in OWNED},
    'owned_runtime_sources_same_in_focused_and_final_matrix': all(
        latest['before']['files'][p] == focused['before']['files'][p] for p in core),
    'source_composition': 'Dirty composed worktree including root-owned CampaignClock/calendar and other agents historical/capture work; complete diff and hash snapshots retained per run. No commit or staging by this agent.',
    'advance_owner': 'CampaignTime autoload (CampaignClockDriver); exactly one advance per process frame with any eligible live building_root',
    'pause_policy': 'No eligible waking root, paused SceneTree, explicit CAMPAIGN_TIME_FREEZE=1, or deterministic set_frozen_for_tests prevents automatic advancement. Sky presentation hooks do not freeze this owner.',
    'runtime_context': 'Headless Godot 4.7.1, RTX 4080 / i7-13700KF. Process wall time only; no visual acceptance or performance release evidence.',
    'isolation': 'Unique task-local fresh APPDATA per run; harness creates checked save parent itself; no user profile saves accessed; unchanged tools/run_godot_serial.ps1; serial lane explicitly released to dream_forensics.',
    'diagnostic_rulings': {
        'focused_initial': 'Two expected invalid-calendar refusal errors from deliberately corrupted calendar fixtures; no unclassified warnings/errors or retained resources.',
        'two_root': 'One expected invalid-selector warning; five existing no-legal-wall warnings for cam_noel_witches. No save warnings, engine errors, or object/resource retention diagnostics.',
        'other_final_greens': 'No diagnostic headers in retained stderr.',
    },
    'known_limits_and_debt': [
        'Exact calendar epoch/start/elapsed preservation through all four real-root directions remains unasserted by current 26-check matrix. Prepared patch is not applied or run.',
        'Legacy wrapped timestamps retain original values and an unresolved historical-day annotation. No epoch/day is invented.',
        'A legacy pending porter intent with ambiguous eligible/departed/arrived deadline can remain held indefinitely; explicit new observed-fact reanchoring is recoverability debt. Migration is not claimed fully playable.',
        'Invalid calendar refuses world publication and composition; CampaignShell currently provides no player-facing recovery UI.',
        'DAYNIGHT=0 still disables resident dispatch by legacy default when SCHEDULE is unspecified, preserving old harness behavior. It does not freeze CampaignTime or change minute_now queries.',
        'Focused presence fixture retains the known absent-resident in_home_hearing gap; this change does not repair that observation capability.',
        'M11A green concerns the first exterior cell only; no broad M11 route or human acceptance claim.',
    ],
    'pending_matrix_patch': 'design/astra/reviews/pending_two_root_calendar.json',
    'cases': cases,
}
(BASE / 'receipt.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'cases': len(cases), 'core_runtime_stable': result['owned_runtime_sources_same_in_focused_and_final_matrix'], 'receipt': str(BASE / 'receipt.json')}))
